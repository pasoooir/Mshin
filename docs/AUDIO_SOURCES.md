# Mshin audio asset provenance

The 0.8.9 candidate uses two loopable instrumental racing tracks. Each individual OpenGameArt submission identifies the license as **CC0 1.0**; those pages are the authoritative license records.

| In-game use | Track | Author | License evidence | Format |
|---|---|---|---|---|
| Main menu / vehicle selection | Sky Blue Street | MintoDog | https://opengameart.org/content/sky-blue-street | OGG Vorbis |
| Race | Pure Raceway | MintoDog | https://opengameart.org/content/pure-raceway | OGG Vorbis |

The browser asset manifest points to immutable commit `e280012e423cf2c800bd54e4fe361edaa9cae167` of a public GitHub mirror so the runtime URLs do not float with a branch head. The source pages above—not the mirror repository—establish the CC0 license. The Service Worker caches these exact URLs opportunistically; the boot loader still blocks the game from entering its runtime when either required soundtrack asset cannot be fetched.
