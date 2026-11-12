# Residential Upgrade Audit — 2026-11-12

## Reference behaviour

- EA beginner guide: tap the hard-hat icon to inspect the building plan, collect the listed materials, then drag the materials onto the building; the plan exposes required items and upgrade rewards. EA also describes the yellow hard-hat indicator for a home ready to upgrade.
  - https://help.ea.com/en/articles/simcity/simcity-buildit/beginner-guide/
- SimCity BuildIt Fandom residential-building guide: the plan shows required items and rewards; plans can be refreshed or the hard hat transferred to another building, with a 30-minute change period; after materials are delivered, scaffolding appears for a few seconds; population does not decrease and new residents are added immediately after completion.
  - https://simcity-buildit.fandom.com/wiki/Residential_Buildings
- Game Developer analysis, “Progression Control in Sim City BuildIt” (17 April 2015): residential requirements are generated across slots; slot count, material type, and quantity vary. It reports up to six requirement slots by level 15 and describes increasingly complex unlocked product pools.
  - https://www.gamedeveloper.com/design/progression-control-in-sim-city-buildit

## Implemented in this branch

- Residential upgrade now consumes the listed materials when accepted and enters a short scaffold phase instead of increasing the level instantly.
- The scaffold phase lasts 4 seconds in Mshin. This is a project timing choice; the Fandom reference only says “a few seconds.”
- Population remains unchanged during the scaffold phase. At completion, population is increased (never reduced), XP and Simoleons are awarded, and the upgraded building visual is rebuilt.
- The upgrade finish timestamp and in-progress state are saved and restored. If the timer elapsed while the game was closed, completion is deferred until after the saved resident count is restored.
- The selected home shows a blue hard-hat marker; closing the plan panel hides it.
- The panel displays required materials, current stock/shortage, rewards, and the current upgrade state.

## Important unresolved differences

- The current six-stage material table, population tiers, XP formula, and Simoleon reward formula are **Mshin fallback values**, not verified SCBI data. The UI now labels the material plan and reward values as unverified. Only the starter Nails + Metal pattern follows the user-provided example; exact quantities, later-stage plans, population progression, and reward ranges still need authoritative in-game captures or a complete reference dataset.
- The 30-minute refresh-plan and hard-hat-transfer actions are not implemented yet. The plan generator/verified alternate-plan pool must exist before refresh can change material requirements without inventing data.
- The blue marker is a deliberate Mshin UI choice; EA's beginner guide describes a yellow ready-to-upgrade hard hat.
