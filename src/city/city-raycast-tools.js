/** Screen/world projection and surface-picking helpers for the 3D city renderer. */
export function createCityRaycastTools(THREE,{camera,buildings,groundPlane,getViewport}){
  const raycaster=new THREE.Raycaster();
  const pointer=new THREE.Vector2();
  const pointAt=(screenX,screenY)=>{
    const {width,height}=getViewport();
    pointer.set(screenX/Math.max(1,width)*2-1,-screenY/Math.max(1,height)*2+1);
    raycaster.setFromCamera(pointer,camera);
  };
  function tileAt(screenX,screenY){
    pointAt(screenX,screenY);
    const point=new THREE.Vector3();
    if(!raycaster.ray.intersectPlane(groundPlane,point))return{x:-1,y:-1};
    return{x:Math.floor(point.x/2+16),y:Math.floor(point.z/2+16)};
  }
  function groundPointAt(screenX,screenY){
    pointAt(screenX,screenY);
    const point=new THREE.Vector3();
    return raycaster.ray.intersectPlane(groundPlane,point)?{x:point.x,z:point.z}:null;
  }
  function focusPointAt(screenX,screenY){
    pointAt(screenX,screenY);
    const hits=raycaster.intersectObjects(buildings.children,true);
    if(hits.length)return{x:hits[0].point.x,y:hits[0].point.y,z:hits[0].point.z};
    return groundPointAt(screenX,screenY);
  }
  function screenForTile(x,y){
    const {width,height}=getViewport();
    const point=new THREE.Vector3((x-15.5)*2,0.16,(y-15.5)*2).project(camera);
    return{x:(point.x+1)*width/2,y:(1-point.y)*height/2};
  }
  return{tileAt,groundPointAt,focusPointAt,screenForTile};
}
