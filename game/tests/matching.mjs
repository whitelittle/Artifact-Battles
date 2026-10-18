import fs from'node:fs';import{prelude,lua,encode,runLua}from'../lua.mjs';const bank=JSON.parse(fs.readFileSync(new URL('../data/opponents.json',import.meta.url)));const result=runLua(prelude+'local BANK='+lua(bank)+'\n'+encode+`
local rows={};for tier=1,3 do
 local b=BANK[(6-1)*32+(tier-1)*4+tier];local r=E.newRun(b.hero,113+tier);r.round=b.round;r.space=b.space;r.items=E.copy(b.items);r.talents=E.copy(b.talents);r.sub=b.sub
 local job=E.prepareMatch(r,BANK);while not E.stepMatch(job)do end
 local best=999;for _,q in ipairs(job.shortlist)do best=math.min(best,q.fairness)end
 local opponent,meta=E.finishMatch(job);assert(E.validBuild(opponent));assert(opponent.round==r.round);assert(math.abs(meta.estimatedMargin)<=best+.121)
 local f=E.simulate(r,opponent,7731+tier);rows[#rows+1]={hero=r.hero,budgetTier=tier,candidates=meta.candidates,trialBuilds=meta.trialBuilds,bestMargin=best,chosenMargin=math.abs(meta.estimatedMargin),actualResult=f.winner,actualSeconds=f.time,referencePower=meta.referencePower,shoppingGain=meta.shoppingGain}
end
return json({sameRound=true,legalUnscaledOpponents=true,twoTrialSeeds=true,samples=rows})
`);console.log(result);fs.writeFileSync(new URL('../out/matching-report.json',import.meta.url),result);
