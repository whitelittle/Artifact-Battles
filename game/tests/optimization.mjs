import fs from'node:fs';import{prelude,lua,encode,runLua}from'../lua.mjs';const bank=JSON.parse(fs.readFileSync(new URL('../data/opponents.json',import.meta.url))).slice(0,4);const result=runLua(prelude+'local BANK='+lua(bank)+'\n'+encode+`
local r=E.newRun('raiden',512);local baseline=E.power(r);local before=E.prepareMatch(r,BANK);local seed=r.seed
r.shop[1]={def=E.byName('雾切之回光'),price=13,sale=false,sold=false,locked=false};local ok,q=E.buy(r,1);assert(ok and E.autoPlace(r,q));assert(E.power(r)>baseline)
local after=E.prepareMatch(r,BANK);assert(after.power==before.power);assert(#after.reference.items==3 and #r.items==4);for i,v in ipairs(before.shortlist)do assert(v.index==after.shortlist[i].index)end
local aa=E.copy(r);local bb=E.copy(r);local j=E.prepareMatch(aa,BANK);local calls=0;while not E.stepMatch(j,7)do calls=calls+1;assert(calls<10000)end;local oa,ma=E.finishMatch(j)
local k=E.prepareMatch(bb,BANK);while not E.stepMatch(k)do end;local ob,mb=E.finishMatch(k);assert(ma.estimatedMargin==mb.estimatedMargin and ma.shoppingGain>0);assert(oa.hero==ob.hero and oa.items[1].def==ob.items[1].def);assert(E.validBuild(oa))
local utility=E.newRun('raiden',1);utility.items={};utility.nextId=1;utility.space=63
local apple=E.add(utility,E.byName('苹果'),1,1,3);local mint=E.add(utility,E.byName('薄荷'),2,1,2);local sword=E.add(utility,E.byName('无锋剑'),3,1,3);assert(E.linked(apple,mint));assert(not E.linked(mint,sword));local food=E.add(utility,E.byName('北地烟熏鸡'),2,2,5);assert(not E.linked(mint,food));food.x=0;food.y=0;assert(E.related(utility,apple.id)[mint.id]);local stamina=E.staminaInfo(utility);assert(math.abs(stamina.demand-.65)<.00001);sword.x=0;sword.y=0;assert(E.staminaInfo(utility).demand==0)
local status=E.recipeStatus(utility,E.byName('银剑'));assert(status and #status.missing==1 and status.missing[1]=='白铁块');E.add(utility,E.byName('银剑'),0,0,5);assert(E.recipeStatus(utility,E.byName('银剑')).complete);local options=E.recipeOptions(sword.def);assert(#options>0)
local originalSeed=utility.seed;local originalGold=utility.gold;local originalCount=#utility.items;E.purchaseSpace(utility,1);assert(utility.seed==originalSeed and utility.gold==originalGold and #utility.items==originalCount)
local reconciled=0
for _,hero in ipairs({'raiden','xiangling','noelle'})do
 local a=E.newRun(hero,91);a.round=8;a.space=63;a.items={};a.nextId=1;a.sub=1;a.talents={1};for _,name in ipairs({'暗铁剑','匣里灭辰','树莓','守护徽印','海染砗磲','苹果'})do local item=E.add(a,E.byName(name),0,0,3);assert(E.autoPlace(a,item))end
 local enemy=E.snapshot(a);enemy.hero='zhongli';local f=E.simulate(a,enemy,31);a.phase='battle';a.match={ratio=1,estimatedMargin=0};assert(E.finish(a,f));local rec=a.history[1];local sum=rec.coreDamage+rec.dotDamage+rec.thornDamage;for _,v in ipairs(rec.contributions)do sum=sum+v.damage;assert(v.hits>=0)end;assert(math.abs(sum-rec.damage)<.00001);assert(E.validate(a));reconciled=reconciled+1
 local old=E.copy(a);old.matchAnchor=nil;old.history[1].contributions=nil;old.history[1].diagnosis=nil;assert(E.validate(old))
end
return json({shoppingAnchorPreserved=true,shoppingGain=ma.shoppingGain,incrementalMatchesSameResult=true,chunkCalls=calls,synergyOnlyRealEffects=true,recipeMissingMaterials=true,staminaExcludesStash=true,purchasePreviewPure=true,damageReconciledBattles=reconciled,legacySavesAccepted=true})
`);console.log(result);fs.writeFileSync(new URL('../out/optimization-report.json',import.meta.url),result);
