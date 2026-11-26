"""Draw original shelf packaging for the Mabini Mart aisle meshes."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math
import random

out = Path(__file__).resolve().parents[2] / "game/assets/coop"
out.mkdir(parents=True, exist_ok=True)
font_dir = Path("C:/Windows/Fonts")
def font(size, bold=False):
    return ImageFont.truetype(str(font_dir / ("arialbd.ttf" if bold else "arial.ttf")),size)

items = [
    ("SARDINAS","Tomato sauce","aa4430","e7b754","fish"),
    ("PANDESAL","Bread mix","cb9035","5b3930","grain"),
    ("BUKO","Coconut milk","338173","f0e9c8","palm"),
    ("KAPE","Ground coffee","494655","bc794b","beans"),
    ("KALAMANSI","Fruit drink","899e4a","e5c34e","citrus"),
]
for i,(name, subtitle, base, accent, motif) in enumerate(items):
    img=Image.new("RGB",(256,320),"#"+base)
    d=ImageDraw.Draw(img)
    rng=random.Random(i+17)
    for j in range(310):
        x,y=rng.randrange(256),rng.randrange(320)
        d.line((x,y,x+2,y),fill="#"+accent,width=1)
    d.polygon([(0,153),(256,107),(256,243),(0,279)],fill="#"+accent)
    d.line((0,149,256,103),fill="#efe2bb",width=4)
    d.rounded_rectangle((80,23,176,51),14,fill="#f2e5ba")
    d.text((128,37),"MABINI",font=font(16,True),anchor="mm",fill="#37382f")
    d.text((128,88),name,font=font(34 if len(name)<8 else 28,True),anchor="mm",fill="#fff4ce",stroke_width=1,stroke_fill="#524632")
    if motif=="fish":
        d.ellipse((58,157,178,207),fill="#e5dac3",outline="#384b50",width=4)
        d.polygon([(174,181),(205,152),(201,213)],fill="#53696c"); d.ellipse((77,168,85,176), fill="#232a29")
        for x in range(105,161,12): d.arc((x-7,162,x+7,197),-80,80,fill="#668080",width=2)
    elif motif=="grain":
        for j in range(3):
            x=65+j*46
            d.ellipse((x-18,151+j*5,x+36,210+j*5),fill="#df9c4e",outline="#f8d18a",width=4)
            for k in range(3): d.line((x-10+k*13,173+j*5,x-3+k*13,163+j*5),fill="#936037",width=4)
    elif motif=="palm":
        d.ellipse((74,146,177,216),fill="#6b5139");d.ellipse((80,150,175,203),fill="#f7eed5");d.ellipse((95,157,166,193),fill="#ddd9b6")
        for j in range(5): d.line((148,166,155+j*7,122+j*3),fill="#387459",width=4)
    elif motif=="beans":
        for x,y in [(92,181),(141,169),(158,203)]:
            d.ellipse((x-21,y-17,x+21,y+17),fill="#513529",outline="#7b4d38",width=2)
            d.arc((x-17,y-7,x+18,y+9),5,180,fill="#c28a56",width=3)
    else:
        for x,y,r in [(100,180,36),(147,186,31)]:
            d.ellipse((x-r,y-r,x+r,y+r),fill="#dada7a",outline="#547146",width=5)
            for j in range(8):
                a=j*math.pi/4
                d.line((x,y,x+math.cos(a)*(r-6),y+math.sin(a)*(r-6)),fill="#f8e5a1",width=2)
    d.text((128,245),subtitle,font=font(18,True),anchor="mm",fill="#272d26",stroke_width=1,stroke_fill="#eadaba")
    d.line((22,283,234,283),fill="#efe4c3",width=2)
    d.text((21,291),"NET WT.  250 g",font=font(12),fill="#fff2d7")
    for j in range(21):
        x=161+j*3
        d.rectangle((x,290,x+rng.randrange(1,3),306),fill="#f0e9d2")
    img.save(out / ("label_%d.png"%i))

