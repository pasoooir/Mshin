// Natural curved terrain and CC0-textured boulder clusters for the racing circuit.
export function* appendNaturalTracksideTerrain({snapshot,half,mobile,softwareRenderer,landscape,terrainRocks,quad,sphere,clamp}){
  // Curved near-field terrain replaces the abrupt flat horizon around the circuit.
  const terrainRows=mobile?120:softwareRenderer?180:360,terrainBands=mobile?9:softwareRenderer?12:18;
  const terrainStart=half+820,terrainReach=mobile?3600:softwareRenderer?4600:7200;
  const terrainHeight=(angle,offset,side)=>{
   const fade=clamp((offset-terrainStart)/1700,0,1);
   return fade*(Math.sin(angle*4+offset*.00072+side*.8)*34+Math.cos(angle*9-offset*.00115+side*1.7)*17+Math.sin(angle*2+offset*.0021)*22);
  };
  for(let row=0;row<terrainRows;row++){
   const t0=row/terrainRows*Math.PI*2,t1=(row+1)/terrainRows*Math.PI*2,f0=snapshot.frameAt(t0),f1=snapshot.frameAt(t1);
   for(const side of [-1,1])for(let band=0;band<terrainBands;band++){
    const u0=Math.pow(band/terrainBands,1.18),u1=Math.pow((band+1)/terrainBands,1.18),o0=terrainStart+u0*terrainReach,o1=terrainStart+u1*terrainReach;
    const point=(frame,angle,offset)=>[frame.p.x+frame.nx*side*offset,(frame.height||0)+terrainHeight(angle,offset,side),-(frame.p.y+frame.ny*side*offset)];
    quad(landscape,point(f0,t0,o0),point(f0,t0,o1),point(f1,t1,o1),point(f1,t1,o0));
   }
   if(row%6===5)yield {progress:.451+.004*(row/terrainRows)};
  }
  // Scattered boulder clusters add natural scale and break up the grass horizon.
  const rockCount=mobile?18:softwareRenderer?26:54;
  for(let i=0;i<rockCount;i++){
   const t=(i+.37)/rockCount*Math.PI*2,side=i%2?1:-1,offset=1500+(i%7)*620,f=snapshot.frameAt(t);
   const x=f.p.x+f.nx*side*offset,z=-(f.p.y+f.ny*side*offset),base=(f.height||0)+terrainHeight(t,offset,side),cluster=[];
   sphere(cluster,x,base+13,z,34+(i%4)*12,18+(i%3)*7,28+(i%5)*8,8,5);
   if(i%3===0)sphere(cluster,x+28,base+9,z-22,21,13,18,7,4);
   terrainRocks.push(...cluster);
   if(i%6===5)yield {progress:.456+.003*(i/rockCount)};
  }
}
