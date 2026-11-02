const THREE_CDN="https://cdn.jsdelivr.net/npm/three@0.180.0/build/three.module.js";
export async function createCityThreeRenderer(sourceCanvas){
 let THREE;try{THREE=await import(THREE_CDN)}catch{THREE=await import("https://unpkg.com/three@0.180.0/build/three.module.js")}
 const renderer=new THREE.WebGLRenderer({antialias:true,powerPreference:"high-performance"});
 renderer.setPixelRatio(Math.min(devicePixelRatio||1,1.5));renderer.setSize(innerWidth,innerHeight,false);
 renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.12;
 const canvas=renderer.domElement;canvas.id="cityThreeViewport";canvas.style.cssText="position:fixed;inset:0;width:100%;height:100%;z-index:1;pointer-events:none;display:block";
 sourceCanvas.parentNode.insertBefore(canvas,sourceCanvas.nextSibling);sourceCanvas.style.opacity="0";
 const scene=new THREE.Scene();scene.background=new THREE.Color("#b8d5e0");scene.fog=new THREE.Fog("#b8d5e0",70,135);
 const camera=new THREE.OrthographicCamera(-36,36,24,-24,.1,220);camera.position.set(42,50,42);camera.lookAt(0,0,0);
 scene.add(new THREE.HemisphereLight("#e9f7ff","#687d58",2.15));
 const sun=new THREE.DirectionalLight("#fff0d2",3.2);sun.position.set(-30,52,-24);sun.castShadow=true;sun.shadow.mapSize.set(1024,1024);sun.shadow.camera.left=-42;sun.shadow.camera.right=42;sun.shadow.camera.top=42;sun.shadow.camera.bottom=-42;scene.add(sun);
 const fill=new THREE.DirectionalLight("#8dc8ff",.75);fill.position.set(25,22,30);scene.add(fill);
 const base=new THREE.Mesh(new THREE.PlaneGeometry(180,180),new THREE.MeshStandardMaterial({color:"#789d69",roughness:1}));base.rotation.x=-Math.PI/2;base.position.y=-.2;base.receiveShadow=true;scene.add(base);
 const grassGeo=new THREE.BoxGeometry(1.94,.18,1.94),roadGeo=new THREE.BoxGeometry(1.99,.13,1.99);
 const grassA=new THREE.InstancedMesh(grassGeo,new THREE.MeshStandardMaterial({color:"#82ad68",roughness:.96}),1024);
 const grassB=new THREE.InstancedMesh(grassGeo,new THREE.MeshStandardMaterial({color:"#8db978",roughness:.96}),1024);
 const roads=new THREE.InstancedMesh(roadGeo,new THREE.MeshStandardMaterial({color:"#38434c",roughness:.94}),1024);
 const dummy=new THREE.Object3D(),edges=[],markings=[];let a=0,b=0,r=0;
 for(let y=0;y<32;y++)for(let x=0;x<32;x++){
  const px=(x-15.5)*2,pz=(y-15.5)*2,isRoad=[7,8,15,16,23,24].includes(x)||[7,8,15,16,23,24].includes(y);
  dummy.position.set(px,isRoad?-.005:.015,pz);dummy.updateMatrix();
  if(isRoad){roads.setMatrixAt(r++,dummy.matrix);continue}
  ((x+y)%2?grassB:grassA).setMatrixAt((x+y)%2?b++:a++,dummy.matrix);
  const yy=.112;edges.push(px-.92,yy,pz-.92,px+.92,yy,pz-.92,px+.92,yy,pz-.92,px+.92,yy,pz+.92,px+.92,yy,pz+.92,px-.92,yy,pz+.92,px-.92,yy,pz+.92,px-.92,yy,pz-.92);
 }
 grassA.count=a;grassB.count=b;roads.count=r;grassA.instanceMatrix.needsUpdate=true;grassB.instanceMatrix.needsUpdate=true;roads.instanceMatrix.needsUpdate=true;
 grassA.receiveShadow=true;grassB.receiveShadow=true;roads.receiveShadow=true;scene.add(grassA,grassB,roads);
 const edgeGeo=new THREE.BufferGeometry();edgeGeo.setAttribute("position",new THREE.Float32BufferAttribute(edges,3));scene.add(new THREE.LineSegments(edgeGeo,new THREE.LineBasicMaterial({color:"#e0edc8",transparent:true,opacity:.78})));
 for(let i=0;i<32;i++)for(const k of [7,8,15,16,23,24])if(i%2===0){const z=(i-15.5)*2,x=(i-15.5)*2;markings.push((k-15.5)*2-.25,.065,z,(k-15.5)*2+.25,.065,z,x,.065,(k-15.5)*2-.25,x,.065,(k-15.5)*2+.25)}
 const markGeo=new THREE.BufferGeometry();markGeo.setAttribute("position",new THREE.Float32BufferAttribute(markings,3));scene.add(new THREE.LineSegments(markGeo,new THREE.LineBasicMaterial({color:"#f4e8bb",transparent:true,opacity:.82})));
 const objects=new THREE.Group();scene.add(objects);let signature="";
 const raycaster=new THREE.Raycaster(),pointer=new THREE.Vector2(),plane=new THREE.Plane(new THREE.Vector3(0,1,0),0);let width=innerWidth,height=innerHeight;
 function resize(){width=innerWidth;height=innerHeight;renderer.setPixelRatio(Math.min(devicePixelRatio||1,1.5));renderer.setSize(width,height,false);const aspect=width/height;camera.left=-25*aspect;camera.right=25*aspect;camera.top=25;camera.bottom=-25;camera.updateProjectionMatrix()}
 function updateCamera(cam){const zoom=Math.max(.4,Math.min(1.7,(cam.zoom||.72)*1.25));camera.zoom=zoom;const scale=height/50;const tx=-(cam.x||0)/scale,tz=-(cam.y||0)/scale;camera.position.set(42+tx,50,42+tz);camera.lookAt(tx,0,tz);camera.updateProjectionMatrix()}
 function updateBuildings(city){const next=city.buildings.map(v=>[v.id,v.type,v.x,v.y,v.level].join(":")).join("|");if(next===signature)return;signature=next;objects.clear();for(const v of city.buildings){const x=(v.x-15.5)*2,z=(v.y-15.5)*2;if(v.type==="park"){const m=new THREE.Mesh(new THREE.BoxGeometry(1.7,.22,1.7),new THREE.MeshStandardMaterial({color:"#4d9852"}));m.position.set(x,.2,z);objects.add(m);continue}const h=1.3+(v.level||1)*.65,color=v.type==="home"?"#e8c68b":v.type==="shop"?"#62aeb7":v.type==="industrial"?"#9caab0":"#9d9ac5";const body=new THREE.Mesh(new THREE.BoxGeometry(1.25,h,1.25),new THREE.MeshStandardMaterial({color,roughness:.78}));body.position.set(x,.2+h/2,z);body.castShadow=true;objects.add(body);const roof=new THREE.Mesh(new THREE.BoxGeometry(1.32,.12,1.32),new THREE.MeshStandardMaterial({color:"#dce6e8"}));roof.position.set(x,.2+h+.06,z);objects.add(roof)}}
 function render(city,view,cam){updateCamera(cam);updateBuildings(city);renderer.render(scene,camera)}
 function tileAt(px,py){pointer.set(px/width*2-1,-py/height*2+1);raycaster.setFromCamera(pointer,camera);const p=new THREE.Vector3();if(!raycaster.ray.intersectPlane(plane,p))return{x:-1,y:-1};return{x:Math.floor(p.x/2+16),y:Math.floor(p.z/2+16)}}
 function screenForTile(x,y){const p=new THREE.Vector3((x-15.5)*2,.12,(y-15.5)*2).project(camera);return{x:(p.x+1)*width/2,y:(1-p.y)*height/2}}
 resize();const onResize=()=>resize();addEventListener("resize",onResize);
 return{render,tileAt,screenForTile,resize,destroy(){removeEventListener("resize",onResize);renderer.dispose();canvas.remove();sourceCanvas.style.opacity=""}};
}