// Shared automotive metallic-roughness PBR pipeline for showroom and live race cars.
// WebGL 1 compatible: Cook-Torrance GGX + Schlick Fresnel + a procedural studio cubemap.
export const PBR_VERTEX = `
attribute vec3 aPosition;
attribute vec3 aNormal;
uniform mat4 uMvp;
uniform mat4 uModel;
varying vec3 vNormal;
varying vec3 vWorldPosition;
varying vec3 vObjectPosition;
void main(){
  vec4 world=uModel*vec4(aPosition,1.0);
  gl_Position=uMvp*vec4(aPosition,1.0);
  vWorldPosition=world.xyz;
  vObjectPosition=aPosition;
  vNormal=normalize(mat3(uModel)*aNormal);
}
`;
export const PBR_FRAGMENT = `
precision mediump float;
uniform vec3 uBaseColor;
uniform vec3 uCameraPosition;
uniform vec3 uLightDirection;
uniform vec3 uLightColor;
uniform samplerCube uEnvironmentMap;
uniform sampler2D uSurfaceTexture;
uniform float uSurfaceEnabled;
uniform float uMetallic;
uniform float uRoughness;
uniform float uClearcoat;
uniform float uEmissive;
uniform float uMaterialKind;
varying vec3 vNormal;
varying vec3 vWorldPosition;
varying vec3 vObjectPosition;
const float PI=3.14159265359;
float saturate(float x){return clamp(x,0.0,1.0);}
float hash31(vec3 p){p=fract(p*.1031);p+=dot(p,p.yxz+33.33);return fract((p.x+p.y)*p.z);}
float distributionGGX(vec3 N,vec3 H,float roughness){
 float a=max(roughness*roughness,.025),a2=a*a;
 float nh=max(dot(N,H),0.0),d=nh*nh*(a2-1.0)+1.0;
 return a2/max(PI*d*d,.0001);
}
float geometrySchlick(float nv,float roughness){
 float r=roughness+1.0,k=(r*r)/8.0;
 return nv/max(nv*(1.0-k)+k,.0001);
}
vec3 fresnelSchlick(float cosTheta,vec3 f0){return f0+(1.0-f0)*pow(1.0-saturate(cosTheta),5.0);}
void main(){
 vec3 N=normalize(gl_FrontFacing?vNormal:-vNormal);
 vec3 V=normalize(uCameraPosition-vWorldPosition);
 vec3 L=normalize(uLightDirection);
 vec3 H=normalize(V+L);
 float rough=clamp(uRoughness,.045,1.0);
 float metal=saturate(uMetallic);
 vec3 base=uBaseColor;
 if(uSurfaceEnabled>.5){vec2 uv=fract(vWorldPosition.xz*.045);vec3 scanned=texture2D(uSurfaceTexture,uv).rgb;base=mix(base,scanned,.68);}
 // Fine metallic flakes in clear-coated automotive paint; deterministic object-space grain.
 if(uMaterialKind<1.5){
   float flake=hash31(floor(vObjectPosition*vec3(5.0,11.0,5.0)));
   base*=1.0+(flake-.5)*.055;
 }
 // Carbon-fibre twill and woven composite texture for splitters, diffusers and aero.
 if(uMaterialKind>6.5&&uMaterialKind<7.5){
   vec2 weave=vObjectPosition.xz*vec2(1.35,1.8);
   float thread=mod(floor(weave.x)+floor(weave.y),2.0);
   float fibre=.91+.09*thread+.035*sin(weave.x*PI*2.0)*sin(weave.y*PI*2.0);
   base*=fibre;
 }
 // Rubber sidewall micrograin and fine tread-like tonal variation.
 if(uMaterialKind>3.5&&uMaterialKind<4.5){
   float grain=hash31(floor(vObjectPosition*vec3(18.0,24.0,18.0)));
   base*=.94+.06*grain;
 }
 // Brushed aluminium anisotropic-looking lathe grain on alloy faces.
 if(uMaterialKind>4.5&&uMaterialKind<5.5){
   float brush=.96+.04*sin(vObjectPosition.y*125.0);
   base*=brush;
 }
 float nv=max(dot(N,V),.001),nl=max(dot(N,L),0.0);
 vec3 f0=mix(vec3(.04),base,metal);
 vec3 F=fresnelSchlick(max(dot(H,V),0.0),f0);
 float D=distributionGGX(N,H,rough);
 float G=geometrySchlick(nv,rough)*geometrySchlick(nl,rough);
 vec3 specular=(D*G*F)/max(4.0*nv*nl,.001);
 vec3 kd=(vec3(1.0)-F)*(1.0-metal);
 vec3 direct=(kd*base/PI+specular)*uLightColor*nl;
 // Image-based studio reflections: softboxes and environment gradients are encoded in a local cubemap.
 vec3 R=reflect(-V,N);
 vec3 envDiffuse=textureCube(uEnvironmentMap,N).rgb;
 vec3 envSpec=textureCube(uEnvironmentMap,R).rgb;
 vec3 ambientDiffuse=envDiffuse*base*kd*.72;
 vec3 ambientSpec=envSpec*F*mix(.92,.28,rough)*(.35+.65*metal);
 // Automotive clearcoat is a second, narrow dielectric lobe above the metallic base coat.
 float coatF=.04+.96*pow(1.0-nv,5.0);
 float coatD=distributionGGX(N,H,.105);
 float coatG=geometrySchlick(nv,.105)*geometrySchlick(nl,.105);
 float coatSpec=coatD*coatG*coatF/max(4.0*nv*nl,.001);
 vec3 clearcoat=vec3((coatSpec*nl+coatF*.12)*uClearcoat);
 vec3 color=direct+ambientDiffuse+ambientSpec+clearcoat+base*uEmissive;
 // Filmic shoulder keeps bright paint highlights and LED emitters from clipping harshly.
 color=color/(color+vec3(.72));
 color=pow(max(color,vec3(0.0)),vec3(1.0/2.2));
 gl_FragColor=vec4(color,1.0);
}
`;
export function createVehicleEnvironment(gl){
 const texture=gl.createTexture();
 gl.bindTexture(gl.TEXTURE_CUBE_MAP,texture);
 const size=64;
 const faces=[
  {target:gl.TEXTURE_CUBE_MAP_POSITIVE_X,dir:(u,v)=>[1,-v,-u]},
  {target:gl.TEXTURE_CUBE_MAP_NEGATIVE_X,dir:(u,v)=>[-1,-v,u]},
  {target:gl.TEXTURE_CUBE_MAP_POSITIVE_Y,dir:(u,v)=>[u,1,v]},
  {target:gl.TEXTURE_CUBE_MAP_NEGATIVE_Y,dir:(u,v)=>[u,-1,-v]},
  {target:gl.TEXTURE_CUBE_MAP_POSITIVE_Z,dir:(u,v)=>[u,-v,1]},
  {target:gl.TEXTURE_CUBE_MAP_NEGATIVE_Z,dir:(u,v)=>[-u,-v,-1]}
 ];
 const normalize=v=>{const n=Math.hypot(...v)||1;return v.map(x=>x/n)};
 const softbox=(d,c,power,spread)=>Math.pow(Math.max(0,d[0]*c[0]+d[1]*c[1]+d[2]*c[2]),spread)*power;
 for(const face of faces){
  const pixels=new Uint8Array(size*size*4);
  for(let y=0;y<size;y++)for(let x=0;x<size;x++){
   const u=(x/(size-1))*2-1,v=(y/(size-1))*2-1,d=normalize(face.dir(u,v));
   const sky=Math.max(d[1],0),ground=Math.max(-d[1],0);
   let r=.055+sky*.22+ground*.055,g=.075+sky*.27+ground*.06,b=.105+sky*.34+ground*.075;
   const key=softbox(d,normalize([-.45,.88,.35]),2.8,34);
   const fill=softbox(d,normalize([.82,.5,-.3]),1.9,25);
   const rim=softbox(d,normalize([.05,.96,-.92]),2.2,38);
   const horizon=softbox(d,normalize([0,.08,1]),.42,10);
   r+=key+fill*.82+rim*.72+horizon*.2;
   g+=key*.97+fill*.9+rim*.92+horizon*.25;
   b+=key*.9+fill+rim+horizon*.32;
   const i=(y*size+x)*4;
   pixels[i]=Math.round(Math.min(1,r)*255);pixels[i+1]=Math.round(Math.min(1,g)*255);
   pixels[i+2]=Math.round(Math.min(1,b)*255);pixels[i+3]=255;
  }
  gl.texImage2D(face.target,0,gl.RGBA,size,size,0,gl.RGBA,gl.UNSIGNED_BYTE,pixels);
 }
 gl.texParameteri(gl.TEXTURE_CUBE_MAP,gl.TEXTURE_MIN_FILTER,gl.LINEAR);
 gl.texParameteri(gl.TEXTURE_CUBE_MAP,gl.TEXTURE_MAG_FILTER,gl.LINEAR);
 gl.texParameteri(gl.TEXTURE_CUBE_MAP,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);
 gl.texParameteri(gl.TEXTURE_CUBE_MAP,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
 gl.bindTexture(gl.TEXTURE_CUBE_MAP,null);
 return texture;
}
export const VEHICLE_MATERIALS={
 body:{metallic:.72,roughness:.22,clearcoat:1,kind:1},
 glass:{metallic:.08,roughness:.1,clearcoat:.82,kind:2},
 trim:{metallic:.68,roughness:.3,clearcoat:.22,kind:3},
 rubber:{metallic:0,roughness:.86,clearcoat:0,kind:4},
 rims:{metallic:.94,roughness:.2,clearcoat:.35,kind:5},
 brakes:{metallic:.82,roughness:.34,clearcoat:.08,kind:9},
 interior:{metallic:.04,roughness:.76,clearcoat:.02,kind:10},
 lights:{metallic:.18,roughness:.13,clearcoat:.55,kind:6},
 aero:{metallic:.58,roughness:.34,clearcoat:.18,kind:7},
 decals:{metallic:.28,roughness:.27,clearcoat:.72,kind:8}
};
