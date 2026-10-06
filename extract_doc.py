import zipfile, xml.etree.ElementTree as ET
p = r'c:\Users\Admin\Desktop\Palengke+\ActivityMidtermLesosn1softwarereviewsinspectionsandwalkthroughs.docx'
with zipfile.ZipFile(p) as z:
    xml = z.read('word/document.xml')
root = ET.fromstring(xml)
ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
texts = []
for para in root.findall('.//w:p', ns):
    s = ''.join(t.text or '' for t in para.findall('.//w:t', ns))
    if s.strip():
        texts.append(s)
print('\n'.join(texts[:500]))
