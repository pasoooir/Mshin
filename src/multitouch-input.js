export function createMultiTouchPointerSet(){
  const active=new Set();
  return Object.freeze({
    press(pointerId){if(pointerId===undefined||pointerId===null)return false;const size=active.size;active.add(pointerId);return active.size!==size;},
    release(pointerId){return active.delete(pointerId);},
    clear(){const hadPointers=active.size>0;active.clear();return hadPointers;},
    has(pointerId){return active.has(pointerId);},
    get size(){return active.size;},
    get pressed(){return active.size>0;}
  });
}
