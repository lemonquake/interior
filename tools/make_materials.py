"""Author small game textures and extract portrait inserts from the reference.

These are native 3D material resources, not an edited replacement of the photo.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
import numpy as np,random,json
root=Path(__file__).resolve().parent.parent
p=root/'room/textures'; p.mkdir(exist_ok=True)
rng=np.random.default_rng(38); random.seed(12)
size=1024
def noise(s,scale):
    a=(rng.random((scale,scale))*255).astype('uint8')
    return np.asarray(Image.fromarray(a).resize((s,s),Image.Resampling.BICUBIC)).astype(float)/255
def cloth(name,base):
    n=noise(512,180)*.6+noise(512,20)*.4
    yy,xx=np.indices(n.shape)
    woven=((xx%4<1)+(yy%4<1))*.08
    a=np.clip(np.array(base)[None,None,:]*(.83+n[:,:,None]*.30+woven[:,:,None]),0,255).astype('uint8')
    Image.fromarray(a).save(p/(name+'.jpg'),quality=93)
cloth('fabric_brown',[96,64,46]); cloth('fabric_beige',[184,162,130]); cloth('crib_gray',[134,135,133])
cloth('leather_brown',[70,43,34])
marble=Image.new('RGB',(size,size),(237,231,218)); d=ImageDraw.Draw(marble)
for i in range(19):
    x0=random.randrange(-600,1500); points=[]
    for y in range(-50,1100,55):
        x=x0+y*.5+random.uniform(-33,33)+50*np.sin(y*.01+i)
        points.append((int(x),y))
    width=random.choice([2,3,5,9,17])
    d.line(points,fill=(166,161,151),width=width+6)
    d.line(points,fill=(100,96,87),width=width)
    if i%2==0:d.line([(x+width//2+2,y) for x,y in points],fill=(185,139,64),width=max(2,width//2))
    if i%3==0:
        x,y=points[10]; d.line([(x,y),(x-160,y+80),(x-245,y+130),(x-350,y+215)],fill=(174,157,125),width=3)
marble=marble.filter(ImageFilter.GaussianBlur(.65))
a=np.asarray(marble).astype(float); n=noise(size,40)
a=np.clip(a*(.97+n[:,:,None]*.06),0,255).astype('uint8')
Image.fromarray(a).save(p/'gold_marble.jpg',quality=94)
n=noise(size,50)*.5+noise(size,350)*.24+noise(size,10)*.26
col=np.array([183,172,157])[None,None,:]*(.62+n[:,:,None]*.68)
yy,xx=np.indices(n.shape); col[(xx%230<6)|(yy%230<6)]*=.79
Image.fromarray(np.clip(col,0,255).astype('uint8')).save(p/'rug.jpg',quality=94)
photo=Image.open(root/'room/images/reference.png')
crops=[(1297,23,1339,106),(1357,22,1395,101),(1412,75,1459,124),(1530,57,1571,117),(1630,40,1670,116),(1011,196,1036,232),(1010,267,1040,309),(570,363,589,410)]
for i,crop in enumerate(crops):photo.crop(crop).resize((192,256),Image.Resampling.LANCZOS).save(p/f'portrait_{i}.jpg',quality=92)
provenance=json.loads((root/'room/asset-provenance.json').read_text())
provenance['authoredTextures']='tools/make_materials.py; deterministic native material generation'
provenance['portraitInserts']='Small texture inserts sampled from owner supplied room photo'
provenance['externalTextures'].append(dict(name='Marble 01',author='Rob Tuytel',license='CC0',source='https://polyhaven.com/a/marble_01',path='textures/marble_01_diff_1k.jpg'))
(root/'room/asset-provenance.json').write_text(json.dumps(provenance,indent=2))
print('Authored native materials and portrait inserts')
