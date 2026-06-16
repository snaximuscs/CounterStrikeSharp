#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/minimal-linux"
NATIVE_BUILD_DIR="$BUILD_DIR/native"
MANAGED_PUBLISH_DIR="$BUILD_DIR/api-publish"
OUTPUT_DIR="$ROOT_DIR/artifacts/minimal-linux"
PACKAGE_ZIP="$ROOT_DIR/artifacts/counterstrikesharp-linux-minimal.zip"
DOTNET_RUNTIME_VERSION="${DOTNET_RUNTIME_VERSION:-10.0.3}"
WITH_RUNTIME="${WITH_RUNTIME:-0}"

cd "$ROOT_DIR"

if [[ -n "${MINIMAL_VERSION:-}" ]]; then
    VERSION="$MINIMAL_VERSION"
else
    UPSTREAM_VERSION="${UPSTREAM_VERSION:-}"
    if [[ -z "$UPSTREAM_VERSION" ]] && command -v dotnet-gitversion >/dev/null 2>&1; then
        UPSTREAM_VERSION="$(dotnet-gitversion /showvariable SemVer 2>/dev/null || true)"
    fi
    if [[ -z "$UPSTREAM_VERSION" ]]; then
        UPSTREAM_VERSION="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)"
    fi
    if [[ -z "$UPSTREAM_VERSION" ]]; then
        UPSTREAM_VERSION="1.0.369"
    fi
    VERSION="${UPSTREAM_VERSION%-minimal}-minimal"
fi

ASSEMBLY_VERSION="${ASSEMBLY_VERSION:-${VERSION%%-*}}"
if [[ ! "$ASSEMBLY_VERSION" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]]; then
    ASSEMBLY_VERSION="1.0.0"
fi

SHORT_SHA="$(git rev-parse --short=7 HEAD 2>/dev/null || echo Local)"

echo "Building CounterStrikeSharp minimal Linux package"
echo "Version: $VERSION"
echo "Author: Snaximus CS"
echo "Runtime target: linux-x64"
echo "Include bundled .NET runtime: $WITH_RUNTIME"

rm -rf "$MANAGED_PUBLISH_DIR" "$OUTPUT_DIR" "$PACKAGE_ZIP"
mkdir -p "$NATIVE_BUILD_DIR" "$MANAGED_PUBLISH_DIR" "$OUTPUT_DIR"

export SEMVER="$VERSION"
export GITHUB_SHA_SHORT="$SHORT_SHA"

cmake -S "$ROOT_DIR" -B "$NATIVE_BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$NATIVE_BUILD_DIR" --config Release --parallel "${BUILD_PARALLELISM:-$(nproc)}"

dotnet publish "$ROOT_DIR/managed/CounterStrikeSharp.API/CounterStrikeSharp.API.csproj" \
    -c Release \
    -o "$MANAGED_PUBLISH_DIR" \
    -p:Version="$VERSION" \
    -p:PackageVersion="$VERSION" \
    -p:AssemblyVersion="$ASSEMBLY_VERSION" \
    -p:FileVersion="$ASSEMBLY_VERSION" \
    -p:InformationalVersion="$VERSION" \
    -p:Authors="Snaximus CS" \
    -p:Company="Snaximus CS" \
    -p:Product="CounterStrikeSharp Minimal" \
    -p:Description="Custom minimal production-focused CounterStrikeSharp fork runtime assembly for Linux CS2 servers" \
    -p:DebugType=none \
    -p:DebugSymbols=false \
    -p:GenerateCompatibilitySuppressionFile=false \
    -p:ApiCompatValidateAssemblies=false

cp -a "$NATIVE_BUILD_DIR/addons" "$OUTPUT_DIR/"

mkdir -p "$OUTPUT_DIR/addons/counterstrikesharp/api"
cp -a "$MANAGED_PUBLISH_DIR"/. "$OUTPUT_DIR/addons/counterstrikesharp/api/"

mkdir -p "$OUTPUT_DIR/licenses"
cp "$ROOT_DIR/LICENSE.GPL3" "$OUTPUT_DIR/licenses/"
cp "$ROOT_DIR/LICENSE.MIT" "$OUTPUT_DIR/licenses/"
cp "$ROOT_DIR/ACKNOWLEDGEMENTS.md" "$OUTPUT_DIR/licenses/"

find "$OUTPUT_DIR" -type f \( -name '*.pdb' -o -name '*.dbg' -o -name '*.dSYM' -o -name '*.snupkg' -o -name '*.nupkg' \) -delete
find "$OUTPUT_DIR" -type f -name '*.cs' -delete
rm -rf "$OUTPUT_DIR/addons/counterstrikesharp/api/runtimes/win" \
       "$OUTPUT_DIR/addons/counterstrikesharp/api/runtimes/win-x64" \
       "$OUTPUT_DIR/addons/counterstrikesharp/api/runtimes/osx" \
       "$OUTPUT_DIR/addons/counterstrikesharp/api/runtimes/osx-x64" \
       "$OUTPUT_DIR/addons/counterstrikesharp/api/runtimes/osx-arm64"
find "$OUTPUT_DIR/addons/counterstrikesharp/api/runtimes" -type d -empty -delete 2>/dev/null || true
rm -rf "$OUTPUT_DIR/addons/counterstrikesharp/source"

if [[ "$WITH_RUNTIME" == "1" ]]; then
    RUNTIME_DIR="$OUTPUT_DIR/addons/counterstrikesharp/dotnet"
    mkdir -p "$RUNTIME_DIR"
    curl -fsSL "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/${DOTNET_RUNTIME_VERSION}/aspnetcore-runtime-${DOTNET_RUNTIME_VERSION}-linux-x64.tar.gz" \
        | tar xz -C "$RUNTIME_DIR"
fi

FORBIDDEN_REGEX='(^|/)(docs?|docfx|examples?|samples?|HelloWorld|TestPlugin|tests?|benchmarks?|\.github|\.devcontainer|\.vscode|source)(/|$)|\.(cs)$|launchSettings\.json$|packages\.config$|\.ya?ml$|workflow'
if find "$OUTPUT_DIR" -print | grep -Eiq "$FORBIDDEN_REGEX"; then
    echo "Minimal package contains forbidden docs/dev/test/source content:" >&2
    find "$OUTPUT_DIR" -print | grep -Ei "$FORBIDDEN_REGEX" >&2
    exit 1
fi

test -f "$OUTPUT_DIR/addons/counterstrikesharp/bin/linuxsteamrt64/counterstrikesharp.so"
test -f "$OUTPUT_DIR/addons/counterstrikesharp/api/CounterStrikeSharp.API.dll"
test -f "$OUTPUT_DIR/addons/counterstrikesharp/api/CounterStrikeSharp.API.deps.json"
test -f "$OUTPUT_DIR/addons/counterstrikesharp/api/CounterStrikeSharp.API.runtimeconfig.json"
test -f "$OUTPUT_DIR/addons/counterstrikesharp/gamedata/gamedata.json"
test -f "$OUTPUT_DIR/addons/counterstrikesharp/configs/core.example.json"
test -f "$OUTPUT_DIR/licenses/LICENSE.GPL3"
test -f "$OUTPUT_DIR/licenses/LICENSE.MIT"

if command -v zip >/dev/null 2>&1; then
    (cd "$OUTPUT_DIR" && zip -qr "$PACKAGE_ZIP" .)
fi

echo "Minimal package output: $OUTPUT_DIR"
if [[ -f "$PACKAGE_ZIP" ]]; then
    echo "Minimal package zip: $PACKAGE_ZIP"
    echo "Zip size: $(du -h "$PACKAGE_ZIP" | awk '{print $1}')"
fi
echo "Directory size: $(du -sh "$OUTPUT_DIR" | awk '{print $1}')"
