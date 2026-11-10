# Responsive UI & UX Standard — Pasoo City BuildIt

## Purpose
This document defines the acceptance standard for the game's adaptive HUD and build menus. The game must adapt to available viewport space and input method; it must not simply scale one fixed mobile layout across every device.

## Layout profiles

| Profile | Detection | Navigation | Build catalog | Input |
|---|---|---|---|---|
| Compact landscape | viewport width < 900 logical px | Right-side rail, vertically scrollable | Bottom horizontal carousel | Touch-first |
| Tablet | 900–1439 logical px | Wider right-side rail | Bottom carousel with larger cards | Touch and stylus |
| Desktop | viewport width >= 1440 logical px | Persistent left rail | Center-bottom catalog; desktop pointer/keyboard support | Mouse and keyboard |

The profile is based on the live viewport, not device model or user-agent. Re-evaluate layout when the viewport changes.

## Minimum visual targets

### Navigation categories
- Category icon: 48 logical px or larger on mobile/tablet; 52 logical px or larger on desktop.
- Category button height: 64 logical px minimum before profile scaling.
- Category label: 14 logical px minimum; full category name must remain visible.
- Active, hover, pressed, disabled and locked states must be visually distinct.
- The build menu is visible and discoverable on first entry; the close control remains visible while open.

### Building catalog cards
- Card baseline: 196 × 148 logical px.
- Submenu choices are icon-first: preserve the original transparent PNG artwork without tint, colored backing, or text labels beneath it.
- Hover/press feedback scales only the artwork by approximately 10–15%; it must not move neighbouring choices or paint a background tile.
- A choice locked by player level shows a compact, readable `LV n` badge beside the artwork; its tooltip/status explains that it unlocks at that level. Unlocked choices do not show a level badge.
- Horizontal submenu catalogs support comfortable left/right touch swipes. Hide the scrollbar chrome without disabling scrolling, and keep card widths stable rather than compressing icons.

### HUD and action controls
- Resource values must remain legible and must not overlap the city or each other.
- Interactive controls should target at least 48 × 48 logical px.
- Keep safe margins from viewport edges and mobile system insets.
- Tooltips are supplementary: essential actions must also have visible labels.
- Do not use color as the sole indicator of state.

## Accessibility and visual quality
- Use WCAG 2.2 AA contrast targets as the design baseline: 4.5:1 for normal text and 3:1 for large text and meaningful UI boundaries where applicable.
- Use readable text sizes, adequate spacing, clear focus/selection states and descriptive labels.
- Avoid clipped text, overlapping controls, inaccessible scroll areas and touch targets hidden behind other controls.
- Respect reduced motion preferences where platform integration supports them.

## Input behavior
- Touch: tap to select, drag in the world to place/pan, pinch to zoom, two-finger gesture to orbit. UI controls must consume their own pointer events and must not leak into camera gestures.
- Mouse: click to select, wheel to zoom, drag to pan/orbit according to the active camera mode, hover to reveal supplementary tooltips.
- Keyboard: Escape closes the current panel or cancels the active tool; X cancels the current placement/tool; focus must remain visible and navigable.

## Acceptance matrix
Test at minimum:
- 854×480 and 960×540 compact landscape
- 1024×768 and 1280×800 tablet-like viewports
- 1366×768, 1536×864 and 1920×1080 desktop viewports
- portrait resize and return to landscape
- live resize while a category submenu is open
- long category names, long building names and locked items
- touch interaction over the HUD while camera gestures are active
- all seven main build categories and all nested service/specialization groups

## Release gate
A responsive UI release is accepted only when:
1. no labels or icons are clipped at the listed viewports;
2. build categories are visible and discoverable on first entry;
3. cards retain the required hierarchy and readable type sizes;
4. menu interaction does not trigger world placement or camera movement;
5. every action has a working behavior or an explicit unavailable/locked explanation;
6. Godot headless validation and browser/mobile smoke tests pass.
