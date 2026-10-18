-- 提瓦特背包乱斗 / Lua 5.3 / beyond-simulator native UI demo
local W,H=1600,900
local T={group=1073742701,rect=1073742702,text=1073742703,cursor=1073742704}
local colors={ink='#362820',dark='#493629',wood='#76523b',gold='#d7b265',paper='#ead6ac',muted='#8f7352',light='#fff1ce',purple='#9568b9',green='#75a76a',red='#b85143',blue='#698eaa'}
local function col(s,a) s=colors[s] or s;return Color.FromRGBA(tonumber(s:sub(2,3),16),tonumber(s:sub(4,5),16),tonumber(s:sub(6,7),16),a or 255) end
local ui,views,slots,items,shop={},{},{},{},{}
local created,peak,batch=0,0,0
local init,loading,ready
local queue,qi,recording={},1,false
local hero='raiden'
local s={phase='shop',round=1,wins=0,lives=3,gold=14,selected=0,rotation=0,clock=0,speed=1,seed=271828,nextid=1,note='点击商店购买，再点击背包格子放置。'}
local names={raiden='雷电将军',nahida='纳西妲'}
local defs={
 {name='训练单手剑',tag='weapon',w=1,h=3,price=3,quality=1,kind='sword',damage=8,cd=2.3,cost=2,desc='每2.3秒造成8伤害，消耗2耐力。'},
 {name='西风剑',tag='weapon',w=1,h=3,price=6,quality=2,kind='favonius',damage=10,cd=2.2,cost=2,desc='每2.2秒10伤害；命中额外获得1能量。'},
 {name='甜甜花酿鸡',tag='food',w=2,h=1,price=3,quality=1,kind='chicken',heal=13,cd=5,desc='生命低于75%时食用，恢复13生命；每场2次。'},
 {name='日落果',tag='food',w=1,h=1,price=2,quality=1,kind='fruit',heal=6,cd=3.5,desc='低于75%生命恢复6点；每场3次。'},
 {name='冒险家怀表',tag='charm',w=1,h=1,price=4,quality=2,kind='clock',desc='相邻武器冷却缩短12%；同件只计算一次。'},
 {name='充能晶片',tag='material',w=1,h=1,price=3,quality=2,kind='crystal',desc='每4秒获得2能量；可与训练剑合成引雷剑。',cd=4},
 {name='守护之花',tag='armor',w=2,h=2,price=4,quality=1,kind='flower',shield=9,cd=4,desc='每4秒获得9护盾。'},
 {name='薄荷',tag='material',w=1,h=1,price=2,quality=1,kind='mint',desc='相邻料理治疗+25%；可与日落果合成薄荷果冻。'},
 {name='引雷剑',tag='weapon',w=1,h=3,price=10,quality=3,kind='thunder',damage=17,cd=2.1,cost=2,desc='每2.1秒17伤害；命中额外获得2能量。'},
 {name='薄荷果冻',tag='food',w=1,h=1,price=6,quality=2,kind='jelly',heal=15,cd=4,desc='低于75%生命恢复15点；每场3次。'},
 {name='史莱姆瓶',tag='summon',w=2,h=2,price=5,quality=2,kind='slime',damage=5,cd=2.4,desc='每2.4秒造成5伤害；每份相邻料理伤害+20%。'},
 {name='精油药剂',tag='potion',w=1,h=2,price=4,quality=2,kind='potion',desc='每6秒强化下一次武器攻击，伤害+60%。',cd=6},
 {name='幸运羽饰',tag='charm',w=1,h=2,price=4,quality=2,kind='feather',desc='所有武器暴击率+15%，最多两件生效。'},
 {name='北地烟熏鸡',tag='food',w=2,h=1,price=4,quality=2,kind='chicken',cd=5,desc='每5秒恢复3耐力；每场3次。'},
 {name='祭礼残章',tag='weapon',w=2,h=2,price=7,quality=3,kind='book',damage=12,cd=3,cost=1,desc='每3秒12伤害，消耗1耐力；命中获得2能量。'}
}
local quality={'普通','精良','稀有'}
local qcolors={'#b8ae8a','#75a76a','#698eaa'}
local function rand(n) s.seed=(s.seed*48271)%2147483647;return s.seed%n+1 end
local function spawn(kind,parent,name,x,y,w,h)
 local function create()
  local p=parent;if type(p)=='table' and p.__resolve then p=p.__resolve() end
  local c=game.InstantiateClientUIControl(T[kind],p);assert(c,'缺失模板 '..kind)
  c.name=name;c:SetAnchorMin(0,0);c:SetAnchorMax(0,0);c:SetPivot(0,0);c:SetAnchoredPosition(x or 0,y or 0);c:SetSizeDelta(w or 0,h or 0)
  created=created+1;return c
 end
 if not recording then return create()end
 local handle;local proxy={__resolve=function()return handle end}
 queue[#queue+1]={create=true,run=function()handle=create()end}
 setmetatable(proxy,{__newindex=function(_,k,v)
  if recording then queue[#queue+1]={run=function()handle[k]=v end}else handle[k]=v end
 end,__index=function(_,k)
  if recording then return function(_,...)
   local args={...};queue[#queue+1]={run=function()handle[k](handle,table.unpack(args))end}
  end end
  local v=handle[k];if type(v)=='function' then return function(_,...)return v(handle,...)end end;return v
 end})
 return proxy
end

local function group(p,n,x,y,w,h) return spawn('group',p,n,x,y,w or W,h or H) end
local function shape(p,n,x,y,w,h,c,img,angle)
 local v=spawn('rect',p,n,x,y,w,h);v:SetImage(Enum.ImageSource.StaticReference,img or 100001);v.imageColor=col(c)
 if angle then v:SetPivot(.5,.5);v:SetLocalRotation(0,0,angle) end
 return v
end
local function text(p,n,x,y,w,h,t,size,c)
 local v=spawn('text',p,n,x,y,w,h);v.text=t;v.fontSize=size or 22;v.fontColor=col(c or 'ink');v.bgColor=col('#000000',0);v.enableOutline=false;v.adaptiveFontSize=false;v.horizontalAlignment=Enum.TextHorizontalAlignment.Left;v.verticalAlignment=Enum.TextVerticalAlignment.Middle;return v
end
local function panel(p,n,x,y,w,h)
 local b=group(p,n,x,y,w,h);shape(b,n..'_shadow',5,-6,w,h,'dark');shape(b,n..'_edge',0,0,w,h,'wood');shape(b,n..'_gold',3,3,w-6,h-6,'gold');shape(b,n..'_paper',7,7,w-14,h-14,'paper');shape(b,n..'_shade',8,8,w-16,3,'#c3a976');shape(b,n..'_shine',8,h-11,w-16,3,'#f8e8be');for _,pt in ipairs({{2,2},{w-7,2},{2,h-7},{w-7,h-7}})do shape(b,n..'_stud',pt[1],pt[2],5,5,'#533c2c',100002)end;return b
end
local function button(p,n,x,y,w,h,t,fn,c)
 local v=spawn('cursor',p,n,x,y,w,h);v.raycastTarget=true
 local bg=shape(v,n..'_edge',0,0,w,h,'dark');shape(v,n..'_trim',2,2,w-4,h-4,'gold');local fill=shape(v,n..'_fill',5,5,w-10,h-10,c or 'wood');local label=text(v,n..'_text',12,0,w-24,h,t,22,'light')
 v:AddCursorEventListener(Enum.CursorEventType.CursorClick,function() if ready then fn() end end)
 return {body=v,fill=fill,label=label}
end
-- Vector icon language. Unit-space rectangles, ellipses and rotated bars.
local function iconData(kind)
 local a={};local function r(x,y,w,h,c,img,rot) a[#a+1]={x,y,w,h,c,img or 100001,rot or 0} end
 local function e(x,y,w,h,c)r(x,y,w,h,c,100002)end
 if kind=='sword' or kind=='favonius' or kind=='thunder' then
  r(27,6,8,18,'#704839');r(25,8,12,5,'gold');r(14,25,34,6,'gold');r(27,29,8,29,'#b9d2d8');r(31,30,4,27,'#f3f3e0');r(24,57,15,12,'#dce6df',100003)
  if kind~='sword' then r(20,27,7,13,kind=='thunder' and 'purple' or 'green',100004);r(37,27,7,13,kind=='thunder' and 'purple' or 'green',100004) end
 elseif kind=='chicken' then
  e(5,12,54,29,'#f2e4c2');e(11,16,43,23,'#bb7435');e(15,24,31,26,'#d49445');r(38,30,20,6,'#e6c28b',100001,-25);e(50,21,9,10,'light');e(53,28,9,10,'light');e(20,31,10,6,'#efbc67')
 elseif kind=='fruit' then e(15,12,36,37,'#dc863e');e(16,32,16,15,'#e9ae51');r(31,46,4,12,'wood');e(34,49,17,9,'green')
 elseif kind=='clock' then e(10,8,46,48,'gold');e(15,13,36,38,'light');r(31,49,6,12,'gold');r(32,31,3,15,'ink');r(32,30,13,3,'ink');e(29,28,7,7,'wood')
 elseif kind=='crystal' then r(32,32,27,45,'#91cce0',100004,12);r(27,31,9,31,'#d3f1e3',100004,12);r(45,20,13,21,'purple',100004,-15)
 elseif kind=='flower' then
  for i=0,4 do local t=i*math.pi*2/5;e(24+math.cos(t)*14,24+math.sin(t)*14,24,20,'#c9d5aa') end;e(26,26,15,15,'gold');r(31,4,4,16,'green')
 elseif kind=='mint' then r(30,7,4,41,'green');e(12,17,23,12,'#72a982');e(33,29,23,12,'#5d976e');e(16,38,20,13,'#8fc593')
 elseif kind=='jelly' then e(10,10,49,15,'light');r(17,20,35,25,'green',100003);e(21,31,23,10,'#b8d898');e(26,36,7,4,'light')
 elseif kind=='slime' then r(19,3,30,7,'gold');r(14,10,40,41,'#8eafb5');r(18,13,32,34,'#c5e0d7');e(21,17,26,22,'#76b9bb');e(27,25,3,4,'ink');e(38,25,3,4,'ink');r(21,52,26,8,'gold');r(24,58,20,5,'wood')
 elseif kind=='potion' then e(15,8,39,36,'#6689a0');e(20,12,29,22,'purple');r(27,39,14,17,'#b5c9bb');r(23,54,22,8,'wood');e(22,25,7,10,'#d5cde2')
 elseif kind=='feather' then r(30,30,21,48,'#d6d4b3',100002,-28);r(25,22,3,43,'gold',100001,-28);r(20,13,16,4,'purple',100001,-28)
 elseif kind=='book' then r(11,10,44,45,'purple');r(16,14,37,37,'gold');r(20,16,33,34,'#dee0c7');r(29,31,16,21,'purple',100004);r(11,10,7,45,'#593f78')
 elseif kind=='eye' then e(5,19,54,30,'purple');e(12,25,40,18,'light');e(24,21,20,27,'purple');r(30,22,7,27,'#49315f');r(6,55,13,13,'gold',100004)
 else e(10,10,44,44,'green') end
 return a
end
local function iconPool(p,n,x,y,scale)
 local root=group(p,n,x,y,64,64);root:SetLocalScale(scale or 1,scale or 1,1);local v={root=root,kids={}}
 for i=1,28 do v.kids[i]=shape(root,n..'_vector'..i,0,0,1,1,'paper');v.kids[i]:SetVisible(false) end
 return v
end
local function setIcon(v,kind)
 if v.kind==kind then return end;v.kind=kind
 local a={};for _,q in ipairs(iconData(kind))do local t={q[1]-1.2,q[2]-1.2,q[3]+2.4,q[4]+2.4,'#685039',q[6],q[7]};a[#a+1]=t;a[#a+1]=q end
 for i,c in ipairs(v.kids) do local q=a[i];c:SetVisible(q~=nil);if q then c:SetPivot(q[7]~=0 and .5 or 0,q[7]~=0 and .5 or 0);c:SetAnchoredPosition(q[1],q[2]);c:SetSizeDelta(q[3],q[4]);c:SetImage(Enum.ImageSource.StaticReference,q[6]);c.imageColor=col(q[5]);c:SetLocalRotation(0,0,q[7]) end end
end
local function sprite(p,n,x,y,scale)
 local v={root=group(p,n,x,y,1,1),kids={},scale=scale};v.root:SetLocalScale(scale,scale,1)
 local max=0;for _,a in pairs(ART) do max=math.max(max,a.n) end
 for i=1,max do local c=shape(v.root,n..'_fit'..i,0,0,1,1,'light');v.kids[i]=c;c:SetVisible(false) end
 return v
end
local function setSprite(v,key)
 if v.key==key then return end;v.key=key;local a=ART[key];local scale=v.scale*(key=='nahida' and 1.12 or 1);v.root:SetLocalScale(scale,scale,1)
 for i,c in ipairs(v.kids) do c:SetVisible(i<=a.n);if i<=a.n then local j=(i-1)*5;local p=a.pal[a.r[j+5]];c:SetAnchoredPosition(a.r[j+1],a.r[j+2]);c:SetSizeDelta(a.r[j+3],a.r[j+4]);c.imageColor=Color.FromRGBA(p[1],p[2],p[3],p[4]) end end
end
local function dims(q) local d=defs[q.def];if q.rot%2==1 then return d.h,d.w end;return d.w,d.h end
local function fits(q,x,y,rot)
 local old=q.rot;q.rot=rot;local w,h=dims(q);q.rot=old
 if x<1 or y<1 or x+w-1>8 or y+h-1>5 then return false end
 for _,v in ipairs(items) do if v~=q and v.x>0 then local a,b=dims(v);if x<v.x+a and x+w>v.x and y<v.y+b and y+h>v.y then return false end end end
 return true
end
local function adjacent(a,b)
 if a.x==0 or b.x==0 then return false end
 local aw,ah=dims(a);local bw,bh=dims(b)
 return ((a.x+aw==b.x or b.x+bw==a.x) and a.y<b.y+bh and b.y<a.y+ah) or ((a.y+ah==b.y or b.y+bh==a.y) and a.x<b.x+bw and b.x<a.x+aw)
end
local function selected()for _,q in ipairs(items) do if q.id==s.selected then return q end end end
local function note(t)s.note=t end
local function addItem(k,x,y) local q={id=s.nextid,def=k,x=x or 0,y=y or 0,rot=0};s.nextid=s.nextid+1;items[#items+1]=q;return q end
local function genShop()
 local pool=s.round<=2 and {1,2,3,4,5,6,7,8,11,12,13,14} or {2,3,5,6,7,8,11,12,13,14,15}
 for i=1,5 do if not shop[i] or not shop[i].locked then shop[i]={def=pool[rand(#pool)],sold=false,locked=false} end end
 if s.round==1 and not s.refreshed then shop[1]={def=6};shop[2]={def=5};shop[3]={def=3};shop[4]={def=7};shop[5]={def=11} end
end
local function buy(i)
 if s.phase~='shop' then return end;local z=shop[i];if z.sold then return note('这件物品已售出，刷新补货。') end
 if #items>=20 then return note('物品已达20件，请出售或合成。') end
 local waiting=0;for _,q in ipairs(items) do if q.x==0 then waiting=waiting+1 end end;if waiting>=4 then return note('储物区已满，请先放置或出售。') end
 local d=defs[z.def];if s.gold<d.price then return note('摩拉不足。出售闲置物品，或开始下一战。') end
 s.gold=s.gold-d.price;local q=addItem(z.def);s.selected=q.id;s.rotation=0;z.sold=true;note('已购买'..d.name..'，点击空格放置。')
end
local function place(x,y)
 if s.phase~='shop' then return end
 local q=selected();if q then if fits(q,x,y,s.rotation) then q.x=x;q.y=y;q.rot=s.rotation;s.selected=0;note('放置完成。相邻联动已重新计算。')else note('放不下：请旋转或选择更多连续空格。')end;return end
 for _,v in ipairs(items) do if v.x>0 then local w,h=dims(v);if x>=v.x and x<v.x+w and y>=v.y and y<v.y+h then s.selected=v.id;s.rotation=v.rot;note('选中'..defs[v.def].name..'。点击目标格移动。');return end end end
 note('先点击一件装备，再点击空格移动。')
end
local function rotate()if s.phase~='shop' then return end;local q=selected();if not q then return note('先选中物品。') end;s.rotation=(s.rotation+1)%2;note('已旋转预览，点击背包格子确认放置。')end
local function sell()
 if s.phase~='shop' then return end;local q=selected();if not q then return note('先选中要出售的物品。') end
 for i,v in ipairs(items) do if v==q then table.remove(items,i);break end end;s.gold=s.gold+math.floor(defs[q.def].price/2);s.selected=0;note('出售完成。')
end
local function stash()
 if s.phase~='shop' then return end;local q=selected();if not q then return note('先选中背包内物品。')end
 local n=0;for _,v in ipairs(items)do if v.x==0 then n=n+1 end end;if n>=4 then return note('储物区已满。')end;q.x=0;q.y=0;s.selected=0;note('已移入储物区，本场不生效。')
end
local function combine()
 if s.phase~='shop' then return end
 for _,recipe in ipairs({{1,6,9},{4,8,10}}) do
  local a,b;for _,q in ipairs(items)do if q.def==recipe[1] and not a then a=q elseif q.def==recipe[2] and not b then b=q end end
  if a and b then
   -- Results use the first material's footprint or a smaller one; no collision growth.
   a.def=recipe[3];for i,q in ipairs(items)do if q==b then table.remove(items,i);break end end;s.selected=0;note('合成成功：'..defs[a.def].name..'！');return
  end
 end
 note('配方：训练单手剑＋充能晶片＝引雷剑；日落果＋薄荷＝薄荷果冻。')
end
local function refresh()
 if s.phase~='shop' then return end;if s.gold<1 then return note('刷新需要1摩拉。')end;s.gold=s.gold-1;s.refreshed=true;genShop();note('商店已刷新。长按不需要，点击锁定可保留商品。')
end
local function switchHero()
 if s.phase~='shop' then return end;hero=hero=='raiden' and 'nahida' or 'raiden';setSprite(views.hero,hero);note('已切换'..names[hero]..'。背包保留，角色核心随之变化。')
end
local function restart()
 items={};shop={};hero='raiden';s.phase='shop';s.round=1;s.wins=0;s.lives=3;s.gold=14;s.selected=0;s.preview=nil;s.nextid=1;s.refreshed=false;s.seed=271828
 addItem(1,1,1);addItem(4,3,1);addItem(7,5,1);addItem(11,5,4);genShop();if views.hero then setSprite(views.hero,hero)end;note('出发！购买充能晶片可与训练剑合成。目标5胜，3次失败结束。')
end
local function compile(list)
 local out={};local feathers=0
 for _,q in ipairs(list)do if q.x>0 and q.def==13 then feathers=math.min(2,feathers+1)end end
 for _,q in ipairs(list)do if q.x>0 then
  local d=defs[q.def];local z={id=q.id,def=q.def,cd=d.cd or 0,time=0,damage=d.damage or 0,heal=d.heal or 0,uses=q.def==3 and 2 or 3,crit=.05+.15*feathers,links=0}
  local clock=false;local mint=false;local foods=0
  for _,b in ipairs(list)do if b~=q and adjacent(q,b) then if b.def==5 then clock=true end;if b.def==8 then mint=true end;if defs[b.def].tag=='food' then foods=foods+1 end end end
  if clock and d.tag=='weapon' then z.cd=z.cd*.88;z.links=z.links+1 end
  if mint and d.tag=='food' then z.heal=z.heal*1.25;z.links=z.links+1 end
  if d.tag=='summon' then z.damage=z.damage*(1+.2*foods);z.links=z.links+foods end
  z.time=z.cd;out[#out+1]=z
 end end;return out
end
local battle
local function opponent()
 -- Legal, authored footprints within 8x5, progressively reinforced.
 local b={{def=1,x=1,y=1,rot=0,id=101},{def=4,x=3,y=1,rot=0,id=102},{def=7,x=5,y=1,rot=0,id=103}}
 if s.round>=2 then b[#b+1]={def=11,x=5,y=4,rot=0,id=104}end
 if s.round>=3 then b[1].def=2;b[#b+1]={def=5,x=2,y=2,rot=0,id=105}end
 if s.round>=4 then b[#b+1]={def=6,x=4,y=3,rot=0,id=106}end
 if s.round>=5 then b[1].def=9;b[#b+1]={def=3,x=7,y=1,rot=0,id=107}end
 if s.round>=7 then b[#b+1]={def=15,x=7,y=3,rot=0,id=108}end
 return b
end
local function startBattle()
 if s.phase~='shop' then return end
 local list=compile(items);local attack=false;for _,q in ipairs(list)do if q.damage>0 then attack=true end end;if not attack then return note('请至少放入一件武器或召唤物。')end
 s.phase='battle';s.selected=0;s.clock=0;s.acc=0;s.speed=1;local hp=100+10*(s.round-1)
 battle={a={hp=hp,max=hp,shield=0,stamina=10,energy=0,core=0,items=list,damage=0,heal=0,blocked=0,bursts=0,buff=0},b={hp=hp,max=hp,shield=0,stamina=10,energy=0,core=0,items=compile(opponent()),damage=0,heal=0,blocked=0,bursts=0,buff=0},logs={},flash=0}
 setSprite(views.duelHero,hero);setSprite(views.enemy,s.round%2==0 and 'raiden' or 'nahida');note('自动战斗中：每次武器命中产能，留意耐力与核心触发。')
end
local function log(t) table.insert(battle.logs,1,t);if #battle.logs>5 then table.remove(battle.logs)end end
local function damage(a,b,n,label)
 n=math.floor(n+.5);local shield=math.min(b.shield,n);b.shield=b.shield-shield;b.blocked=b.blocked+shield;b.hp=b.hp-(n-shield);a.damage=a.damage+n;battle.flash=.16;log(label..' '..n)
end
local function act(a,b,label,isRaiden,dt)
 a.stamina=math.min(10,a.stamina+dt*2);a.core=a.core+dt
 for _,q in ipairs(a.items)do
  local d=defs[q.def];q.time=q.time-dt
  if q.cd>0 and q.time<=0 then
   if d.tag=='weapon' then
    if a.stamina>=(d.cost or 0)then a.stamina=a.stamina-(d.cost or 0);local n=q.damage;if rand(100)<=q.crit*100 then n=n*1.5 end;if a.buff>0 then n=n*1.6;a.buff=0 end;damage(a,b,n,label..'·'..d.name);a.energy=a.energy+1+(q.def==2 and 1 or q.def==9 and 2 or q.def==15 and 1 or 0);q.time=q.time+q.cd;q.hits=(q.hits or 0)+1 else q.wait=(q.wait or 0)+dt end
   elseif d.tag=='summon' then damage(a,b,q.damage,label..'·史莱姆');q.time=q.time+q.cd
   elseif q.def==6 then a.energy=a.energy+2;q.time=q.time+q.cd
   elseif q.def==7 then a.shield=math.min(80,a.shield+9);q.time=q.time+q.cd
   elseif q.def==12 then a.buff=1;q.time=q.time+q.cd
   elseif d.tag=='food' then
    if q.uses>0 and (q.def==14 or a.hp<a.max*.75)then
     if q.def==14 then a.stamina=math.min(10,a.stamina+3)else local h=math.min(q.heal,a.max-a.hp);a.hp=a.hp+h;a.heal=a.heal+h end;q.uses=q.uses-1;q.time=q.time+q.cd
    end
   end
  end
 end
 local need=isRaiden and 10 or 8
 if a.energy>=need then a.energy=a.energy-need;a.bursts=a.bursts+1
  if isRaiden then damage(a,b,30+s.round*2,label..'·梦想一刀')else damage(a,b,15+s.round,label..'·灭净三业');local h=math.min(14,a.max-a.hp);a.hp=a.hp+h;a.heal=a.heal+h end
 end
end
local function finish()
 local a,b=battle.a,battle.b;local win=a.hp>0 and b.hp<=0;local draw=(a.hp<=0 and b.hp<=0)or s.clock>=60
 if win then s.wins=s.wins+1;s.result='胜利'else s.lives=s.lives-1;s.result=draw and '平局' or '败北'end
 s.phase='result';note('查看本场贡献，然后继续采购。储物区物品不会参与战斗。')
end
local function tick(dt)
 s.clock=s.clock+dt;battle.flash=math.max(0,battle.flash-dt)
 -- Both players finish this fixed step before death checks.
 act(battle.a,battle.b,'我方',hero=='raiden',dt);act(battle.b,battle.a,'对手',s.round%2==0,dt)
 if s.clock>30 then local n=(s.clock-30)*.35*dt;battle.a.hp=battle.a.hp-n;battle.b.hp=battle.b.hp-n end
 if battle.a.hp<=0 or battle.b.hp<=0 or s.clock>=60 then finish()end
end
local function nextRound()
 if s.phase~='result' then return end
 if s.wins>=5 or s.lives<=0 or s.round>=9 then s.phase='ended';note(s.wins>=5 and '挑战完成！你已取得5胜。点击重新启程再试一种构筑。' or '本次旅途结束。试试减少武器数量，补充充能和耐力。');return end
 s.round=s.round+1;s.gold=s.gold+10+math.floor((s.round-1)/3);s.phase='shop';s.selected=0;s.refreshed=true;genShop();note('获得新一轮摩拉。观察上一战的问题，继续完善背包。')
end
local function build()
 local root=script.object
 shape(root,'tavern_wall',0,0,W,H,'#a88659')
 -- Broad vector bands approximate paper and wood tones; grain is geometry.
 for i=0,17 do shape(root,'wall_tone'..i,0,i*50,W,51,string.format('#%02x%02x%02x',170+i,134+i,86+i)) end
 for i=1,32 do local x=(i*233)%1600;local y=(i*137)%900;shape(root,'paper_speck'..i,x,y,22+(i%7)*8,1,'#aa865b')end
 shape(root,'top_beam',0,872,W,28,'wood');shape(root,'bottom_beam',0,0,W,20,'wood');shape(root,'left_beam',0,0,20,H,'wood');shape(root,'right_beam',1580,0,20,H,'wood')
 for i=0,7 do shape(root,'beam_grain'..i,24,878+i*2,1552,1,i%2==0 and '#8a6645' or '#61452f')end
 text(root,'title',43,810,600,55,'提瓦特 · 背包乱斗',38,'ink');text(root,'subtitle',45,781,700,30,'',20,'dark')
 ui.stats=text(root,'run_stats',850,817,700,40,'',26,'ink')
 local bag=panel(root,'bag_frame',38,276,800,495);text(bag,'bag_title',20,445,700,36,'冒险行囊    8 × 5',25,'ink')
 ui.cells={};for y=1,5 do for x=1,8 do local xx=23+(x-1)*94;local yy=22+(5-y)*80;local id=(y-1)*8+x
  local c=spawn('cursor',bag,'cell_'..x..'_'..y,xx,yy,90,76);c.raycastTarget=true;local bg=shape(c,'cell_bg',0,0,90,76,'#cfba91');shape(c,'cell_inner',3,3,84,70,(x+y)%2==0 and '#decca6' or '#e5d3ac');ui.cells[id]={body=c,bg=bg};local cx,cy=x,y;c:AddCursorEventListener(Enum.CursorEventType.CursorClick,function()if ready then place(cx,cy)end end)
 end end
 views.itemLayer=group(bag,'item_layer',0,0,800,440)
 for i=1,20 do local v={root=group(views.itemLayer,'item_'..i,0,0,90,76)};v.bg=shape(v.root,'item_fill',0,0,90,76,'green');v.edge=shape(v.root,'item_edge',3,3,84,70,'#e9dfc0');v.icon=iconPool(v.root,'item_icon',8,12,.8);v.cooldown=shape(v.root,'item_cooldown',5,27,1,3,'purple');v.label=text(v.root,'item_name',4,2,180,25,'',15,'ink');v.root:SetVisible(false);slots[i]=v end
 local st=panel(root,'stash_frame',38,175,800,88);text(st,'stash_title',15,48,180,30,'储物区 · 不参战',20,'ink');ui.stash={}
 for i=1,4 do local n=i;ui.stash[i]=button(st,'stash_'..i,188+(i-1)*148,13,140,61,'空',function()if s.phase=='shop' then local n2=0;for _,q in ipairs(items)do if q.x==0 then n2=n2+1;if n2==n then s.selected=q.id;s.rotation=q.rot;note('已选中'..defs[q.def].name..'，点击背包放置。');return end end end end end,'muted') end
 ui.rotate=button(root,'rotate',40,112,142,49,'旋转 · 1',rotate);button(root,'stash_action',193,112,142,49,'移入储物',stash);button(root,'sell',346,112,142,49,'出售',sell);button(root,'combine',499,112,158,49,'合成配方',combine);button(root,'cancel',668,112,167,49,'取消选择',function()s.selected=0;s.preview=nil;note('已取消选择。')end)
 ui.detail=panel(root,'detail_panel',38,25,800,75);ui.detailText=text(ui.detail,'detail_text',14,8,772,60,'',19,'ink')
 views.shop=group(root,'shop_view',0,0,W,H)
 text(views.shop,'shop_heading',885,741,400,40,'冒险家商店',31,'ink');button(views.shop,'refresh',1333,735,205,53,'刷新 · 1摩拉',refresh)
 ui.shop={}
 for i=1,5 do local y=624-(i-1)*98;local n=i;local row=panel(views.shop,'shop_row'..i,883,y,655,87);local v={body=row};v.icon=iconPool(row,'shop_icon'..i,12,11,.92);v.name=text(row,'shop_name',84,43,355,30,'',23,'ink');v.desc=text(row,'shop_desc',84,12,355,27,'',16,'dark');v.buy=button(row,'buy_'..i,460,17,111,53,'',function()buy(n)end);v.lock=button(row,'lock_'..i,580,17,61,53,'锁',function()if s.phase=='shop' and not shop[n].sold then shop[n].locked=not shop[n].locked;note(shop[n].locked and '商品已锁定，下轮保留。'or'已解除锁定。')end end,'muted');local inspect=spawn('cursor',row,'inspect_shop_'..i,10,10,435,68);inspect.raycastTarget=true;inspect:AddCursorEventListener(Enum.CursorEventType.CursorClick,function()s.selected=0;s.preview=shop[n].def;note('查看商品说明。点击右侧价格购买。')end);ui.shop[i]=v end
 button(views.shop,'start_battle',1123,55,415,72,'整装出战 →',startBattle,'green')
 views.hero=sprite(root,'traveler_portrait',937,35,.78);setSprite(views.hero,hero)
 ui.heroTitle=text(root,'hero_title',1055,173,500,35,'',24,'ink');ui.heroDesc=text(root,'hero_desc',1055,129,485,44,'',18,'dark');ui.switch=button(root,'switch_hero',870,190,168,42,'切换角色',switchHero,'purple')
 views.battle=group(root,'battle_view',850,260,710,530);views.battle:SetVisible(false)
 local arena=panel(views.battle,'arena',18,0,680,520)
 text(arena,'duel_title',20,461,620,40,'地脉试炼',29,'ink');shape(arena,'floor',13,191,654,5,'wood');for i=1,8 do shape(arena,'floor_line',17+i*70,155,50,2,'muted')end
 views.duelHero=sprite(arena,'duel_hero',165,196,1.0);views.enemy=sprite(arena,'duel_enemy',515,196,1.0);setSprite(views.duelHero,hero);setSprite(views.enemy,'nahida')
 ui.playerHp=text(arena,'player_hp',22,414,310,37,'',21,'ink');ui.enemyHp=text(arena,'enemy_hp',359,414,305,37,'',21,'ink');ui.hp1=shape(arena,'hp1',25,401,275,10,'green');ui.hp2=shape(arena,'hp2',365,401,275,10,'red')
 ui.resources=text(arena,'resources',22,354,640,38,'',20,'dark');ui.battleLog=text(arena,'battle_log',22,24,638,139,'',21,'ink');ui.slash=shape(arena,'burst_slash',326,272,265,10,'purple',100001,20);ui.slash:SetVisible(false)
 ui.timer=text(arena,'timer',268,195,170,40,'',20,'ink');button(arena,'speed',425,460,222,44,'战斗速度 ×1/×3',function()if s.phase=='battle' then s.speed=s.speed==1 and 3 or 1 end end,'purple')
 views.result=panel(root,'result_view',869,287,672,470);views.result:SetVisible(false);ui.resultTitle=text(views.result,'result_title',26,386,615,65,'',40,'ink');ui.resultBody=text(views.result,'result_body',26,102,615,268,'',23,'ink');ui.next=button(views.result,'next_round',27,26,617,65,'领取摩拉 · 下一轮 →',function()if s.phase=='ended'then restart()else nextRound()end end,'green')
 ui.restart=button(root,'restart',1348,777,190,39,'重新启程',restart,'wood')
 ui.notice=text(root,'notice',45,779,1280,30,'',18,'ink')
 restart()
end
local function render()
 ui.stats.text='第 '..s.round..' 轮     胜场 '..s.wins..'/5     生命 '..s.lives..'     摩拉 '..s.gold
 ui.notice.text=s.note
 views.shop:SetVisible(s.phase=='shop');views.battle:SetVisible(s.phase=='battle');views.result:SetVisible(s.phase=='result' or s.phase=='ended');ui.switch.body:SetVisible(s.phase=='shop')
 ui.heroTitle.text=names[hero]..(hero=='raiden' and ' · 愿力之轮' or ' · 摩耶之殿');ui.heroDesc.text=hero=='raiden' and '武器命中产能；10能量释放梦想一刀。'or'武器命中产能；8能量触发灭净三业并治疗。'
 local q=selected();local desc='选择装备查看效果。  配方：训练剑＋晶片 / 日落果＋薄荷'
 if q then local d=defs[q.def];desc=d.name..' ['..quality[d.quality]..']  方向：'..(s.rotation%2==0 and '原向' or '横转')..'\n'..d.desc elseif s.preview then local d=defs[s.preview];desc=d.name..' ['..quality[d.quality]..'] · '..d.w..'×'..d.h..'格\n'..d.desc end
 ui.detailText.text=desc
 local occupied={};local links={};local timers={};if battle and s.phase=='battle' then for _,z in ipairs(battle.a.items)do timers[z.id]=z end end;for _,z in ipairs(compile(items))do links[z.id]=z.links end
 for _,v in ipairs(items)do if v.x>0 then local w,h=dims(v);for y=v.y,v.y+h-1 do for x=v.x,v.x+w-1 do occupied[(y-1)*8+x]=true end end end end
 for i,v in ipairs(ui.cells)do v.bg.imageColor=col(occupied[i] and '#ac936f' or '#cfba91')end
 for i,v in ipairs(slots)do local z=items[i];local on=z~=nil and z.x>0;v.root:SetVisible(on);if on then local d=defs[z.def];local w,h=dims(z);v.root:SetAnchoredPosition(23+(z.x-1)*94,22+(6-z.y-h)*80);v.bg:SetSizeDelta(w*94-4,h*80-4);v.bg.imageColor=col(z.id==s.selected and '#efc453' or qcolors[d.quality]);v.edge:SetSizeDelta(w*94-10,h*80-10);v.edge.imageColor=col(z.id==s.selected and '#f9e5a5' or '#e6d9b8');v.icon.root:SetPivot(.5,.5);v.icon.root:SetAnchoredPosition(w*94/2,h*80/2+6);v.icon.root:SetLocalScale(math.min((d.w*94-18)/64,2.3),math.min((d.h*80-32)/64,2.9),1);v.icon.root:SetLocalRotation(0,0,z.rot%2==1 and 90 or 0);setIcon(v.icon,d.kind);v.label:SetSizeDelta(w*94-10,25);v.label.text=d.name..((links[z.id]or 0)>0 and ' ★' or '');local timer=timers[z.id];v.cooldown:SetVisible(timer~=nil and timer.cd>0);if timer and timer.cd>0 then v.cooldown:SetSizeDelta((w*94-14)*math.max(0,math.min(1,1-timer.time/timer.cd)),3)end end end
 local waiting={};for _,v in ipairs(items)do if v.x==0 then waiting[#waiting+1]=v end end;for i,v in ipairs(ui.stash)do v.label.text=waiting[i] and defs[waiting[i].def].name or '空';v.fill.imageColor=col(waiting[i] and waiting[i].id==s.selected and 'purple' or 'muted')end
 for i,v in ipairs(ui.shop)do local z=shop[i];if z then local d=defs[z.def];setIcon(v.icon,d.kind);v.name.text=d.name..' · '..quality[d.quality];v.desc.text=d.tag=='weapon' and ('攻击 '..(d.damage or 0)..' / 冷却 '..(d.cd or 0)..'秒 / 耐力 '..(d.cost or 0)) or d.tag=='food' and '料理 · 单场消耗，下场恢复' or d.tag=='charm' and '饰物 · 强化构筑与空间联动' or d.tag=='summon' and '召唤 · 相邻料理提供增益' or d.tag=='armor' and '护具 · 周期获得护盾' or d.tag=='potion' and '药剂 · 周期强化下一次攻击' or '材料 · 充能或料理联动';v.buy.label.text=z.sold and '售罄' or d.price..'摩拉';v.buy.fill.imageColor=col(z.sold and 'muted' or s.gold>=d.price and 'wood' or 'red');v.lock.label.text=z.locked and '已锁' or '锁' end end
 if battle and (s.phase=='battle' or s.phase=='result') then
  local a,b=battle.a,battle.b
  ui.playerHp.text='我方 '..math.max(0,math.ceil(a.hp))..' / '..a.max..'  盾'..math.floor(a.shield);ui.enemyHp.text='对手 '..math.max(0,math.ceil(b.hp))..' / '..b.max..'  盾'..math.floor(b.shield)
  ui.hp1:SetSizeDelta(275*math.max(0,a.hp/a.max),10);ui.hp2:SetSizeDelta(275*math.max(0,b.hp/b.max),10)
  ui.resources.text='耐力 '..string.format('%.1f',a.stamina)..'/10    能量 '..a.energy..'    核心 '..a.bursts..'次'
  ui.timer.text=string.format('%.1f 秒  ×%d',s.clock,s.speed);ui.battleLog.text=table.concat(battle.logs,'\n');ui.slash:SetVisible(battle.flash>0)
  local breath=math.sin(s.clock*3)*2;views.duelHero.root:SetAnchoredPosition(165,196+breath);views.enemy.root:SetAnchoredPosition(515,196-breath)
  if s.phase=='result' then local waits=0;for _,z in ipairs(a.items)do waits=waits+(z.wait or 0)end
   ui.resultTitle.text=s.result..'  ·  第'..s.round..'轮';ui.resultBody.text='造成伤害 '..a.damage..'     治疗 '..math.floor(a.heal)..'\n我方护盾吸收 '..a.blocked..'     核心 '..a.bursts..'次\n\n'..(waits>2 and '武器争抢耐力，累计等待 '..string.format('%.1f',waits)..'秒。\n试试减少武器或加入耐力料理。'or'耐力循环顺畅，尝试加强空间联动。')..'\n\n胜场 '..s.wins..'/5     剩余生命 '..s.lives
  end
 end
 ui.next.label.text=s.phase=='ended' and '重新启程 →' or (s.wins>=5 or s.lives<=0 or s.round>=9) and '查看本局成绩 →' or '领取摩拉 · 下一轮 →';if s.phase=='ended' then ui.detailText.text=s.note;ui.resultTitle.text=s.wins>=5 and '挑战通关 · 行囊成型' or '旅途结束';ui.resultBody.text='本局胜场 '..s.wins..' / 5\n经历轮次 '..s.round..'     剩余生命 '..s.lives..'\n\n'..s.note end
end
function OnStart()
 local root=script.object;local cw,ch=game.GetUICanvasSize();local scale=math.min(cw/W,ch/H)
 root:SetAnchorMin(.5,.5);root:SetAnchorMax(.5,.5);root:SetPivot(.5,.5);root:SetAnchoredPosition(0,0);root:SetSizeDelta(W,H);root:SetLocalScale(scale,scale,1);root.showCursor=true;root.disableKeyEventPassthrough=true;root.disableCursorEventPassthrough=true
 loading=shape(root,'loading',0,0,W,H,'ink');text(loading,'loading_label',430,400,900,100,'正在整理冒险行囊 · 分批准备图元',32,'light')
 recording=true;build();recording=false;init=true;script:EnableUpdate(true)
 local function key(n,fn)local k=Enum.KeyEventType[n];if k then root:AddKeyEventListener(k,function()if ready then fn()end;return true end)end end
 key('KeyboardCraftspersonKey1Down',rotate);key('KeyboardCraftspersonKey2Down',refresh);key('KeyboardCraftspersonKey3Down',combine);key('KeyboardCraftspersonKey4Down',function()if s.phase=='shop'then startBattle()elseif s.phase=='result'then nextRound()end end)
end
function OnUpdate(dt)
 if init then
  batch=0
  while qi<=#queue do local job=queue[qi];if job.create and batch>=60 then break end;job.run();if job.create then batch=batch+1 end;qi=qi+1 end
  peak=math.max(peak,batch);loading:SetAsLastSibling()
  if qi>#queue then init=nil;ready=true;loading:SetVisible(false);render()end;return
 end
 if not ready then return end
 if s.phase=='battle' then s.acc=math.min(.3,(s.acc or 0)+math.min(dt,.1)*s.speed);while s.acc>=.05 and s.phase=='battle'do tick(.05);s.acc=s.acc-.05 end end
 s.paint=(s.paint or 0)+dt;if s.paint>=.1 then s.paint=0;render()end
end
function Inspect()
 local list={};for _,q in ipairs(items)do list[#list+1]={id=q.id,def=q.def,x=q.x,y=q.y,rot=q.rot}end
 return {ready=ready or false,phase=s.phase,hero=hero,round=s.round,wins=s.wins,lives=s.lives,gold=s.gold,selected=s.selected,rotation=s.rotation,items=list,shop=shop,note=s.note,clock=s.clock,created=created,peakCreated=peak,result=s.result,combat=battle and {hp=battle.a.hp,enemyHp=battle.b.hp,damage=battle.a.damage,bursts=battle.a.bursts,heal=battle.a.heal}or nil}
end
