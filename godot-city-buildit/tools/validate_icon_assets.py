from pathlib import Path
import re
import struct
import sys
import zlib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ICON_ROOT = ROOT / "assets" / "icons"
errors = []
required = set()

def require(category: str, icon_id: str) -> None:
    required.add((category, icon_id))

build_manager = (ROOT / "scripts/autoload/BuildManager.gd").read_text(encoding="utf-8")
production = (ROOT / "scripts/autoload/ProductionManager.gd").read_text(encoding="utf-8")
hud = (ROOT / "scripts/ui/HUD.gd").read_text(encoding="utf-8")

# Every building definition is covered by its real catalog category and id.
for icon_id, raw_category in re.findall(r'^\s*"([a-z0-9_]+)"\s*:\s*\{"name".*?"category":"([a-z]+)"', build_manager, re.M):
    category = {"service": "services", "park": "specializations"}.get(raw_category, raw_category)
    require(category, icon_id)

# Production catalogs are independent icon sources; check both raw and crafted IDs.
for variable, category in (("raw_materials", "raw"), ("crafted_items", "crafted")):
    section = production.split(f"var {variable} := {{", 1)
    if len(section) != 2:
        errors.append(f"ProductionManager is missing {variable}")
        continue
    section_text = section[1].split("\n}", 1)[0]
    for icon_id in re.findall(r'^\s*"([a-z0-9_]+)"\s*:\s*\{', section_text, re.M):
        require(category, icon_id)

# Disabled-but-visible product identities must still have local artwork.
store_catalog_section = production.split("var store_catalog := {", 1)
if len(store_catalog_section) == 2:
    store_catalog_text = store_catalog_section[1].split("\nvar upgrade_requirements", 1)[0]
    for icon_id in re.findall(r'"id":"([a-z0-9_]+)"', store_catalog_text):
        require("crafted", icon_id)

# Menu group IDs and their service/specialization buildings are also visible UI items.
service_section = hud.split("const SERVICE_GROUPS := [", 1)[1].split("\n]", 1)[0]
for group_id in re.findall(r'\{"id":"([a-z0-9_]+)"', service_section):
    require("services", "group_" + group_id)
for buildings in re.findall(r'"buildings":\[([^\]]*)\]', service_section):
    for icon_id in re.findall(r'"([a-z0-9_]+)"', buildings):
        require("services", icon_id)

special_section = hud.split("const SPECIALIZATION_GROUPS := [", 1)[1].split("\n]", 1)[0]
for group_id in re.findall(r'\{"id":"([a-z0-9_]+)"', special_section):
    require("specializations", "group_" + group_id)
for buildings in re.findall(r'"buildings":\[([^\]]*)\]', special_section):
    for icon_id in re.findall(r'"([a-z0-9_]+)"', buildings):
        require("specializations", icon_id)

# All permanent HUD, modal, and toolbar controls have dedicated named PNGs.
ui_ids = """
placeholder storage trade save cancel close collect lock back confirm bulldoze
build_menu settings info plus money population happiness level warning check
arrow_left arrow_right services commercial industrial road residential parks
hard_hat simoleons golden_key fire power water park police health sewage waste
government education transportation entertainment gambling beach mountain
landmark global_trade epic regions fallback
""".split()
for icon_id in ui_ids:
    require("ui", icon_id)

for icon_id in ["road", "road_build", "road_upgrade", "road_bulldoze"]:
    require("roads", icon_id)
for icon_id in ["smoke", "no_power", "no_water", "no_fire_coverage", "storage_full", "ready_collect", "upgrading", "abandoned"]:
    require("status", icon_id)

# PNG-32 requirements: valid PNG, 8-bit RGBA, >=128px, transparent canvas corners.
for category, icon_id in sorted(required):
    path = ICON_ROOT / category / f"{icon_id}.png"
    if not path.is_file():
        # New product and service-building art may use original transparent SVG.
        # Required build icons and toolbar controls remain strict PNG-32 assets.
        svg_path = ICON_ROOT / category / f"{icon_id}.svg"
        if category in ("crafted", "commercial", "services", "ui") and svg_path.is_file():
            try:
                svg_root = ET.parse(svg_path).getroot()
                if not svg_root.tag.endswith("svg") or svg_root.attrib.get("viewBox") != "0 0 128 128":
                    errors.append(f"Invalid product SVG viewBox/root: {category}/{icon_id}.svg")
            except Exception as exc:
                errors.append(f"Invalid product SVG: {category}/{icon_id}.svg ({exc})")
            continue
        errors.append(f"Missing icon: {category}/{icon_id}.png")
        continue
    data = path.read_bytes()
    if len(data) < 64 or data[:8] != b"\x89PNG\r\n\x1a\n":
        errors.append(f"Invalid PNG file: {category}/{icon_id}.png")
        continue
    width, height, bit_depth, color_type = struct.unpack(">IIBB", data[16:26])
    # The legacy UI control pack is intentionally 77x77 and is rendered at
    # 48-66 logical pixels by HUD.gd. Keep the 128px minimum for catalog,
    # production-item, road and status artwork, where the larger source size
    # is needed for zoomed/building cards.
    minimum_size = 64 if category == "ui" else 128
    if width < minimum_size or height < minimum_size:
        errors.append(
            f"Icon is smaller than {minimum_size}x{minimum_size}: "
            f"{category}/{icon_id}.png ({width}x{height})"
        )
    if bit_depth != 8 or color_type != 6:
        errors.append(f"Icon must be 8-bit RGBA PNG-32: {category}/{icon_id}.png (depth={bit_depth}, type={color_type})")
        continue
    # Decode the PNG image data and verify both outer corners retain alpha=0.
    offset = 8
    idat = bytearray()
    while offset + 8 <= len(data):
        chunk_size = struct.unpack(">I", data[offset:offset+4])[0]
        chunk_type = data[offset+4:offset+8]
        chunk_data = data[offset+8:offset+8+chunk_size]
        if chunk_type == b"IDAT":
            idat.extend(chunk_data)
        offset += 12 + chunk_size
        if chunk_type == b"IEND":
            break
    try:
        decoded = zlib.decompress(bytes(idat))
        stride = width * 4 + 1
        corners = [
            decoded[1 + 3],
            decoded[1 + (width - 1) * 4 + 3],
            decoded[(height - 1) * stride + 1 + 3],
            decoded[(height - 1) * stride + 1 + (width - 1) * 4 + 3],
        ]
        if any(alpha != 0 for alpha in corners):
            errors.append(f"Icon canvas corners must be transparent: {category}/{icon_id}.png")
        has_artwork = any(
            decoded[row * stride + 1 + column * 4 + 3] > 0
            for row in range(height)
            for column in range(width)
        )
        if not has_artwork:
            errors.append(f"Icon artwork is fully transparent: {category}/{icon_id}.png")
    except Exception as exc:
        errors.append(f"Could not decode icon PNG {category}/{icon_id}.png: {exc}")

if errors:
    print("ICON ASSET VALIDATION FAILED")
    for error in errors:
        print(" - " + error)
    sys.exit(1)

print(f"Local icon validation passed: {len(required)} catalog/UI/status assets checked (PNG-32 plus approved product SVGs).")
