# Settling In

A menu bar app that shows what macOS is doing in the background, especially the setup work a new Mac does in its first days: Photos analysis, Spotlight indexing, iCloud sync.

- **Right now:** CPU used by Apple's background jobs, with plain names.
- **Photos analysis:** how much of the library is analyzed, what's left, and the recent pace. Shared Album photos are listed separately because macOS doesn't fully analyze them.
- **Spotlight:** whether file indexing and knowledge indexing are running.
- **While you were away:** how long the Mac slept versus worked during the last stretch you were away, and which jobs ran.

Settling In needs Full Disk Access (System Settings > Privacy & Security) to read the Photos database. It opens it read-only.

Photos progress comes from Photos' private database, which Apple doesn't document. A macOS update can change it and break that section.

## Building

```
make build   # build with xcodebuild
make test    # run SettleCore tests
make run     # build and launch a debug copy
make install # release build into /Applications, then launch it
```

Add `--preview-window` when launching the binary to open the panel as a regular window.
