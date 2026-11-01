const clamp=(v,min,max)=>Math.max(min,Math.min(max,v));
export function calculateRaceSteering({lateral=0,targetLateral=0,yaw=0,lateralVelocity=0,trackCurvature=0}){
const l=Number.isFinite(lateral)?lateral:0,t=Number.isFinite(targetLateral)?targetLateral:0,y=Number.isFinite(yaw)?yaw:0,c=Number.isFinite(trackCurvature)?trackCurvature:0,v=Number.isFinite(lateralVelocity)?lateralVelocity:0;
const steer=clamp(Math.atan(c*128)/.48-(l-t)/500-y*.28-v/900,-.52,.52);return Math.abs(steer)<.035?0:steer}