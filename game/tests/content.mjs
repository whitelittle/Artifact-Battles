import fs from'node:fs';import{prelude,lua,encode,runLua}from'../lua.mjs';const bank=JSON.parse(fs.readFileSync(new URL('../data/opponents.json',import.meta.url)));const result=runLua(prelude+'local BANK='+lua(bank)+'\n'+encode+`
for _,b in ipairs(BANK)do assert(E.validBuild(b))end
local count=0
for _,p in ipairs(E.recipes)do
 local r=E.newRun('raiden',173);r.items={};r.space=63;r.nextId=1
 local a=E.add(r,p.a,1,1,3);local b=E.add(r,p.b,0,0,2)
 local found=false;for y=1,7 do for x=1,9 do for rot=0,1 do if not found and E.fits(r,b,x,y,rot)then b.x=x;b.y=y;b.rot=rot;if E.adjacent(a,b)then found=true else b.x=0;b.y=0 end end end end end
 assert(found,E.name(p.out));assert(E.craft(r)>=1);assert(#r.items==1 and r.items[1].def==p.out,E.name(p.out));assert(E.validate(r));count=count+1
end
local r=E.newRun('raiden',11);local invalid=E.copy(r);invalid.hero='fake';assert(not E.validate(invalid));invalid=E.copy(r);invalid.items[1].paid=-1;assert(not E.validate(invalid));invalid=E.copy(r);invalid.shop[1].def=999;assert(not E.validate(invalid));invalid=E.copy(r);invalid.items[1].x=.5;assert(not E.validate(invalid));invalid=E.copy(r);invalid.history={{round=1}};assert(not E.validate(invalid))
-- Both specializations retain periodic core activations.
for _,id in ipairs({'zhongli','furina','xiangling','noelle','klee'})do local a=E.newRun(id,19);a.round=18;a.sub=2;local b=E.startBattle(a,a,1);for i=1,200 do E.step(b,.05)end;assert(b.a.coreCount>0,id)end
return json({legalBank=#BANK,recipesCrafted=count,malformedSavesRejected=5,specializationTimers=true})
`);console.log(result);fs.writeFileSync(new URL('../out/content-report.json',import.meta.url),result);
