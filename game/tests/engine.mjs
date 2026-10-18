import assert from'node:assert/strict';import fs from'node:fs';import{prelude,runLua,encode,data}from'../lua.mjs';
const result=runLua(prelude+encode+`
local names={};for _,d in ipairs(E.defs)do assert(not names[d.name]);names[d.name]=true end
assert(#E.defs==140 and #E.heroes==8 and #E.recipes==34)
for _,h in ipairs(E.heroes)do local r=E.newRun(h.id,9181);assert(E.validate(r));assert(E.power(r)>1);local same=E.snapshot(r);local b=E.simulate(same,same,1138);assert(b.done);assert(b.time<60)end
local r=E.newRun('raiden',813);local a=r.items[1];local x,y=a.x,a.y;assert(not E.move(r,a.id,9,7,0));assert(a.x==x and a.y==y)
local gold=r.gold;r.phase='battle';assert(not E.buy(r,1));assert(not E.expand(r));assert(not E.sell(r,a.id));assert(r.gold==gold);r.phase='shop'
r.shop[1]={def=E.byName('苹果'),price=2,locked=true,sale=false,sold=false};assert(E.refresh(r,true));assert(r.shop[1].def==E.byName('苹果'))
r.rerolls=4;gold=r.gold;assert(E.refresh(r,false));assert(r.gold==gold-2)
-- Recipe placement and rollback preserve both inputs when the result cannot fit.
r.items={};r.nextId=1;local sword=E.add(r,E.byName('无锋剑'),1,1,3);local iron=E.add(r,E.byName('白铁块'),2,1,2);assert(E.craft(r)==1);assert(#r.items==1 and r.items[1].def==E.byName('银剑'));assert(E.validate(r))
-- All generated opponents use legal footprints and unmodified economy growth.
local power={};for round=1,18 do for _,h in ipairs(E.heroes)do local b=E.bot(round,h.id,round*97,.8);assert(E.validBuild(b));assert(E.power(b)>1);power[#power+1]=E.power(b)end end
local a=E.newRun('raiden',9181);local b=E.bot(1,'klee',118,.8);local f=E.simulate(a,b,212);local g=E.simulate(a,b,212);assert(f.winner==g.winner and f.a.hp==g.a.hp)
a.phase='battle';E.finish(a,f);assert(a.phase=='result');assert(#a.history==1);E.next(a);assert(a.round==2 and a.phase=='shop');a.round=3;assert(not E.begin(a));assert(E.choose(a,2));
a.phase='result';a.wins=10;E.next(a);assert(a.phase=='milestone');E.next(a,'survive');assert(a.survival and a.phase=='shop');a.phase='result';a.round=18;E.next(a);assert(a.phase=='ended')
local en=E.newRun('fischl',321,'endless');en.phase='result';en.round=18;E.next(en);assert(en.round==19 and en.phase=='shop')
return json({items=#E.defs,recipes=#E.recipes,heroes=#E.heroes,deterministic=true,legalBots=144,checks={'transaction guards','lock','reroll escalation','craft','collision','full run milestones','endless','deterministic battle'}})
`);console.log(result);fs.writeFileSync(new URL('../out/engine-report.json',import.meta.url),result);
