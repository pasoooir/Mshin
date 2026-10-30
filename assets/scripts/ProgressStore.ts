import { sys } from "cc";
import { StageDefinition } from "../../src/stage-catalog";
export interface PlayerProgress { unlockedStage:number;completed:number[];bestTimes:Record<string,number>; }
const KEY="mshin.progress.v1";
const fresh=():PlayerProgress=>({unlockedStage:1,completed:[],bestTimes:{}});
export class ProgressStore {
 static load():PlayerProgress {
  try{const raw=sys.localStorage.getItem(KEY);if(!raw)return fresh();const value=JSON.parse(raw) as Partial<PlayerProgress>;
   const completed=Array.isArray(value.completed)?value.completed.filter(n=>Number.isInteger(n)&&n>=1&&n<=50):[];
   const unlockedStage=Math.max(1,Math.min(50,Number(value.unlockedStage)||1));
   const bestTimes=value.bestTimes&&typeof value.bestTimes==="object"?value.bestTimes:{};
   return {unlockedStage,completed,bestTimes};
  }catch{return fresh();}
 }
 static save(p:PlayerProgress):void{sys.localStorage.setItem(KEY,JSON.stringify(p));}
 static isUnlocked(id:number,_p=ProgressStore.load()):boolean{return Number.isInteger(id)&&id>=1&&id<=50;}
 static complete(stage:StageDefinition,time:number):PlayerProgress {
  const p=ProgressStore.load();if(!p.completed.includes(stage.id))p.completed.push(stage.id);
  p.unlockedStage=Math.max(p.unlockedStage,Math.min(50,stage.id+1));
  const old=p.bestTimes[String(stage.id)];if(!old||time<old)p.bestTimes[String(stage.id)]=time;
  this.save(p);return p;
 }
}
