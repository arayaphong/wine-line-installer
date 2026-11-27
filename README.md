# LINE for Linux offline installer

Build and install LINE Desktop 26.6.0.4004 on Debian 13 amd64 using a pinned Wine runner. The installer was tested on Debian 13.8 Slim with `libc6:amd64` `2.41-12+deb13u5`. LINE uses an X11 or XWayland session and the installation includes Thai fonts and color emoji support.

Start with the [installation skill](.agents/skills/line-offline-install/SKILL.md) and its [rebuild guide](.agents/skills/line-offline-install/references/rebuild.md). Every step can be followed in a terminal or by an AI agent that reads Markdown and runs commands. The offline install and launch path uses standalone Wine. The optional file acquisition workflow uses Bottles to reproduce the original LINE installation.

## Pinned build versions

### LINE installers and Wine runner

| Component | Version used |
|---|---|
| Offline installer | `LINE-offline-26.6.0.4004-linux-x86_64.run` |
| Installed LINE Desktop | `LINE.exe` x64, `26.6.0.4004` |
| Official online bootstrapper | `LineInst.exe` x86, `1.0.0.24` |
| Bundled launcher and updater | `LineLauncher.exe` x86, `1.0.0.23` and `LineUpdater.exe` x86, `1.0.1.93` |
| Connector | `LineConnector.exe` x64, `1.0.0.1` and `LINE.msix` package identity `26.6.0.0` |
| Wine engine and base runner | `wine-11.0` with Bottles Soda `soda-11.0-10` |
| Packaged Wine runner | `soda-11.0-10-line.runtime.tar.gz` with project patches `0001` through `0004` |
| Valve Wine source | Commit `0509a0b64a4852741364c95bcdc67ae8f74ef11d` |

The bootstrapper resolves the desktop installer at download time. Its SHA-256 is `5dbceadb14d130b76f8d16c3519f0e41ac0cbb5b4c6bdae302a850a7cf0a2462`. For a byte-identical build, match the installed LINE files against the payload manifest and use the exact Wine runner archive. [LINE payload manifest](offline/phase3/payload-files.sha256) · [Wine archive checksum](offline/phase2/soda-11.0-10-line.runtime.tar.gz.sha256)

The Wine DLL build fetches Valve's source tag `experimental-wine-bleeding-edge-11.0-428201-20260904-pdf1645-w0509a0-dd7ac25-v35bdee`. The patch guide records the exact Soda release revision, patch order, and runner assembly commands. [Wine patch guide](patches/README.md)

### Microsoft system DLLs and catalogs

The x64 files and the x86 `dwmapi.dll` and `msimg32.dll` came from Windows 11 build `10.0.26100.9457`, `install.wim` image 1. The x86 `gdiplus.dll` came from Windows 7 SP1 (`KB976932`). The x86 `webio.dll` and `winhttp.dll` came from `KB3140245`. The table uses the numeric PE `FileVersion` for each architecture present in the payload.

| DLL | x86 FileVersion (`SysWOW64`) | x64 FileVersion (`System32`) | Final Wine override |
|---|---|---|---|
| `crypt32.dll` | — | `10.0.26100.9278` | `builtin` |
| `dwmapi.dll` | `10.0.26100.9278` | `10.0.26100.9278` | `builtin` |
| `dxgi.dll` | — | `10.0.26100.9444` | `builtin` |
| `gdiplus.dll` | `6.1.7601.17514` | — | `native,builtin` |
| `mfplat.dll` | — | `10.0.26100.9278` | `builtin` |
| `msimg32.dll` | `10.0.26100.9444` | `10.0.26100.9444` | `builtin` |
| `userenv.dll` | — | `10.0.26100.9278` | `builtin` |
| `version.dll` | — | `10.0.26100.1150` | `builtin` |
| `webio.dll` | `6.1.7601.23375` | — | `native,builtin` |
| `winhttp.dll` | `6.1.7601.23375` | `10.0.26100.9278` | `builtin` |
| `wininet.dll` | — | `11.0.26100.9444` | `builtin` |
| `winmm.dll` | — | `10.0.26100.9278` | `builtin` |

The five matching catalogs are Windows 11 `10.0.26100.9457` packages `Client-Desktop-Required-WOW64-Package0010`, `Client-Desktop-Required-Package0415` and `OneCore-CoreSystem-Core-merged-Package`, the Windows 7 SP1 `foundation-package` at `6.1.7601.17514`, and `package_1_for_kb3140245` at `6.1.1.0`. Both manifests list the full catalog filenames alongside all 15 DLL checksums. [x86 DLL and catalog checksums](ms-dlls/x86/SHA256SUMS) · [x64 DLL and catalog checksums](ms-dlls/x64-ondisk/SHA256SUMS)

For source recovery from `KB3140245`, the delta extraction used Microsoft `msdelta.dll` x64 with PE `FileVersion` `5.0.1.1` and SHA-256 `a5b38f57fe4b1130c275268709b0671530486cb67124ffa6821882243f840d57`. [Delta extraction notes](analysis/NOTES.md#fixing-wine-runs-819--installer-succeeds)

### Modified Wine DLLs

There are eight modified Wine DLL files in the runner. Use the per-file digest for version cells marked **SHA-256**. The runner archive and its manifest pin the remaining Wine libraries. [Modified DLL checksums](wine-src/out/SHA256SUMS) · [Full Wine runner manifest](offline/phase1/wine-runner-manifest.json)

| DLL | x86 FileVersion | x64 FileVersion | Project change |
|---|---|---|---|
| `dnsapi.dll` | `5.2.3790.4318` | — | Added stub exports to Soda's DLL |
| `dwrite.dll` | — | **SHA-256** | Rebuilt with patch `0004` for Qt color emoji |
| `ntdll.dll` | `6.1.7601.24059` | — | Added stub exports to Soda's DLL. Patch `0002` records the source-level `SbSelectProcedure` change |
| `secur32.dll` | **SHA-256** | **SHA-256** | Rebuilt with patch `0003` for TLS endpoint bindings |
| `user32.dll` | `5.1.2600.2180` | — | Added stub exports to Soda's DLL |
| `wintrust.dll` | `6.1.7601.23769` | `6.1.7601.23769` | Rebuilt with patch `0001` for Windows catalog support |

### DLLs bundled by LINE

The LINE payload includes 118 application DLLs. The manifest pins each file by its relative path and SHA-256. [LINE payload manifest](offline/phase3/payload-files.sha256)

| Files in the LINE application directory | Count | Architecture | Version identifier |
|---|---:|---|---|
| `Qt6*.dll` and the DLLs in `imageformats/`, `multimedia/`, `platforms/`, `plugins/` and `texttospeech/` | 89 | x64 | Qt `6.6.3` (PE `6.6.3.0`) |
| `ucrtbase.dll`, `api-ms-win-core-*.dll` and `api-ms-win-crt-*.dll` | 19 | x64 | `10.0.26100.6901` |
| `msvcp140*.dll` and `vcruntime140*.dll` | 5 | x64 | `14.44.35211.0` |
| `WebView2Loader.dll` | 1 | x64 | `1.0.3065.39` |
| `dbghelp.dll` | 1 | x86 | `6.6.7.5` |
| `libcrypto-1_1-x64.dll` and `libssl-1_1-x64.dll` | 2 | x64 | OpenSSL `1.1.1n` from the embedded build string |
| `skottie.dll` | 1 | x64 | SHA-256 in the manifest |

## Build in a fresh checkout

1. Restore the exact build inputs at the paths listed in the rebuild guide. These include the Wine runner, Debian packages, signed Microsoft DLLs and catalogs, fonts and LINE program files. The repository contains the source code, checksums and provenance. Supply the binary inputs from your own copies or the documented upstream sources. If the LINE bootstrapper now installs a different release, the pinned build needs a retained copy of the recorded version.
   Check the runner and Microsoft DLLs from the project root before building.

   ```bash
   (cd offline/phase2 && sha256sum -c soda-11.0-10-line.runtime.tar.gz.sha256)
   (cd ms-dlls/x86 && sha256sum -c SHA256SUMS)
   (cd ms-dlls/x64-ondisk && sha256sum -c SHA256SUMS)
   ```

2. Run these commands from the project root with Python 3.11 or newer, Bash, GNU tar, gzip, `sha256sum` and `unzstd` if using the snapshot route.

   ```bash
   python3 offline/phase3/build-payload.py
   bash offline/phase5/build.sh
   git diff --exit-code HEAD -- offline/phase5/LINE-offline-26.6.0.4004-linux-x86_64.run.sha256
   ```

   For a clean, matching LINE installation, use `python3 offline/phase3/build-payload.py --installed-line-dir /path/to/AppData/Local/LINE` in the first step. The payload builder checks the allowlisted program files against the recorded hashes. When building from a source archive, compare the final hash with the recorded installer checksum from before the build. [Recorded installer checksum](offline/phase5/LINE-offline-26.6.0.4004-linux-x86_64.run.sha256)

## Install and verify

Copy `offline/phase5/LINE-offline-26.6.0.4004-linux-x86_64.run` and its checksum to the target Debian machine. Run the installer with root privileges and launch LINE from the desktop account.

```bash
sha256sum -c LINE-offline-26.6.0.4004-linux-x86_64.run.sha256
sudo sh ./LINE-offline-26.6.0.4004-linux-x86_64.run
line-offline
```

The first launch creates a Wine prefix under `${XDG_DATA_HOME:-$HOME/.local/share}/line-offline/wine`. Check Thai text on the sign-in screen and paste `🔮🔥🙏` into the email field to verify all three appear in color. Clear the email field and connect to the internet to sign in. The account owner scans the QR code in LINE on their phone and confirms the sign-in. Verify that the chat list opens and the same desktop account can start LINE again.

The clean Debian test covers offline installation, launch, colored emoji and a restart using the same prefix. The separate online test reached the QR screen. Completing sign-in requires the account owner's confirmation. [Offline test](offline/phase6/clean-debian-validation.log) · [Online readiness test](analysis/fresh-login-readiness-20261127.log)

## Project references

- [Pinned input inventory](offline/phase1/inventory.json) and [Wine runner manifest](offline/phase1/wine-runner-manifest.json)
- [DLL overrides, font routing and prefix provisioning](offline/phase3/install-line.sh)
- [Wine patches and their target revisions](patches/README.md) and [Bottles and Wine helper scripts](scripts/)
- [Project progress](PROGRESS.md) and [technical notes](analysis/NOTES.md)

Keep the `.run`, downloaded binaries, local Wine prefixes and account data outside Git. The optional `bash scripts/make_handoff_bundle.sh` exports the committed source files for use on a machine without GitHub access.
