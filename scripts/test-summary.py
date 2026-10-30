"""Surface failed test names without publishing application logs or secrets."""
from pathlib import Path
import xml.etree.ElementTree as ET
print('### API test results')
for path in sorted(Path('api/reports').glob('*.xml')):
    root = ET.parse(path).getroot()
    tests = list(root.iter('testcase'))
    failed = [t for t in tests if t.find('failure') is not None or t.find('error') is not None]
    print(f'- {path.name}: {len(tests)} tests, {len(failed)} failures')
    for test in failed:
        print(f"  - Failed: {test.get('classname', '')} / {test.get('name', '')}")
