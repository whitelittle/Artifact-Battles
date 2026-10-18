from PIL import Image,ImageDraw
from pathlib import Path
import json,math
r=Path(__file__).parent;root=r.parent;out={};reports={}
def fit(path,width):
 im=Image.open(path).convert('RGBA');bbox=im.getchannel('A').point(lambda a:255 if a>=170 else 0).getbbox();im=im.crop(bbox);w=width;h=round(im.height*w/im.width);im=im.resize((w,h),Image.Resampling.LANCZOS);alpha=im.getchannel('A');q=im.convert('RGB').quantize(colors=32,method=Image.Quantize.MEDIANCUT);p=q.getpalette();pix=q.load();ap=alpha.load();rects=[];active={}
 for y in range(h):
  runs=[];x=0
  while x<w:
   if ap[x,y]<170:x+=1;continue
   c=pix[x,y];start=x;x+=1
   while x<w and ap[x,y]>=170 and pix[x,y]==c:x+=1
   runs.append((start,x-start,c))
  current={}
  for x,ww,c in runs:
   key=x,ww,c
   if key in active:
    i=active[key];rects[i][3]+=1
   else:i=len(rects);rects.append([x,y,ww,1,c])
   current[key]=i
  active=current
 u=200/h;data=[]
 for x,y,ww,hh,c in rects:data.extend([round((x-w/2)*u,4),round((h-y-hh)*u,4),round((ww+.04)*u,4),round((hh+.04)*u,4),c+1])
 return {'n':len(rects),'r':data,'pal':[p[i:i+3]+[255]for i in range(0,96,3)]},(w,h)
for hero in json.loads((r/'data/catalog.json').read_text())['characters']:
 name=hero['id'];width=124
 while True:
  a,size=fit(root/'dist/portraits'/f'{name}.png',width)
  if a['n']<=1600 or width<=62:break
  width-=6
 out[name]=a;reports[name]={'primitives':a['n'],'sampleSize':size,'source':f'portraits/{name}.png','method':'32-color quantization, alpha silhouette threshold, exact-color run spans merged vertically','nativeHeight':200}
(root/'game/art/portraits.json').write_text(json.dumps(out,separators=(',',':')))
(root/'game/out/portrait-fit-report.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2));print(json.dumps(reports,ensure_ascii=False))
