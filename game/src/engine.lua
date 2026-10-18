-- Pure deterministic game rules. No UI, IO or device APIs.
local E={version=2,defs=DATA.items,heroes=DATA.characters,recipes=DATA.recipes,economy=DATA.economy}
local D=E.defs
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
E.copy=copy
function E.rand(r,n)r.seed=(r.seed*48271.0)%2147483647;return math.floor(r.seed%n)+1 end
function E.hero(id)for _,h in ipairs(E.heroes)do if h.id==id then return h end end;return E.heroes[1]end
function E.name(id)return D[id].name end
function E.byName(n)for _,d in ipairs(D)do if d.name==n then return d.id end end end
function E.cells(q,x,y,rot)
 local d=D[q.def];x=x or q.x;y=y or q.y;rot=rot or q.rot or 0;local out={}
 local cells=d.cells or {};if #cells==0 then for a=0,d.w-1 do for b=0,d.h-1 do cells[#cells+1]={a,b}end end end
 for _,p in ipairs(cells)do local a,b=p[1],p[2];if rot%4==1 then a,b=d.h-1-b,a elseif rot%4==2 then a,b=d.w-1-a,d.h-1-b elseif rot%4==3 then a,b=b,d.w-1-a end;out[#out+1]={x+a,y+b}end;return out
end
local order={};for y=1,7 do for x=1,9 do order[#order+1]={x,y}end end;table.sort(order,function(a,b)local aa=math.max(a[1],a[2]);local bb=math.max(b[1],b[2]);if aa~=bb then return aa<bb end;if a[2]~=b[2]then return a[2]<b[2]end;return a[1]<b[1]end)
function E.openMap(r)local t={};for i=1,r.space do local p=order[i];t[(p[2]-1)*9+p[1]]=true end;return t end
function E.fits(r,q,x,y,rot,ignore)
 local open=E.openMap(r);local occupied={};for _,a in ipairs(r.items)do if a~=q and a~=ignore and a.x>0 then for _,p in ipairs(E.cells(a))do occupied[(p[2]-1)*9+p[1]]=true end end end
 for _,p in ipairs(E.cells(q,x,y,rot))do if p[1]<1 or p[1]>9 or p[2]<1 or p[2]>7 or not open[(p[2]-1)*9+p[1]]or occupied[(p[2]-1)*9+p[1]]then return false end end;return true
end
function E.adjacent(a,b)if a.x==0 or b.x==0 then return false end;for _,p in ipairs(E.cells(a))do for _,q in ipairs(E.cells(b))do if math.abs(p[1]-q[1])+math.abs(p[2]-q[2])==1 then return true end end end;return false end
function E.add(r,def,x,y,paid)local q={id=r.nextId,def=def,x=x or 0,y=y or 0,rot=0,paid=paid or D[def].price};r.nextId=r.nextId+1;r.items[#r.items+1]=q;return q end
function E.autoPlace(r,q)
 local open=E.openMap(r);local occupied={}
 for _,v in ipairs(r.items)do if v~=q and v.x>0 then for _,p in ipairs(E.cells(v))do occupied[(p[2]-1)*9+p[1]]=true end end end
 for rot=0,1 do for y=1,7 do for x=1,9 do local valid=true
  for _,p in ipairs(E.cells(q,x,y,rot))do local k=(p[2]-1)*9+p[1];if p[1]>9 or p[2]>7 or not open[k]or occupied[k]then valid=false;break end end
  if valid then q.x=x;q.y=y;q.rot=rot;return true end
 end end end;return false
end
function E.find(r,id)for _,q in ipairs(r.items)do if q.id==id then return q end end end
function E.stashCount(r)local n=0;for _,q in ipairs(r.items)do if q.x==0 then n=n+1 end end;return n end
function E.rarity(r)local row=E.economy.rarity[math.min(r.round,12)];local v=E.rand(r,100);for i,p in ipairs(row)do v=v-p;if v<=0 then return i end end;return 1 end
function E.refresh(r,free)
 if r.phase~='shop'then return false,'仅准备阶段可刷新'end;local cost=r.rerolls<4 and 1 or 2
 if not free then if r.gold<cost then return false,'摩拉不足'end;r.gold=r.gold-cost;r.rerolls=r.rerolls+1 end
 for i=1,5 do if not r.shop[i]or not r.shop[i].locked or r.shop[i].sold then
  local q=E.rarity(r);local pool={};for _,d in ipairs(D)do if d.q==q and d.minRound<=r.round then pool[#pool+1]=d.id end end
  if #pool==0 then for _,d in ipairs(D)do if d.q==1 then pool[#pool+1]=d.id end end end
  local id=pool[E.rand(r,#pool)];local sale=E.rand(r,100)<=10;r.shop[i]={def=id,price=sale and math.ceil(D[id].price*.5)or D[id].price,sale=sale,locked=false,sold=false}
 end end;return true
end
function E.newRun(hero,seed,mode)
 local r={version=2,hero=hero or'raiden',mode=mode or'standard',phase='shop',round=1,wins=0,losses=0,lives=5,gold=13,space=16,items={},shop={},nextId=1,seed=seed or 823147,rerolls=0,talents={},sub=0,history={},recent={},autoCraft=true,ghosts={}}
 for _,id in ipairs(E.hero(r.hero).start)do local q=E.add(r,id,0,0,0);assert(E.autoPlace(r,q))end;E.refresh(r,true);r.matchAnchor=E.snapshot(r);return r
end
function E.buy(r,i)
 if r.phase~='shop'then return false,'仅准备阶段可购买'end;local z=r.shop[i];if not z or z.sold then return false,'商品已售出'end
 if r.gold<z.price then return false,'摩拉不足'end;if #r.items>=32 or E.stashCount(r)>=8 then return false,'储物区或物品数量已满'end
 r.gold=r.gold-z.price;z.sold=true;local q=E.add(r,z.def,0,0,z.price);return true,q
end
function E.sell(r,id)
 if r.phase~='shop'then return false,'战斗中无法出售'end;for i,q in ipairs(r.items)do if q.id==id then local n=math.min(math.ceil(D[q.def].price/2),q.paid);r.gold=r.gold+n;table.remove(r.items,i);return true,n end end;return false,'未选中物品'
end
function E.move(r,id,x,y,rot)
 if r.phase~='shop'then return false,'战斗中无法移动'end;local q=E.find(r,id);if not q then return false,'未选中物品'end
 if x==0 then if q.x~=0 and E.stashCount(r)>=8 then return false,'储物区已满'end;q.x=0;q.y=0;return true end
 if not E.fits(r,q,x,y,rot)then return false,'格子未开放、越界或发生重叠'end;q.x=x;q.y=y;q.rot=rot%4;return true
end
function E.expand(r)if r.phase~='shop'then return false,'仅准备阶段可扩容'end;if r.space>=63 then return false,'背包已满'end;if r.gold<4 then return false,'扩容需4摩拉'end;r.gold=r.gold-4;r.space=math.min(63,r.space+4);return true end
function E.undoLayout(r,before)if r.phase~='shop'then return false end;local test=copy(r);for _,q in ipairs(test.items)do local b=before[q.id];if b then q.x=b.x;q.y=b.y;q.rot=b.rot end end;for _,q in ipairs(test.items)do if q.x>0 and not E.fits(test,q,q.x,q.y,q.rot)then return false end end;r.items=test.items;return true end
function E.craftable(r)
 local out={};local taken={};for _,p in ipairs(E.recipes)do for _,a in ipairs(r.items)do if a.def==p.a and not taken[a.id]then for _,b in ipairs(r.items)do if b~=a and b.def==p.b and not taken[b.id]and E.adjacent(a,b)then
  local q={def=p.out,rot=a.rot,x=a.x,y=a.y};if E.fits(r,q,a.x,a.y,a.rot,a)then -- also need to ignore both inputs below
  end
  out[#out+1]={a=a.id,b=b.id,out=p.out};taken[a.id]=true;taken[b.id]=true;break
 end end end end end;return out
end
function E.craft(r)
 local count=0
 for _,p in ipairs(E.craftable(r))do
  local a,b=E.find(r,p.a),E.find(r,p.b)
  if a and b then
   local old=copy(a);local bx,by=b.x,b.y;a.def=p.out;b.x=0;b.y=0
   if not E.fits(r,a,a.x,a.y,a.rot)then a.x=0;a.y=0;E.autoPlace(r,a)end
   if a.x==0 then a.def=old.def;a.x=old.x;a.y=old.y;a.rot=old.rot;b.x=bx;b.y=by
   else a.paid=a.paid+b.paid;for i,q in ipairs(r.items)do if q==b then table.remove(r.items,i);break end end;count=count+1 end
  end
 end
 return count
end

function E.snapshot(r)return{hero=r.hero,round=r.round,space=r.space,items=copy(r.items),talents=copy(r.talents),sub=r.sub,source='本地构筑镜像'}end
local function triggered(d)return(d.cd or 0)>0 or d.effect=='healstrike'or(d.tag=='material'and d.effect=='shield')end
function E.compile(build)
 local out={};local global={haste=0,crit=.05,weapon=1,heal=1,summon=1,core=1,poison=1,burn=1,armor=1,thorns=0,regen=0,income=0}
 for _,q in ipairs(build.items)do if q.x>0 then local d=D[q.def];if d.effect=='income'then global.income=math.min(3,global.income+1)end end end
 for _,q in ipairs(build.items)do if q.x>0 then local d=D[q.def];local z=copy(d);z.instance=q.id;z.links=0;z.damage=d.damage or 0;z.cd=d.cd or 0;z.crit=.05;z.heal=1;z.food=0;z.speed=1;z.dot=1;z.cost=d.cost or 0
  for _,b in ipairs(build.items)do if b~=q and E.adjacent(q,b)then local x=D[b.def];local eff=x.effect;local k=x.amount or .1
   if eff=='haste'and triggered(d)and(x.tag=='artifact'or x.tag=='gadget'or x.tag=='material')then z.speed=z.speed+.12;z.links=z.links+1 end
   if eff=='crit'and x.tag=='artifact'and d.tag=='weapon'then z.crit=z.crit+.1;z.links=z.links+1 end
   if eff=='foodboost'and d.tag=='food'and(d.effect=='heal'or d.effect=='regen'or d.effect=='rescue')then z.heal=z.heal+.2;z.links=z.links+1 end
   if eff=='healboost'and(d.effect=='heal'or d.effect=='regen'or d.effect=='rescue')then z.heal=z.heal+.15;z.links=z.links+1 end
   if eff=='weaponboost'and d.tag=='weapon'then z.damage=z.damage*1.12;z.links=z.links+1 end
   if eff=='summonboost'and d.tag=='summon'then z.damage=z.damage*1.15;z.links=z.links+1 end
   if x.tag=='food'and d.tag=='summon'then z.damage=z.damage*1.1;z.links=z.links+1 end
   if eff=='armorboost'and d.effect=='shield'then z.amount=z.amount*1.15;z.links=z.links+1 end
   if eff=='coreboost'then global.core=math.min(1.6,global.core+.025)end
   if eff=='burnboost'and d.effect=='burn'and triggered(d)then z.dot=z.dot*1.15;z.links=z.links+1 end
   if eff=='poisonboost'and d.effect=='poison'and triggered(d)then z.dot=z.dot*1.15;z.links=z.links+1 end
   if x.tag=='material'and(eff=='burn'or eff=='poison'or eff=='slow')and d.tag=='weapon'then z.infuse=eff;z.links=z.links+1 end
   if x.effect=='luck'and d.tag=='weapon'then z.crit=z.crit+.025;z.links=z.links+1 end
  end end
  z.speed=math.min(1.6,z.speed);z.crit=math.min(.45,z.crit);if z.effect=='healstrike'and z.cd==0 then z.cd=4.5 end;if z.tag=='material'and z.effect=='shield'and z.cd==0 then z.cd=6 end;z.time=z.cd;z.uses=d.uses or 999;z.total=0;z.healed=0;z.shielded=0;z.hits=0;z.wait=0;out[#out+1]=z
 end end
 for _,t in ipairs(build.talents or{})do if t==1 then global.weapon=global.weapon*1.08 elseif t==2 then global.heal=global.heal*1.12 elseif t==3 then global.haste=global.haste+.08 end end
 return out,global
end
function E.power(build)
 local list,g=E.compile(build);local dmg,heal,shield,energy,stamina=0,0,0,0,0
 for _,z in ipairs(list)do if z.cd>0 then local cd=z.cd/z.speed
  dmg=dmg+z.damage/cd*(1+z.crit*.5);stamina=stamina+z.cost/cd
  if z.effect=='heal'or z.effect=='regen'or z.effect=='rescue'then heal=heal+(z.amount or 0)*z.heal/cd*.6 end
  if z.effect=='shield'then shield=shield+(z.amount or 0)/cd end
  if z.effect=='energy'then energy=energy+(z.tag=='weapon'and 1 or z.amount or 1)/cd end
  if z.effect=='burn'or z.effect=='poison'then dmg=dmg+(z.amount or 1)*.4/cd end
 end end
 local factor=stamina>1.6 and math.max(.4,1.6/stamina)or 1
 return math.max(1,(dmg*factor*g.weapon+math.min(heal+shield,5+build.round*.65)*.52+energy*.65+1+build.round*.28)*(1+((build.sub or 0)>0 and .08 or 0)))
end
-- Explicit deterministic battle RNG, independent of shop draws and UI time.
function E.startBattle(a,b,seed)
 local function player(build)local list,g=E.compile(build);local hp=E.economy.hp[math.min(build.round,18)]or 350;local p={hero=build.hero,sub=build.sub or 0,hp=hp,max=hp,shield=0,stamina=5,energy=0,items=list,global=g,poison=0,burn=0,slow=0,empower=0,regen=0,buff=0,attacks=0,activations=0,foods=0,summons=0,coreClock=0,subClock=0,coreCount=0,thorns=0,totals={damage=0,heal=0,shield=0,absorbed=0,wait=0},revive=false};return p end
 return{a=player(a),b=player(b),time=0,seed=seed or 8123,round=a.round,logs={},done=false,winner=0,flash=0}
end
local function log(b,t)table.insert(b.logs,1,t);if #b.logs>5 then table.remove(b.logs)end end
local function hit(b,a,target,n,z,label,bypass,credit)
 n=math.max(0,n);if z and E.rand(b,100)<=math.min(.65,z.crit+(a.critBonus or 0))*100 then n=n*1.5 end
 local block=bypass and 0 or math.min(target.shield,n);target.shield=target.shield-block;target.hp=target.hp-(n-block);target.totals.absorbed=target.totals.absorbed+block;a.totals.damage=a.totals.damage+n;local credited=credit or z;if credited then credited.total=credited.total+n else a.coreDamage=(a.coreDamage or 0)+n end;b.flash=.15
 if label then log(b,label..' '..math.floor(n+.5))end
 if z and z.tag=='weapon'and target.thorns>0 then local ret=math.min(n,target.thorns);a.hp=a.hp-ret;target.thornDamage=(target.thornDamage or 0)+ret;target.totals.damage=target.totals.damage+ret end
 return n
end
local function heal(a,n,z)local v=math.min(math.max(0,a.max-a.hp),n*a.global.heal);a.hp=a.hp+v;a.totals.heal=a.totals.heal+v;if z then z.healed=z.healed+v end;return v end
local function shield(a,n,z)local v=math.min(math.max(0,a.max*.8-a.shield),n);a.shield=a.shield+v;a.totals.shield=a.totals.shield+v;if z then z.shielded=z.shielded+v end end
local function effect(b,a,target,z)
   if z.infuse=='poison'then target.poison=math.min(30,target.poison+.35)elseif z.infuse=='burn'then target.burn=math.min(30,target.burn+.35)elseif z.infuse=='slow'then target.slow=math.min(.25,target.slow+.01)end
 local e=z.effect;local n=z.amount or 1
 if e=='energy'then a.energy=a.energy+(z.tag=='weapon'and n or n)
 elseif e=='stamina'then a.stamina=math.min(5,a.stamina+math.min(3,n))
 elseif e=='heal'or e=='rescue'then heal(a,n*z.heal,z)
 elseif e=='regen'then a.regen=math.min(6,a.regen+math.max(.25,n*z.heal*.15))
 elseif e=='shield'then shield(a,n*(a.hero=='zhongli'and 1.12 or 1),z)
 elseif e=='burn'then target.burn=math.min(30,target.burn+math.max(1,n*.5)*(z.dot or 1))
 elseif e=='poison'then target.poison=math.min(30,target.poison+math.max(1,n*.5)*(z.dot or 1))
 elseif e=='slow'then target.slow=math.min(.25,target.slow+.025)
 elseif e=='cleanse'then a.poison=math.max(0,a.poison-n);a.burn=math.max(0,a.burn-n);a.slow=math.max(0,a.slow-.04)
 elseif e=='empower'then a.empower=math.min(10,a.empower+math.max(.4,n*.2))
 elseif e=='crit'and z.tag=='food'then a.critBonus=math.min(.2,(a.critBonus or 0)+.04)
 elseif e=='haste'and z.tag~='artifact'then a.global.haste=math.min(.3,a.global.haste+.015)
 elseif e=='summon'then hit(b,a,target,math.max(1,z.damage*.18),nil,'弦外协同',false,z)
 elseif e=='extra'then hit(b,a,target,z.damage*.2,nil,nil,false,z)
 elseif e=='lifesteal'then heal(a,math.min(3,z.damage*.15),z)
 elseif e=='fish'then if a.attacks%4==0 then hit(b,a,target,z.damage*.45,nil,'大鲔冲击',false,z)end
 elseif e=='alchemy'then a.energy=a.energy+1;shield(a,n*.4,z)
 elseif e=='copy'then a.energy=a.energy+1;heal(a,1,z)
 elseif e=='thorns'then a.thorns=math.min(4,a.thorns+.3)
 elseif e=='healstrike'then hit(b,a,target,math.min(8,a.totals.heal*.12),nil,'海染泡沫',false,z)end
end
local function core(b,a,t,dt)
 a.coreClock=a.coreClock+dt;a.subClock=a.subClock+dt;local n=2+b.round*.45;local mul=a.global.core*(a.sub==1 and 1.12 or 1)*(E.hero(a.hero).balance or 1)
 if a.hero=='raiden'and a.energy>=10 then a.energy=a.energy-10;hit(b,a,t,(5+b.round*.8)*mul,nil,'梦想一刀');a.coreCount=a.coreCount+1
 elseif a.hero=='nahida'and a.activations>=5 then a.activations=a.activations-5;hit(b,a,t,n*.65*mul,nil,'灭净三业');heal(a,n*.3*mul,nil);a.coreCount=a.coreCount+1
 elseif a.hero=='zhongli'and a.coreClock>=5 then a.coreClock=a.coreClock-5;shield(a,n*1.05*mul,nil);hit(b,a,t,n*.45*mul,nil,'岩脊共鸣');a.coreCount=a.coreCount+1
 elseif a.hero=='furina'and a.coreClock>=4 then a.coreClock=a.coreClock-4;hit(b,a,t,n*.9*mul,nil,'沙龙协奏');heal(a,n*.25*mul,nil);a.coreCount=a.coreCount+1
 elseif a.hero=='xiangling'and a.coreClock>=4 then a.coreClock=a.coreClock-4;hit(b,a,t,(n*.8+math.min(4,a.foods*.35))*mul,nil,'锅巴出击');t.burn=math.min(30,t.burn+.5);a.coreCount=a.coreCount+1
 elseif a.hero=='noelle'and a.coreClock>=6 then a.coreClock=a.coreClock-6;shield(a,n*.8*mul,nil);heal(a,n*.6*mul,nil);a.coreCount=a.coreCount+1
 elseif a.hero=='fischl'and a.attacks>=4 then a.attacks=a.attacks-4;hit(b,a,t,n*1.1*mul,nil,'奥兹追击');a.coreCount=a.coreCount+1
 elseif a.hero=='klee'and a.coreClock>=6 then a.coreClock=a.coreClock-6;hit(b,a,t,n*1.2*mul,nil,'蹦蹦炸弹');t.burn=math.min(30,t.burn+1);a.coreCount=a.coreCount+1 end
 if a.sub==2 and a.subClock>=2 then a.subClock=a.subClock-2;heal(a,.3+b.round*.08,nil)end
end
local function act(b,a,target,dt)
 a.stamina=math.min(5,a.stamina+dt);local ready={}
 for _,z in ipairs(a.items)do if z.cd>0 then z.time=z.time-dt*math.max(.5,1+a.global.haste-a.slow)*z.speed;if z.time<=0 and z.uses>0 then ready[#ready+1]=z end end end
 table.sort(ready,function(x,y)if math.abs(x.time-y.time)>.00001 then return x.time<y.time end;return x.instance<y.instance end)
 for _,z in ipairs(ready)do local active=true
  if z.tag=='weapon'and a.stamina<z.cost then active=false;z.wait=z.wait+dt;a.totals.wait=a.totals.wait+dt end
  if z.tag=='food'and(z.effect=='heal'or z.effect=='rescue'or z.effect=='regen')and a.hp>a.max*.75 then active=false end
  if active then
   z.time=z.time+z.cd;z.hits=z.hits+1;a.activations=a.activations+1
   if z.tag=='weapon'then a.stamina=a.stamina-z.cost;a.attacks=a.attacks+1;a.energy=a.energy+1;local damage=(z.damage+a.empower)*a.global.weapon;if a.hero=='noelle'and a.shield>0 then damage=damage*1.08 end;hit(b,a,target,damage,z,E.hero(a.hero).name..'·'..z.name)
   elseif z.tag=='summon'then a.summons=a.summons+1;local mul=a.hero=='furina'and 1.1 or 1;hit(b,a,target,z.damage*mul,z,E.hero(a.hero).name..'·'..z.name)end
   if z.tag=='food'then a.foods=a.foods+1;z.uses=z.uses-1 end
   effect(b,a,target,z)
  end
 end
 core(b,a,target,dt)
end
function E.step(b,dt)
 if b.done then return end;b.time=b.time+dt;b.flash=math.max(0,b.flash-dt)
 act(b,b.a,b.b,dt);act(b,b.b,b.a,dt)
 if math.floor(b.time)>math.floor(b.time-dt)then
  for _,a in ipairs({b.a,b.b})do if a.regen>0 then heal(a,a.regen*.5,nil)end
   local dot=a.poison*.35+a.burn*.45;local source=a==b.a and b.b or b.a;source.dotDamage=(source.dotDamage or 0)+dot;source.totals.damage=source.totals.damage+dot;a.hp=a.hp-dot;a.burn=math.max(0,a.burn-.25)
   if b.time>=17 then local k=math.floor(b.time)-16;local f=k+math.max(0,k-10)*.6;a.hp=a.hp-f end
  end
 end
 if b.a.hp<=0 or b.b.hp<=0 or b.time>=60 then b.done=true;b.winner=b.a.hp>0 and b.b.hp<=0 and 1 or b.b.hp>0 and b.a.hp<=0 and -1 or 0 end
end
function E.simulate(a,b,seed)local fight=E.startBattle(a,b,seed);for i=1,1200 do E.step(fight,.05);if fight.done then break end end;return fight end
local botNames={'冒险家协会','万民堂食客','猫尾酒馆常客','西风骑士','须弥学者','枫丹观众','往生堂客卿','蒙德旅行者'}
function E.bot(round,hero,seed,budgetFactor)
 local r=E.newRun(hero,seed);r.round=round;r.items={};r.nextId=1;r.space=math.min(63,16+math.floor((round-1)*3));r.talents=round>=3 and {E.rand(r,3)}or{};if round>=10 then r.talents[2]=E.rand(r,3)end;r.sub=round>=8 and E.rand(r,2)or 0
 local budget=0;for i=1,math.min(round,18)do budget=budget+E.economy.gold[i]end;budget=budget*(budgetFactor or .8)-math.floor((r.space-16)/4)*4
 local preferred=hero=='xiangling'and'food'or hero=='noelle'and'food'or hero=='furina'and'summon'or hero=='zhongli'and'artifact'or hero=='nahida'and'material'or'weapon'
 local h=E.hero(hero);local first=E.add(r,h.start[1],0,0);E.autoPlace(r,first);budget=budget-D[first.def].price
 for k=1,80 do local counts={};for _,z in ipairs(r.items)do local tag=D[z.def].tag;counts[tag]=(counts[tag]or 0)+1 end;if budget<2 or #r.items>=27 then break end
  local pool={};local maxq=round<3 and 2 or round<6 and 3 or round<10 and 4 or 5
  for _,d in ipairs(D)do if d.minRound<=round and d.price<=budget and d.q<=maxq and d.effect~='income'and(counts[d.tag]or 0)<({weapon=3,food=6,material=4,artifact=7,gadget=5,summon=5})[d.tag] then
   local w=1;if d.tag==preferred then w=2 end;if d.tag=='weapon'and #r.items>5 then w=1 end;for n=1,w do pool[#pool+1]=d.id end
  end end
  if #pool==0 then break end;local id=pool[E.rand(r,#pool)];local z=E.add(r,id,0,0);if E.autoPlace(r,z)then budget=budget-D[id].price else table.remove(r.items);end
 end
 r.source='电脑构筑';r.name=botNames[E.rand(r,8)];return E.snapshot(r),r.name
end
function E.prepareMatch(r,bank)
 local combined={};for _,b in ipairs(bank or{})do combined[#combined+1]=b end;for _,b in ipairs(r.ghosts or{})do combined[#combined+1]=b end
 local reference=r.matchAnchor and r.matchAnchor.round==r.round and r.matchAnchor.hero==r.hero and r.matchAnchor or E.snapshot(r)
 local power=E.power(reference);local recentScore=0;for i=math.max(1,#r.history-2),#r.history do recentScore=recentScore+(r.history[i].winner or 0)end;local target=-math.max(-.09,math.min(.09,recentScore*.03))
 local candidates={};local recent={};for _,id in ipairs(r.recent or{})do recent[id]=true end
 for i,b in ipairs(combined)do if b.round==math.min(r.round,18)then local p=b.power or E.power(b);local dist=math.abs(math.log(p/power))+(recent[i]and .4 or 0);candidates[#candidates+1]={build=b,index=i,distance=dist,power=p}end end
 if #candidates==0 then for h=1,8 do local b=E.bot(math.min(r.round,18),E.heroes[h].id,1777+r.round*63+h*11,.8);candidates[#candidates+1]={build=b,index=h,power=E.power(b),distance=math.abs(math.log(E.power(b)/power))}end end
 table.sort(candidates,function(a,b)if a.distance==b.distance then return a.index<b.index end;return a.distance<b.distance end)
 local shortlist,seen={},{};for i=1,math.min(6,#candidates)do shortlist[#shortlist+1]=candidates[i];seen[candidates[i].build.hero]=true end
 for _,q in ipairs(candidates)do if not seen[q.build.hero]then shortlist[#shortlist+1]=q;seen[q.build.hero]=true end end
 return{r=r,reference=reference,target=target,power=power,candidates=#candidates,shortlist=shortlist,recent=recent,index=1,seed=1,margin=0,trial=0,total=#shortlist*2}
end
function E.stepMatch(job,stepBudget)
 if job.done then return true end
 local q=job.shortlist[job.index];local r=job.r
 if not job.fight then local opponent=copy(q.build);opponent.round=r.round;job.fight=E.startBattle(job.reference,opponent,9173+r.round*97+job.seed*311)end
 local f=job.fight;for i=1,(stepBudget or 1200)do if f.done then break end;E.step(f,.05)end
 if not f.done then return false end
 job.fight=nil;job.margin=job.margin+(f.a.hp-f.b.hp)/math.max(f.a.max,f.b.max);job.trial=job.trial+1
 if job.seed==1 then job.seed=2 else q.margin=job.margin/2;q.fairness=math.abs(q.margin-job.target)+(job.recent[q.index]and .12 or 0);job.index=job.index+1;job.seed=1;job.margin=0 end
 job.done=job.index>#job.shortlist;return job.done
end
function E.finishMatch(job)
 assert(job.done);local list=job.shortlist;local r=job.r
 table.sort(list,function(a,b)if a.fairness==b.fairness then return a.index<b.index end;return a.fairness<b.fairness end)
 local n=1;while n<math.min(3,#list)and list[n+1].fairness<=list[1].fairness+.12 do n=n+1 end
 local q=list[E.rand(r,n)];local opp=copy(q.build);opp.round=r.round;r.recent[#r.recent+1]=q.index;while #r.recent>3 do table.remove(r.recent,1)end
 return opp,{source=opp.source or'电脑构筑',opponentPower=q.power,playerPower=E.power(r),referencePower=job.power,shoppingGain=E.power(r)/job.power-1,ratio=q.power/E.power(r),targetMargin=job.target,candidates=job.candidates,trialBuilds=#list,estimatedMargin=q.margin,method='同轮次／购物前构筑／近期表现／双种子分步预演'}
end
function E.match(r,bank)local job=E.prepareMatch(r,bank);while not E.stepMatch(job)do end;return E.finishMatch(job)end
function E.canBegin(r)
 if r.phase~='shop'then return false,'当前不能出战'end
 if(r.round==3 or r.round==10)and #r.talents<(r.round==3 and 1 or 2)then return false,'请先选择本轮天赋'end
 if r.round>=8 and r.sub==0 then return false,'请先选择角色专精'end
 for _,q in ipairs(r.items)do if q.x>0 and(D[q.def].tag=='weapon'or D[q.def].tag=='summon')then return true end end
 return false,'请放入至少一件武器或召唤物'
end
function E.launch(r,opp,match)r.phase='battle';r.match=match;r.opponent=opp;return E.startBattle(r,opp,E.rand(r,9999999))end
function E.begin(r,bank)local ok,msg=E.canBegin(r);if not ok then return false,msg end;local opp,match=E.match(r,bank);return true,E.launch(r,opp,match)end

function E.finish(r,b)
 if r.phase~='battle'or not b.done then return false end
 r.phase='result';r.wins=r.wins+(b.winner==1 and 1 or 0);if b.winner~=1 then r.losses=r.losses+1;r.lives=r.lives-1 end
 local snap=E.snapshot(r);r.ghosts[#r.ghosts+1]=snap;while #r.ghosts>36 do table.remove(r.ghosts,1)end
 local crafted=r.autoCraft and E.craft(r)or 0
 local contributions={};local unusedFood=0;local worst=nil
 for _,z in ipairs(b.a.items)do local entry={id=z.instance,def=z.id,name=z.name,damage=z.total,heal=z.healed,shield=z.shielded,hits=z.hits,wait=z.wait};contributions[#contributions+1]=entry;if z.tag=='food'and z.hits==0 then unusedFood=unusedFood+1 end;if z.tag=='weapon'and(not worst or z.wait>worst.wait)then worst=entry end end
 table.sort(contributions,function(a,b)local aa=a.damage+a.heal*.7+a.shield*.5;local bb=b.damage+b.heal*.7+b.shield*.5;if aa==bb then return a.id<b.id end;return aa>bb end)
 local diagnosis={};if worst and worst.wait>1.5 then diagnosis[#diagnosis+1]=worst.name..'耐力等待 '..string.format('%.1f',worst.wait)..'秒'end
 if unusedFood>0 then diagnosis[#diagnosis+1]=unusedFood..'件料理本轮未触发'end
 if b.time>=17 then diagnosis[#diagnosis+1]='本轮进入17秒后的疲劳阶段'elseif b.winner==-1 and b.time<10 then diagnosis[#diagnosis+1]='10秒内败北，检查护盾与治疗启动'end
 local record={round=r.round,winner=b.winner,time=b.time,damage=b.a.totals.damage,heal=b.a.totals.heal,absorbed=b.a.totals.absorbed,wait=b.a.totals.wait,core=b.a.coreCount,match=r.match,crafted=crafted,contributions=contributions,diagnosis=diagnosis,coreDamage=b.a.coreDamage or 0,dotDamage=b.a.dotDamage or 0,thornDamage=b.a.thornDamage or 0};r.history[#r.history+1]=record;return true,record
end
function E.next(r,choice)
 if r.phase~='result'and r.phase~='milestone'then return false end
 if r.lives<=0 then r.phase='ended';return true end
 if r.wins>=10 and not r.survival and r.mode~='endless'then if choice=='stop'then r.phase='ended';return true elseif choice=='survive'then r.survival=true else r.phase='milestone';return true end end
 if r.round>=999 or(r.round>=18 and r.mode~='endless')then r.phase='ended';return true end
 r.round=r.round+1;r.gold=r.gold+E.economy.gold[math.min(r.round,18)];local _,g=E.compile(r);r.gold=r.gold+g.income;r.rerolls=0;r.phase='shop';E.refresh(r,true);r.matchAnchor=E.snapshot(r);return true
end
function E.choose(r,choice)
 if r.phase~='shop'then return false end
 if(r.round==3 or r.round==10)and #r.talents<(r.round==3 and 1 or 2)then r.talents[#r.talents+1]=choice;return true end
 if r.round>=8 and r.sub==0 and choice<=2 then r.sub=choice;return true end;return false
end
function E.staminaInfo(r)
 local items,g=E.compile(r);local demand=0;local weapons=0
 for _,z in ipairs(items)do if z.tag=='weapon'and z.cd>0 then demand=demand+z.cost/z.cd*z.speed*(1+g.haste);weapons=weapons+1 end end
 return{demand=demand,regen=1,weapons=weapons,bufferSeconds=demand>1 and 5/(demand-1)or 999}
end
local function affects(a,b)
 local x,y=D[a.def],D[b.def];local e=x.effect
 return e=='coreboost'or(e=='haste'and triggered(y)and(x.tag=='artifact'or x.tag=='gadget'or x.tag=='material'))or(e=='crit'and x.tag=='artifact'and y.tag=='weapon')or(e=='foodboost'and y.tag=='food'and(y.effect=='heal'or y.effect=='regen'or y.effect=='rescue'))or(e=='healboost'and(y.effect=='heal'or y.effect=='regen'or y.effect=='rescue'))or(e=='weaponboost'and y.tag=='weapon')or(e=='summonboost'and y.tag=='summon')or(x.tag=='food'and y.tag=='summon')or(e=='armorboost'and y.effect=='shield')or(e=='burnboost'and y.effect=='burn'and triggered(y))or(e=='poisonboost'and y.effect=='poison'and triggered(y))or(x.tag=='material'and(e=='burn'or e=='poison'or e=='slow')and y.tag=='weapon')or(e=='luck'and y.tag=='weapon')
end
function E.linked(a,b)return E.adjacent(a,b)and(affects(a,b)or affects(b,a))end
function E.related(r,id)
 local out={};local a=E.find(r,id);if a and a.x>0 then for _,b in ipairs(r.items)do if b~=a and E.linked(a,b)then out[b.id]=true end end end;return out
end
function E.previewRelated(r,q,x,y,rot)local a=copy(q);a.x=x;a.y=y;a.rot=rot;local out={};for _,b in ipairs(r.items)do if b.id~=q.id and E.linked(a,b)then out[b.id]=true end end;return out end
function E.recipeOptions(def)local out={};for _,p in ipairs(E.recipes)do if not def or p.a==def or p.b==def or p.out==def then out[#out+1]=p end end;return out end
function E.recipeStatus(r,out)
 local recipe=nil;for _,p in ipairs(E.recipes)do if p.out==out then recipe=p;break end end;if not recipe then return nil end
 local count={};for _,q in ipairs(r.items)do count[q.def]=(count[q.def]or 0)+1 end
 local missing={};local need={};need[recipe.a]=(need[recipe.a]or 0)+1;need[recipe.b]=(need[recipe.b]or 0)+1
 for _,id in ipairs({recipe.a,recipe.b})do if need[id]then if(count[id]or 0)<need[id]then missing[#missing+1]=D[id].name..(need[id]-(count[id]or 0)>1 and'×2'or'')end;need[id]=nil end end
 local ready=false;for _,c in ipairs(E.craftable(r))do if c.out==out then ready=true;break end end
 return{recipe=recipe,missing=missing,ready=ready,owned=#missing==0,complete=(count[out]or 0)>0}
end
function E.purchaseSpace(r,index)
 local offer=r.shop[index];if not offer or offer.sold then return false end
 local test={space=r.space,items=copy(r.items),nextId=r.nextId};local q=E.add(test,offer.def,0,0,offer.price);return E.autoPlace(test,q)
end
-- Public diagnostics and validated local save format; no effects on match outcomes.
local function integer(n,lo,hi)return type(n)=='number'and n==math.floor(n)and n>=lo and n<=hi end
local function validBuild(r)
 if type(r)~='table'or E.hero(r.hero).id~=r.hero or not integer(r.round,1,999)or not integer(r.space,16,63)or type(r.items)~='table'or #r.items>32 then return false end
 local seen={};local stash=0;local high=0
 for _,q in ipairs(r.items)do
  if type(q)~='table'or not integer(q.def,1,#D)or not integer(q.id,1,1000000)or seen[q.id]or not integer(q.x,0,9)or not integer(q.y,0,7)or not integer(q.rot,0,3)or not integer(q.paid,0,100000)then return false end
  seen[q.id]=true;high=math.max(high,q.id);if q.x==0 then stash=stash+1;if q.y~=0 then return false end elseif q.y==0 or not E.fits(r,q,q.x,q.y,q.rot)then return false end
 end
 if stash>8 or type(r.talents)~='table'or #r.talents>2 or not integer(r.sub,0,2)then return false end
 for _,v in ipairs(r.talents)do if not integer(v,1,3)then return false end end
 return true,high
end
E.validBuild=validBuild
function E.validate(r)
 local ok,high=validBuild(r);if not ok or r.version~=2 then return false end
 if r.mode~='standard'and r.mode~='endless'then return false end
 if r.phase~='shop'and r.phase~='result'and r.phase~='milestone'and r.phase~='ended'then return false end
 for k,bounds in pairs({gold={0,1000000},nextId={high+1,1000001},seed={1,2147483646},wins={0,999},losses={0,999},lives={0,5},rerolls={0,100000}})do if not integer(r[k],bounds[1],bounds[2])then return false end end
 if type(r.autoCraft)~='boolean'then return false end
 if type(r.shop)~='table'or #r.shop~=5 or type(r.history)~='table'or #r.history>999 or type(r.recent)~='table'or #r.recent>3 or type(r.ghosts)~='table'or #r.ghosts>36 then return false end
 for _,s in ipairs(r.shop)do if type(s)~='table'or not integer(s.def,1,#D)or not integer(s.price,0,100)or type(s.sale)~='boolean'or type(s.locked)~='boolean'or type(s.sold)~='boolean'then return false end end
 for _,g in ipairs(r.ghosts)do if not validBuild(g)then return false end end
 for _,h in ipairs(r.history)do
  if type(h)~='table'or not integer(h.round,1,999)or not integer(h.winner,-1,1)or type(h.match)~='table'or type(h.match.ratio)~='number'or h.match.ratio<=0 then return false end
  for _,k in ipairs({'time','damage','heal','absorbed','wait','core','crafted'})do local v=h[k];if type(v)~='number'or v~=v or v<0 or v>100000000 then return false end end
  if h.match.estimatedMargin~=nil and(type(h.match.estimatedMargin)~='number'or h.match.estimatedMargin~=h.match.estimatedMargin)then return false end
 end
 if r.opponent and not validBuild(r.opponent)then return false end
 if r.matchAnchor and not validBuild(r.matchAnchor)then return false end
 if r.trackedRecipe~=nil and(not integer(r.trackedRecipe,1,#D)or not E.recipeStatus(r,r.trackedRecipe))then return false end
 for _,h in ipairs(r.history)do
  if h.contributions~=nil then if type(h.contributions)~='table'or #h.contributions>32 then return false end;for _,z in ipairs(h.contributions)do if type(z)~='table'or type(z.name)~='string'then return false end;for _,k in ipairs({'damage','heal','shield','hits','wait'})do if type(z[k])~='number'or z[k]<0 or z[k]~=z[k]then return false end end end end
  if h.diagnosis~=nil then if type(h.diagnosis)~='table'or #h.diagnosis>4 then return false end;for _,t in ipairs(h.diagnosis)do if type(t)~='string'then return false end end end
 end
 for _,i in ipairs(r.recent)do if not integer(i,1,100000)then return false end end
 return true
end
return E
