#!/usr/bin/env python3
"""Mirror ambientCG CC0 PBR texture sets into Mshin; runtime stays self-hosted."""
import io, json, re, urllib.parse, urllib.request, zipfile
from pathlib import Path

ROOT = Path("assets/city/textures/cc0")
ASSETS = {"asphalt":"Asphalt025C","concrete":"Concrete031","grass":"Grass004","sidewalk":"PavingStones128","brick":"Bricks090"}

def get_json(url):
    req=urllib.request.Request(url,headers={"User-Agent":"Mshin-City-Texture-Mirror/1.0","Accept":"application/json"})
    with urllib.request.urlopen(req,timeout=45) as r: return json.load(r)

def main():
    ROOT.mkdir(parents=True,exist_ok=True)
    manifest={"schemaVersion":1,"source":"ambientCG","license":"CC0-1.0","licenseUrl":"https://ambientcg.com/license","resolution":"1K-JPG","runtimePolicy":"self-hosted","materials":{}}
    for surface,asset_id in ASSETS.items():
        query=urllib.parse.urlencode({"type":"material","q":asset_id,"limit":20,"include":"title,downloads"})
        assets=get_json("https://ambientcg.com/api/v3/assets?"+query).get("assets",[])
        found=next((a for a in assets if a.get("id","").lower()==asset_id.lower()),None)
        if not found: raise RuntimeError("ambientCG asset missing: "+asset_id)
        package=next((p for p in found.get("downloads",[]) if p.get("attributes")=="1K-JPG" and p.get("extension")=="zip"),None)
        if not package: raise RuntimeError("1K-JPG package missing: "+asset_id)
        req=urllib.request.Request(package["url"],headers={"User-Agent":"Mshin-City-Texture-Mirror/1.0"})
        with urllib.request.urlopen(req,timeout=90) as r: archive=zipfile.ZipFile(io.BytesIO(r.read()))
        folder=ROOT/surface; folder.mkdir(parents=True,exist_ok=True); maps={}
        names={"Color":"albedo.jpg","NormalGL":"normal.jpg","Roughness":"roughness.jpg"}
        for member in archive.namelist():
            filename=Path(member).name
            match=re.search(r"_(Color|NormalGL|Roughness)\\.jpg$",filename,re.I)
            if match:
                key=next(k for k in names if k.lower()==match.group(1).lower())
                output=names[key]; (folder/output).write_bytes(archive.read(member)); maps[output]=surface+"/"+output
        if len(maps)!=3: raise RuntimeError(f"Incomplete maps for {asset_id}: {maps}")
        manifest["materials"][surface]={"assetId":asset_id,"title":found.get("title",asset_id),"sourceUrl":"https://ambientcg.com/view?id="+asset_id,"license":"CC0-1.0","maps":maps}
        print("Mirrored",surface,asset_id)
    (ROOT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\\n",encoding="utf-8")

if __name__=="__main__": main()
