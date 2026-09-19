import sys
import re
import xml.etree.ElementTree as ET

ns = {'ss': 'urn:schemas-microsoft-com:office:spreadsheet'}

def cell_text(cell):
    data = cell.find('ss:Data', ns)
    return data.text if data is not None else ''

def convert(xml_path, csv_path):
    tree = ET.parse(xml_path)
    root = tree.getroot()
    worksheet = root.find('ss:Worksheet', ns)
    table = worksheet.find('ss:Table', ns)
    rows = table.findall('ss:Row', ns)

    out_lines = []
    for row in rows:
        cells = row.findall('ss:Cell', ns)
        values = [cell_text(c) for c in cells]
        out_lines.append(','.join(values))

    with open(csv_path, 'w') as f:
        f.write('\n'.join(out_lines) + '\n')

if __name__ == '__main__':
    convert(sys.argv[1], sys.argv[2])
