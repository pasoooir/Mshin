// Bounded synchronous pixel sampling for visual acceptance diagnostics.
// Read only a small center crop; never drain the full mobile drawing buffer.
export function sampleRaceFramePixels(gl,canvas,state){
 const fullWidth=canvas.width,fullHeight=canvas.height;
 const sampleWidth=Math.max(1,Math.min(256,fullWidth,fullHeight));
 const sampleHeight=sampleWidth;
 const sampleX=Math.max(0,Math.floor((fullWidth-sampleWidth)/2));
 const sampleY=Math.max(0,Math.floor((fullHeight-sampleHeight)/2));
 const samplePixels=new Uint8Array(sampleWidth*sampleHeight*4);
 const sampleStarted=performance.now();
 gl.readPixels(sampleX,sampleY,sampleWidth,sampleHeight,gl.RGBA,gl.UNSIGNED_BYTE,samplePixels);
 let visiblePixels=0,roadLikePixels=0;const sampledColors=new Set();
 for(let i=0;i<samplePixels.length;i+=4*4){
  const red=samplePixels[i],green=samplePixels[i+1],blue=samplePixels[i+2];
  if(red+green+blue>24)visiblePixels++;
  if(Math.max(red,green,blue)-Math.min(red,green,blue)<42&&red>24&&red<205&&green>24&&green<205&&blue>24&&blue<205)roadLikePixels++;
  sampledColors.add((red>>4)+":"+ (green>>4)+":"+ (blue>>4));
 }
 return {width:sampleWidth,height:sampleHeight,visiblePixels,roadLikePixels,uniqueColors:sampledColors.size,sourceWidth:fullWidth,sourceHeight:fullHeight,sampleX,sampleY,drawCalls:state.lastFrameDrawCalls,triangles:state.lastFrameTriangles,pixelBytes:samplePixels.byteLength,readbackMs:performance.now()-sampleStarted,context:true,glError:gl.getError()};
}
