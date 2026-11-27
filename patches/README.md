# LINE compatibility patches for Wine 11.0

Apply the numbered patches to a clean checkout of `ValveSoftware/wine` at commit `0509a0b64a4852741364c95bcdc67ae8f74ef11d`. The tag for that commit is `experimental-wine-bleeding-edge-11.0-428201-20260904-pdf1645-w0509a0-dd7ac25-v35bdee`. [Valve Wine patch target](https://github.com/ValveSoftware/wine/commit/0509a0b64a4852741364c95bcdc67ae8f74ef11d)

The binary base for the LINE runner is Bottles **Soda `soda-11.0-10`** for Linux x86_64. The Soda release tag in `bottlesdevs/wine` resolves to `75ceacbc281484a46704131ed3c338fbd08d3d3c`, and its build workflow pins the same Valve Wine commit. The `soda-11.0-10-x86_64.tar.xz` used here has SHA-256 `14633fabd180d308d2c1ebcb84a16f36d0484dded5809c64f8a7c93e654d7296`. [Soda release](https://github.com/bottlesdevs/wine/releases/tag/soda-11.0-10) · [Pinned Soda build workflow](https://github.com/bottlesdevs/wine/blob/75ceacbc281484a46704131ed3c338fbd08d3d3c/.github/workflows/build-soda.yml)

## Apply in this order

| Patch | Change |
|---|---|
| [0001](0001-wintrust-catalog-v2-members.patch) | Add support for Windows catalog members used by LINE's trust checks |
| [0002](0002-ntdll-SbSelectProcedure-stub.patch) | Add the `SbSelectProcedure` export at source level |
| [0003](0003-secur32-endpoint-bindings-cng-hash.patch) | Support the TLS endpoint bindings needed by the online installer |
| [0004](0004-dwrite-legacy-qt-color-glyph-run.patch) | Enable opt-in color glyph enumeration for LINE's Qt 6.6.3 |

For manual application, run the following from a clean Valve Wine checkout with `line_repo` set to the path of this project.

```bash
line_repo=/path/to/wine-line-installer
test "$(git rev-parse HEAD)" = 0509a0b64a4852741364c95bcdc67ae8f74ef11d &&
  git apply --check "$line_repo"/patches/000[1-4]-*.patch &&
  git apply "$line_repo"/patches/000[1-4]-*.patch
```

## Assemble `soda-11.0-10-line`

Extract the base Soda release into `~/.var/app/com.usebottles.bottles/data/bottles/runners/` so its executable is at `soda-11.0-10/bin/wine` relative to that directory. Run these commands from the LINE installer repository root.

```bash
bash scripts/build_wine_dlls.sh
bash scripts/build_line_runner.sh
```

The first script applies the patches and rebuilds `wintrust.dll` and `secur32.dll` for i386 and x86_64 and `dwrite.dll` for x86_64. The second adds the required exports to Soda's i386 `ntdll.dll`, `user32.dll`, and `dnsapi.dll` while assembling the separate LINE runner. This step supplies the runtime version of the `SbSelectProcedure` stub described in patch `0002`. [DLL build script](../scripts/build_wine_dlls.sh) · [Runner assembly script](../scripts/build_line_runner.sh)

Git stores the source patches, build scripts, and checksums. Compare a rebuilt runner with the recorded reference when reproducing the installer byte for byte. [Modified DLL checksums](../wine-src/out/SHA256SUMS) · [Tested runtime archive checksum](../offline/phase2/soda-11.0-10-line.runtime.tar.gz.sha256)
