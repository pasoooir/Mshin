from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
errors = []

for path in root.rglob("*.gd"):
    content = path.read_text(encoding="utf-8")
    if content.rstrip().endswith(("extends Node3D", "extends Node", "mat = mate")):
        errors.append(f"Likely truncated script: {path.relative_to(root)}")
    for resource in re.findall(r'"res://([^"\\s]+)"', content):
        if not (root / resource).exists():
            errors.append(f"Missing script resource {resource} in {path.relative_to(root)}")

for path in root.rglob("*.tscn"):
    content = path.read_text(encoding="utf-8")
    for resource in re.findall(r'path="res://([^"]+)"', content):
        if not (root / resource).exists():
            errors.append(f"Missing scene resource {resource} in {path.relative_to(root)}")

project = (root / "project.godot").read_text(encoding="utf-8")
for script in re.findall(r'="\\*res://([^"]+)"', project):
    if not (root / script).exists():
        errors.append(f"Missing autoload {script}")

build_manager = (root / "scripts/autoload/BuildManager.gd").read_text(encoding="utf-8")
hud = (root / "scripts/ui/HUD.gd").read_text(encoding="utf-8")
keys = set(re.findall(r'^\\s*"([a-z0-9_]+)"\\s*:\\s*\\{"name"', build_manager, re.M))
for selected in re.findall(r'BuildManager\\.select_building\\("([a-z0-9_]+)"\\)', hud):
    if selected not in keys:
        errors.append(f"HUD references undefined building type: {selected}")
if "commercial_1" in hud:
    errors.append("Obsolete undefined commercial_1 reference remains in HUD")

production = (root / "scripts/autoload/ProductionManager.gd").read_text(encoding="utf-8")
storage = (root / "scripts/autoload/StorageManager.gd").read_text(encoding="utf-8")
for item in re.findall(r'"item"\\s*:\\s*"([a-z0-9_]+)"', production):
    if f'"{item}"' not in storage:
        errors.append(f"Upgrade material missing from storage definitions: {item}")

if errors:
    print("VALIDATION FAILED")
    print("\\n".join(errors))
    sys.exit(1)
print("Static project validation passed.")
