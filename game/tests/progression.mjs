import fs from'node:fs';import{prelude,encode,runLua}from'../lua.mjs';const result=runLua(prelude+encode+`
local paths={}
-- Scripted results isolate progression, rewards, branches and persistent layout.
for _,mode in ipairs({'standard','survival','endless','defeat'})do
 local r=E.newRun('raiden',811,mode=='endless'and'endless'or'standard');local rounds=mode=='defeat'and 5 or mode=='standard'and 10 or mode=='survival'and 18 or 21;local rewards=13
 for n=1,rounds do
  assert(r.phase=='shop'and r.round==n);if n==3 or n==10 then assert(E.choose(r,1))end;if n==8 then assert(E.choose(r,2))end
  assert(E.canBegin(r));local snap=E.snapshot(r);local f=E.startBattle(snap,snap,1);f.done=true;f.winner=mode=='defeat'and -1 or 1;f.time=12;r.phase='battle';r.match={ratio=1,estimatedMargin=0,source='进度测试'};assert(E.finish(r,f));assert(#r.history==n)
  assert(E.next(r));if r.phase=='milestone'then assert(mode=='standard'or mode=='survival');assert(E.next(r,mode=='standard'and'stop'or'survive'))end
  if n<rounds then assert(r.phase=='shop');rewards=rewards+E.economy.gold[math.min(r.round,18)]end
 end
 if mode=='endless'then assert(r.phase=='shop'and r.round==22)else assert(r.phase=='ended')end
 assert(#r.items==3);assert(E.validate(r));paths[#paths+1]={mode=mode,round=r.round,wins=r.wins,losses=r.losses,phase=r.phase}
end
return json({method='Scripted results test transitions, not win-rate evidence',paths=paths,tenWinBranch=true,fiveLossBranch=true,survival18=true,endlessBeyond18=true})
`);console.log(result);fs.writeFileSync(new URL('../out/progression-report.json',import.meta.url),result);
