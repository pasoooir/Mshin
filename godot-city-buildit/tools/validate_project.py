from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []

for path in ROOT.rglob("*.gd"):
    source = path.read_text(encoding="utf-8")
    if source.rstrip().endswith(("extends Node3D", "extends Node", "mat = mate")):
        errors.append(f"Likely truncated script: {path.relative_to(ROOT)}")
    for resource in re.findall(r'"res://([^"\\s]+)"', source):
        if not (ROOT / resource).is_file():
            errors.append(f"Missing script resource {resource} in {path.relative_to(ROOT)}")

for path in ROOT.rglob("*.tscn"):
    source = path.read_text(encoding="utf-8")
    for resource in re.findall(r'path="res://([^"]+)"', source):
        if not (ROOT / resource).is_file():
            errors.append(f"Missing scene resource {resource} in {path.relative_to(ROOT)}")

project = (ROOT / "project.godot").read_text(encoding="utf-8")
for script in re.findall(r'="\\*res://([^"]+)"', project):
    if not (ROOT / script).is_file():
        errors.append(f"Missing autoload {script}")

build_manager = (ROOT / "scripts/autoload/BuildManager.gd").read_text(encoding="utf-8")
hud = (ROOT / "scripts/ui/HUD.gd").read_text(encoding="utf-8")
building_ids = set(re.findall(r'^\\s*"([a-z0-9_]+)"\\s*:\\s*\\{"name"', build_manager, re.M))
for selected in re.findall(r'BuildManager\\.select_building\\("([a-z0-9_]+)"\\)', hud):
    if selected not in building_ids:
        errors.append(f"HUD references undefined building type: {selected}")
if "commercial_1" in hud:
    errors.append("Obsolete commercial_1 reference remains in HUD")

production = (ROOT / "scripts/autoload/ProductionManager.gd").read_text(encoding="utf-8")
storage = (ROOT / "scripts/autoload/StorageManager.gd").read_text(encoding="utf-8")
for item in re.findall(r'"item"\\s*:\\s*"([a-z0-9_]+)"', production):
    if f'"{item}"' not in storage:
        errors.append(f"Upgrade material missing from storage definitions: {item}")

if errors:
    print("VALIDATION FAILED")
    print("\\n".join(errors))
    sys.exit(1)

print("Static project validation passed.")
