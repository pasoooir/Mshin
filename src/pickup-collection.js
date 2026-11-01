const pointSegmentDistanceSquared=(point,start,end)=>{const dx=end.x-start.x,dy=end.y-start.y,lengthSquared=dx*dx+dy*dy;if(lengthSquared<=1e-9){const px=point.x-start.x,py=point.y-start.y;return px*px+py*py}const projection=Math.max(0,Math.min(1,((point.x-start.x)*dx+(point.y-start.y)*dy)/lengthSquared));const nearestX=start.x+projection*dx,nearestY=start.y+projection*dy,px=point.x-nearestX,py=point.y-nearestY;return px*px+py*py};

/** Detect pickup contact along the vehicle centre path, not only at frame end. */
export function sweptPickupContact(previous,current,pickup,radius=66){
 if(!previous||!current||!pickup||![previous.x,previous.y,current.x,current.y,pickup.x,pickup.y,radius].every(Number.isFinite)||radius<0)return false;
 return pointSegmentDistanceSquared(pickup,previous,current)<=radius*radius;
}
