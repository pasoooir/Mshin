# Vendored runtime assets — Mshin 0.9.3

All 23 browser runtime assets are committed under `cdn/assets/`. Runtime references are same-origin relative paths; the service worker no longer proxies or caches third-party hosts.

| Asset | Repository file | Original source URL | Declared license |
|---|---|---|---|
| scene-01 | ./cdn/assets/scenes/scene-01.jpg | https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1600&q=76 | Upstream terms require verification before redistribution |
| scene-02 | ./cdn/assets/scenes/scene-02.jpg | https://images.unsplash.com/photo-1509316785289-025f5b846b35?auto=format&fit=crop&w=1600&q=76 | Upstream terms require verification before redistribution |
| scene-03 | ./cdn/assets/scenes/scene-03.jpg | https://images.unsplash.com/photo-1418985991508-e47386d96a71?auto=format&fit=crop&w=1600&q=76 | Upstream terms require verification before redistribution |
| scene-04 | ./cdn/assets/scenes/scene-04.jpg | https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&w=1600&q=76 | Upstream terms require verification before redistribution |
| scene-05 | ./cdn/assets/scenes/scene-05.jpg | https://images.unsplash.com/photo-1519501025264-65ba15a82390?auto=format&fit=crop&w=1600&q=76 | Upstream terms require verification before redistribution |
| scene-06 | ./cdn/assets/scenes/scene-06.jpg | https://images.unsplash.com/photo-1518005020951-eccb494ad742?auto=format&fit=crop&w=1600&q=76 | Upstream terms require verification before redistribution |
| scene-07 | ./cdn/assets/scenes/scene-07.jpg | https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1600&q=76 | Upstream terms require verification before redistribution |
| scene-08 | ./cdn/assets/scenes/scene-08.jpg | https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1600&q=76 | Upstream terms require verification before redistribution |
| scene-09 | ./cdn/assets/scenes/scene-09.jpg | https://images.unsplash.com/photo-1462331940025-496dfbfc7564?auto=format&fit=crop&w=1600&q=76 | Upstream terms require verification before redistribution |
| scene-10 | ./cdn/assets/scenes/scene-10.jpg | https://images.unsplash.com/photo-1506157786151-b8491531f063?auto=format&fit=crop&w=1600&q=76 | Upstream terms require verification before redistribution |
| accelerate | ./cdn/assets/icons/accelerate.svg | https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6.7.2/svgs/solid/arrow-up.svg | Upstream terms require verification before redistribution |
| brake | ./cdn/assets/icons/brake.svg | https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6.7.2/svgs/solid/hand.svg | Upstream terms require verification before redistribution |
| nitro | ./cdn/assets/icons/nitro.svg | https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6.7.2/svgs/solid/bolt.svg | Upstream terms require verification before redistribution |
| engine0 | ./cdn/assets/audio/engine0.wav | https://cdn.jsdelivr.net/gh/yashimosh/border-run@38d6afa442a06bbd414f21ac05c0f1b4d08bd705/public/sfx/engine/loop_0.wav | CC0 |
| engine1 | ./cdn/assets/audio/engine1.wav | https://cdn.jsdelivr.net/gh/yashimosh/border-run@38d6afa442a06bbd414f21ac05c0f1b4d08bd705/public/sfx/engine/loop_1_0.wav | CC0 |
| engine2 | ./cdn/assets/audio/engine2.wav | https://cdn.jsdelivr.net/gh/yashimosh/border-run@38d6afa442a06bbd414f21ac05c0f1b4d08bd705/public/sfx/engine/loop_2_0.wav | CC0 |
| engine3 | ./cdn/assets/audio/engine3.wav | https://cdn.jsdelivr.net/gh/yashimosh/border-run@38d6afa442a06bbd414f21ac05c0f1b4d08bd705/public/sfx/engine/loop_3_0.wav | CC0 |
| engine4 | ./cdn/assets/audio/engine4.wav | https://cdn.jsdelivr.net/gh/yashimosh/border-run@38d6afa442a06bbd414f21ac05c0f1b4d08bd705/public/sfx/engine/loop_4_0.wav | CC0 |
| engine5 | ./cdn/assets/audio/engine5.wav | https://cdn.jsdelivr.net/gh/yashimosh/border-run@38d6afa442a06bbd414f21ac05c0f1b4d08bd705/public/sfx/engine/loop_5_0.wav | CC0 |
| brakeSqueal | ./cdn/assets/audio/brakeSqueal.mp3 | https://sfxmint.com/dl/race-car-07.mp3 | Upstream terms require verification before redistribution |
| gearDown | ./cdn/assets/audio/gearDown.mp3 | https://sfxmint.com/dl/race-car-10.mp3 | Upstream terms require verification before redistribution |
| musicMenu | ./cdn/assets/audio/musicMenu.ogg | https://cdn.jsdelivr.net/gh/JerryMerweather/Checkpoint-Chaser@e280012e423cf2c800bd54e4fe361edaa9cae167/darkness_road_remake_bpm165.ogg | CC0-1.0 |
| musicRace | ./cdn/assets/audio/musicRace.ogg | https://cdn.jsdelivr.net/gh/JerryMerweather/Checkpoint-Chaser@e280012e423cf2c800bd54e4fe361edaa9cae167/pure_raceway_bpm160.ogg | CC0-1.0 |

## License and attribution notes

- Six engine-loop files are declared CC0 in the original asset manifest.
- Menu and race music are declared CC0-1.0; original OpenGameArt source pages are preserved in the manifest.
- The braking/downshift SFX and photographic scene images have no explicit license field in the original manifest. Their source URLs are retained above, but redistribution rights must be checked against upstream terms before treating this release as legally cleared.
- The three Font Awesome SVG controls are bundled from Font Awesome Free 6.7.2; retain its applicable CC BY 4.0 attribution/license notice.
- Local storage does not itself grant redistribution rights.

## Offline behavior

The service worker precaches every local image, icon and audio path. No runtime asset request should contact jsDelivr, Unsplash, SFXMint, OpenGameArt, or another third-party CDN. Browser navigation still requires the initial GitHub Pages connection; after the app shell is installed/cached, gameplay assets are local.
