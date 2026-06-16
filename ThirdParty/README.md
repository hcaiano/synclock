# ThirdParty

## ableton-link/ — Phase 0 real Link bridge

Vendored Ableton Link C++ source (NOT LinkKit — LinkKit is iOS-license-only),
pinned as a git submodule at `Link-4.0`:

```sh
git submodule add https://github.com/Ableton/link ThirdParty/ableton-link
cd ThirdParty/ableton-link
git checkout Link-4.0
git submodule update --init --recursive   # asio-standalone
```

The `AbletonLinkBridge` target in `Package.swift` is wired with header search
paths for
`ThirdParty/ableton-link/include` and
`ThirdParty/ableton-link/modules/asio-standalone/asio/include`, plus
`LINK_PLATFORM_MACOSX=1`. Requires C++17 / Xcode 16.2+.

`Sources/AbletonLinkBridge/AbletonLinkBridge.cpp` now owns a real
`std::unique_ptr<ableton::Link>` behind the unchanged C ABI in
`Sources/AbletonLinkBridge/include/AbletonLinkBridge.h`.
`MCLinkIsRealImplementation()` must return `true`.

Phase 0 proof commands:

```sh
swift build
swift run SynclockTests
swift run SynclockLinkCheck --self-peer

# Optional external-process peer proof with Ableton's silent example:
cmake -S ThirdParty/ableton-link -B ThirdParty/ableton-link/build-synclock \
  -DLINK_BUILD_TESTS=OFF -DLINK_BUILD_ASIO=OFF -DLINK_BUILD_JACK=OFF \
  -DCMAKE_BUILD_TYPE=Release
cmake --build ThirdParty/ableton-link/build-synclock --target LinkHutSilent -j 8
{ printf 'a'; sleep 8; printf 'q'; } | \
  ThirdParty/ableton-link/build-synclock/bin/LinkHutSilent >/tmp/synclock-linkhut.log 2>&1 &
swift run SynclockLinkCheck --require-peer
trash ThirdParty/ableton-link/build-synclock
```

License obligation: Ableton Link is GPLv2-or-later — ship GPL text + Ableton
copyright/notices, publish corresponding source.
