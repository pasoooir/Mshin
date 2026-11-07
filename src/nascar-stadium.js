// Incremental procedural geometry for the oval racing stadium.
export function* buildNascarStadium({snapshot,mobile,softwareRenderer,quad,box,sphere,crowdBodies,crowdHeads,crowdArms,crowdLegs,stadiumDecks,stadiumRisers,stadiumSupports,stadiumCanopies,state}){
  const standSections=mobile?16:softwareRenderer?22:40;
  const standRows=mobile?4:5;
  let stadiumSpectators=0;
  for(let section=0;section<standSections;section++){
   const t0=section/standSections*Math.PI*2,t1=(section+1)/standSections*Math.PI*2;
   const f0=snapshot.frameAt(t0),f1=snapshot.frameAt(t1);
   for(const side of [-1,1]){
    const surfacePoint=(frame,along,outward,y)=>[
     frame.p.x+frame.nx*side*outward+frame.ny*along,
     (frame.height||0)+y,
     -(frame.p.y+frame.ny*side*outward+frame.nx*along)
    ];
    for(let row=0;row<standRows;row++){
     const inner=260+row*42,outer=inner+42,seatY=24+row*27;
     const a=surfacePoint(f0,-390,inner,seatY),b=surfacePoint(f0,390,inner,seatY);
     const c=surfacePoint(f1,390,inner,seatY),d=surfacePoint(f1,-390,inner,seatY);
     const e=surfacePoint(f0,-390,outer,seatY+7),g=surfacePoint(f0,390,outer,seatY+7);
     const h=surfacePoint(f1,390,outer,seatY+7),j=surfacePoint(f1,-390,outer,seatY+7);
     quad(stadiumDecks,a,b,g,e);quad(stadiumDecks,d,c,h,j);
     quad(stadiumRisers,a,e,j,d);
     // Repeated seat rows and aisle edges remain visible from the chase camera.
     const stripeA=surfacePoint(f0,-390,inner+8,seatY+9),stripeB=surfacePoint(f0,390,inner+8,seatY+9);
     const stripeC=surfacePoint(f1,390,inner+8,seatY+9),stripeD=surfacePoint(f1,-390,inner+8,seatY+9);
     quad(stadiumRisers,stripeA,stripeB,stripeC,stripeD);
     if(section%3===0&&row===0){
      for(const along of [-330,0,330]){
       const p=surfacePoint(f0,along,outer,0);
       box(stadiumSupports,p[0],(f0.height||0)+seatY*.5+20,p[2],12,seatY+40,12);
      }
     }
     const peoplePerRow=mobile?1:softwareRenderer?1:2;
     for(let person=0;person<peoplePerRow;person++){
      const along=(person-(peoplePerRow-1)/2)*250;
      const p=surfacePoint(f0,along,inner+18,seatY+15),x=p[0],y=p[1],z=p[2];
      box(crowdBodies,x,y+13,z,9,17,7);
      sphere(crowdHeads,x,y+27,z,5,5.5,5,6,3);
      box(crowdArms,x-8,y+18,z,3,14,3);
      box(crowdArms,x+8,y+18,z,3,14,3);
      box(crowdLegs,x-3,y+3,z,3,8,4);
      box(crowdLegs,x+3,y+3,z,3,8,4);
      stadiumSpectators++;
     }
    }
    // High continuous canopy on every second section, with a bright fascia.
    if(section%2===0){
     const roofInner=430,roofOuter=610,roofY=24+standRows*27+115;
     const a=surfacePoint(f0,-390,roofInner,roofY),b=surfacePoint(f0,390,roofInner,roofY);
     const c=surfacePoint(f1,390,roofInner,roofY),d=surfacePoint(f1,-390,roofInner,roofY);
     const e=surfacePoint(f0,-390,roofOuter,roofY+18),g=surfacePoint(f0,390,roofOuter,roofY+18);
     const h=surfacePoint(f1,390,roofOuter,roofY+18),j=surfacePoint(f1,-390,roofOuter,roofY+18);
     quad(stadiumCanopies,a,b,g,e);quad(stadiumCanopies,d,c,h,j);
     quad(stadiumCanopies,e,g,h,j);
    }
   }
   if(section%4===3)yield section;
  }
  state.environmentCounts.spectators+=stadiumSpectators;
  state.environmentCounts.grandstandSections=standSections*2;
  state.environmentCounts.grandstandRows=standRows;
  return {spectators:stadiumSpectators,sections:standSections*2,rows:standRows};
}
