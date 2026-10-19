-- Teyvat Backpack Battles R2.1. UI is a projection of the pure Lua rules.
local W,H=1600,900
local T={group=1073742701,rect=1073742702,text=1073742703,cursor=1073742704}
-- Neutral colours (item icons, functional states). Everything else is themed by the hero's element.
local colors={ink='#1a0f2e',dark='#120a22',wood='#3b2477',gold='#ffc93c',paper='#fff7e8',muted='#6c5a9a',light='#ffffff',purple='#8b3dff',green='#22c55e',red='#ff3b5c',blue='#2a7bff',pink='#ff3d9a',cyan='#14d6c8',orange='#ff7a1a',lime='#a6e22e',lav='#e6dcff'}
-- Element themes. Each one is a monochrome ramp (bg → dark → main → soft → face) plus one accent, so
-- screens stay harmonious while the graffiti shapes keep their contrast.
local THEMES={
 electro={glyph='雷',label='雷元素',bg='#1a0d33',bg2='#2a1457',ink='#140a2b',face='#f4eeff',shade='#ddd0fb',text='#2d1d52',main='#8b3dff',dark='#4c1d95',soft='#c4a7ff',accent='#ffd23f',cell='#c9b4ff',cellIn='#efe8ff',lock='#24124b',lockIn='#2e1860',muted='#6b5a96'},
 dendro={glyph='草',label='草元素',bg='#0a2116',bg2='#113522',ink='#08180f',face='#f0faea',shade='#d5ecc8',text='#173a24',main='#2fb457',dark='#14663a',soft='#9be3a7',accent='#e2f25c',cell='#b5e3ad',cellIn='#eefaea',lock='#113522',lockIn='#17452c',muted='#5c7d66'},
 geo={glyph='岩',label='岩元素',bg='#231705',bg2='#3a280a',ink='#1c1204',face='#fff7e3',shade='#f1dfb2',text='#4a3510',main='#e0a020',dark='#8f5a0c',soft='#f5d27a',accent='#fff4c8',cell='#f0d595',cellIn='#fff6dc',lock='#3a280a',lockIn='#4a3410',muted='#8a7550'},
 hydro={glyph='水',label='水元素',bg='#071a38',bg2='#0c2a57',ink='#05112a',face='#ecf6ff',shade='#cfe5fb',text='#123460',main='#2a86ff',dark='#13489e',soft='#8fd0ff',accent='#5ff0f0',cell='#a9d2ff',cellIn='#eef7ff',lock='#0c2a57',lockIn='#123a73',muted='#5a77a0'},
 pyro={glyph='火',label='火元素',bg='#2a0a08',bg2='#46130e',ink='#1f0604',face='#fff2e8',shade='#f8d6c2',text='#5a1e10',main='#ff5226',dark='#a8260f',soft='#ffa070',accent='#ffcf3a',cell='#ffc2a3',cellIn='#fff4ec',lock='#46130e',lockIn='#5a1a12',muted='#8f5a4c'},
}
local heroElement={raiden='electro',nahida='dendro',zhongli='geo',furina='hydro',xiangling='pyro',noelle='geo',fischl='electro',klee='pyro'}
local TH=THEMES.electro;local themed={}
local function themeOf(hero)return THEMES[heroElement[hero]or'electro']end
local function col(s,a)
 if s:sub(1,1)=='@'then local role,al=s:match('^@(%a+)_?(%x*)$');s=TH[role]..al else s=colors[s]or s end
 return Color.FromRGBA(tonumber(s:sub(2,3),16),tonumber(s:sub(4,5),16),tonumber(s:sub(6,7),16),a or(#s>=9 and tonumber(s:sub(8,9),16))or 255)
end
local function bindTheme(v,prop,c)if type(c)=='string'and c:sub(1,1)=='@'then themed[#themed+1]={v,prop,c}end end
local function applyTheme(t)TH=t;for _,q in ipairs(themed)do q[1][q[2]]=col(q[3])end end
local ui,views,slots={},{},{}
local created,peak,batch=0,0,0
local init,loading,loadingLabel,ready,totalCreates,pendingBase
local queue,qi,recording={},1,false
local r=E.newRun('raiden',382173)
local selectedId,rotation,preview,notice=0,0,nil,'选择角色开始一场新的冒险。'
local title=true;local resumable=false;local shopOpen=false;local bagOpen=false;local toggleShop,toggleBag;local pickFromTitle=false;local bookFromTitle=false
local pick=false;local previewHero='raiden';local mode='standard';local book=false;local bookPage=1;local bookTab='items';local history=false
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
 local v=spawn('rect',p,n,x,y,w,h);v:SetImage(Enum.ImageSource.StaticReference,img or 100001);v.imageColor=col(c);bindTheme(v,'imageColor',c)
 if angle then v:SetPivot(.5,.5);v:SetLocalRotation(0,0,angle) end
 return v
end
local function text(p,n,x,y,w,h,t,size,c,outline,align)
 -- The device drops any line taller than its box (simulator does not); keep >= one full line, centred.
 c=c or'@text';size=size or 22;local need=math.ceil(size*1.3+12);if h<need then y=y-(need-h)/2;h=need end
 local v=spawn('text',p,n,x,y,w,h);v.text=t;v.fontSize=size;v.fontColor=col(c);bindTheme(v,'fontColor',c);v.bgColor=col('#000000',0);v.enableOutline=outline~=nil;if outline then v.outlineColor=col(outline);bindTheme(v,'outlineColor',outline)end;v.adaptiveFontSize=false;v.horizontalAlignment=Enum.TextHorizontalAlignment[align or'Left'];v.verticalAlignment=Enum.TextVerticalAlignment.Middle;return v
end
-- Sticker panel: hard ink drop shadow, ink keyline, tinted face, accent top band and a /// hatch.
local function panel(p,n,x,y,w,h,accent)
 local b=group(p,n,x,y,w,h);accent=accent or'@main'
 shape(b,n..'_shadow',9,-9,w,h,'@ink');shape(b,n..'_edge',0,0,w,h,'@ink');shape(b,n..'_paper',4,4,w-8,h-8,'@face')
 local bh=h<100 and 5 or 8;shape(b,n..'_band',4,h-4-bh,w-8,bh,accent);shape(b,n..'_foot',4,4,w-8,3,'@shade')
 if h>=100 then for i=1,3 do shape(b,n..'_hatch'..i,w-58+i*13,h-26,5,20,accent,100001,-28)end end
 return b
end
-- Straight label block: ink rim, drop shadow, top sheen, outlined lettering.
local function tag(p,n,x,y,w,h,t,size,c)
 c=c or'@main';shape(p,n..'_shadow',x+6,y-6,w,h,'@ink');shape(p,n..'_rim',x-3,y-3,w+6,h+6,'@ink');local face=shape(p,n..'_face',x,y,w,h,c);shape(p,n..'_sheen',x,y+h-math.floor(h*.32),w,math.floor(h*.32),'#ffffff22')
 local light=c=='@accent'or c=='@soft'or c=='@face'
 local label=text(p,n,x+14,y,w-28,h,t,size or 24,light and'@ink'or'light',not light and'@ink'or nil);return label,face
end
-- Floating plate: soft and hard drop shadows, ink rim, accent border, face with a sheen. Returns the face.
local function plate(p,n,x,y,w,h,c,border)
 shape(p,n..'_soft',x+16,y-18,w,h,'@ink_70');shape(p,n..'_hard',x+8,y-9,w,h,'@ink');shape(p,n..'_rim',x-4,y-4,w+8,h+8,'@ink');shape(p,n..'_border',x,y,w,h,border or'@accent')
 local face=shape(p,n..'_face',x+5,y+5,w-10,h-10,c);local sh=math.floor((h-10)*.22);shape(p,n..'_sheen',x+5,y+h-5-sh,w-10,sh,'#ffffff24');shape(p,n..'_base',x+5,y+5,w-10,4,'#00000030');return face
end
-- Rounded rectangle from primitives: a pill is 1 rect + 2 circles, otherwise 2 rects + 4 circles.
local function rshape(p,n,x,y,w,h,rad,c)
 rad=math.min(rad,h/2,w/2);local parts={}
 if h-2*rad>.5 then parts[#parts+1]=shape(p,n..'_h',x,y+rad,w,h-2*rad,c)end
 parts[#parts+1]=shape(p,n..'_v',x+rad,y,w-2*rad,h,c)
 local ys=h-2*rad>.5 and{y+rad,y+h-rad}or{y+rad}
 for _,cy in ipairs(ys)do for _,cx in ipairs({x+rad,x+w-rad})do parts[#parts+1]=shape(p,n..'_c'..#parts,cx-rad,cy-rad,rad*2,rad*2,c,100002)end end
 return setmetatable({parts=parts},{__newindex=function(t,k,v)if k=='imageColor'then for _,q in ipairs(t.parts)do q.imageColor=v end else rawset(t,k,v)end end})
end
-- Jelly buttons: glossy rounded body with an ink rim, squash-and-stretch on hover and press (see OnUpdate).
local jellies={}
local function wobble(body,amp)local j=jellies[body];if j and j.t<.12 and j.amp>=amp then return end;jellies[body]={t=0,amp=amp}end
local function button(p,n,x,y,w,h,t,fn,c)
 c=c or'@main';local v=spawn('cursor',p,n,x,y,w,h);v.raycastTarget=true;v:SetPivot(.5,.5);v:SetAnchoredPosition(x+w/2,y+h/2)
 local rad=h<=56 and h/2 or math.min(28,h/2)
 rshape(v,n..'_rim',-3,-8,w+6,h+11,rad+3,'@ink');local fill=rshape(v,n..'_fill',0,0,w,h,rad,c)
 local dh=math.min(h*.34,26);shape(v,n..'_deep',rad*.45,1,w-rad*.9,dh,'#00000026',100002)
 local sh=math.min(h*.4,30);shape(v,n..'_shine',rad*.55,h-sh-math.min(h*.1,8),w-rad*1.1,sh,'#ffffff4a',100002)
 local d=math.min(math.max(5,h*.14),10);shape(v,n..'_spec',rad*.6,h-sh*.7-math.min(h*.1,8),d*1.6,d,'#ffffffd0',100002)
 local light=c=='@accent'or c=='@soft'or c=='@face'
 local label=text(v,n..'_text',10,0,w-20,h,t,h>=44 and 22 or 17,light and'@ink'or'light',not light and'@ink'or nil,'Middle')
 v:AddCursorEventListener(Enum.CursorEventType.CursorClick,function() if ready then wobble(v,.14);fn() end end)
 v:AddCursorEventListener(Enum.CursorEventType.CursorEnter,function()wobble(v,.06)end)
 return {body=v,fill=fill,label=label}
end
-- Vector icon language. 64-unit space, y up. Axis shapes use bottom-left x,y; rotated shapes use centre x,y.
-- Each item kind has its own silhouette; the accent colour comes from the item's effect so 140 items read apart.
local accents={burn='#ff5a1f',burnboost='#ff5a1f',poison='#7bdc2a',poisonboost='#7bdc2a',heal='#22c55e',regen='#22c55e',healboost='#22c55e',rescue='#34d399',healstrike='#14d6c8',shield='#ffc93c',armorboost='#ffc93c',thorns='#f59e0b',crit='#ff3d9a',luck='#ff3d9a',haste='#14d6c8',slow='#5aa9ff',energy='#a855f7',empower='#ff3b5c',weaponboost='#ff3b5c',stamina='#ffd23f',summon='#2a7bff',summonboost='#2a7bff',coreboost='#c026d3',income='#ffc93c',foodboost='#ff7a1a',cleanse='#7dd3fc',extra='#ff5fd2',lifesteal='#e11d48',fish='#2a9dff',alchemy='#b06bff',copy='#ffd23f'}
local tagAccent={weapon='#5aa9ff',food='#ff7a1a',material='#22c55e',artifact='#ff3d9a',gadget='#14d6c8',summon='#2a7bff'}
local function iconData(kind,A)
 local a={};local function r(x,y,w,h,c,img,rot,bare) a[#a+1]={x,y,w,h,c,img or 100001,rot or 0,bare} end
 local function e(x,y,w,h,c,rot,bare)r(x,y,w,h,c,100002,rot,bare)end
 local function t(x,y,w,h,c,rot,bare)r(x,y,w,h,c,100003,rot,bare)end
 local function s4(x,y,w,h,c,rot)r(x,y,w,h,c,100004,rot,true)end
 local steel,edge='#eef4ff','#9fb4d8'
 if kind=='sword' then
  e(26,0,12,8,A);r(28,6,8,14,'#5b2a86');r(12,19,40,7,'gold');r(26,26,12,28,steel);r(32,26,6,28,edge,nil,0,true);t(26,53,12,10,steel);r(32,22.5,9,9,A,nil,45)
 elseif kind=='greatsword' then
  r(27,0,10,15,'#5b2a86');e(25,-2,14,6,A);r(6,15,52,9,'gold');r(16,24,32,28,steel);r(32,24,16,28,edge,nil,0,true);t(16,51,32,13,steel);r(22,32,20,6,A,nil,0,true);s4(25,40,14,14,'#ffffff')
 elseif kind=='spear' then
  r(29,0,6,50,'#8a4a1f');r(29,9,6,4,A,nil,0,true);r(29,19,6,4,A,nil,0,true);e(21,40,22,10,A);r(23,47,18,5,'gold');t(25,51,14,13,steel);r(32,52,3,10,edge,nil,0,true)
 elseif kind=='bow' then
  r(22,46,7,32,'#8a4a1f',nil,-22);r(22,18,7,32,'#8a4a1f',nil,22);r(18,27,9,10,'gold');r(35,3,2,58,'#fff3c4',nil,0,true);r(4,30,50,4,'#ffe7a3');t(58,32,10,10,steel,-90);r(6,27,8,10,A);s4(48,46,12,12,A)
 elseif kind=='fish' then
  t(32,7,26,14,'#1e6fd8',180);e(10,10,44,44,'#2a9dff');e(16,12,30,24,'#bfeaff',0,true);t(9,32,14,16,'#1e6fd8',90);e(34,38,10,10,'#ffffff');e(37,41,5,5,'ink',0,true);e(44,50,13,13,'#ffe3f4');r(26,10,4,24,A,nil,0,true)
 elseif kind=='book' then
  r(8,6,46,52,A);r(8,6,8,52,'#2a1352',nil,0,true);r(16,10,36,44,'paper');r(21,14,27,36,A,nil,0,true);s4(26,24,16,16,'gold');r(44,0,6,12,'red')
 elseif kind=='fruit' then
  e(12,6,40,40,A);e(19,28,11,9,'#ffffff9a',0,true);r(31,44,4,12,'#6b3b1f');e(42,53,16,8,'green',25)
 elseif kind=='chicken' then
  e(2,4,60,20,'#ffffff');e(7,8,50,12,'#dfe4ff',0,true);e(10,13,44,26,A);e(16,22,32,18,'#ffd27a',0,true);e(22,30,10,7,'green',0,true);r(20,48,4,12,A,nil,0,true);r(30,50,4,12,A,nil,0,true);r(40,48,4,12,A,nil,0,true)
 elseif kind=='jelly' then
  e(4,4,56,14,'#ffffff');r(14,11,36,26,A);e(14,30,36,14,'#ffffff80',0,true);r(19,16,4,14,'#ffffffb0',nil,0,true);s4(40,40,14,14,'gold')
 elseif kind=='mint' then
  r(30,2,4,42,'#15803d');e(22,22,26,12,'#22c55e',-25);e(42,32,26,12,'#4ade80',25);e(24,44,22,11,'#86efac',-20);s4(26,46,14,14,A);e(26,0,12,6,A)
 elseif kind=='crystal' then
  r(32,30,32,32,A,nil,45);r(32,30,15,15,'#ffffffa0',nil,45,true);t(4,4,14,22,A);t(46,2,12,18,A);s4(40,42,18,18,'#ffffff')
 elseif kind=='clock' then
  r(29,52,6,10,'gold');e(6,4,52,52,'gold');e(11,9,42,42,'#ffffff');r(31,29,3,17,'ink',nil,0,true);r(31,28,14,3,'ink',nil,0,true);e(27,25,10,10,A);s4(46,40,14,14,A)
 elseif kind=='feather' then
  e(36,36,22,58,A,-28);e(37,36,10,48,'#ffffffa0',-28,true);r(30,30,3,60,'gold',nil,-28);s4(14,6,14,14,'#ffffff')
 elseif kind=='flower' then
  for i=0,4 do local q=i*math.pi*2/5+math.pi/2;e(21+math.cos(q)*15,23+math.sin(q)*15,22,22,A)end;e(23,25,18,18,'gold');e(28,30,8,8,'#ffffff',0,true);e(48,10,18,8,'green',30)
 elseif kind=='potion' then
  e(10,2,44,44,'#e8f0ff');e(14,4,36,30,A);r(25,42,14,12,'#e8f0ff');r(22,52,20,9,'#a0522d');r(18,16,5,14,'#ffffffc0',nil,0,true);e(32,20,7,7,'#ffffffc0',0,true)
 elseif kind=='slime' then
  e(4,4,56,56,A..'40',0,true);t(20,40,24,20,A);e(14,10,36,36,A);e(18,16,28,22,'#ffffff');e(24,24,5,8,'ink',0,true);e(35,24,5,8,'ink',0,true);s4(46,44,14,14,'gold');s4(4,36,10,10,'gold')
 else e(10,10,44,44,A) end
 return a
end
local function iconPool(p,n,x,y,scale)
 local root=group(p,n,x,y,64,64);root:SetLocalScale(scale or 1,scale or 1,1);local v={root=root,kids={}}
 for i=1,30 do v.kids[i]=shape(root,n..'_vector'..i,0,0,1,1,'paper');v.kids[i]:SetVisible(false) end
 return v
end
local function setIcon(v,d)
 local A=accents[d.effect]or tagAccent[d.tag]or'pink';local key=d.kind..A;if v.kind==key then return end;v.kind=key
 local a={};for _,q in ipairs(iconData(d.kind,A))do
  if not q[8]then if q[7]~=0 then a[#a+1]={q[1],q[2],q[3]+4,q[4]+4,'ink',q[6],q[7]}else a[#a+1]={q[1]-2,q[2]-2,q[3]+4,q[4]+4,'ink',q[6],0}end end;a[#a+1]=q end
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
local qcolors={'#a79fc4','#22c55e','#2a9dff','#b04bff','#ff9f1c'}
local function touch()revision=revision+1 end
local function notify(t)notice=t;touch()end
local function selected()return E.find(r,selectedId)end
local function saveUndo()local t={};for _,q in ipairs(r.items)do t[q.id]={x=q.x,y=q.y,rot=q.rot}end;undo[#undo+1]=t;if #undo>15 then table.remove(undo,1)end end
local function invoke(fn,...)
 if title or matchJob or pick or book or history then return end
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
 if title or matchJob or r.phase~='shop'or pick or book or history then return end
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
local function editable()return ready and not matchJob and not pendingBattle and r.phase=='shop'and bagOpen and not pick and not book and not history and not title end
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
 if title or matchJob or pick or book or history then return end
 local ok,msg=E.canBegin(r);if not ok then return notify(msg)end
 shopOpen=false;matchJob=E.prepareMatch(r,BOT_BANK);notify('正在匹配：比较同轮次背包，分批进行战斗预演…')
end
local function nextRound(choice)local ok=E.next(r,choice);if ok then selectedId=0;undo={};touch();notify(r.phase=='shop'and'新一轮摩拉已到账。留意天赋、专精和背包扩容。'or'查看本局成绩，或选择继续挑战。')end end
local function openPick()if pendingBattle or matchJob then return end;if title then pickFromTitle=true end;title=false;book=false;history=false;pick=true;previewHero=r.hero;setSprite(views.hero,previewHero);touch()end
local function chooseHero(id)previewHero=id;setSprite(views.hero,id);touch()end
local function newRun()
 local oldGhosts=r.ghosts;r=E.newRun(previewHero,math.floor((revision+1)*8273+17291),mode);r.ghosts=oldGhosts;title=false;pickFromTitle=false;resumable=true;bagOpen=false;shopOpen=false;pick=false;book=false;history=false;selectedId=0;drag=nil;hoverX=0;hoverY=0;undo={};fight=nil;setSprite(views.hero,r.hero);notify('初始13摩拉。购买装备、整理背包后出战。')
end
toggleShop=function()if title or pick or book or history or matchJob or r.phase~='shop'then return end;shopOpen=not shopOpen;if shopOpen then bagOpen=true end;notify(shopOpen and'商店已打开：把商品拖进背包，或点击购买。'or'商店已关闭。');touch()end
toggleBag=function()if title or pick or book or history or matchJob or r.phase~='shop'then return end;bagOpen=not bagOpen;if not bagOpen then shopOpen=false;selectedId=0;drag=nil end;notify(bagOpen and'背包已打开：拖动装备摆放，下方可旋转、储物、出售与合成。'or'背包已收起。');touch()end
local visibility={}
local function show(c,on)if visibility[c]~=on then visibility[c]=on;c:SetVisible(on)end end
-- Graffiti decorations built only from rect / circle / triangle / star primitives.
local function splat(p,n,x,y,z,c)
 shape(p,n..'_core',x-z/2,y-z/2,z,z,c,100002)
 for i,o in ipairs({{.62,.2,.32},{-.6,.35,.22},{.3,-.62,.26},{-.48,-.5,.16},{.82,-.28,.12},{-.15,.7,.14}})do local d=z*o[3];shape(p,n..'_bit'..i,x+o[1]*z-d/2,y+o[2]*z-d/2,d,d,c,100002)end
 local dw=z*.13;shape(p,n..'_drip',x-z*.2,y-z*1.02,dw,z*.62,c);shape(p,n..'_drop',x-z*.2-dw*.25,y-z*1.12,dw*1.5,dw*1.5,c,100002)
end
local function dots(p,n,x,y,cols,rows,gap,size,c)
 for i=0,cols-1 do for j=0,rows-1 do local d=size*(1-(i+j)/(cols+rows));if d>2 then shape(p,n..i..'_'..j,x+i*gap,y+j*gap,d,d,c,100002)end end end
end
local function zigzag(p,n,x,y,count,len,c,th)
 for i=1,count do shape(p,n..i,x+(i-1)*len*.64,y,th or 7,len,c,100001,i%2==0 and 40 or-40)end
end
local function spin(v,cx,cy,angle)v:SetPivot(.5,.5);v:SetAnchoredPosition(cx,cy);v:SetLocalRotation(0,0,angle);return v end
local helpPages={
 {'游戏流程','选择冒险者 → 商店购买装备并摆进背包\n→ 整装出战，双方自动战斗 → 结算与自动合成\n→ 进入下一轮。\n\n标准模式：10胜通关，5次失败结束；\n10胜后可继续生存挑战至第18轮。\n无尽模式：18轮后沿用末轮经济与生命，\n继续匹配，仍受5次失败限制。\n\n第3、10轮选择天赋，第8轮选择角色专精。'},
 {'背包与摆放','把商店、背包或储物区的装备拖到格子上：\n绿色可放，红色不可放；松手才购买，\n拖放取消不扣摩拉。也可点击购买再点击空格。\n\n旋转 [1] · 移入储物（不参战）· 出售\n撤销摆放 · 扩容（4摩拉 / 4格）\n锁定商品 · 刷新 [2]\n\n深色格为尚未解锁的背包空间。'},
 {'联动与合成','选中或悬停装备，会高亮实际生效的相邻联动；\n名称带 ★ 表示有联动加成。\n\n战后合成 [3]：两种材料在背包内相邻、\n且空间足够时，战斗后自动合成；\n空间不足会保留原材料。\n\n详情面板「追踪／下一条」可追踪配方，\n商店里的材料会以 ◆ 标出。'},
 {'战斗要点','耐力上限5，每秒回复1；武器出手消耗耐力。\n暴击基础5%，1.5倍伤害；加速、暴击、护盾有上限。\n17秒后进入疲劳并逐渐加速，60秒判平局。\n\n结算后打开「战斗贡献分析」，\n查看每件装备的伤害、治疗、护盾和耐力等待。\n\n快捷键：1旋转 2刷新 3合成 4出战/下一轮\n5取消（鼠标右键亦可）'},
}
-- Hero card geometry: card frame, portrait window (masked half-body) and the skill box below it.
local CX,CY,CW,CH=1000,118,560,662
local TS={x=1210,y=450,w=430,h=1600,a=22,s=4.2}
local PX,PY,PW,PH=CX+14,CY+206,CW-28,CH-220
local fx={parts={},rays=nil,aura=nil,shine=nil,t=0,kind=nil}
local function build()
 local root=script.object
 -- Backdrop: element-tinted night with tilted slabs and halftone dots.
 shape(root,'wall',0,0,W,H,'@bg');shape(root,'bg_slab1',1220,420,700,1500,'@bg2',nil,24);shape(root,'bg_slab2',330,300,420,1400,'@bg2',nil,24)
 shape(root,'bg_stripe1',930,450,26,1500,'@main60',nil,24);shape(root,'bg_stripe2',974,450,10,1500,'@accent70',nil,24)
 dots(root,'bg_dot',8,8,9,6,22,11,'@main50')
 -- Ticker tape for the notice line, then the header.
 shape(root,'ticker',0,792,W,32,'@accent');for i=1,4 do shape(root,'ticker_hatch'..i,i*12-6,808,7,44,'@ink',nil,-32)end;ui.notice=text(root,'notice',58,792,1480,32,'',18,'@ink')
 shape(root,'top',0,824,W,76,'@ink');shape(root,'top_line',0,824,W,4,'@main')
 ui.chips={};for i,c in ipairs({'@soft','@accent','@main','@dark'})do local x=40+(i-1)*172;rshape(root,'chip_shadow'..i,x+5,834,150,46,23,'@bg');rshape(root,'chip_rim'..i,x-3,838,156,52,26,'@ink');rshape(root,'chip_border'..i,x,841,150,46,23,'@face');rshape(root,'chip_face'..i,x+3,844,144,40,20,c);ui.chips[i]=text(root,'chip_text'..i,x,841,150,46,'',21,i<=2 and'@ink'or'light',i>2 and'@ink'or nil,'Middle')end
 button(root,'menu',1340,840,210,46,'≡  菜单',function()if not ready or matchJob or pendingBattle or r.phase=='battle'then return notify('战斗进行中，结束后再打开菜单。')end;title=true;pick=false;book=false;history=false;shopOpen=false;drag=nil;touch()end,'@dark')
 -- Hub (bag closed): round banner, two big tiles and a build summary.
 views.hub=group(root,'hub',0,0,W,H)
 plate(views.hub,'hub_plate',56,642,640,124,'@dark');ui.hubRound=text(views.hub,'hub_round',82,694,400,64,'',54,'light','@ink');ui.hubSub=text(views.hub,'hub_sub',84,652,590,34,'',19,'@soft')
 ui.bagTile=button(views.hub,'bag_tile',56,300,370,300,'背包',function()toggleBag()end,'@main');ui.bagTile.label.fontSize=44;ui.bagTile.label:SetAnchoredPosition(10,104);ui.bagTile.label:SetSizeDelta(350,80)
 local bt=ui.bagTile.body;rshape(bt,'bag_ic_handle',150,248,70,40,20,'@ink');rshape(bt,'bag_ic_handle_in',160,250,50,26,13,'@main');rshape(bt,'bag_ic_body',118,182,134,82,20,'@face');rshape(bt,'bag_ic_flap',118,226,134,38,16,'@shade');shape(bt,'bag_ic_buckle',176,212,18,22,'@accent');ui.bagTileSub=text(bt,'bag_tile_sub',10,40,350,56,'',20,'@face',nil,'Middle')
 ui.shopTile=button(views.hub,'shop_tile',446,300,370,300,'商店',function()toggleShop()end,'@dark');ui.shopTile.label.fontSize=44;ui.shopTile.label:SetAnchoredPosition(10,104);ui.shopTile.label:SetSizeDelta(350,80)
 local st=ui.shopTile.body;shape(st,'shop_ic_counter',115,182,140,46,'@face');shape(st,'shop_ic_coin',166,196,38,20,'@accent',100002);for i=0,4 do local c=i%2==0 and'@accent'or'@face';shape(st,'shop_ic_awning'..i,108+i*31,238,31,34,c);shape(st,'shop_ic_scallop'..i,123.5+i*31,236,31,16,c,100003,180)end;shape(st,'shop_ic_roof',104,270,162,8,'@ink');ui.shopTileSub=text(st,'shop_tile_sub',10,40,350,56,'',20,'@face',nil,'Middle')
 local hp=panel(views.hub,'hub_info',56,30,760,236,'@main');tag(hp,'hub_info_tag',16,174,170,40,'构筑概况',20,'@main');ui.hubInfo=text(hp,'hub_info_text',22,16,716,150,'',18,'@text');text(hp,'hub_info_keys',210,176,530,36,'快捷键  6 商店 · 7 背包 · 4 出战',16,'@muted')
 -- Backpack window: grid on top, toolbox (detail, item controls, crafting, stash) underneath.
 views.bagWin=group(root,'bag_window',0,0,W,H)
 local bag=panel(views.bagWin,'bag_frame',36,305,802,474,'@main');tag(bag,'bag_label',16,423,250,40,'冒险行囊 · 9 × 7',22,'@main');ui.space=text(bag,'space_label',290,425,180,35,'',20,'@text')
 button(bag,'bag_shop',478,424,150,40,'商店 · 6',function()toggleShop()end,'@dark');button(bag,'bag_close',640,424,140,40,'收起 · 7',function()toggleBag()end,'@soft')
 ui.cells={};for y=1,7 do for x=1,9 do local xx=20+(x-1)*84;local yy=20+(7-y)*56;local n=(y-1)*9+x
  local c=spawn('cursor',bag,'cell_'..x..'_'..y,xx,yy,80,52);c.raycastTarget=true;local bg=shape(c,'cell_bg',0,0,80,52,'@cell');local edge=shape(c,'cell_inset',3,3,74,46,'@cellIn');ui.cells[n]={body=c,bg=bg,edge=edge};local cx,cy=x,y;c:AddCursorEventListener(Enum.CursorEventType.CursorClick,function()if ready then cell(cx,cy)end end)
  c:AddCursorEventListener(Enum.CursorEventType.CursorEnter,function()if editable()and not drag then hoverX=cx;hoverY=cy;local q=itemAt(cx,cy);hoverItem=q and q.id or 0;if q and selectedId==0 then preview=q.def end;touch()end end)
  c:AddCursorEventListener(Enum.CursorEventType.CursorExit,function()if not drag and hoverX==cx and hoverY==cy then hoverX=0;hoverY=0;hoverItem=0;touch()end end)
  bindDrag(c,function()return itemAt(cx,cy)end)
 end end
 local itemLayer=group(bag,'items',0,0,802,420)
 for i=1,32 do local v={root=group(itemLayer,'item_'..i,0,0,80,52)};v.shadow=shape(v.root,'item_shadow',3,-3,80,52,'@ink90');v.bg=shape(v.root,'item_quality',0,0,80,52,'green');v.fill=shape(v.root,'item_paper',4,4,72,44,'@face');v.icon=iconPool(v.root,'item_icon',0,0,1);v.name=text(v.root,'item_name',5,-3,160,30,'',13,'@text');v.cool=shape(v.root,'item_cooldown',4,23,1,4,'@main');v.root:SetVisible(false);slots[i]=v end
 ui.ghost={};local ghostLayer=group(bag,'placement_preview',0,0,802,420)
 for i=1,12 do local c=shape(ghostLayer,'placement_cell'..i,0,0,80,52,'green');c:SetVisible(false);ui.ghost[i]=c end
 local tb=panel(views.bagWin,'toolbox',36,17,802,276,'@main')
 ui.detailText=text(tb,'detail_text',20,179,388,80,'',16,'@text')
 ui.track=button(tb,'track_recipe',20,133,180,38,'追踪配方',trackRecipe,'@dark');ui.track.label.fontSize=16;ui.craft=button(tb,'craft',212,133,192,38,'战后合成',craftToggle,'@main');ui.craft.label.fontSize=16
 button(tb,'rotate',20,79,122,40,'旋转 · 1',rotate,'@main');button(tb,'stash_action',150,79,122,40,'移入储物',stash,'@main');button(tb,'sell',280,79,124,40,'出售',sell,'@dark')
 button(tb,'undo',20,21,180,40,'撤销摆放',function()if #undo>0 and r.phase=='shop'then E.undoLayout(r,table.remove(undo));notify('已撤销最近一次摆放。')end end,'@soft');button(tb,'expand',212,21,192,40,'扩容 · 4摩拉',function()local ok=invoke(E.expand);if ok then notify('新增4格背包空间。')end end,'@soft')
 shape(tb,'toolbox_divider',424,18,3,236,'@shade');text(tb,'stash_heading',440,224,330,30,'储物区 · 8件 · 不参战',17,'@text');ui.stash={}
 for i=1,8 do local n=i;ui.stash[i]=button(tb,'stash_'..i,440+(i-1)%4*86,178-math.floor((i-1)/4)*40,80,32,'空',function()
  if r.phase~='shop'then return end;local t={};for _,q in ipairs(r.items)do if q.x==0 then t[#t+1]=q end end;if t[n]then selectedId=t[n].id;rotation=t[n].rot;preview=t[n].def;notify('已选中储物装备，点击空格放入。')end
 end,'@muted');ui.stash[i].label.fontSize=13;bindDrag(ui.stash[i].body,function()local list={};for _,q in ipairs(r.items)do if q.x==0 then list[#list+1]=q end end;return list[n]end)end
 ui.buildSummary=text(tb,'build_summary',440,16,345,108,'',15,'@text')
 -- Hero card base: ink rim, accent filigree border, masked inner field with light rays, aura and a shine sweep.
 views.card=group(root,'hero_card',0,0,W,H)
 shape(views.card,'card_shadow',CX+10,CY-10,CW,CH,'@ink');shape(views.card,'card_rim',CX,CY,CW,CH,'@ink');shape(views.card,'card_gild',CX+4,CY+4,CW-8,CH-8,'@accent');shape(views.card,'card_line',CX+9,CY+9,CW-18,CH-18,'@ink')
 local field=shape(views.card,'card_field',CX+12,CY+12,CW-24,CH-24,'@bg2');field.enableMask=true;ui.cardField=field
 local fw,fh=CW-24,CH-24;local ccx,ccy=fw/2,fh-200
 shape(field,'card_glow',fw/2,fh-150,fw*1.2,300,'@main40',100002);shape(field,'card_band',fw/2,fh*.35,fw*1.6,120,'@dark80',nil,-14)
 fx.rays=group(field,'card_rays',ccx,ccy,0,0);fx.rays:SetPivot(.5,.5);for i=0,11 do local ang=i*30;local L=520;local rad=math.rad(ang);shape(fx.rays,'ray'..i,math.cos(rad)*L/2,math.sin(rad)*L/2,L*.22,L,'@soft22',100003,ang+90)end
 fx.aura=shape(field,'card_aura',ccx,ccy,360,360,'@main55',100002,0);shape(field,'card_aura_in',ccx,ccy,220,220,'@soft35',100002,0)
 dots(field,'card_dots',fw-200,fh-170,9,7,22,11,'@soft40');for i=1,6 do shape(field,'card_diamond'..i,40+i*78,26,14,14,'@accent60',100001,45)end
 fx.shine=shape(field,'card_shine',-200,fh/2,70,fh*1.6,'#ffffff30',nil,18)
 -- Skill box (bottom of the card).
 ui.skill=group(views.card,'skill_box',CX+20,CY+20,CW-40,178);shape(ui.skill,'skill_back',0,0,CW-40,178,'@face');shape(ui.skill,'skill_top',0,174,CW-40,4,'@accent');shape(ui.skill,'skill_side',0,0,6,178,'@main')
 tag(ui.skill,'skill_tag',14,128,128,36,'核心技能',18,'@main');ui.skillName=text(ui.skill,'skill_name',156,126,360,42,'',25,'@text');ui.core=text(ui.skill,'core_text',18,8,500,114,'',17,'@text')
 ui.start=button(root,'start_battle',CX,17,CW,86,'整装出战  →',begin,'@main');ui.start.label.fontSize=34;shape(ui.start.body,'start_star',CW-30,74,40,40,'@accent',100005,14);shape(ui.start.body,'start_spark',28,70,20,20,'#ffffff',100004)
 -- Battle arena (below the hero layer so the fighter portraits stand on it).
 views.battle=panel(root,'battle_view',875,322,685,458,'@main');show(views.battle,false);tag(views.battle,'battle_title',16,398,200,42,'匹配对决',24,'@main')
 ui.slabL=shape(views.battle,'slab_l',170,232,240,180,'@main',nil,-6);ui.slabR=shape(views.battle,'slab_r',505,232,240,180,'red',nil,6);shape(views.battle,'stage',15,124,655,12,'@ink')
 ui.playerHp=text(views.battle,'player_hp',20,360,305,30,'',19,'@text');ui.enemyHp=text(views.battle,'enemy_hp',349,360,306,30,'',19,'@text')
 shape(views.battle,'hp1_frame',17,339,296,19,'@ink');shape(views.battle,'hp2_frame',346,339,296,19,'@ink');shape(views.battle,'hp1_back',20,342,290,13,'@lock');shape(views.battle,'hp2_back',349,342,290,13,'@lock')
 ui.hp1=shape(views.battle,'hp1',20,342,290,13,'green');ui.hp2=shape(views.battle,'hp2',349,342,290,13,'red')
 ui.resources=text(views.battle,'resources',22,303,630,34,'',18,'@text');ui.timer=text(views.battle,'battle_time',265,140,175,31,'',20,'@text');ui.log=text(views.battle,'battle_log',20,10,410,108,'',17,'@text')
 shape(views.battle,'vs_burst',338,236,104,104,'@accent',100005,-10);spin(text(views.battle,'vs',0,0,140,90,'VS',52,'light','@ink','Middle'),338,232,-8)
 ui.slash=shape(views.battle,'slash',325,220,280,10,'@accent',100001,22);ui.slash:SetVisible(false);button(views.battle,'enemy_build',454,16,211,38,'查看对手背包',function()book=true;bookTab='enemy';bookPage=1;touch()end,'@dark').label.fontSize=17;button(views.battle,'battle_speed',454,398,211,38,'速度 ×1／×3',function()speed=speed==1 and 3 or 1 end,'@main').label.fontSize=18
 -- Title screen.
 views.title=group(root,'title_view',0,0,W,H);local tv=views.title
 shape(tv,'t_bg',0,0,W,H,'@bg');local blocker=spawn('cursor',tv,'title_blocker',0,0,W,H);blocker.raycastTarget=true;shape(tv,'t_slab',1190,450,760,1600,'@bg2',nil,22);ui.titleSlab=shape(tv,'t_hero_slab',1210,450,430,1600,'@main',nil,22)
 shape(tv,'t_stripe1',925,450,36,1600,'@dark',nil,22);shape(tv,'t_stripe2',982,450,12,1600,'@accent',nil,22);shape(tv,'t_stripe3',1480,450,20,1600,'@soft',nil,22)
 dots(tv,'t_dots',20,520,10,9,26,14,'@main80');dots(tv,'t_dots2',1240,30,12,6,26,13,'#ffffff40')
 splat(tv,'t_splat1',1468,700,110,'@accent');splat(tv,'t_splat3',820,110,60,'@main')
 shape(tv,'t_star1',1520,500,70,70,'@accent',100005,-14);shape(tv,'t_star2',880,700,46,46,'#ffffff',100004);shape(tv,'t_star3',560,820,34,34,'@soft',100004)
 -- Logo: straight floating plates.
 local tx,ty,tw,th,ta=188,768,256,64,-4
 shape(tv,'logo_top_soft',tx+16,ty-18,tw,th,'@ink_70',nil,ta);shape(tv,'logo_top_hard',tx+8,ty-9,tw,th,'@ink',nil,ta);shape(tv,'logo_top_rim',tx,ty,tw+8,th+8,'@ink',nil,ta);shape(tv,'logo_top_border',tx,ty,tw,th,'@accent',nil,ta);shape(tv,'logo_top_face',tx,ty,tw-10,th-10,'@dark',nil,ta)
 spin(text(tv,'logo_top_text',0,0,tw-40,th,'提瓦特',40,'light','@ink'),tx,ty,ta)
 plate(tv,'logo_main',60,592,650,128,'@main');text(tv,'logo_main_text',60,592,650,128,'背包乱斗',96,'light','@ink','Middle')
 plate(tv,'logo_sub',60,546,500,36,'@ink','@soft');text(tv,'logo_sub_text',60,546,500,36,'TEYVAT · BACKPACK BRAWL',20,'@accent',nil,'Middle')
 -- The hero stands enlarged on the tilted slab (TS) and is drawn above it, free to overlap its edges.
 ui.titleButtons={}
 for i,m in ipairs({{'继续冒险','@main',function()if resumable then title=false;touch()else notify('还没有进行中的冒险，先开始新的冒险吧。')end end},{'新的冒险','@dark',function()pickFromTitle=true;title=false;pick=true;previewHero=r.hero;setSprite(views.hero,previewHero);touch()end},{'物品图鉴','@dark',function()book=true;bookTab='items';bookPage=1;touch()end},{'对局记录','@dark',function()history=true;touch()end},{'玩法说明','@soft',function()book=true;bookTab='help';bookPage=1;touch()end}})do
  local b=button(tv,'menu_'..i,70+(i-1)*18,470-(i-1)*80,440,64,m[1],m[3],m[2]);b.label.fontSize=28;ui.titleButtons[i]=b
 end
 ui.titleRun=text(tv,'t_run',540,470,330,64,'',19,'@soft','@ink')
 -- Character picker.
 views.picker=panel(root,'picker',35,25,1520,750,'@main');show(views.picker,false)
 ui.pickSlab=shape(views.picker,'pick_slab',225,380,300,600,'@main',nil,12);ui.pickDisc=shape(views.picker,'pick_disc',25,170,400,400,'#ffffff55',100002);dots(views.picker,'pick_dots',30,40,9,7,24,13,'@main60');splat(views.picker,'pick_splat',360,560,70,'@accent')
 tag(views.picker,'pick_title',30,655,360,62,'选择你的冒险者',34,'@main');shape(views.picker,'pick_info_back',420,450,1040,166,'#ffffff');ui.pickInfoBar=shape(views.picker,'pick_info_bar',420,450,12,166,'@main');ui.pickInfo=text(views.picker,'pick_info',450,460,1000,146,'',26,'@text');ui.heroButtons={};ui.heroStars={}
 for i,h in ipairs(E.heroes)do local id=h.id;local x=430+(i-1)%4*255;local y=285-math.floor((i-1)/4)*100;local b=button(views.picker,'hero_'..id,x,y,240,80,h.name..'\n'..h.role,function()chooseHero(id)end,'@dark');b.label.fontSize=22;local th=themeOf(id);shape(b.body,'hero_gem_ring',14,12,30,30,'#ffffff',100002);shape(b.body,'hero_gem',17,15,24,24,th.main,100002);text(b.body,'hero_gem_glyph',13,12,32,30,th.glyph,15,'#ffffff',nil,'Middle');ui.heroStars[i]=shape(b.body,'hero_star',224,70,40,40,'@accent',100005,12);ui.heroButtons[i]=b end
 ui.mode=button(views.picker,'mode',430,83,440,62,'标准：10胜／5败',function()mode=mode=='standard'and'endless'or'standard';touch()end,'@dark');ui.confirm=button(views.picker,'confirm_hero',895,83,555,62,'以此角色开始冒险 →',newRun,'@main');ui.confirm.label.fontSize=26
 button(views.picker,'close_picker',1320,665,125,44,'返回',function()pick=false;if pickFromTitle then title=true end;pickFromTitle=false;setSprite(views.hero,r.hero);touch()end,'@soft')
 -- Hero layer: the mask clips the portrait to the card window in the board pose and spans the canvas otherwise.
 ui.heroMask=shape(root,'hero_mask',0,0,W,H,'#00000000');ui.heroMask.enableMask=true
 views.hero=sprite(ui.heroMask,'hero_portrait',0,0,1);setSprite(views.hero,'raiden')
 views.enemy=sprite(root,'enemy_portrait',1390,457,.85);show(views.enemy.root,false)
 -- Card overlays above the hero: element particles, corner filigree, emblem, name ribbon.
 views.cardTop=group(root,'card_top',0,0,W,H)
 local fm=shape(views.cardTop,'fx_mask',PX,PY,PW,PH,'#00000000');fm.enableMask=true
 for i=1,16 do local q=shape(fm,'fx_particle'..i,0,0,10,10,'@accent',100004);fx.parts[i]={c=q,x=(i*67)%PW,y=(i*131)%PH,sp=24+(i*13)%40,ph=i*1.7,sz=8+(i*7)%12}end
 for i,c in ipairs({{PX,PY},{PX+PW,PY},{PX,PY+PH},{PX+PW,PY+PH}})do shape(views.cardTop,'card_corner'..i,c[1],c[2],30,30,'@accent',100004,45)end
 shape(views.cardTop,'emblem_back',CX+16,CY+CH-98,84,84,'@ink',100002);shape(views.cardTop,'emblem_ring',CX+20,CY+CH-94,76,76,'@accent',100006);shape(views.cardTop,'emblem_fill',CX+29,CY+CH-85,58,58,'@main',100002);ui.emblem=text(views.cardTop,'emblem_glyph',CX+16,CY+CH-98,84,84,'',34,'light','@ink','Middle')
 ui.elementTag=tag(views.cardTop,'element_tag',CX+CW-196,CY+CH-74,170,40,'',19,'@dark',3)
 shape(views.cardTop,'ribbon_back',PX,PY,PW,68,'@ink_c8');shape(views.cardTop,'ribbon_line',PX,PY+64,PW,4,'@accent')
 ui.cardName=text(views.cardTop,'card_name',PX+18,PY+4,330,42,'',30,'light','@ink');ui.cardRole=text(views.cardTop,'card_role',PX+20,PY+42,330,22,'',15,'@soft')
 for i=1,5 do shape(views.cardTop,'card_star'..i,PX+PW-150+i*24,PY+34,22,22,'@accent',100005)end
 -- Shop window.
 views.shop=group(root,'shop_view',0,0,W,H);panel(views.shop,'shop_window',862,318,703,470,'@main');tag(views.shop,'shop_title',877,738,250,44,'冒险家商店',25,'@main')
 button(views.shop,'close_shop',1214,738,112,44,'关闭',function()shopOpen=false;touch()end,'@soft');ui.refresh=button(views.shop,'refresh',1340,738,210,44,'刷新 · 1摩拉',function()local ok=invoke(E.refresh,false);if ok then notify('已刷新。第5次起刷新需2摩拉。')end end,'@dark')
 ui.shop={};for i=1,5 do local y=650-(i-1)*80;local n=i;local row=panel(views.shop,'shop_row'..i,875,y,675,74,'@soft');local v={body=row};v.qbar=shape(row,'shop_quality',4,4,7,62,'@muted');shape(row,'shop_icon_bg',13,6,60,60,'@cellIn',100002);v.icon=iconPool(row,'shop_icon',14,7,.85);v.name=text(row,'shop_name',82,35,370,29,'',22,'@text');v.desc=text(row,'shop_effect',82,9,370,26,'',16,'@muted');v.buy=button(row,'buy_'..i,463,15,125,44,'',function()buy(n)end,'@main');v.buy.label.fontSize=18;v.lock=button(row,'lock_'..i,598,15,62,44,'锁',function()if not matchJob and r.phase=='shop'and not r.shop[n].sold then r.shop[n].locked=not r.shop[n].locked;notify(r.shop[n].locked and'商品已锁定。'or'已解锁。')end end,'@muted');v.lock.label.fontSize=17
  local hit=spawn('cursor',row,'inspect_shop_'..i,8,7,440,61);hit.raycastTarget=true;hit:AddCursorEventListener(Enum.CursorEventType.CursorClick,function()preview=r.shop[n].def;selectedId=0;notify(E.purchaseSpace(r,n)and'背包有可用位置；可直接拖入，或点击购买。'or'背包暂时放不下；购买后将进入储物区。')end)
  local function source()local z=r.shop[n];if z.sold or r.gold<z.price then return nil end;return{def=z.def,id=-1,x=0,y=0,rot=0},n end
  bindDrag(hit,source);bindDrag(v.buy.body,source);ui.shop[i]=v
 end
 -- Result and choices.
 views.result=panel(root,'result_view',875,322,685,458,'@main');show(views.result,false);ui.resultStar=shape(views.result,'result_star',570,390,170,170,'@accent',100005,12);ui.resultTitle=text(views.result,'result_title',24,352,630,80,'',54,'light','@ink');ui.resultBody=text(views.result,'result_body',24,112,630,235,'',20,'@text')
 button(views.result,'analysis',24,30,200,62,'贡献分析',function()book=true;bookTab='analysis';bookPage=1;touch()end,'@soft').label.fontSize=22;ui.next=button(views.result,'next',236,30,425,62,'下一轮 →',function()if r.phase=='ended'then openPick()else nextRound()end end,'@main');ui.next.label.fontSize=28
 views.choice=panel(root,'choice_view',875,322,685,458,'@main');show(views.choice,false);shape(views.choice,'choice_star',600,380,90,90,'@accent',100005,-8);ui.choiceTitle=text(views.choice,'choice_title',25,344,560,80,'',31,'@text');ui.choiceText=text(views.choice,'choice_text',25,245,625,94,'',22,'@text');ui.choices={}
 for i=1,3 do local n=i;ui.choices[i]=button(views.choice,'choice_'..i,25,177-(i-1)*64,635,52,'',function()if r.phase=='milestone'then nextRound(n==1 and'stop'or'survive')else if E.choose(r,n)then notify('选择已生效，本局不可更换。')end end end,i==1 and'@main'or'@dark')end
 -- Codex / help book.
 views.book=panel(root,'book_view',865,145,695,635,'@main');show(views.book,false);ui.bookTitle=text(views.book,'book_title',20,557,600,56,'',30,'@text');ui.bookText=text(views.book,'book_text',20,104,650,449,'',19,'@text')
 ui.bookRows={};ui.bookRowLayer=group(views.book,'book_rows',0,0,695,635)
 for i=1,5 do local y=553-i*88;local v={};v.chip=shape(ui.bookRowLayer,'book_row_chip'..i,18,y+4,6,78,'@muted');v.back=shape(ui.bookRowLayer,'book_row_back'..i,30,y+8,72,72,'@cellIn',100002);v.icon=iconPool(ui.bookRowLayer,'book_row_icon'..i,34,y+12,1);v.text=text(ui.bookRowLayer,'book_row_text'..i,116,y,560,86,'',17,'@text');ui.bookRows[i]=v end
 button(views.book,'book_prev',20,34,135,48,'上一页',function()bookPage=math.max(1,bookPage-1);touch()end,'@dark');button(views.book,'book_next',170,34,135,48,'下一页',function()bookPage=bookPage+1;touch()end,'@dark');button(views.book,'book_tab',320,34,190,48,'物品／配方',function()bookTab=bookTab=='items'and'recipes'or'items';bookPage=1;touch()end,'@main');button(views.book,'book_close',525,34,145,48,'返回',function()book=false;history=false;touch()end,'@soft')
 touch()
end
local lastRevision=-1;local lastPose=nil;local layoutCache={};local paintKey
local poseBase={x=0,y=0,s=1}
local function render()
 local h=E.hero(r.hero);local th=themeOf((pick and previewHero)or r.hero)
 if TH~=th or not ui.themeApplied then ui.themeApplied=true;applyTheme(th);paintKey=nil;lastRevision=-1;fx.kind=nil end
 ui.chips[1].text='第 '..r.round..' 轮';ui.chips[2].text='胜 '..r.wins..'/10';ui.chips[3].text='生命 '..r.lives;ui.chips[4].text='摩拉 '..r.gold;ui.notice.text=notice
 local key=r.hero..previewHero..tostring(resumable)..tostring(TH)
 if paintKey~=key then paintKey=key
ui.titleButtons[1].fill.imageColor=col(resumable and'@main'or'@muted');ui.titleButtons[1].label.text=resumable and'继续冒险'or'继续冒险 · 无进度'
  local ht=themeOf(r.hero);ui.emblem.text=ht.glyph;ui.elementTag.text=ht.label..' · ★5';ui.cardName.text=h.name;ui.cardRole.text=h.role;ui.slabL.imageColor=col('@main_b0')
 end
 ui.titleRun.text=resumable and('第'..r.round..'轮 · 胜 '..r.wins..'/10 · 生命 '..r.lives..'\n'..(r.mode=='endless'and'无尽模式'or'标准模式'))or''
 show(views.title,title)
 local choosing=r.phase=='shop'and((r.round==3 and #r.talents<1)or(r.round==10 and #r.talents<2)or(r.round>=8 and r.sub==0))
 local rightHidden=pick or book or history or title
 local shopPhase=r.phase=='shop'and not rightHidden
 local bagVisible=not rightHidden and((r.phase=='shop'and bagOpen)or r.phase=='battle'or r.phase=='result'or r.phase=='ended'or r.phase=='milestone')
 local shopVisible=shopPhase and not choosing and shopOpen
 local rightPanel=shopVisible or(r.phase=='battle'and not rightHidden)or((r.phase=='result'or r.phase=='ended')and not rightHidden)or((choosing or r.phase=='milestone')and not rightHidden)or book or history
 ui.start.label.text=matchJob and'正在匹配…'or'整装出战  →'
 show(views.shop,shopVisible);show(views.battle,r.phase=='battle'and not rightHidden);show(views.result,(r.phase=='result'or r.phase=='ended')and not rightHidden);show(views.choice,(choosing or r.phase=='milestone')and not rightHidden);show(views.book,book or history);show(views.picker,pick)
 show(views.bagWin,bagVisible);show(views.hub,shopPhase and not bagVisible)
 show(ui.start.body,shopPhase and not choosing);show(views.card,not pick and not title);show(views.cardTop,not pick and not title and not rightPanel)
 show(views.hero.root,not(title and(book or history)))
 show(views.enemy.root,r.phase=='battle'and not rightHidden)
 local battlePose=r.phase=='battle'and not rightHidden
 local pose=pick and'pick'or title and'title'or battlePose and'battle'or'board'
 if pose~=lastPose then
  local m=ui.heroMask
  m:SetPivot(0,0);m:SetLocalRotation(0,0,0);views.hero.root:SetLocalRotation(0,0,0)
  if pose=='board'then m:SetAnchoredPosition(PX,PY);m:SetSizeDelta(PW,PH);poseBase={x=PW/2,y=-340,s=3.9}
  elseif pose=='title'then m:SetAnchoredPosition(0,0);m:SetSizeDelta(W,H);poseBase={x=TS.x,y=TS.y-100*TS.s,s=TS.s}
  else m:SetAnchoredPosition(0,0);m:SetSizeDelta(W,H)
   if pick then poseBase={x=255,y=168,s=2.1}else poseBase={x=1045,y=457,s=.85}end
  end;views.hero.root:SetAnchoredPosition(poseBase.x,poseBase.y);views.hero.root:SetLocalScale(poseBase.s,poseBase.s,1);lastPose=pose
 end
 ui.skillName.text=h.core;ui.core.text=h.desc..'\n'..(r.sub>0 and('专精：'..h.subclasses[r.sub])or'第8轮专精：'..h.subclasses[1]..' / '..h.subclasses[2])..(#r.talents>0 and(' · 已选天赋 '..#r.talents..' 项')or'')
 ui.hubRound.text='第 '..r.round..' 轮';ui.hubSub.text='准备阶段 · 摩拉 '..r.gold..' · 胜 '..r.wins..' / 败 '..r.losses..(r.mode=='endless'and' · 无尽'or'')
 local placed,stored=0,0;for _,q in ipairs(r.items)do if q.x>0 then placed=placed+1 else stored=stored+1 end end
 ui.bagTileSub.text='装备 '..placed..' 件 · 储物 '..stored..' · 空间 '..r.space..'/63';local left=0;for _,z in ipairs(r.shop)do if not z.sold then left=left+1 end end;ui.shopTileSub.text='在售 '..left..' 件 · 刷新 '..(r.rerolls<4 and 1 or 2)..' 摩拉'
 ui.space.text='空间 '..r.space..'/63';ui.refresh.label.text='刷新 · '..(r.rerolls<4 and 1 or 2)..'摩拉';ui.craft.label.text=r.autoCraft and'合成：开启'or'合成：关闭';ui.craft.fill.imageColor=col(r.autoCraft and'@main'or'@muted')
 local timers={};if fight and r.phase=='battle'then for _,z in ipairs(fight.a.items)do timers[z.instance]=z end end
 if lastRevision~=revision then
  local parts={r.hero,r.space,r.sub,table.concat(r.talents,',')};for _,q in ipairs(r.items)do parts[#parts+1]=q.id..':'..q.def..':'..q.x..':'..q.y..':'..q.rot end;for _,z in ipairs(r.shop)do parts[#parts+1]=z.def..':'..tostring(z.sold)end
  local signature=table.concat(parts,'|');if signature~=layoutCache.key then layoutCache={key=signature,items=E.compile(r),open=E.openMap(r),stamina=E.staminaInfo(r),spaces={}};for i=1,5 do layoutCache.spaces[i]=E.purchaseSpace(r,i)end end
  if layoutCache.tracked~=r.trackedRecipe then layoutCache.tracked=r.trackedRecipe;layoutCache.track=r.trackedRecipe and E.recipeStatus(r,r.trackedRecipe)or nil end
  local list=layoutCache.items;local links={};for _,z in ipairs(list)do links[z.instance]=z.links end
  local related=highlighted()
  local open=layoutCache.open;for i,v in ipairs(ui.cells)do v.bg.imageColor=col(open[i]and'@cell'or'@lock');v.edge.imageColor=col(open[i]and'@cellIn'or'@lockIn')end
  local q=placeTarget();local cells=q and hoverX>0 and E.cells(q,hoverX,hoverY,rotation)or{};local valid=q and hoverX>0 and E.fits(r,q,hoverX,hoverY,rotation)
  for i,c in ipairs(ui.ghost)do local p=cells[i];local on=p~=nil and p[1]>=1 and p[1]<=9 and p[2]>=1 and p[2]<=7 and editable();c:SetVisible(on);if on then c:SetAnchoredPosition(20+(p[1]-1)*84,20+(7-p[2])*56);c.imageColor=col(valid and'#22c55e'or'#ff3b5c',160)end end
  local info=layoutCache.stamina;local track=layoutCache.track
  ui.buildSummary.text=string.format('耐力需求 %.2f/s · 自然恢复 1/s%s',info.demand,info.demand>1 and' ⚠'or'')..'\n'..(track and('追踪：'..E.name(r.trackedRecipe)..'｜'..(track.complete and'已拥有，可切换下一条配方'or track.ready and'相邻已就绪'or track.owned and'材料齐，需相邻摆放'or'缺 '..table.concat(track.missing,'、')))or(info.demand>1 and('初始耐力约可支撑 '..string.format('%.1f',info.bufferSeconds)..'秒（未计料理）')or'选择装备查看联动；拖动装备可预览放置。'))
  for i,v in ipairs(slots)do local q=r.items[i];v.root:SetVisible(q~=nil and q.x>0);if q and q.x>0 then local d=E.defs[q.def];local w,hh=d.w,d.h;if q.rot%2==1 then w,hh=hh,w end;v.root:SetAnchoredPosition(20+(q.x-1)*84,20+(8-q.y-hh)*56);v.bg:SetSizeDelta(w*84-4,hh*56-4);v.bg.imageColor=col(selectedId==q.id and'@accent'or related[q.id]and'@main'or qcolors[d.q]);v.shadow:SetSizeDelta(w*84-4,hh*56-4);v.fill:SetSizeDelta(w*84-12,hh*56-12);v.icon.root:SetPivot(.5,.5);v.icon.root:SetAnchoredPosition(w*84/2,hh*56/2+5);v.icon.root:SetLocalScale(math.min(1.9,(d.w*84-15)/64),math.min(2.2,(d.h*56-27)/64),1);v.icon.root:SetLocalRotation(0,0,q.rot*90);setIcon(v.icon,d);v.name:SetSizeDelta(w*84-10,30);v.name.text=d.name..((links[q.id]or 0)>0 and' ★'or'')end end
  local waiting={};for _,q in ipairs(r.items)do if q.x==0 then waiting[#waiting+1]=q end end;for i,v in ipairs(ui.stash)do v.label.text=waiting[i]and E.name(waiting[i].def)or'空';v.fill.imageColor=col(waiting[i]and waiting[i].id==selectedId and'@main'or'@muted')end
  for i,v in ipairs(ui.shop)do local z=r.shop[i];local d=E.defs[z.def];setIcon(v.icon,d);v.qbar.imageColor=col(qcolors[d.q]);local material=track and not track.complete and(d.id==track.recipe.a or d.id==track.recipe.b);v.name.text=(material and'◆ 'or'')..d.name..' · '..quality[d.q];v.desc.text=(effectNames[d.effect]or'稳定攻击')..(not z.sold and not layoutCache.spaces[i]and' · 暂无空位'or'');v.buy.label.text=z.sold and'售罄'or(z.sale and'特价'or'')..z.price..'摩拉';v.buy.fill.imageColor=col(z.sold and'@muted'or r.gold>=z.price and'@main'or'#9a4a5a');v.lock.label.text=z.locked and'已锁'or'锁';v.lock.fill.imageColor=col(z.locked and'@accent'or'@muted');v.lock.label.fontColor=col(z.locked and'@ink'or'light')end
  local q=selected();local d=q and E.defs[q.def]or preview and E.defs[preview];ui.detailText.text=d and describe(d)or('选中物品查看说明。相邻材料将在战后合成。\n可合成 '..#E.craftable(r)..' 组；第3/10轮天赋，第8轮专精。');ui.hubInfo.text=ui.buildSummary.text..'\n可合成 '..#E.craftable(r)..' 组 · 已装备物品会在战斗中按冷却自动触发\n第3/10轮选择天赋，第8轮选择专精'
  lastRevision=revision
 end
 for i,v in ipairs(slots)do local q=r.items[i];local z=q and timers[q.id];v.cool:SetVisible(z~=nil and z.cd>0);if z and z.cd>0 then local d=E.defs[q.def];local w=q.rot%2==1 and d.h or d.w;v.cool:SetSizeDelta((w*84-14)*math.max(0,math.min(1,1-z.time/z.cd)),4)end end
 if fight and r.phase=='battle'then local a,b=fight.a,fight.b
  ui.playerHp.text=h.name..' '..math.ceil(math.max(0,a.hp))..'/'..a.max..' 盾'..math.floor(a.shield);ui.enemyHp.text=E.hero(b.hero).name..' '..math.ceil(math.max(0,b.hp))..'/'..b.max..' 盾'..math.floor(b.shield);ui.hp1:SetSizeDelta(290*math.max(0,a.hp/a.max),13);ui.hp2:SetSizeDelta(290*math.max(0,b.hp/b.max),13);if ui.enemyKey~=b.hero..tostring(TH)then ui.enemyKey=b.hero..tostring(TH);ui.slabR.imageColor=col(themeOf(b.hero).main..'b0')end;ui.resources.text='耐力 '..string.format('%.1f',a.stamina)..'/5  能量 '..math.floor(a.energy)..'  核心 '..a.coreCount..'次';ui.log.text=table.concat(fight.logs,'\n');ui.timer.text=string.format('%.1f秒 ×%d',fight.time,speed);ui.slash:SetVisible(fight.flash>0)
 else ui.slash:SetVisible(false)end
 if r.phase=='result'or r.phase=='ended'then local rec=r.history[#r.history];ui.resultTitle.text=r.phase=='ended'and(r.wins>=10 and'本局完成'or'旅途结束')or rec and(rec.winner==1 and'胜利!'or rec.winner==0 and'平局'or'败北')or'结算'
  local win=r.phase=='ended'and r.wins>=10 or rec and rec.winner==1;local tone=win and'@accent'or rec and rec.winner==0 and'@soft'or'@muted';ui.resultStar.imageColor=col(tone);ui.resultTitle.fontColor=col(win and'@main'or rec and rec.winner==0 and'@soft'or'#9a8fa8')
  local top=rec and rec.contributions and rec.contributions[1];local diagnosis=rec and rec.diagnosis or{}
  ui.resultBody.text=rec and('伤害 '..math.floor(rec.damage)..'  治疗 '..math.floor(rec.heal)..'  吸收 '..math.floor(rec.absorbed)..'\n核心 '..rec.core..' 次  合成 '..rec.crafted..' 组\n\n'..(top and('主要贡献：'..top.name..' · 触发'..top.hits..'次\n')or'')..table.concat(diagnosis,'\n')..'\n\n胜场 '..r.wins..'  失败 '..r.losses..'  轮次 '..r.round..'\n基准预演差距 '..string.format('%.0f%%',math.abs(rec.match.estimatedMargin or 0)*100))or'';ui.next.label.text=r.phase=='ended'and'选择角色 · 再来一局'or'下一轮 →'
 end
 if choosing or r.phase=='milestone'then
  if r.phase=='milestone'then ui.choiceTitle.text='10胜达成 · 继续挑战？';ui.choiceText.text='可以带着当前成绩收官，或进入生存模式至第18轮。';ui.choices[1].label.text='收官并记录成绩';ui.choices[2].label.text='继续生存挑战';ui.choices[3].body:SetVisible(false)
  elseif r.round>=8 and r.sub==0 and not(r.round==10 and #r.talents<2)then ui.choiceTitle.text='选择角色专精';ui.choiceText.text='本局选择不可更换，专精强化核心或持续恢复。';ui.choices[1].label.text=h.subclasses[1]..' · 核心效果 +12%';ui.choices[2].label.text=h.subclasses[2]..' · 持续恢复';ui.choices[3].body:SetVisible(false)
  else ui.choiceTitle.text='选择冒险天赋';ui.choiceText.text='第3与第10轮各选择一次。';ui.choices[1].label.text='武艺精进 · 武器伤害 +8%';ui.choices[2].label.text='丰盛补给 · 治疗效果 +12%';ui.choices[3].label.text='迅捷节奏 · 冷却速度 +8%';ui.choices[3].body:SetVisible(true)end
 end
 if pick then local p=E.hero(previewHero);ui.pickInfo.text=p.name..' · '..p.role..'\n'..p.core..'\n'..p.desc;ui.mode.label.text=mode=='standard'and'标准：10胜／5次失败'or'无尽：持续匹配，失败5次结束';for i,v in ipairs(ui.heroButtons)do local on=E.heroes[i].id==previewHero;v.fill.imageColor=col(on and'@main'or'@dark');ui.heroStars[i]:SetVisible(on)end end
 if book or history then
  local lines={}
  if history then ui.bookTitle.text='本局对战记录';for i=math.max(1,#r.history-7),#r.history do local q=r.history[i];lines[#lines+1]='第'..q.round..'轮 '..(q.winner==1 and'胜'or'负')..' '..string.format('%.1f',q.time)..'秒  伤害'..math.floor(q.damage)..'  预演差'..string.format('%.0f%%',math.abs(q.match.estimatedMargin or 0)*100)end
  elseif bookTab=='analysis'then local rec=r.history[#r.history];local data=rec and rec.contributions or{};local pages=math.max(1,math.ceil(#data/4));bookPage=math.min(bookPage,pages);ui.bookTitle.text='战斗贡献 '..bookPage..'/'..pages
   if rec then lines[#lines+1]='核心伤害 '..math.floor(rec.coreDamage or 0)..' · 持续伤害 '..math.floor(rec.dotDamage or 0)..' · 反伤 '..math.floor(rec.thornDamage or 0)end
   for i=(bookPage-1)*4+1,math.min(bookPage*4,#data)do local z=data[i];lines[#lines+1]=z.name..' · 触发 '..z.hits..' 次\n伤害 '..math.floor(z.damage)..' / 治疗 '..math.floor(z.heal)..' / 护盾 '..math.floor(z.shield)..'\n耐力等待 '..string.format('%.1f',z.wait)..'秒'end
  elseif bookTab=='enemy'and r.opponent then local page=math.min(bookPage,math.max(1,math.ceil(#r.opponent.items/10)));bookPage=page;ui.bookTitle.text='对手背包 · '..E.hero(r.opponent.hero).name;for i=(page-1)*10+1,math.min(page*10,#r.opponent.items)do local z=r.opponent.items[i];lines[#lines+1]=E.name(z.def)..'  '..z.x..','..z.y..'  旋转'..z.rot*90 ..'°'end
  elseif bookTab=='help'then bookPage=math.min(bookPage,#helpPages);local hp=helpPages[bookPage];ui.bookTitle.text='玩法说明 '..bookPage..'/'..#helpPages..' · '..hp[1];lines[1]=hp[2]
  elseif bookTab=='items'then local page=math.min(bookPage,math.ceil(#E.defs/5));bookPage=page;ui.bookTitle.text='物品图鉴 '..page..'/'..math.ceil(#E.defs/5)..' · '..#E.defs..'件'
   for k,v in ipairs(ui.bookRows)do local d=E.defs[(page-1)*5+k];v.chip:SetVisible(d~=nil);v.back:SetVisible(d~=nil);v.icon.root:SetVisible(d~=nil);v.text.text=d and describe(d)or'';if d then v.chip.imageColor=col(qcolors[d.q]);setIcon(v.icon,d)end end
  else local page=math.min(bookPage,math.ceil(#E.recipes/6));bookPage=page;ui.bookTitle.text='配方图鉴 '..page..'/'..math.ceil(#E.recipes/6);for i=(page-1)*6+1,math.min(page*6,#E.recipes)do local p=E.recipes[i];lines[#lines+1]=E.name(p.a)..' ＋ '..E.name(p.b)..'\n → '..E.name(p.out)end end
  ui.bookText.text=table.concat(lines,'\n\n');show(ui.bookRowLayer,book and not history and bookTab=='items')
 end
end
function OnStart()
 local root=script.object;local cw,ch=game.GetUICanvasSize();local scale=math.min(cw/W,ch/H);root:SetAnchorMin(.5,.5);root:SetAnchorMax(.5,.5);root:SetPivot(.5,.5);root:SetSizeDelta(W,H);root:SetAnchoredPosition(0,0);root:SetLocalScale(scale,scale,1);root.showCursor=true;root.disableKeyEventPassthrough=true;root.disableCursorEventPassthrough=true
 loading=shape(root,'loading',0,0,W,H,'dark');loadingLabel=text(loading,'loading_label',390,410,1000,80,'正在准备冒险行囊 · 分批构建图元',30,'light');recording=true;build();recording=false;pendingBase=pendingBase or 0;totalCreates=0;for _,job in ipairs(queue)do if job.create then totalCreates=totalCreates+1 end end;init=true;script:EnableUpdate(true)
 local function key(n,fn)local en=Enum.KeyEventType['KeyboardCraftspersonKey'..n..'Down'];if en then root:AddKeyEventListener(en,function()if ready and not title and not pick and not book and not history then fn()end;return true end)end end
 key(5,function()CancelInteraction(true)end);key(1,rotate);key(2,function()invoke(E.refresh,false)end);key(3,craftToggle);key(6,function()toggleShop()end);key(7,function()toggleBag()end);key(4,function()if r.phase=='shop'then begin()elseif r.phase=='result'then nextRound()end end)
end
-- Idle motion: breathing portrait, slow light rays, pulsing aura, a periodic shine sweep and element particles
-- (electro sparks, dendro leaves, geo shards, hydro bubbles, pyro embers). Transform/colour updates only.
local fxShape={electro=100004,dendro=100002,geo=100001,hydro=100002,pyro=100002}
local function animate(dt)
 fx.t=fx.t+dt;local t=fx.t;local b=math.sin(t*2.1);local s=poseBase.s;local hr=views.hero.root
 hr:SetLocalScale(s*(1+.005*b),s*(1+.011*b),1);hr:SetAnchoredPosition(poseBase.x,poseBase.y+s*.8*b)
 if lastPose~='board'or not visibility[views.card]then return end
 fx.rays:SetLocalRotation(0,0,t*6);local p=1+.06*math.sin(t*1.7);fx.aura:SetLocalScale(p,p,1)
 local cyc=t%6;fx.shine:SetAnchoredPosition(cyc<1.2 and(-120+cyc/1.2*(CW+200))or 2000,(CH-24)/2)
 if not visibility[views.cardTop]then return end
 local kind=heroElement[r.hero]or'electro'
 if fx.kind~=kind then fx.kind=kind;for _,q in ipairs(fx.parts)do q.c:SetImage(Enum.ImageSource.StaticReference,fxShape[kind]);q.c:SetPivot(.5,.5);q.c:SetLocalRotation(0,0,kind=='geo'and 45 or 0)end end
 local speed=kind=='pyro'and 1.7 or kind=='dendro'and .6 or kind=='geo'and .5 or 1
 for i,q in ipairs(fx.parts)do
  q.y=q.y+q.sp*dt*speed;if q.y>PH+20 then q.y=-20;q.x=(q.x+137)%PW end
  local sway=kind=='dendro'and 30 or kind=='hydro'and 16 or 10;local x=q.x+math.sin(t*1.3+q.ph)*sway
  local life=q.y/PH;local a=math.max(0,math.min(1,(1-life)*1.8,(life+.1)*4))
  local z=q.sz*(kind=='electro'and(.55+.6*math.abs(math.sin(t*5+q.ph)))or kind=='hydro'and(.7+.4*life)or 1)
  q.c:SetAnchoredPosition(x,q.y);q.c:SetSizeDelta(z,kind=='dendro'and z*.5 or z);if kind=='dendro'then q.c:SetLocalRotation(0,0,math.sin(t*1.8+q.ph)*50)end
  q.c.imageColor=col(i%3==0 and'@soft'or'@accent',math.floor(a*(kind=='hydro'and 150 or 225)))
 end
end
function OnUpdate(dt)
 for body,j in pairs(jellies)do j.t=j.t+math.min(dt,.05);local d=j.amp*math.exp(-7*j.t)*math.cos(24*j.t);if j.t>.7 then d=0;jellies[body]=nil end;body:SetLocalScale(1+d,1-d,1)end
 if init then batch=0;local operations=0;while qi<=#queue do local job=queue[qi];if operations>=1200 or(job.create and batch>=60)then break end;job.run();operations=operations+1;if job.create then batch=batch+1 end;qi=qi+1 end;peak=math.max(peak,batch);loadingLabel.text='正在准备角色与行囊 · '..math.min(100,math.floor((qi-1)/math.max(1,#queue)*100))..'%';loading:SetAsLastSibling();if qi>#queue then init=nil;ready=true;queue={};loading:SetVisible(false);launchPending();render()end;return end
 if not ready then return end
 animate(dt)
 if matchJob then
  local done=E.stepMatch(matchJob,60);notice='匹配预演 '..matchJob.trial..'/'..matchJob.total..' · 正在寻找接近的背包';touch()
  if done then local opp,meta=E.finishMatch(matchJob);matchJob=nil;pendingBattle={opp=opp,meta=meta};setSprite(views.enemy,opp.hero);if not init then launchPending()end end
 end
 if r.phase=='battle'and fight and not title then acc=math.min(.4,acc+math.min(dt,.1)*speed);while acc>=.05 and not fight.done do E.step(fight,.05);acc=acc-.05 end;if fight.done then E.finish(r,fight);notify('对战结束；材料相邻且空间允许时已自动合成。')end end
 paint=paint+dt;if paint>=.1 then paint=0;render()end
end
function Inspect()return{ready=ready or false,phase=r.phase,title=title,shopOpen=shopOpen,bagOpen=bagOpen,resumable=resumable,pick=pick,hero=r.hero,previewHero=previewHero,round=r.round,wins=r.wins,lives=r.lives,gold=r.gold,space=r.space,items=copy and copy(r.items)or E.copy(r.items),shop=E.copy(r.shop),selected=selectedId,rotation=rotation,note=notice,revision=revision,created=created,peakCreated=peak,dragging=drag~=nil,hoverX=hoverX,hoverY=hoverY,book=book,bookTab=bookTab,placementValid=placeTarget()and hoverX>0 and E.fits(r,placeTarget(),hoverX,hoverY,rotation)or false,trackedRecipe=r.trackedRecipe,stamina=E.staminaInfo(r),related=highlighted(),matchProgress=matchJob and{done=matchJob.trial,total=matchJob.total}or nil,match=r.match,talents=r.talents,sub=r.sub,clock=fight and fight.time or 0,combat=fight and{hp=fight.a.hp,enemyHp=fight.b.hp,damage=fight.a.totals.damage,bursts=fight.a.coreCount}or nil}end
function ExportSave()if not ready or pendingBattle or matchJob or r.phase=='battle'then return nil end;return E.copy(r)end
function ImportSave(value)if matchJob or pendingBattle or not ready or not E.validate(value)or value.phase=='battle'then return false end;r=E.copy(value);resumable=true;pick=false;book=false;history=false;selectedId=0;drag=nil;hoverX=0;hoverY=0;hoverItem=0;setSprite(views.hero,r.hero);fight=nil;notify('已恢复本地对局。');return true end

function OpenCharacterPicker()if not ready or matchJob then return false end;openPick();return true end

function CancelInteraction(clear)if clear then selectedId=0 end;drag=nil;hoverX=0;hoverY=0;hoverItem=0;touch();return true end
