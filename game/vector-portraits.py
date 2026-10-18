from PIL import Image,ImageFilter
import numpy as np,contourpy,json
from pathlib import Path
r=Path(__file__).parent;out={}
def rdp(p,e):
 if len(p)<4:return p
 a,b=p[0],p[-1];v=b-a;norm=np.linalg.norm(v)
 d=np.linalg.norm(p-a,axis=1)if norm<1e-6 else np.abs(v[0]*(a[1]-p[:,1])-(a[0]-p[:,0])*v[1])/norm
 i=int(np.argmax(d))
 if d[i]>e:return np.vstack([rdp(p[:i+1],e)[:-1],rdp(p[i:],e)])
 return np.vstack([a,b])
for hero in json.loads((r/'data/catalog.json').read_text())['characters']:
 name=hero['id'];im=Image.open(r.parent/'dist/portraits'/f'{name}.png').convert('RGBA');bbox=im.getchannel('A').point(lambda a:255 if a>=170 else 0).getbbox();im=im.crop(bbox);w=192;h=round(w*im.height/im.width);im=im.resize((w,h),Image.Resampling.LANCZOS);valid=np.array(im.getchannel('A'))>=170;q=im.convert('RGB').filter(ImageFilter.MedianFilter(3)).quantize(colors=32).filter(ImageFilter.ModeFilter(3));pal=q.getpalette();arr=np.array(q);polys=[]
 for c in range(32):
  mask=((arr==c)&valid).astype(float);cg=contourpy.contour_generator(z=np.pad(mask,1),fill_type='OuterOffset');points,offsets=cg.filled(.5,1.5)
  for ps,os in zip(points,offsets):
   rings=[]
   for i in range(len(os)-1):
    ring=ps[os[i]:os[i+1]]-1
    if len(ring)<4:continue
    area=abs(np.sum(ring[:-1,0]*ring[1:,1]-ring[1:,0]*ring[:-1,1]))/2
    if area<2.5:continue
    # Lower simplification on faces to retain eyes and hair identity.
    eps=.35 if np.mean(ring[:,1])<h*.3 else .75
    half=len(ring)//2;ring=np.vstack([rdp(ring[:half+1],eps)[:-1],rdp(ring[half:],eps)])
    if len(ring)>=4:rings.append(ring[:-1].tolist())
   if rings:polys.append({'rings':rings,'c':c+1})
 out[name]={'polys':polys,'pal':[pal[i:i+3]+[255]for i in range(0,96,3)],'w':w,'h':h}
 print(name,len(polys),'regions')
(r/'art/polygons.json').write_text(json.dumps(out,separators=(',',':')))
