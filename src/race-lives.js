export function createRaceLives(maximum=3){
 const total=Math.max(1,Math.floor(Number(maximum)||3));
 return {maximum:total,explosions:0,remaining:total,lost:false};
}
export function registerPlayerExplosion(lives){
 if(!lives||lives.lost)return {respawn:false,lost:true,remaining:0,explosions:lives?.explosions||0};
 lives.explosions=Math.min(lives.maximum,lives.explosions+1);
 lives.remaining=Math.max(0,lives.maximum-lives.explosions);
 lives.lost=lives.explosions>=lives.maximum;
 return {respawn:!lives.lost,lost:lives.lost,remaining:lives.remaining,explosions:lives.explosions};
}
