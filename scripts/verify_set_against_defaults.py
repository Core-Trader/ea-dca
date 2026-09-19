#!/usr/bin/env python3
"""
verify_set_against_defaults.py — catch silent .set drift from an EA's compiled defaults.

Root cause this exists to prevent (found 2026-09-20): a new study's own "default"
.set file was built by copying an old reference .set that predated a later fix to
the EA's actual compiled default (InpBBAppliedPrice). Nothing caught the mismatch
for ~40 backtests. This script makes that mismatch visible in one command, before
a single backtest runs.

This tool does NOT decide what's "wrong" — many .set files deliberately override
the compiled default (magic number, risk caps, symbol-specific tuning) and that's
fine. Its only job is to make every difference VISIBLE so a human/AI consciously
accepts or rejects it, instead of inheriting it silently from a stale copy-paste.

Usage:
    python scripts/verify_set_against_defaults.py <path-to-ea.mq5> <path-to-file.set> [more.set ...]

Exit code: 0 if every .set matches the compiled defaults exactly, 1 if any field
differs (this is intentional — wire it into a pre-study checklist, not a silent log).
"""

import re
import sys

# Native MQL5 enums not defined in this project's own .mq5 files — the two that
# actually caused the 2026-09-20 incident are ENUM_APPLIED_PRICE fields
# (InpBBAppliedPrice / InpMAAppliedPrice). Extend this table if a future EA uses
# other native enums as input types.
NATIVE_ENUMS = {
    'ENUM_APPLIED_PRICE': {
        'PRICE_CLOSE': 0, 'PRICE_OPEN': 1, 'PRICE_HIGH': 2, 'PRICE_LOW': 3,
        'PRICE_MEDIAN': 4, 'PRICE_TYPICAL': 5, 'PRICE_WEIGHTED': 6,
    },
    'ENUM_MA_METHOD': {
        'MODE_SMA': 0, 'MODE_EMA': 1, 'MODE_SMMA': 2, 'MODE_LWMA': 3,
    },
    'ENUM_LINE_STYLE': {
        'STYLE_SOLID': 0, 'STYLE_DASH': 1, 'STYLE_DOT': 2, 'STYLE_DASHDOT': 3,
        'STYLE_DASHDOTDOT': 4,
    },
    'ENUM_TIMEFRAMES': {
        'PERIOD_M1': 1, 'PERIOD_M5': 5, 'PERIOD_M15': 15, 'PERIOD_M30': 30,
        'PERIOD_H1': 16385, 'PERIOD_H4': 16388, 'PERIOD_D1': 16408,
        'PERIOD_W1': 32769, 'PERIOD_MN1': 49153,
    },
}

# Value part: a double-quoted string (may contain ; or , — matched whole, escapes
# respected) OR anything up to the next semicolon. Quoted alternative must come
# first so it wins on inputs like an info string containing embedded semicolons.
INPUT_RE = re.compile(
    r'^input\s+(\w+)\s+(\w+)\s*=\s*("(?:[^"\\]|\\.)*"|[^;]+?)\s*;',
    re.MULTILINE,
)
ENUM_BLOCK_RE = re.compile(r'enum\s+(ENUM_\w+)[^{]*?\{([^}]*)\}', re.MULTILINE | re.DOTALL)


def parse_custom_enums(mq5_text):
    """Build {enum_type_name: {member_name: int_value}} for every enum defined in the file."""
    enums = {}
    for m in ENUM_BLOCK_RE.finditer(mq5_text):
        enum_name = m.group(1)
        body = m.group(2)
        # Strip each line's trailing // comment BEFORE splitting on commas —
        # comments here routinely contain commas themselves (e.g. "1,1,1,2,3,5,8"),
        # which corrupts a naive whole-body comma-split if done first.
        comment_free_lines = [line.split('//', 1)[0] for line in body.splitlines()]
        comment_free = ','.join(comment_free_lines)
        members = {}
        next_val = 0
        for piece in comment_free.split(','):
            piece = piece.strip()
            if not piece:
                continue
            mm = re.match(r'(\w+)\s*(?:=\s*(-?\d+))?$', piece)
            if not mm:
                continue
            name = mm.group(1)
            val = int(mm.group(2)) if mm.group(2) is not None else next_val
            members[name] = val
            next_val = val + 1
        if members:
            enums[enum_name] = members
    return enums


def resolve_literal(type_name, raw_value, custom_enums):
    """Resolve a compiled default's raw text to a comparable string. Returns
    (resolved_value_str, resolvable: bool)."""
    raw_value = raw_value.strip()

    # (color)0xNNNNNN or (color)12345 casts — strip the cast, keep the number.
    cast_m = re.match(r'\((\w+)\)\s*(.+)', raw_value)
    if cast_m:
        raw_value = cast_m.group(2).strip()

    # Plain literal: number, bool, quoted string.
    if re.match(r'^-?\d+(\.\d+)?$', raw_value):
        return raw_value, True
    if raw_value in ('true', 'false'):
        return raw_value, True
    if raw_value.startswith('"') and raw_value.endswith('"'):
        return raw_value[1:-1], True

    # Symbolic constant — look it up as a member of its declared enum type first,
    # then in the native-enum table, trying every native enum if the type itself
    # isn't one we recognise (covers PERIOD_* handled elsewhere, etc.).
    if type_name in custom_enums and raw_value in custom_enums[type_name]:
        return str(custom_enums[type_name][raw_value]), True
    if type_name in NATIVE_ENUMS and raw_value in NATIVE_ENUMS[type_name]:
        return str(NATIVE_ENUMS[type_name][raw_value]), True
    for table in custom_enums.values():
        if raw_value in table:
            return str(table[raw_value]), True
    for table in NATIVE_ENUMS.values():
        if raw_value in table:
            return str(table[raw_value]), True

    return raw_value, False


def parse_mq5_defaults(mq5_path):
    with open(mq5_path, encoding='utf-8') as f:
        text = f.read()
    custom_enums = parse_custom_enums(text)

    defaults = {}
    unresolved = []
    for m in INPUT_RE.finditer(text):
        type_name, var_name, raw_value = m.group(1), m.group(2), m.group(3)
        if type_name == 'group':
            continue
        resolved, ok = resolve_literal(type_name, raw_value, custom_enums)
        defaults[var_name] = resolved
        if not ok:
            unresolved.append((var_name, type_name, raw_value))
    return defaults, unresolved


def parse_set_file(set_path):
    values = {}
    with open(set_path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(';') or '=' not in line:
                continue
            name, rest = line.split('=', 1)
            # Optimization format: Default||Start||Step||Stop||Y/N — first field is live value.
            current = rest.split('||')[0]
            values[name.strip()] = current.strip()
    return values


def compare(mq5_path, set_path):
    defaults, unresolved = parse_mq5_defaults(mq5_path)
    set_values = parse_set_file(set_path)

    mismatches = []
    for name, set_val in set_values.items():
        if name not in defaults:
            continue  # info-only strings / fields not present as real inputs
        default_val = defaults[name]
        # Normalize numeric formatting (e.g. "40" vs "40.0", "2.25" vs "2.250").
        try:
            if float(default_val) == float(set_val):
                continue
        except ValueError:
            pass
        if default_val == set_val:
            continue
        mismatches.append((name, default_val, set_val))

    return mismatches, unresolved


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)

    mq5_path = sys.argv[1]
    set_paths = sys.argv[2:]
    any_mismatch = False

    for set_path in set_paths:
        mismatches, unresolved = compare(mq5_path, set_path)
        print(f"=== {set_path} ===")
        if not mismatches:
            print("  OK — every field present in this .set matches the EA's compiled default.")
        else:
            any_mismatch = True
            for name, default_val, set_val in mismatches:
                print(f"  DIFFERS: {name}  compiled_default={default_val}  set_file={set_val}")
        print()

    if unresolved:
        print("--- Inputs whose compiled default could not be resolved to a number ---")
        print("(not necessarily a problem - just means this script can't verify them;")
        print(" add the enum to NATIVE_ENUMS if one of these is a native MQL5 enum type)")
        seen = set()
        for name, type_name, raw in unresolved:
            key = (name, type_name, raw)
            if key in seen:
                continue
            seen.add(key)
            print(f"  {name} ({type_name}) = {raw}")

    sys.exit(1 if any_mismatch else 0)


if __name__ == '__main__':
    main()
