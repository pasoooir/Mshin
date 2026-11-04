import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),"..");
test("neighborhood roads interrupt curbs at intersections and add accessible ramps",async()=>{
 const html=await readFile(path.join(root,"city-neighborhood-preview.html"),"utf8");
 assert.match(html,/function curbRunX\(/);assert.match(html,/function curbRunZ\(/);
 assert.match(html,/function addCurbRamp\(/);assert.match(html,/city-curb-ramp/);
 assert.match(html,/city-tactile-paving/);
 assert.match(html,/ramp\.rotation\.x=-sign\*\.11/);
 assert.match(html,/ramp\.rotation\.z=sign\*\.11/);
 assert.match(html,/live pedestrian priority and routing remain governed by the city pedestrian graph/);
});
test("four preview junctions have zebra crossings in both road directions",async()=>{
 const html=await readFile(path.join(root,"city-neighborhood-preview.html"),"utf8");
 assert.match(html,/function addCrosswalkStripe\(/);
 assert.match(html,/addCrosswalkStripe\(x\+i\*1\.15,z-4\.4,"horizontal"\)/);
 assert.match(html,/addCrosswalkStripe\(x-4\.4,z\+i\*1\.15,"vertical"\)/);
 assert.match(html,/addCrosswalkStripe\(x\+4\.4,z\+i\*1\.15,"vertical"\)/);
});
