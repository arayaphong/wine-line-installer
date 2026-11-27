# LINE compatibility patches for Wine 11.0

Apply the numbered patches to a clean checkout of `ValveSoftware/wine` at commit `0509a0b64a4852741364c95bcdc67ae8f74ef11d`. The tag for that commit is `experimental-wine-bleeding-edge-11.0-428201-20260904-pdf1645-w0509a0-dd7ac25-v35bdee`. [Valve Wine patch target](https://github.com/ValveSoftware/wine/commit/0509a0b64a4852741364c95bcdc67ae8f74ef11d)

The binary base for the LINE runner is Bottles **Soda `soda-11.0-10`** for Linux x86_64. The Soda release tag in `bottlesdevs/wine` resolves to `75ceacbc281484a46704131ed3c338fbd08d3d3c`, and its build workflow pins the same Valve Wine commit. The `soda-11.0-10-x86_64.tar.xz` used here has SHA-256 `14633fabd180d308d2c1ebcb84a16f36d0484dded5809c64f8a7c93e654d7296`. [Soda release](https://github.com/bottlesdevs/wine/releases/tag/soda-11.0-10) · [Pinned Soda build workflow](https://github.com/bottlesdevs/wine/blob/75ceacbc281484a46704131ed3c338fbd08d3d3c/.github/workflows/build-soda.yml)

## Apply in this order

| Patch | What led to the change | What to verify |
|---|---|---|
| [0001](0001-wintrust-catalog-v2-members.patch) | Wine failed to read SHA-256 catalogs and `CAT_MEMBERINFO2` records. The patch supports the Windows catalog entries and checks decoding results. | LINE opens with the pinned signed DLL and catalog files. |
| [0002](0002-ntdll-SbSelectProcedure-stub.patch) | Windows `dwmapi.dll` imported `SbSelectProcedure`, which was missing in Wine. A null result lets it use its default path. | The i386 Wine DLLs have the required exports and the 32-bit loader starts. |
| [0003](0003-secur32-endpoint-bindings-cng-hash.patch) | The online bootstrapper hit WinHTTP error `12029` when the TLS certificate used an ECDSA SHA-384 signature. The patch maps the CNG hash name for endpoint bindings. | The bootstrapper can load its installer metadata over TLS when testing the online route. |
| [0004](0004-dwrite-legacy-qt-color-glyph-run.patch) | Qt 6.6.3 requested a color glyph run before `MoveNext`. Wine reported `E_NOT_VALID_STATE`. The patch provides an opt-in for that call order. | `🔮🔥🙏` appear in color in the LINE email field with `fontengine=native`, `PrimeColorGlyphRun=1` and Segoe UI Emoji. |

The research notes record the observed errors and the tests that led to these changes. [Wine installer investigations](../analysis/NOTES.md#fixing-wine-runs-819--installer-succeeds) · [Qt color emoji investigation](../analysis/NOTES.md#wine-compatibility-patch-for-qt-color-emoji-2026-11-26)

For manual application, run the following from a clean Valve Wine checkout with `line_repo` set to the path of this project.

```bash
line_repo=/path/to/wine-line-installer
test "$(git rev-parse HEAD)" = 0509a0b64a4852741364c95bcdc67ae8f74ef11d &&
  git apply --check "$line_repo"/patches/000[1-4]-*.patch &&
  git apply "$line_repo"/patches/000[1-4]-*.patch
```

## Assemble `soda-11.0-10-line`

Generate the runtime as part of each fresh installer build. Run this command from the LINE installer repository root with the pinned Soda tarball available locally.

```bash
bash offline/phase2/build-runtime.sh /path/to/soda-11.0-10-x86_64.tar.xz
```

The runtime build verifies the base tarball, checks the Valve Wine revision and uses the existing DLL build and runner assembly scripts. `build_wine_dlls.sh` applies the patches and rebuilds `wintrust.dll` and `secur32.dll` for i386 and x86_64 and `dwrite.dll` for x86_64. `build_line_runner.sh` adds the required exports to Soda's i386 `ntdll.dll`, `user32.dll`, and `dnsapi.dll` while assembling the LINE runner in a temporary build directory. This step supplies the runtime version of the `SbSelectProcedure` stub described in patch `0002`. [Soda tarball checksum](../offline/phase2/soda-11.0-10-x86_64.tar.xz.sha256) · [DLL build script](../scripts/build_wine_dlls.sh) · [Runner assembly script](../scripts/build_line_runner.sh)

The build writes `offline/phase2/soda-11.0-10-line.runtime.tar.gz` and its matching SHA-256 for the `.run` build. Retain the source patches, revision pins, and verification results as the record of the work. The saved runtime checksum is the reference for the earlier tested build. [Modified DLL checksums](../wine-src/out/SHA256SUMS) · [Original tested runtime checksum](../offline/phase2/soda-11.0-10-line.runtime.tar.gz.sha256)
