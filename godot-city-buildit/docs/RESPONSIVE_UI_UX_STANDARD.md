# Responsive UI & UX Standard — Pasoo City BuildIt

## Goal and platform contract

Every player-facing screen must remain readable, complete and operable on desktop, tablet and mobile. The layout must respond to the live logical viewport and available height; it must not shrink one desktop layout until its labels become illegible. Gameplay remains landscape-first on phones. Portrait is supported for modal/overlay resizing and must not crop content.

This project uses native Godot 4.3 Control, Container, Theme, ScrollContainer and viewport layout APIs. CSS is not used by the Godot runtime.

## Viewport profiles

| Profile | Logical viewport width | Layout |
|---|---:|---|
| Compact / mobile | < 900 px | Touch-first; reflow grids; full-width modal cards; vertical content scrolling |
| Tablet | 900–1439 px | Balanced card grids; larger controls; touch/stylus support |
| Desktop | ≥ 1440 px | Wider catalog grids; pointer/keyboard support; content max-width |

Profile selection is based on the live viewport, not device name or user-agent. Re-evaluate geometry and grid columns after every viewport resize. The UI scale may range from 0.72 to 1.20; readable text and touch targets have independent minimums and must not be reduced solely by scale.

## Global typography and content rules

- Normal labels: minimum 12 logical px in compact/overlay content; buttons: minimum 13 logical px.
- Main section headings should be 18–24 px; modal titles should remain visually distinct from supporting labels.
- Never clip essential names, quantities, recipe inputs, status explanations, timers or action labels. Labels must wrap where space is constrained.
- Keep numerals, quantities, units and state text together where possible. Long supply-chain, provenance and requirement text must have a scroll or wrap path.
- Text must meet WCAG 2.2 AA contrast targets: 4.5:1 for normal text and 3:1 for large text and meaningful boundaries.
- Icon meaning must not rely on color alone; locked, ready, producing, shortage and disabled states need text/status cues.

## Geometry, spacing and touch

- Interactive targets: at least 48 × 44 logical px; primary touch actions should target 48 × 48 px or larger.
- Use scaled but bounded panel padding and consistent container separation. Do not use fixed offsets that place content outside the visible safe area.
- Dialogs must stay inside the viewport with visible close controls and no inaccessible edge controls.
- Prefer Godot containers, anchors and size flags over manually positioned child controls.
- Use ScrollContainer for content that can exceed available height. Do not hide overflow or disable scrolling when content exceeds the viewport.
- Preserve stable icon/card aspect ratios. Reflow columns before shrinking product names or icons.
- Respect mobile system insets and safe margins when the platform exposes them.

## Screen inventory and required responsive behavior

### HUD and navigation
- Resource HUD, level/XP, happiness, currency, right-side category rail, bottom actions, context header and status text.
- Category rail remains discoverable, scrollable and within safe margins. Category buttons retain at least 64 px height and icons at least 48 px.
- Catalog submenu remains a horizontal swipe carousel with stable card widths; scroll chrome may be hidden but scrolling must remain enabled.
- Category/building names, lock badges, counts and the building detail panel must wrap and remain readable at all profiles.
- Building detail information (area, boost, price, level requirement, construction time and BUILD/LOCKED action) must not be squeezed into a narrow fixed-width strip.

### Factory and commercial production
- Building header, store-star status/upgrade, instructions, product catalog, product cards, lock/stock state, product detail, recipe inputs, supply-chain explanation, start action, queue heading, slot count, queue purchase, every queue card, timer, progress bar, collect action and Storage Full state.
- Product catalog: 3 columns compact, 4 tablet, 6 desktop; vertical scrolling is enabled so no product becomes unreachable.
- Queue: horizontal scrolling with stable card widths; timer/progress/collect state remains readable.
- Product details and recipe/supply-chain text wrap; START remains a distinct, usable action.
- Collection blocked by full storage must remain explicit and must not hide the ready item.

### City Needs dashboard
- Summary, economy metrics, inventory cards, shortages, stored/required/producing/ready/deficit counts, supplier status/actions, active orders/timers, home plans and each home's individual requirements.
- Resource metrics: 2 columns compact and 4 tablet/desktop.
- Inventory: 3 columns compact, 4 tablet and 5 desktop.
- Dashboard content scrolls vertically; long names, supplier labels and status text wrap.

### Residential upgrade
- Home name/level, reward/population, plan note, construction/scaffold status, every required material, owned/required quantities, supplier, shortage explanation, progress and upgrade action.
- Entire content is inside a vertical scroll region. The upgrade action remains reachable and is not clipped below the viewport.

### City Storage
- Header, close action, used/capacity progress, every stored item icon/name/count, empty state and capacity action.
- Inventory uses two columns where width permits and one column below 520 logical px. The inventory region scrolls vertically.
- Item names and counts remain distinct; icon size must not force text outside its cell.

### Other overlays and states
- Catalog info, contextual building actions, tooltips, confirmation/status panels, locked/unavailable explanations, construction/upgrade feedback, dialogs and empty/loading/error states.
- Each newly added player-facing panel must be added to the responsive screen inventory and tested at the same viewport matrix.

## Acceptance matrix

Automated GameplaySmoke exercises compact, tablet and desktop breakpoints by passing representative logical sizes into the responsive layout functions, then checks grid reflow, modal dimensions, text floors and touch-target floors. The project viewport in headless mode is not a reliable physical-window emulator; it does not claim to replace actual display testing.

Manual visual acceptance is required at minimum:
- Compact landscape phone: 854×480 and 960×540
- Tablet: 1024×768 and 1280×800
- Desktop: 1366×768, 1536×864 and 1920×1080
- Mobile portrait resize and return to landscape (modal/overlay behavior)
- Resize while build submenu, production, City Needs, residential upgrade and storage are open
- Long product/building names, multi-input recipes, long supplier names, locked/disabled states, full-storage collection and maximum queue length
- Touch interaction over every overlay while camera gestures are active; keyboard focus and Escape close behavior

## Release gate

A responsive UI change is accepted only when:
1. All panels and nested content stay inside the viewport and all essential text/icons are visible.
2. No horizontal overflow exists except intentional horizontal catalog/queue scrolling.
3. Vertical overflow is scrollable and the last action remains reachable.
4. Font size, spacing, padding, alignment and touch targets meet the rules above.
5. Mobile, tablet and desktop profile/reflow tests pass.
6. Godot headless validation and relevant browser/mobile smoke checks pass.
7. Actual Android-device and tablet visual acceptance is recorded separately; headless tests alone do not prove physical-device readability.
