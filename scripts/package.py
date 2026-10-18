from pathlib import Path
import tarfile,zipfile,shutil,json,csv,io
r=Path(__file__).resolve().parents[1];d=r/'dist/downloads';d.mkdir(exist_ok=True)
for name in ['README.md','DESIGN.md','VALIDATION.md','CHANGELOG.md','UI_HANDOFF.md']:shutil.copy2(r/name,d/name)
# Exact corresponding sources, excluding dependencies and generated downloads.
source=d/'simulator-source.tar.gz'
with tarfile.open(source,'w:gz')as tar:
 for p in sorted(r.rglob('*')):
  if not p.is_file()or p.is_symlink():continue
  rel=p.relative_to(r);parts=rel.parts
  if '__pycache__'in parts or '.git'in parts or 'node_modules'in parts or parts[:2]in[('dist','downloads'),('dist','archive-r1'),('game','qa')]:continue
  if parts[:2]==('game','out')and p.suffix!='.json':continue
  if parts[0]=='.openai':continue
  tar.add(p,arcname=str(Path('teyvat-backpack-r2-source')/rel),recursive=False)
readme='按顺序导入3个GIA，或在模拟器打开backpack-r2.qx-save.json。详见README.md。\n源码tar.gz包含保留模拟器与当前Demo源文件，依赖按锁文件安装。\n'
with zipfile.ZipFile(d/'demo.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6)as z:
 for p in sorted((r/'game/out').glob('*.gia')):z.write(p,p.name)
 for name in ['backpack-r2.lua','backpack-r2.qx-save.json']:z.write(r/'game/out'/name,name)
 for name in ['README.md','DESIGN.md','VALIDATION.md','CHANGELOG.md','UI_HANDOFF.md','catalog.html','simulator-source.tar.gz']:z.write(d/name,name)
 z.writestr('先读我.txt',readme)
 for p in sorted((r/'dist/portraits').glob('*.png')):z.write(p,'portraits/'+p.name)
 for p in sorted((r/'game/out').glob('*.json')):
  if p.name!='backpack-r2.qx-save.json':z.write(p,'validation/'+p.name)
 z.write(r/'game/data/catalog.json','data/catalog.json');z.write(r/'game/data/opponents.json','data/opponents.json')
 for p in sorted((r/'licenses').glob('*')):z.write(p,'licenses/'+p.name)
 c=json.loads((r/'game/data/catalog.json').read_text());s=io.StringIO();writer=csv.DictWriter(s,fieldnames=['id','name','tag','q','w','h','price','minRound','damage','cd','cost','effect','amount','uses'],extrasaction='ignore');writer.writeheader();writer.writerows(c['items']);z.writestr('data/items.csv','\ufeff'+s.getvalue())
with zipfile.ZipFile(d/'demo.zip')as z:assert z.testzip()is None;assert len([n for n in z.namelist()if n.endswith('.gia')])==3
print(json.dumps({'zipBytes':(d/'demo.zip').stat().st_size,'sourceBytes':source.stat().st_size,'zip':str(d/'demo.zip')},ensure_ascii=False))
