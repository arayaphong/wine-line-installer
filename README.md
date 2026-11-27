# LINE for Linux offline installer

Build LINE Desktop 26.6.0.4004 by patching Wine from pinned upstream inputs and packaging a `.run` for Debian 13 amd64. The installer was tested on Debian 13.8 Slim with `libc6:amd64` `2.41-12+deb13u5`. LINE uses an X11 or XWayland session. The installation includes the LINE media player, Thai fonts, color emoji support, and a fix for LINE's window shadows on GNOME XWayland.

Start with the [installation skill](.agents/skills/line-offline-install/SKILL.md) and its [rebuild guide](.agents/skills/line-offline-install/references/rebuild.md). Every step can be followed in a terminal or by an AI agent that reads Markdown and runs commands. The offline install and launch path uses standalone Wine. The optional file acquisition workflow uses Bottles to reproduce the original LINE installation.

## Pinned build versions

### LINE installers and Wine runner

| Component | Version used |
|---|---|
| Offline installer | `LINE-offline-26.6.0.4004-linux-x86_64.run` |
| Installed LINE Desktop | `LINE.exe` x64, `26.6.0.4004` |
| Media player | `LineMediaPlayer.exe` x64, `1.2.0.662` |
| Official online bootstrapper | `LineInst.exe` x86, `1.0.0.24` |
| Bundled launcher and updater | `LineLauncher.exe` x86, `1.0.0.23` and `LineUpdater.exe` x86, `1.0.1.93` |
| Connector | `LineConnector.exe` x64, `1.0.0.1` and `LINE.msix` package identity `26.6.0.0` |
| Wine engine and base runner | `wine-11.0` with Bottles Soda `soda-11.0-10` |
| Wine runtime generated during the build | `soda-11.0-10-line.runtime.tar.gz` with project patches `0001` through `0005` |
| Valve Wine source | Commit `0509a0b64a4852741364c95bcdc67ae8f74ef11d` |

The bootstrapper resolves the desktop installer at download time. Its SHA-256 is `5dbceadb14d130b76f8d16c3519f0e41ac0cbb5b4c6bdae302a850a7cf0a2462`. The private backup preserves the installed LINE program files by hash. [LINE payload manifest](offline/phase3/payload-files.sha256)

The Wine build fetches Valve's source tag `experimental-wine-bleeding-edge-11.0-428201-20260904-pdf1645-w0509a0-dd7ac25-v35bdee`. The patch guide records the exact Soda release revision, patch order, and runner assembly commands. [Wine patch guide](patches/README.md)

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

### Modified Wine libraries

The runner replaces eight PE DLL files and the x86_64 Unix X11 driver. Use the per-file digest for version cells marked **SHA-256**. The base runner archive pins the remaining Wine libraries. [Modified library checksums](wine-src/out/SHA256SUMS) · [Soda archive checksum](offline/phase2/soda-11.0-10-x86_64.tar.xz.sha256)

| Library | x86 version | x64 version | Project change |
|---|---|---|---|
| `dnsapi.dll` | `5.2.3790.4318` | — | Added stub exports to Soda's DLL |
| `dwrite.dll` | — | **SHA-256** | Rebuilt with patch `0004` for Qt color emoji |
| `ntdll.dll` | `6.1.7601.24059` | — | Added stub exports to Soda's DLL. Patch `0002` records the source-level `SbSelectProcedure` change |
| `secur32.dll` | **SHA-256** | **SHA-256** | Rebuilt with patch `0003` for TLS endpoint bindings |
| `user32.dll` | `5.1.2600.2180` | — | Added stub exports to Soda's DLL |
| `winex11.so` | — | **SHA-256** | Rebuilt with patch `0005` for window shadow stacking on Mutter XWayland |
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

The offline payload includes all 130 files from LINE's official media player ZIP. Playback uses Wine's Direct3D 11 backend with Mesa and WineGStreamer with the bundled H.264 and AAC components. The player requests native Direct3D resources from Qt, so use Qt's default Windows backend for playback. [Official plugin catalog](https://desktop.line-scdn.net/win/plugin/v1/plugin_remote_info.json) · [Media player file hashes](offline/phase3/media-player-files.sha256) · [Debian runtime packages](offline/phase2/runtime-debs/SHA256SUMS) · [Parser packages](offline/phase2/media-parser-debs/SHA256SUMS)

## Build in a fresh checkout

To rebuild from the preserved inputs, extract `line-installer-downloads-26.6.0.4004.tar.zst` and follow its `README.md`. The archive includes the official player ZIP, the pinned Debian playback packages and the checksums for the tested installer. [Archive on Google Drive](https://drive.google.com/file/d/1tgjea5ZodPtXFg-5IP_zKs2-cmJGHB3b/view?usp=sharing)

1. Restore the pinned LINE program files, extracted Microsoft DLLs and catalogs, fonts and Debian packages from the input archive. Use the media player ZIP in `line/media-player/` and restore both `debian/runtime-debs/` and `debian/media-parser-debs/`. Obtain the `soda-11.0-10-x86_64.tar.xz` base release. The Wine build script checks out the pinned Valve Wine revision if needed. The build runs offline once all inputs are available locally. [Input locations and prerequisites](.agents/skills/line-offline-install/references/rebuild.md#1-รวบรวมไฟล์ต้นทาง) · [Wine patch guide](patches/README.md)

2. Run these commands from the project root. The first command verifies Soda, applies the Wine patches, builds the patched DLLs and X11 driver, and packages the runtime for the current build.

   ```bash
   bash offline/phase2/build-runtime.sh /path/to/soda-11.0-10-x86_64.tar.xz
   archive_dir=/path/to/line-installer-downloads-26.6.0.4004
   python3 offline/phase3/build-payload.py \
     --installed-line-dir "$archive_dir/line/installed-program" \
     --media-player-zip "$archive_dir/line/media-player/LineMediaPlayer-1.2.0.662.zip"
   bash offline/phase5/build.sh
   (cd offline/phase5 && sha256sum -c LINE-offline-26.6.0.4004-linux-x86_64.run.sha256)
   ```

   Use the checksums generated for the new runtime and `.run` together. The checked-in checksums record the tested reference build. Compiler output and packaging can change the checksum of a fresh build from pinned sources. Verify the newly built installer on clean Debian. [Rebuild and test procedure](.agents/skills/line-offline-install/references/rebuild.md)

In a clean checkout, the refreshed archive with the reference Wine runtime reproduced the payload and `.run` hashes recorded in the archive's `project-pins/` directory.

## Install and verify

Copy `offline/phase5/LINE-offline-26.6.0.4004-linux-x86_64.run` and its checksum to the target Debian machine. Run the installer with root privileges and launch LINE from the desktop account.

```bash
sha256sum -c LINE-offline-26.6.0.4004-linux-x86_64.run.sha256
sudo sh ./LINE-offline-26.6.0.4004-linux-x86_64.run
line-offline
```

The first launch creates a Wine prefix under `${XDG_DATA_HOME:-$HOME/.local/share}/line-offline/wine` and puts the bundled media player in `%LOCALAPPDATA%\LINE\Data\plugin\LineMediaPlayer\1.2.0.662`. An existing prefix receives the player on its first launch with the updated `.run`. Check Thai text on the sign-in screen and paste `🔮🔥🙏` into the email field to verify all three appear in color. Clear the email field and connect to the internet to sign in. The account owner scans the QR code in LINE on their phone and confirms the sign-in. Verify that the chat list opens and the same desktop account can start LINE again.

The clean Debian test covers offline installation, driver and decoder dependencies, Direct3D initialization in the bundled player, colored emoji, and provisioning an existing prefix. A separate test played a local H.264/AAC MP4 through to the end on Mutter XWayland and verified a stereo stream through the desktop's PulseAudio-compatible socket. The online test reached the QR screen. Completing sign-in requires the account owner's confirmation. [Offline and playback tests](offline/phase6/clean-debian-validation.log) · [Mutter XWayland shadow test](patches/0005-mutter-xwayland-validation.txt) · [Online readiness test](analysis/fresh-login-readiness-20261127.log)

LINE maintains a separate plugin catalog. In a clean networked test the bundled player files were present at the sign-in screen, while LINE had yet to create its `plugin.bin` cache after 60 seconds. Playback from the signed-in chat interface still needs verification.

## Project references

- [Pinned input inventory](offline/phase1/inventory.json) and [Wine runner manifest](offline/phase1/wine-runner-manifest.json)
- [DLL overrides, font routing and prefix provisioning](offline/phase3/install-line.sh)
- [Wine patches and their target revisions](patches/README.md) and [Bottles and Wine helper scripts](scripts/)
- [Project progress](PROGRESS.md) and [technical notes](analysis/NOTES.md)

Keep the `.run`, generated Wine files, downloaded binaries, local Wine prefixes and account data outside Git. The private backup holds inputs that may be hard to obtain again and files already extracted from Windows installation media. The optional `bash scripts/make_handoff_bundle.sh` exports the committed source files for use on a machine without GitHub access.
