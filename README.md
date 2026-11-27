# LINE for Linux offline installer

Build and install LINE Desktop 26.6.0.4004 on Debian 13 amd64 using a pinned Wine runner. The installer was tested on Debian 13.8 Slim with `libc6:amd64` `2.41-12+deb13u5`. LINE uses an X11 or XWayland session and the installation includes Thai fonts and color emoji support.

Start with the [installation skill](.agents/skills/line-offline-install/SKILL.md) and its [rebuild guide](.agents/skills/line-offline-install/references/rebuild.md). Every step can be followed in a terminal or by an AI agent that reads Markdown and runs commands. The offline install and launch path uses standalone Wine. The optional file acquisition workflow uses Bottles to reproduce the original LINE installation.

## Build in a fresh checkout

1. Restore the exact build inputs at the paths listed in the rebuild guide. These include the Wine runner, Debian packages, signed Microsoft DLLs and catalogs, fonts and LINE program files. The repository contains the source code, checksums and provenance. Supply the binary inputs from your own copies or the documented upstream sources. If the LINE bootstrapper now installs a different release, the pinned build needs a retained copy of the recorded version.
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
sudo sh ./LINE-offline-26.6.0.4004-linux-x86_64.run
line-offline
```

The first launch creates a Wine prefix under `${XDG_DATA_HOME:-$HOME/.local/share}/line-offline/wine`. Check Thai text on the sign-in screen and paste `🔮🔥🙏` into the email field to verify all three appear in color. Clear the email field and connect to the internet to sign in. The account owner scans the QR code in LINE on their phone and confirms the sign-in. Verify that the chat list opens and the same desktop account can start LINE again.

The clean Debian test covers offline installation, launch, colored emoji and a restart using the same prefix. The separate online test reached the QR screen. Completing sign-in requires the account owner's confirmation. [Offline test](offline/phase6/clean-debian-validation.log) · [Online readiness test](analysis/fresh-login-readiness-20261127.log)

## Project references

- [Pinned input inventory](offline/phase1/inventory.json) and [Wine runner manifest](offline/phase1/wine-runner-manifest.json)
- [DLL overrides, font routing and prefix provisioning](offline/phase3/install-line.sh)
- [Wine patches](patches/) and [Bottles and Wine helper scripts](scripts/)
- [Project progress](PROGRESS.md) and [technical notes](analysis/NOTES.md)

Keep the `.run`, downloaded binaries, local Wine prefixes and account data outside Git. The optional `bash scripts/make_handoff_bundle.sh` exports the committed source files for use on a machine without GitHub access.
