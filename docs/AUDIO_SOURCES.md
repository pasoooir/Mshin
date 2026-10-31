# Mshin audio asset provenance

The 0.8.9 candidate uses two loopable instrumental racing tracks, five recorded vehicle/road layers and dedicated collision/brake/gear effects. Each OpenGameArt/SFXMint/BigSoundBank/Freesound source identifies the applicable CC0 license; the source pages are the authoritative license records.

| In-game use | Track | Author | License evidence | Format |
|---|---|---|---|---|
| Main menu / vehicle selection | Sky Blue Street | MintoDog | https://opengameart.org/content/sky-blue-street | OGG Vorbis |
| Race | Pure Raceway | MintoDog | https://opengameart.org/content/pure-raceway | OGG Vorbis |

The browser asset manifest points to immutable commit `e280012e423cf2c800bd54e4fe361edaa9cae167` of a public GitHub mirror so the runtime URLs do not float with a branch head. The source pages above—not the mirror repository—establish the CC0 license. The Service Worker caches these exact URLs opportunistically; the boot loader still blocks the game from entering its runtime when either required soundtrack asset cannot be fetched.

## Recorded vehicle audio layers

| In-game use | File | Original recording / source | License evidence |
|---|---|---|---|
| Engine idle | `engine-idle.wav` | RichieMcMullen, Freesound | https://freesound.org/people/RichieMcMullen/sounds/386793/ — CC0 1.0 |
| Engine under load | `engine-load.wav` | Joseph Sardin, BigSoundBank (processed excerpt of onboard Peugeot 107 recording) | https://bigsoundbank.com/car-on-a-road-s1286.html — CC0 1.0 |
| Tyre/road rolling texture | `road-roll.wav` | Joseph Sardin, BigSoundBank (processed excerpt of the same onboard recording) | https://bigsoundbank.com/car-on-a-road-s1286.html — CC0 1.0 |
| Engine start | `engine-start.wav` | prometheus888, Freesound | https://freesound.org/people/prometheus888/sounds/458461/ — CC0 1.0 |
| Engine stop | `engine-stop.wav` | Joseph Sardin, BigSoundBank | https://bigsoundbank.com/car-on-a-road-s1286.html — CC0 1.0 |

The audio engine blends idle, load and rolling recordings independently, with per-vehicle layer weights, filter resonance, RPM-dependent playback rates and throttle envelopes. The electric vehicle retains a separate synthesized motor profile. This replaces the previous six pitch-only loop layers.

## Other sound effects

| In-game use | File | Source | License evidence |
|---|---|---|---|
| Vehicle collision | `collisionImpact.ogg` | qubodup, “Crash Collision” | https://opengameart.org/content/crash-collision — CC0 1.0 |
| Tyre/brake squeal | `brakeSqueal` | SFXMint race-car-07 | https://sfxmint.com/license — CC0 1.0 |
| Gear change | `gearDown` | SFXMint race-car-10 | https://sfxmint.com/license — CC0 1.0 |
