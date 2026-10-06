from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import textwrap

root = Path(r'C:\Users\Admin\Desktop\Palengke+')
img_dir = root / 'activity_evidence'
img_dir.mkdir(exist_ok=True)
font = ImageFont.truetype(r'C:\Windows\Fonts\arial.ttf', 20)
small = ImageFont.truetype(r'C:\Windows\Fonts\arial.ttf', 16)

files = [
    (img_dir / 'evidence_1_safe_mape.png', 'Evidence 1: Safe MAPE logic', 'This shows the guard that excludes zero actual values before computing percentage error. It proves the defect was corrected so the metric stays finite and valid.'),
    (img_dir / 'evidence_2_test_case.png', 'Evidence 2: Regression test', 'This shows the test that checks zero-value inputs. It proves the defect was converted into a preventive, repeatable regression case.'),
    (img_dir / 'evidence_3_test_run.png', 'Evidence 3: Unit test result', 'This shows the project test output with six passing tests. It proves the fix was verified in the actual workspace using the project’s real test suite.'),
]

for src, title, caption in files:
    img = Image.open(src)
    canvas = Image.new('RGB', (img.width, img.height + 140), 'white')
    canvas.paste(img, (0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.text((20, img.height + 15), title, fill='black', font=font)
    wrapped = textwrap.wrap(caption, width=90)
    y = img.height + 55
    for line in wrapped:
        draw.text((20, y), line, fill='black', font=small)
        y += 22
    out = src.with_name(src.stem + '_captioned.png')
    canvas.save(out)
    print(out)
