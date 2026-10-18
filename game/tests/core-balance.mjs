import fs from'node:fs';import{prelude,runLua,encode,lua}from'../lua.mjs';const bank=JSON.parse(fs.readFileSync(new URL('../data/opponents.json',import.meta.url)));const result=runLua(prelude+'local BANK='+lua(bank)+'\n'+encode+`
local score={};for _,h in ipairs(E.heroes)do score[h.id]={wins=0,draws=0,games=0,damage=0}end
local stages={1,8,18};local time=0;local games=0
for _,round in ipairs(stages)do local fixtures={};for h=1,8 do local index=(round-1)*32+(h-1)*4+3;fixtures[h]=E.copy(BANK[(round-1)*32+3]);fixtures[h].hero=E.heroes[h].id end
 for a=1,8 do for b=a+1,8 do for swap=1,2 do
  local aa,bb=swap==1 and a or b,swap==1 and b or a;local x,y=fixtures[aa],fixtures[bb];local f=E.simulate(x,y,round*1717+a*53+b*7+swap);local sa,sb=score[x.hero],score[y.hero];sa.games=sa.games+1;sb.games=sb.games+1;sa.damage=sa.damage+f.a.totals.damage;sb.damage=sb.damage+f.b.totals.damage
  if f.winner==1 then sa.wins=sa.wins+1 elseif f.winner==-1 then sb.wins=sb.wins+1 else sa.draws=sa.draws+1;sb.draws=sb.draws+1 end;games=games+1;time=time+f.time
 end end end
end
return json({sampleBattles=games,stages=stages,heroes=score,averageSeconds=time/games,method='Identical legal layout, items and talents for all eight cores at each stage; swapped seats. Isolates core effects from random bot compositions. Limited screening, not a live-player balance guarantee.'})
`);fs.writeFileSync(new URL('../out/core-balance-report.json',import.meta.url),JSON.stringify(JSON.parse(result),null,2));console.log(result);
