const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));
const pedal=value=>typeof value==="boolean"?(value?1:0):clamp(Number.isFinite(value)?value:0,0,1);

/**
 * Take one immutable Input State Manager snapshot and map it to the vehicle
 * controller contract. Steering may use its fixed-step filtered value while
 * pedal and turbo channels remain independent and are never mutually cleared.
 */
export function mapInputSnapshotToVehicleControls(snapshot,smoothedSteering=snapshot?.steering??0){
 const source=snapshot&&typeof snapshot==="object"?snapshot:{};
 return Object.freeze({
  steer:clamp(Number.isFinite(smoothedSteering)?smoothedSteering:(Number.isFinite(source.steering)?source.steering:0),-1,1),
  throttle:pedal(source.throttle),
  brake:pedal(source.brake),
  turbo:Boolean(source.turbo)
 });
}
