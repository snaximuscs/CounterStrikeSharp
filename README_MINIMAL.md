# CounterStrikeSharp Minimal Linux Build

Author: Snaximus CS  
Version style: upstream-version-minimal  
Target: Linux x64 production Counter-Strike 2 servers

This is a custom minimal CounterStrikeSharp fork/build for production Linux CS2 dedicated servers, including Pterodactyl/Wings environments. It is not the official upstream CounterStrikeSharp release.

The minimal package preserves public plugin API compatibility for normal CounterStrikeSharp plugins such as MatchZy Minimal. It keeps `CounterStrikeSharp.API`, `BasePlugin`, `ChatColors`, plugin lifecycle loading/unloading, command/event/timer APIs, player/controller/entity wrappers, ConVar and server command APIs, config loading, logging, and the native Metamod/Source2 bridge.

Excluded from the minimal package:

- docs, docfx, and generated documentation
- examples, samples, HelloWorld, TestPlugin, playground plugins, tests, and benchmarks
- `.github`, devcontainer, local editor/debug settings, CI-only files, and development scripts
- source `.cs` files and Windows-only runtime files
- symbols/debug packages unless required at runtime

Build the minimal Linux package:

```bash
scripts/build-minimal-linux.sh
```

The output directory is:

```text
artifacts/minimal-linux/
```

By default the package expects the server host to provide the required .NET runtime. To bundle the ASP.NET Core runtime used by the upstream release flow:

```bash
WITH_RUNTIME=1 scripts/build-minimal-linux.sh
```

Install on a Linux CS2 server by copying the contents of `artifacts/minimal-linux/` into the CS2 game directory that contains `gameinfo.gi`, normally:

```text
/home/container/game/csgo/
```

After install, the CounterStrikeSharp files should be under:

```text
/home/container/game/csgo/addons/counterstrikesharp/
```

Metamod: this package contains the CounterStrikeSharp native bridge under `addons/counterstrikesharp/bin/linuxsteamrt64/`. Your CS2 server still needs a working Metamod:Source installation and a valid CounterStrikeSharp loader entry according to your server layout.

.NET runtime: if you did not build with `WITH_RUNTIME=1`, install a compatible .NET/ASP.NET Core runtime for the target framework used by this repo. The current runtime target framework is `net10.0`.

Verify loading:

```text
meta list
css_plugins list
```

Troubleshooting:

- Missing `hostfxr` or .NET runtime errors: install the required runtime or rebuild with `WITH_RUNTIME=1`.
- Missing native library errors: confirm Linux x64 server environment, Metamod is installed, and `addons/counterstrikesharp/bin/linuxsteamrt64/counterstrikesharp.so` exists.
- Schema/gamedata errors: confirm `addons/counterstrikesharp/gamedata/gamedata.json` is present and current for the server build.
- Plugin load failures: check the plugin is under `addons/counterstrikesharp/plugins/<PluginName>/<PluginName>.dll` and that its dependencies are present.

This minimal build excludes development assets only. Public plugin API compatibility should be preserved.
