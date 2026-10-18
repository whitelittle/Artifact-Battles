from PIL import Image,ImageFilter
import numpy as np,json
from pathlib import Path
r=Path(__file__).parent;out={};report={}
for hero in json.loads((r/'data/catalog.json').read_text())['characters']:
 name=hero['id'];im=Image.open(r.parent/'dist/portraits'/f'{name}.png').convert('RGBA');bbox=im.getchannel('A').point(lambda a:255 if a>=170 else 0).getbbox();im=im.crop(bbox);w=192;h=round(w*im.height/im.width);im=im.resize((w,h),Image.Resampling.LANCZOS);valid=np.array(im.getchannel('A'))>=170;q=im.convert('RGB').filter(ImageFilter.MedianFilter(3)).quantize(colors=64);pal=q.getpalette();arr=np.array(q);smooth=np.array(q.filter(ImageFilter.ModeFilter(3)));arr[int(h*.3):]=smooth[int(h*.3):];rects=[];active={}
 for y in range(h):
  runs=[];x=0
  while x<w:
   if not valid[y,x]:x+=1;continue
   start=x;c=int(arr[y,x]);x+=1
   while x<w and valid[y,x]and arr[y,x]==c:x+=1
   runs.append((start,x,c))
  next={}
  for start,end,c in runs:
   key=(start,end,c)
   if key in active:
    idx=active[key];rects[idx][3]+=1
   else:idx=len(rects);rects.append([start,y,end-start,1,c+1])
   next[key]=idx
  active=next
 # Exact-color maximal rectangles; choose the smaller cover without changing a pixel.
 used=np.zeros((h,w),dtype=bool);greedy=[]
 for yy in range(h):
  for xx in range(w):
   if used[yy,xx]or not valid[yy,xx]:continue
   color=int(arr[yy,xx]);width=0
   while xx+width<w and valid[yy,xx+width]and not used[yy,xx+width]and arr[yy,xx+width]==color:width+=1
   best=(width,1);bestarea=width;limit=width
   for bottom in range(yy+1,h):
    row=0
    while row<limit and valid[bottom,xx+row]and not used[bottom,xx+row]and arr[bottom,xx+row]==color:row+=1
    limit=row
    if limit==0:break
    height=bottom-yy+1
    if limit*height>bestarea:best=(limit,height);bestarea=limit*height
   ww,hh=best;used[yy:yy+hh,xx:xx+ww]=True;greedy.append([xx,yy,ww,hh,color+1])
 baseline=len(rects)
 if len(greedy)<len(rects):rects=greedy
 # Verify the rectangle cover reproduces every visible source color exactly.
 check=np.full((h,w),-1,dtype=int)
 for xx,yy,ww,hh,color in rects:
  assert np.all(check[yy:yy+hh,xx:xx+ww]==-1)
  check[yy:yy+hh,xx:xx+ww]=color-1
 assert np.array_equal(check>=0,valid)and np.array_equal(check[valid],arr[valid])
 v=[]
 for x,y,ww,hh,c in rects:v.extend([(x+ww/2-w/2)*200/h,(h-y-hh/2)*200/h,(ww+.2)*200/h,(hh+.35)*200/h,0,0,c])
 out[name]={'n':len(rects),'r':v,'pal':[pal[i:i+3]+[255]for i in range(0,192,3)],'mode':'scan'};report[name]={'controls':len(rects),'previousControls':baseline,'pixelExact':True,'method':'64-color, 192px source; lossless maximal-area rectangle cover; face details retained; native vector rectangles','nativeHeight':200}
 print(name,len(rects))
(r/'art/portraits.json').write_text(json.dumps(out,separators=(',',':')));(r/'out/portrait-fit-report.json').write_text(json.dumps(report,indent=2))
