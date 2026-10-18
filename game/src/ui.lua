-- Teyvat Backpack Battles R2.1. UI is a projection of the pure Lua rules.
local W,H=1600,900
local T={group=1073742701,rect=1073742702,text=1073742703,cursor=1073742704}
local colors={ink='#352746',dark='#30203e',wood='#614339',gold='#d8b56b',paper='#f2e3c2',muted='#94785e',light='#fff3d5',purple='#7445a3',green='#6d955c',red='#bc5c58',blue='#618fbd'}
local function col(s,a)s=colors[s]or s;return Color.FromRGBA(tonumber(s:sub(2,3),16),tonumber(s:sub(4,5),16),tonumber(s:sub(6,7),16),a or 255)end
local ui,views,slots={},{},{}
local created,peak,batch=0,0,0
local init,loading,loadingLabel,ready,totalCreates,pendingBase
local queue,qi,recording={},1,false
local r=E.newRun('raiden',382173)
local selectedId,rotation,preview,notice=0,0,nil,'选择角色开始一场新的冒险。'
local pick=true;local previewHero='raiden';local mode='standard';local book=false;local bookPage=1;local bookTab='items';local history=false
local pendingBattle=nil;local hoverX,hoverY,hoverItem,drag=0,0,0,nil;local matchJob=nil;local fight=nil;local acc,paint=0,0;local speed=1;local revision=0;local undo={}
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
 if kind=='sword' or kind=='favonius' or kind=='thunder' or kind=='greatsword' or kind=='spear' then
  r(27,6,8,18,'#704839');r(25,8,12,5,'gold');r(14,25,34,6,'gold');r(27,29,8,29,'#b9d2d8');r(31,30,4,27,'#f3f3e0');r(24,57,15,12,'#dce6df',100003)
  if kind~='sword' then r(20,27,7,13,kind=='thunder' and 'purple' or 'green',100004);r(37,27,7,13,kind=='thunder' and 'purple' or 'green',100004) end
 elseif kind=='bow' then
  r(24,31,24,50,'gold',100002);r(18,31,20,42,'paper',100002);r(27,32,2,49,'ink');r(34,31,40,3,'gold');r(54,27,12,12,'blue',100003)
 elseif kind=='fish' then
  e(13,13,36,43,'#829aa5');r(32,6,26,18,'#526d81',100003);e(24,43,4,4,'ink');r(29,22,2,19,'light')
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
 local v={root=group(p,n,x,y,1,1),kids={},scale=scale,name=n};v.root:SetLocalScale(scale,scale,1);return v
end
local function setSprite(v,key)
 if v.key==key then return end
 local a=ART[key];local dynamic=a.n>#v.kids and not recording
 if dynamic then queue={};qi=1;recording=true;init=true;ready=false;pendingBase=created;loading:SetVisible(true);loading:SetAsLastSibling()end
 for i=#v.kids+1,a.n do local c=shape(v.root,v.name..'_pixel'..i,0,0,1,1,'light',100001);c:SetPivot(.5,.5);v.kids[i]=c;c:SetVisible(false)end
 v.key=key
 for i,c in ipairs(v.kids)do c:SetVisible(i<=a.n);if i<=a.n then local j=(i-1)*7;local p=a.pal[a.r[j+7]];c:SetAnchoredPosition(a.r[j+1],a.r[j+2]);if a.mode=='scan'then c:SetImage(Enum.ImageSource.StaticReference,100001);c:SetLocalScale(a.r[j+3],a.r[j+4],1);c:SetLocalRotation(0,0,0)else c:SetImage(Enum.ImageSource.StaticReference,100003);c:SetLocalScale(a.r[j+3],a.r[j+3],1);c:SetLocalRotation(a.r[j+4],a.r[j+5],a.r[j+6])end;c.imageColor=Color.FromRGBA(p[1],p[2],p[3],p[4])end end
 if dynamic then recording=false;pendingBase=pendingBase or 0;totalCreates=0;for _,job in ipairs(queue)do if job.create then totalCreates=totalCreates+1 end end end
end
local effectNames={energy='充能',stamina='耐力',heal='治疗',regen='再生',rescue='急救',shield='护盾',burn='灼烧',poison='中毒',slow='减速',cleanse='净化',empower='强化',haste='加速',crit='暴击',extra='追击',lifesteal='吸血',fish='大鲔冲击',alchemy='质变',copy='记录',thorns='反伤',healstrike='海染泡沫',income='每轮额外摩拉',foodboost='相邻料理强化',healboost='相邻治疗强化',armorboost='相邻护盾强化',weaponboost='相邻武器强化',summon='弦外协同',summonboost='相邻召唤强化',coreboost='核心强化',burnboost='灼烧强化',poisonboost='中毒强化',luck='幸运收藏'}
local quality={'普通','精良','稀有','史诗','传说'}
local qcolors={'#9c9478','#71966a','#6d9cbb','#986cb8','#d4a34f'}
local function touch()revision=revision+1 end
local function notify(t)notice=t;touch()end
local function selected()return E.find(r,selectedId)end
local function saveUndo()local t={};for _,q in ipairs(r.items)do t[q.id]={x=q.x,y=q.y,rot=q.rot}end;undo[#undo+1]=t;if #undo>15 then table.remove(undo,1)end end
local function invoke(fn,...)
 if matchJob or pick or book or history then return end
 local ok,value=fn(r,...);if not ok then notify(value or'操作未满足条件');return false end;touch();return true,value
end
local passiveDesc={foodboost='相邻料理治疗 +20%',healboost='相邻治疗与再生效果 +15%',weaponboost='相邻武器伤害 +12%',summonboost='相邻召唤伤害 +15%',armorboost='相邻护盾值 +15%',coreboost='每个相邻物品：核心 +2.5%，总上限 +60%',burnboost='相邻灼烧叠层 +15%',poisonboost='相邻中毒叠层 +15%',luck='相邻武器暴击率 +2.5%'}
local function describe(d)
 local t=d.name..' ['..quality[d.q]..'] '..d.w..'×'..d.h..'格  买价 '..d.price..'\n'
 if d.damage then t=t..'伤害 '..string.format('%.1f',d.damage)..' / '..d.cd..'秒 / 耐力 '..(d.cost or 0)..'  'end
 if d.tag=='food'and d.effect=='crit'then return t..'每次食用暴击率 +4%，本场最多 +20% · 每场'..d.uses..'次'end
 if passiveDesc[d.effect]then return t..passiveDesc[d.effect]end
 if d.tag=='artifact'and d.effect=='haste'then return t..'相邻物品冷却速度 +12%，总上限 +60%'end
 if d.tag=='artifact'and d.effect=='crit'then return t..'相邻武器暴击率 +10%，总上限45%'end
 if d.tag=='material'and(d.effect=='burn'or d.effect=='poison'or d.effect=='slow')then return t..'相邻武器命中附加：'..effectNames[d.effect]end
 return t..(effectNames[d.effect]or'基础攻击')..(d.effect~=''and d.amount and(' '..string.format('%.2g',d.amount))or'')..(d.uses and(' · 每场'..d.uses..'次')or'')
end
local function cell(x,y)
 if matchJob or r.phase~='shop'or pick or book or history then return end
 local q=selected();if q then saveUndo();local ok,msg=E.move(r,q.id,x,y,rotation);if ok then selectedId=0;notify('已放置：'..E.name(q.def))else table.remove(undo);notify(msg)end;return end
 for _,v in ipairs(r.items)do if v.x>0 then for _,p in ipairs(E.cells(v))do if p[1]==x and p[2]==y then selectedId=v.id;rotation=v.rot;preview=v.def;notify('点击目标格移动；1旋转；可移入储物或出售。');return end end end end
end
local function buy(i)if matchJob then return end;local ok,q=invoke(E.buy,i);if ok then selectedId=q.id;rotation=q.rot;preview=q.def;notify('购入'..E.name(q.def)..'，点击空格放置。')end end
local function rotate()if not matchJob and r.phase=='shop'and(drag and drag.q or selected())then rotation=(rotation+1)%4;notify('旋转预览 '..rotation*90 ..'°，点击格子确认。')end end
local function sell()local q=selected();if not q then return notify('先选中物品。')end;local ok,n=invoke(E.sell,q.id);if ok then selectedId=0;notify('已出售，收回'..n..'摩拉。')end end
local function stash()local q=selected();if not q then return notify('先选中物品。')end;saveUndo();local ok=invoke(E.move,q.id,0,0,q.rot);if ok then selectedId=0;notify('已移入储物区，不参与本轮战斗。')end end
local function craftToggle()if matchJob or r.phase~='shop'then return end;r.autoCraft=not r.autoCraft;notify(r.autoCraft and'已开启战后合成。材料必须放在背包内并相邻。'or'已关闭战后合成。')end
local function itemAt(x,y)
 for _,q in ipairs(r.items)do if q.x>0 then for _,p in ipairs(E.cells(q))do if p[1]==x and p[2]==y then return q end end end end
end
local function editable()return ready and not matchJob and not pendingBattle and r.phase=='shop'and not pick and not book and not history end
local function gridPosition(event,press)
 local x,y;if press then x,y=event:GetPressUIPos()else x,y=event:GetUIPos()end;local cw,ch=game.GetUICanvasSize();local scale=math.min(cw/W,ch/H);x=(x-(cw-W*scale)/2)/scale;y=(y-(ch-H*scale)/2)/scale
 local gx=math.floor((x-56)/84)+1;local gy=7-math.floor((y-325)/56)
 if x<56 or x>=808 or y<325 or y>=713 or gx<1 or gx>9 or gy<1 or gy>7 then return 0,0 end;return gx,gy
end
local function placeTarget()return drag and drag.q or selected()end
local function highlighted()local q=placeTarget();if q and hoverX>0 and E.fits(r,q,hoverX,hoverY,rotation)then return E.previewRelated(r,q,hoverX,hoverY,rotation)end;return E.related(r,selectedId>0 and selectedId or hoverItem)end
local function updateDrag(event)
 if not drag then return end;local x,y=gridPosition(event);hoverX=x>0 and x-drag.dx or 0;hoverY=y>0 and y-drag.dy or 0;touch()
end
local function startDrag(event,q,shopIndex)
 if not editable()or not q then return end
 local x,y=gridPosition(event,true);drag={q=q,shop=shopIndex,dx=not shopIndex and q.x>0 and x-q.x or 0,dy=not shopIndex and q.y>0 and y-q.y or 0};rotation=q.rot or 0
 if not shopIndex then selectedId=q.id end;preview=q.def;updateDrag(event)
end
local function endDrag(event)
 if not drag then return end;updateDrag(event);local d=drag;local q=d.q;local valid=hoverX>0 and E.fits(r,q,hoverX,hoverY,rotation)
 if valid then
  if d.shop then local ok,purchased=E.buy(r,d.shop);if ok then q=purchased else valid=false;notify(purchased)end end
  if valid then saveUndo();local ok,msg=E.move(r,q.id,hoverX,hoverY,rotation);if ok then selectedId=0;notify('已放置：'..E.name(q.def))else table.remove(undo);notify(msg)end end
 else notify('拖放取消：目标不可用，物品与摩拉保持原状。')end
 drag=nil;hoverX=0;hoverY=0;touch()
end
local function bindDrag(control,getSource)
 control:AddCursorEventListener(Enum.CursorEventType.CursorBeginDrag,function(event)local q,index=getSource();startDrag(event,q,index)end)
 control:AddCursorEventListener(Enum.CursorEventType.CursorDrag,function(event)updateDrag(event)end)
 control:AddCursorEventListener(Enum.CursorEventType.CursorEndDrag,function(event)endDrag(event)end)
end
local function trackRecipe()
 if not editable()then return end;local q=selected();local list=E.recipeOptions(q and q.def or preview);if #list==0 then return notify('此物品暂无合成配方。')end
 local index=0;for i,p in ipairs(list)do if p.out==r.trackedRecipe then index=i;break end end
 if index==#list then r.trackedRecipe=nil;notify('已取消配方追踪。')else r.trackedRecipe=list[index+1].out;notify('追踪 '..E.name(r.trackedRecipe)..'；商店材料标记 ◆。')end
end
local function launchPending()
 local p=pendingBattle;if not p then return end;pendingBattle=nil;fight=E.launch(r,p.opp,p.meta);acc=0;speed=1;selectedId=0;drag=nil;undo={};notify('已匹配 '..p.meta.source..'；本轮购买收益已保留。')
end
local function begin()
 if matchJob or pick or book or history then return end
 local ok,msg=E.canBegin(r);if not ok then return notify(msg)end
 matchJob=E.prepareMatch(r,BOT_BANK);notify('正在匹配：比较同轮次背包，分批进行战斗预演…')
end
local function nextRound(choice)local ok=E.next(r,choice);if ok then selectedId=0;undo={};touch();notify(r.phase=='shop'and'新一轮摩拉已到账。留意天赋、专精和背包扩容。'or'查看本局成绩，或选择继续挑战。')end end
local function openPick()if pendingBattle or matchJob then return end;pick=true;previewHero=r.hero;setSprite(views.hero,previewHero);touch()end
local function chooseHero(id)previewHero=id;setSprite(views.hero,id);touch()end
local function newRun()
 local oldGhosts=r.ghosts;r=E.newRun(previewHero,math.floor((revision+1)*8273+17291),mode);r.ghosts=oldGhosts;pick=false;book=false;history=false;selectedId=0;drag=nil;hoverX=0;hoverY=0;undo={};fight=nil;setSprite(views.hero,r.hero);notify('初始13摩拉。购买装备、整理背包后出战。')
end
local visibility={}
local function show(c,on)if visibility[c]~=on then visibility[c]=on;c:SetVisible(on)end end
local function build()
 local root=script.object
 shape(root,'wall',0,0,W,H,'#ad8d61');shape(root,'top',0,792,W,108,'#30203e');shape(root,'floor',0,0,W,24,'#553c35')
 -- Faceted large shapes; no screenshot or PNG wallpaper.
 for i=1,16 do local x=(i*199)%1600;local y=(i*137)%760;shape(root,'wall_facet'..i,x,y,140+i%4*35,80+i%3*22,i%2==0 and'#b89b70'or'#a0815e',100003,i%2==0 and 30 or-25)end
 text(root,'title',42,827,710,55,'提瓦特 · 背包乱斗',36,'light');ui.stats=text(root,'stats',812,831,750,45,'',24,'light');ui.notice=text(root,'notice',44,794,1500,30,'',18,'light')
 local bag=panel(root,'bag_frame',36,305,802,474);text(bag,'bag_label',20,425,520,39,'冒险行囊 · 9 × 7',25,'ink');ui.space=text(bag,'space_label',528,427,250,35,'',20,'ink')
 ui.cells={};for y=1,7 do for x=1,9 do local xx=20+(x-1)*84;local yy=20+(7-y)*56;local n=(y-1)*9+x
  local c=spawn('cursor',bag,'cell_'..x..'_'..y,xx,yy,80,52);c.raycastTarget=true;local bg=shape(c,'cell_bg',0,0,80,52,'paper');local edge=shape(c,'cell_inset',3,3,74,46,'#decca7');ui.cells[n]={body=c,bg=bg,edge=edge};local cx,cy=x,y;c:AddCursorEventListener(Enum.CursorEventType.CursorClick,function()if ready then cell(cx,cy)end end)
  c:AddCursorEventListener(Enum.CursorEventType.CursorEnter,function()if editable()and not drag then hoverX=cx;hoverY=cy;local q=itemAt(cx,cy);hoverItem=q and q.id or 0;if q and selectedId==0 then preview=q.def end;touch()end end)
  c:AddCursorEventListener(Enum.CursorEventType.CursorExit,function()if not drag and hoverX==cx and hoverY==cy then hoverX=0;hoverY=0;hoverItem=0;touch()end end)
  bindDrag(c,function()return itemAt(cx,cy)end)

 end end
 local itemLayer=group(bag,'items',0,0,802,420)
 for i=1,32 do local v={root=group(itemLayer,'item_'..i,0,0,80,52)};v.bg=shape(v.root,'item_quality',0,0,80,52,'green');v.fill=shape(v.root,'item_paper',3,3,74,46,'paper');v.icon=iconPool(v.root,'item_icon',0,0,1);v.name=text(v.root,'item_name',3,0,160,23,'',13,'ink');v.cool=shape(v.root,'item_cooldown',4,23,1,3,'purple');v.root:SetVisible(false);slots[i]=v end
 ui.ghost={};local ghostLayer=group(bag,'placement_preview',0,0,802,420)
 for i=1,12 do local c=shape(ghostLayer,'placement_cell'..i,0,0,80,52,'green');c:SetVisible(false);ui.ghost[i]=c end
 ui.buildSummary=text(root,'build_summary',312,257,526,43,'',16,'ink')
 ui.heroName=text(root,'hero_name',42,271,260,32,'',20,'ink')
 local store=panel(root,'stash_panel',312,126,526,127);text(store,'stash_heading',12,91,500,26,'储物区 · 8件 · 不参战',18,'ink');ui.stash={}
 for i=1,8 do local n=i;ui.stash[i]=button(store,'stash_'..i,13+(i-1)%4*125,12+math.floor((i-1)/4)*38,120,35,'空',function()
  if r.phase~='shop'then return end;local t={};for _,q in ipairs(r.items)do if q.x==0 then t[#t+1]=q end end;if t[n]then selectedId=t[n].id;rotation=t[n].rot;preview=t[n].def;notify('已选中储物装备，点击空格放入。')end
 end,'muted');ui.stash[i].label.fontSize=14;bindDrag(ui.stash[i].body,function()local list={};for _,q in ipairs(r.items)do if q.x==0 then list[#list+1]=q end end;return list[n]end)end
 button(root,'rotate',312,69,164,47,'旋转 · 1',rotate);button(root,'stash_action',488,69,164,47,'移入储物',stash);button(root,'sell',664,69,174,47,'出售',sell)
 button(root,'undo',312,17,164,43,'撤销摆放',function()if #undo>0 and r.phase=='shop'then E.undoLayout(r,table.remove(undo));notify('已撤销最近一次摆放。')end end)
 ui.craft=button(root,'craft',488,17,164,43,'战后合成',craftToggle);button(root,'expand',664,17,174,43,'扩容 · 4摩拉',function()local ok=invoke(E.expand);if ok then notify('新增4格背包空间。')end end)
 views.shop=group(root,'shop_view',0,0,W,H);text(views.shop,'shop_title',877,738,440,42,'冒险家商店',31,'ink');ui.refresh=button(views.shop,'refresh',1340,735,210,48,'刷新 · 1摩拉',function()local ok=invoke(E.refresh,false);if ok then notify('已刷新。第5次起刷新需2摩拉。')end end)
 ui.shop={};for i=1,5 do local y=650-(i-1)*80;local n=i;local row=panel(views.shop,'shop_row'..i,875,y,675,74);local v={body=row};v.icon=iconPool(row,'shop_icon',10,7,.85);v.name=text(row,'shop_name',77,36,370,29,'',22,'ink');v.desc=text(row,'shop_effect',77,10,370,26,'',16,'ink');v.buy=button(row,'buy_'..i,463,14,125,45,'',function()buy(n)end);v.lock=button(row,'lock_'..i,596,14,65,45,'锁',function()if not matchJob and r.phase=='shop'and not r.shop[n].sold then r.shop[n].locked=not r.shop[n].locked;notify(r.shop[n].locked and'商品已锁定。'or'已解锁。')end end,'muted');v.lock.label.fontSize=17
  local hit=spawn('cursor',row,'inspect_shop_'..i,8,7,440,61);hit.raycastTarget=true;hit:AddCursorEventListener(Enum.CursorEventType.CursorClick,function()preview=r.shop[n].def;selectedId=0;notify(E.purchaseSpace(r,n)and'背包有可用位置；可直接拖入，或点击购买。'or'背包暂时放不下；购买后将进入储物区。')end)
  local function source()local z=r.shop[n];if z.sold or r.gold<z.price then return nil end;return{def=z.def,id=-1,x=0,y=0,rot=0},n end
  bindDrag(hit,source);bindDrag(v.buy.body,source);ui.shop[i]=v
 end
 ui.detail=panel(root,'detail',875,219,675,95);ui.detailText=text(ui.detail,'detail_text',12,7,500,81,'',17,'ink');ui.track=button(ui.detail,'track_recipe',520,52,142,32,'追踪／下一条',trackRecipe,'purple');ui.track.label.fontSize=14
 ui.core=text(root,'core_text',880,150,660,64,'',19,'ink');ui.codex=button(root,'codex',875,82,196,53,'物品／配方图鉴',function()book=true;bookTab=(r.phase=='result'or r.phase=='ended')and'analysis'or'items';bookPage=1;touch()end,'purple');button(root,'history',875,23,196,49,'对局记录',function()history=true;touch()end,'wood')
 ui.start=button(root,'start_battle',1100,45,450,88,'整装出战 →',begin,'purple');button(root,'select_hero',1352,781,198,39,'选择角色／重开',openPick,'wood')
 views.battle=panel(root,'battle_view',875,322,675,456);show(views.battle,false);text(views.battle,'battle_title',18,399,625,40,'匹配对决',30,'ink');ui.playerHp=text(views.battle,'player_hp',20,356,305,32,'',20,'ink');ui.enemyHp=text(views.battle,'enemy_hp',349,356,306,32,'',20,'ink');ui.hp1=shape(views.battle,'hp1',20,346,290,9,'green');ui.hp2=shape(views.battle,'hp2',349,346,290,9,'red');shape(views.battle,'floor',15,130,645,4,'wood');ui.resources=text(views.battle,'resources',22,301,630,36,'',18,'ink');ui.timer=text(views.battle,'battle_time',265,140,175,31,'',20,'ink');ui.log=text(views.battle,'battle_log',20,12,630,103,'',18,'ink');ui.slash=shape(views.battle,'slash',325,220,250,7,'purple',100001,22);ui.slash:SetVisible(false);button(views.battle,'enemy_build',20,140,230,37,'查看对手背包',function()book=true;bookTab='enemy';bookPage=1;touch()end,'wood').label.fontSize=18;button(views.battle,'battle_speed',444,398,211,40,'速度 ×1／×3',function()speed=speed==1 and 3 or 1 end,'purple').label.fontSize=18
 views.result=panel(root,'result_view',875,322,675,456);show(views.result,false);ui.resultTitle=text(views.result,'result_title',24,355,630,75,'',36,'ink');ui.resultBody=text(views.result,'result_body',24,112,630,235,'',20,'ink');ui.next=button(views.result,'next',24,30,628,65,'下一轮 →',function()if r.phase=='ended'then openPick()else nextRound()end end,'purple')
 views.choice=panel(root,'choice_view',875,322,675,456);show(views.choice,false);ui.choiceTitle=text(views.choice,'choice_title',25,344,625,80,'',31,'ink');ui.choiceText=text(views.choice,'choice_text',25,245,625,94,'',22,'ink');ui.choices={}
 for i=1,3 do local n=i;ui.choices[i]=button(views.choice,'choice_'..i,25,177-(i-1)*64,625,55,'',function()if r.phase=='milestone'then nextRound(n==1 and'stop'or'survive')else if E.choose(r,n)then notify('选择已生效，本局不可更换。')end end end,i==1 and'purple'or'wood')end
 views.book=panel(root,'book_view',865,145,695,635);show(views.book,false);ui.bookTitle=text(views.book,'book_title',20,557,650,56,'',30,'ink');ui.bookText=text(views.book,'book_text',20,104,650,449,'',19,'ink');button(views.book,'book_prev',20,32,135,51,'上一页',function()bookPage=math.max(1,bookPage-1);touch()end);button(views.book,'book_next',170,32,135,51,'下一页',function()bookPage=bookPage+1;touch()end);button(views.book,'book_tab',320,32,190,51,'物品／配方',function()bookTab=bookTab=='items'and'recipes'or'items';bookPage=1;touch()end);button(views.book,'book_close',525,32,145,51,'返回',function()book=false;history=false;touch()end)
 views.picker=panel(root,'picker',35,25,1520,750);show(views.picker,false);text(views.picker,'pick_title',30,655,1400,70,'选择你的冒险者',40,'ink');ui.pickInfo=text(views.picker,'pick_info',430,460,1020,146,'',27,'ink');ui.heroButtons={}
 for i,h in ipairs(E.heroes)do local id=h.id;local x=430+(i-1)%4*255;local y=285-math.floor((i-1)/4)*100;local b=button(views.picker,'hero_'..id,x,y,240,84,h.name..'\n'..h.role,function()chooseHero(id)end,'wood');b.label.fontSize=23;ui.heroButtons[i]=b end
 ui.mode=button(views.picker,'mode',430,83,440,65,'标准：10胜／5败',function()mode=mode=='standard'and'endless'or'standard';touch()end,'wood');button(views.picker,'confirm_hero',895,83,555,65,'以此角色开始冒险 →',newRun,'purple');button(views.picker,'close_picker',1320,665,125,45,'返回',function()pick=false;setSprite(views.hero,r.hero);touch()end,'wood')
 views.enemy=sprite(root,'enemy_portrait',1390,457,.85);show(views.enemy.root,false)
 views.hero=sprite(root,'hero_portrait',165,30,1.15);setSprite(views.hero,'raiden');touch()
end
local lastRevision=-1;local lastPose=nil;local layoutCache={}
local function render()
 local h=E.hero(r.hero);ui.stats.text='第'..r.round..'轮   '..r.wins..'/10胜   生命 '..r.lives..'   摩拉 '..r.gold;ui.notice.text=notice
 local choosing=r.phase=='shop'and((r.round==3 and #r.talents<1)or(r.round==10 and #r.talents<2)or(r.round>=8 and r.sub==0))
 local rightHidden=pick or book or history
 ui.start.label.text=matchJob and'正在匹配…'or'整装出战 →'
 show(views.shop,r.phase=='shop'and not choosing and not rightHidden);show(views.battle,r.phase=='battle'and not rightHidden);show(views.result,(r.phase=='result'or r.phase=='ended')and not rightHidden);show(views.choice,(choosing or r.phase=='milestone')and not rightHidden);show(views.book,book or history);show(views.picker,pick)
 show(ui.track.body,r.phase=='shop'and not choosing and not rightHidden);show(ui.start.body,r.phase=='shop'and not choosing and not rightHidden);show(ui.detail,not rightHidden);show(ui.core,not rightHidden);show(ui.heroName,not pick)
 show(views.enemy.root,r.phase=='battle'and not rightHidden)
 local battlePose=r.phase=='battle'and not rightHidden
 local pose=pick and'pick'or battlePose and'battle'or'shop'
 if pose~=lastPose then
  if pick then views.hero.root:SetAnchoredPosition(255,168);views.hero.root:SetLocalScale(2.1,2.1,1)
  elseif battlePose then views.hero.root:SetAnchoredPosition(1045,457);views.hero.root:SetLocalScale(.85,.85,1)
  else views.hero.root:SetAnchoredPosition(165,28);views.hero.root:SetLocalScale(1.15,1.15,1)end;lastPose=pose
 end
 ui.codex.label.text=(r.phase=='result'or r.phase=='ended')and'战斗贡献分析'or'物品／配方图鉴'
 ui.heroName.text=h.name..' · '..h.role;ui.core.text=h.core..(r.sub>0 and(' · '..h.subclasses[r.sub])or'')..'\n'..h.desc
 ui.space.text='空间 '..r.space..'/63';ui.refresh.label.text='刷新 · '..(r.rerolls<4 and 1 or 2)..'摩拉';ui.craft.label.text=r.autoCraft and'合成：开启'or'合成：关闭'
 local timers={};if fight and r.phase=='battle'then for _,z in ipairs(fight.a.items)do timers[z.instance]=z end end
 if lastRevision~=revision then
  local parts={r.hero,r.space,r.sub,table.concat(r.talents,',')};for _,q in ipairs(r.items)do parts[#parts+1]=q.id..':'..q.def..':'..q.x..':'..q.y..':'..q.rot end;for _,z in ipairs(r.shop)do parts[#parts+1]=z.def..':'..tostring(z.sold)end
  local signature=table.concat(parts,'|');if signature~=layoutCache.key then layoutCache={key=signature,items=E.compile(r),open=E.openMap(r),stamina=E.staminaInfo(r),spaces={}};for i=1,5 do layoutCache.spaces[i]=E.purchaseSpace(r,i)end end
  if layoutCache.tracked~=r.trackedRecipe then layoutCache.tracked=r.trackedRecipe;layoutCache.track=r.trackedRecipe and E.recipeStatus(r,r.trackedRecipe)or nil end
  local list=layoutCache.items;local links={};for _,z in ipairs(list)do links[z.instance]=z.links end
  local related=highlighted()
  local open=layoutCache.open;for i,v in ipairs(ui.cells)do v.bg.imageColor=col(open[i]and'#c5ad87'or'#665347');v.edge.imageColor=col(open[i]and'#eadbbc'or'#79644f')end
  local q=placeTarget();local cells=q and hoverX>0 and E.cells(q,hoverX,hoverY,rotation)or{};local valid=q and hoverX>0 and E.fits(r,q,hoverX,hoverY,rotation)
  for i,c in ipairs(ui.ghost)do local p=cells[i];local on=p~=nil and p[1]>=1 and p[1]<=9 and p[2]>=1 and p[2]<=7 and editable();c:SetVisible(on);if on then c:SetAnchoredPosition(20+(p[1]-1)*84,20+(7-p[2])*56);c.imageColor=col(valid and'#65b881'or'#d26b69',145)end end
  local info=layoutCache.stamina;local track=layoutCache.track
  ui.buildSummary.text=string.format('耐力需求 %.2f/s · 自然恢复 1/s%s',info.demand,info.demand>1 and' ⚠'or'')..'\n'..(track and('追踪：'..E.name(r.trackedRecipe)..'｜'..(track.complete and'已拥有，可切换下一条配方'or track.ready and'相邻已就绪'or track.owned and'材料齐，需相邻摆放'or'缺 '..table.concat(track.missing,'、')))or(info.demand>1 and('初始耐力约可支撑 '..string.format('%.1f',info.bufferSeconds)..'秒（未计料理）')or'选择装备查看联动；拖动装备可预览放置。'))
  for i,v in ipairs(slots)do local q=r.items[i];v.root:SetVisible(q~=nil and q.x>0);if q and q.x>0 then local d=E.defs[q.def];local w,hh=d.w,d.h;if q.rot%2==1 then w,hh=hh,w end;v.root:SetAnchoredPosition(20+(q.x-1)*84,20+(8-q.y-hh)*56);v.bg:SetSizeDelta(w*84-4,hh*56-4);v.bg.imageColor=col(selectedId==q.id and'gold'or related[q.id]and'green'or qcolors[d.q]);v.fill:SetSizeDelta(w*84-10,hh*56-10);v.icon.root:SetPivot(.5,.5);v.icon.root:SetAnchoredPosition(w*84/2,hh*56/2+5);v.icon.root:SetLocalScale(math.min(1.9,(d.w*84-15)/64),math.min(2.2,(d.h*56-27)/64),1);v.icon.root:SetLocalRotation(0,0,q.rot*90);setIcon(v.icon,d.kind);v.name:SetSizeDelta(w*84-10,23);v.name.text=d.name..((links[q.id]or 0)>0 and' ★'or'')end end
  local waiting={};for _,q in ipairs(r.items)do if q.x==0 then waiting[#waiting+1]=q end end;for i,v in ipairs(ui.stash)do v.label.text=waiting[i]and E.name(waiting[i].def)or'空';v.fill.imageColor=col(waiting[i]and waiting[i].id==selectedId and'purple'or'muted')end
  for i,v in ipairs(ui.shop)do local z=r.shop[i];local d=E.defs[z.def];setIcon(v.icon,d.kind);local material=track and not track.complete and(d.id==track.recipe.a or d.id==track.recipe.b);v.name.text=(material and'◆ 'or'')..d.name..' · '..quality[d.q];v.desc.text=(effectNames[d.effect]or'稳定攻击')..(not z.sold and not layoutCache.spaces[i]and' · 暂无空位'or'');v.buy.label.text=z.sold and'售罄'or(z.sale and'特价'or'')..z.price..'摩拉';v.buy.fill.imageColor=col(z.sold and'muted'or r.gold>=z.price and'wood'or'red');v.lock.label.text=z.locked and'已锁'or'锁'end
  local q=selected();local d=q and E.defs[q.def]or preview and E.defs[preview];ui.detailText.text=d and describe(d)or('选中物品查看说明。相邻材料将在战后合成。\n可合成 '..#E.craftable(r)..' 组；第3/10轮天赋，第8轮专精。')
  lastRevision=revision
 end
 for i,v in ipairs(slots)do local q=r.items[i];local z=q and timers[q.id];v.cool:SetVisible(z~=nil and z.cd>0);if z and z.cd>0 then local d=E.defs[q.def];local w=q.rot%2==1 and d.h or d.w;v.cool:SetSizeDelta((w*84-14)*math.max(0,math.min(1,1-z.time/z.cd)),3)end end
 if fight and r.phase=='battle'then local a,b=fight.a,fight.b
  ui.playerHp.text=h.name..' '..math.ceil(math.max(0,a.hp))..'/'..a.max..' 盾'..math.floor(a.shield);ui.enemyHp.text=E.hero(b.hero).name..' '..math.ceil(math.max(0,b.hp))..'/'..b.max..' 盾'..math.floor(b.shield);ui.hp1:SetSizeDelta(290*math.max(0,a.hp/a.max),9);ui.hp2:SetSizeDelta(290*math.max(0,b.hp/b.max),9);ui.resources.text='耐力 '..string.format('%.1f',a.stamina)..'/5  能量 '..math.floor(a.energy)..'  核心 '..a.coreCount..'次';ui.log.text=table.concat(fight.logs,'\n');ui.timer.text=string.format('%.1f秒 ×%d',fight.time,speed);ui.slash:SetVisible(fight.flash>0)
 else ui.slash:SetVisible(false)end
 if r.phase=='result'or r.phase=='ended'then local rec=r.history[#r.history];ui.resultTitle.text=r.phase=='ended'and(r.wins>=10 and'本局完成'or'旅途结束')or rec and(rec.winner==1 and'胜利'or rec.winner==0 and'平局'or'败北')or'结算'
  local top=rec and rec.contributions and rec.contributions[1];local diagnosis=rec and rec.diagnosis or{}
  ui.resultBody.text=rec and('伤害 '..math.floor(rec.damage)..'  治疗 '..math.floor(rec.heal)..'  吸收 '..math.floor(rec.absorbed)..'\n核心 '..rec.core..' 次  合成 '..rec.crafted..' 组\n\n'..(top and('主要贡献：'..top.name..' · 触发'..top.hits..'次\n')or'')..table.concat(diagnosis,'\n')..'\n\n胜场 '..r.wins..'  失败 '..r.losses..'  轮次 '..r.round..'\n基准预演差距 '..string.format('%.0f%%',math.abs(rec.match.estimatedMargin or 0)*100))or'';ui.next.label.text=r.phase=='ended'and'选择角色 · 再来一局'or'下一轮 →'
 end
 if choosing or r.phase=='milestone'then
  if r.phase=='milestone'then ui.choiceTitle.text='10胜达成 · 继续挑战？';ui.choiceText.text='可以带着当前成绩收官，或进入生存模式至第18轮。';ui.choices[1].label.text='收官并记录成绩';ui.choices[2].label.text='继续生存挑战';ui.choices[3].body:SetVisible(false)
  elseif r.round>=8 and r.sub==0 and not(r.round==10 and #r.talents<2)then ui.choiceTitle.text='选择角色专精';ui.choiceText.text='本局选择不可更换，专精强化核心或持续恢复。';ui.choices[1].label.text=h.subclasses[1]..' · 核心效果 +12%';ui.choices[2].label.text=h.subclasses[2]..' · 持续恢复';ui.choices[3].body:SetVisible(false)
  else ui.choiceTitle.text='选择冒险天赋';ui.choiceText.text='第3与第10轮各选择一次。';ui.choices[1].label.text='武艺精进 · 武器伤害 +8%';ui.choices[2].label.text='丰盛补给 · 治疗效果 +12%';ui.choices[3].label.text='迅捷节奏 · 冷却速度 +8%';ui.choices[3].body:SetVisible(true)end
 end
 if pick then local p=E.hero(previewHero);ui.pickInfo.text=p.name..' · '..p.role..'\n'..p.core..'\n'..p.desc;ui.mode.label.text=mode=='standard'and'标准：10胜／5次失败'or'无尽：持续匹配，失败5次结束';for i,v in ipairs(ui.heroButtons)do v.fill.imageColor=col(E.heroes[i].id==previewHero and'purple'or'wood')end end
 if book or history then
  local lines={}
  if history then ui.bookTitle.text='本局对战记录';for i=math.max(1,#r.history-7),#r.history do local q=r.history[i];lines[#lines+1]='第'..q.round..'轮 '..(q.winner==1 and'胜'or'负')..' '..string.format('%.1f',q.time)..'秒  伤害'..math.floor(q.damage)..'  预演差'..string.format('%.0f%%',math.abs(q.match.estimatedMargin or 0)*100)end
  elseif bookTab=='analysis'then local rec=r.history[#r.history];local data=rec and rec.contributions or{};local pages=math.max(1,math.ceil(#data/4));bookPage=math.min(bookPage,pages);ui.bookTitle.text='战斗贡献 '..bookPage..'/'..pages
   if rec then lines[#lines+1]='核心伤害 '..math.floor(rec.coreDamage or 0)..' · 持续伤害 '..math.floor(rec.dotDamage or 0)..' · 反伤 '..math.floor(rec.thornDamage or 0)end
   for i=(bookPage-1)*4+1,math.min(bookPage*4,#data)do local z=data[i];lines[#lines+1]=z.name..' · 触发 '..z.hits..' 次\n伤害 '..math.floor(z.damage)..' / 治疗 '..math.floor(z.heal)..' / 护盾 '..math.floor(z.shield)..'\n耐力等待 '..string.format('%.1f',z.wait)..'秒'end
  elseif bookTab=='enemy'and r.opponent then local page=math.min(bookPage,math.max(1,math.ceil(#r.opponent.items/10)));bookPage=page;ui.bookTitle.text='对手背包 · '..E.hero(r.opponent.hero).name;for i=(page-1)*10+1,math.min(page*10,#r.opponent.items)do local z=r.opponent.items[i];lines[#lines+1]=E.name(z.def)..'  '..z.x..','..z.y..'  旋转'..z.rot*90 ..'°'end
  elseif bookTab=='items'then local page=math.min(bookPage,math.ceil(#E.defs/5));bookPage=page;ui.bookTitle.text='物品图鉴 '..page..'/'..math.ceil(#E.defs/5)..' · '..#E.defs..'件';for i=(page-1)*5+1,math.min(page*5,#E.defs)do lines[#lines+1]=describe(E.defs[i])end
  else local page=math.min(bookPage,math.ceil(#E.recipes/6));bookPage=page;ui.bookTitle.text='配方图鉴 '..page..'/'..math.ceil(#E.recipes/6);for i=(page-1)*6+1,math.min(page*6,#E.recipes)do local p=E.recipes[i];lines[#lines+1]=E.name(p.a)..' ＋ '..E.name(p.b)..'\n → '..E.name(p.out)end end
  ui.bookText.text=table.concat(lines,'\n\n')
 end
end
function OnStart()
 local root=script.object;local cw,ch=game.GetUICanvasSize();local scale=math.min(cw/W,ch/H);root:SetAnchorMin(.5,.5);root:SetAnchorMax(.5,.5);root:SetPivot(.5,.5);root:SetSizeDelta(W,H);root:SetAnchoredPosition(0,0);root:SetLocalScale(scale,scale,1);root.showCursor=true;root.disableKeyEventPassthrough=true;root.disableCursorEventPassthrough=true
 loading=shape(root,'loading',0,0,W,H,'dark');loadingLabel=text(loading,'loading_label',390,410,1000,80,'正在准备冒险行囊 · 分批构建图元',30,'light');recording=true;build();recording=false;pendingBase=pendingBase or 0;totalCreates=0;for _,job in ipairs(queue)do if job.create then totalCreates=totalCreates+1 end end;init=true;script:EnableUpdate(true)
 local function key(n,fn)local en=Enum.KeyEventType['KeyboardCraftspersonKey'..n..'Down'];if en then root:AddKeyEventListener(en,function()if ready and not pick and not book and not history then fn()end;return true end)end end
 key(5,function()CancelInteraction(true)end);key(1,rotate);key(2,function()invoke(E.refresh,false)end);key(3,craftToggle);key(4,function()if r.phase=='shop'then begin()elseif r.phase=='result'then nextRound()end end)
end
function OnUpdate(dt)
 if init then batch=0;local operations=0;while qi<=#queue do local job=queue[qi];if operations>=1200 or(job.create and batch>=60)then break end;job.run();operations=operations+1;if job.create then batch=batch+1 end;qi=qi+1 end;peak=math.max(peak,batch);loadingLabel.text='正在准备角色与行囊 · '..math.min(100,math.floor((qi-1)/math.max(1,#queue)*100))..'%';loading:SetAsLastSibling();if qi>#queue then init=nil;ready=true;queue={};loading:SetVisible(false);launchPending();render()end;return end
 if not ready then return end
 if matchJob then
  local done=E.stepMatch(matchJob,60);notice='匹配预演 '..matchJob.trial..'/'..matchJob.total..' · 正在寻找接近的背包';touch()
  if done then local opp,meta=E.finishMatch(matchJob);matchJob=nil;pendingBattle={opp=opp,meta=meta};setSprite(views.enemy,opp.hero);if not init then launchPending()end end
 end
 if r.phase=='battle'and fight then acc=math.min(.4,acc+math.min(dt,.1)*speed);while acc>=.05 and not fight.done do E.step(fight,.05);acc=acc-.05 end;if fight.done then E.finish(r,fight);notify('对战结束；材料相邻且空间允许时已自动合成。')end end
 paint=paint+dt;if paint>=.1 then paint=0;render()end
end
function Inspect()return{ready=ready or false,phase=r.phase,pick=pick,hero=r.hero,previewHero=previewHero,round=r.round,wins=r.wins,lives=r.lives,gold=r.gold,space=r.space,items=copy and copy(r.items)or E.copy(r.items),shop=E.copy(r.shop),selected=selectedId,rotation=rotation,note=notice,revision=revision,created=created,peakCreated=peak,dragging=drag~=nil,hoverX=hoverX,hoverY=hoverY,book=book,bookTab=bookTab,placementValid=placeTarget()and hoverX>0 and E.fits(r,placeTarget(),hoverX,hoverY,rotation)or false,trackedRecipe=r.trackedRecipe,stamina=E.staminaInfo(r),related=highlighted(),matchProgress=matchJob and{done=matchJob.trial,total=matchJob.total}or nil,match=r.match,talents=r.talents,sub=r.sub,clock=fight and fight.time or 0,combat=fight and{hp=fight.a.hp,enemyHp=fight.b.hp,damage=fight.a.totals.damage,bursts=fight.a.coreCount}or nil}end
function ExportSave()if not ready or pendingBattle or matchJob or r.phase=='battle'then return nil end;return E.copy(r)end
function ImportSave(value)if matchJob or pendingBattle or not ready or not E.validate(value)or value.phase=='battle'then return false end;r=E.copy(value);pick=false;book=false;history=false;selectedId=0;drag=nil;hoverX=0;hoverY=0;hoverItem=0;setSprite(views.hero,r.hero);fight=nil;notify('已恢复本地对局。');return true end

function OpenCharacterPicker()if not ready or matchJob then return false end;openPick();return true end

function CancelInteraction(clear)if clear then selectedId=0 end;drag=nil;hoverX=0;hoverY=0;hoverItem=0;touch();return true end
