# LINE installer on Wine (Bottles) — findings

## Environment
- Bottles (flatpak) `com.usebottles.bottles`, runner `soda-9.0-1`
- Bottle `LINE`: win64, Environment=Custom, Windows=win10, no dependencies, DXVK/VKD3D off
- Baseline of the empty bottle: `baseline/LINE-empty.tar.zst`, `baseline/files.sha256`, `baseline/*.reg`

## LineInst.exe (sha256 5dbceadb14d130b76f8d16c3519f0e41ac0cbb5b4c6bdae302a850a7cf0a2462)
- PE32 i386 GUI, 903 KB, bootstrapper only (PDB: `line-updater\LineInstaller\bin\LineInstaller.pdb`)
- Authenticode signed (GlobalSign EV code signing); Wine's WinVerifyTrust accepts it (returns 0)
- Downloads manifest `https://desktop.line-scdn.net/win/bin/real/installer/installer.json`
  (copy: `analysis/installer.json`), requires Windows 10 build >= 14393
- Registry keys used: `Software\LINE Corporation\LINE`, `Software\Naver\LINE`,
  `SOFTWARE\(Wow6432Node\)Microsoft\Windows\CurrentVersion\Uninstall\LINE`
- Delay-loaded DLLs: MSIMG32, WINHTTP, dwmapi, gdiplus. Also references Msftedit.dll, SHCore.dll

## Blocker 1 — DLL signature verification (run 2, `analysis/install2-run.log`)
Error dialog:
```
Security verification failed.
The following file failed security verification:
File : C:\windows\syswow64\gdiplus.dll
Reason : NO_SIGNATURE
```
How the check works (Ghidra via REA):
- `FUN_00410a30` calls WinVerifyTrust on each DLL before it is loaded
- Result 0 (signed) → signer must be in allow-list built by `FUN_0040fde0`:
  "Microsoft Corporation", "Microsoft Windows", "Microsoft Windows Publisher", "LY Corporation"
- Result TRUST_E_NOSIGNATURE etc. → if path contains `system32`/`syswow64`/`winsxs`
  (`FUN_00411b80`) it falls back to catalog lookup (`FUN_00411860`, CryptCATAdmin*);
  otherwise fails immediately
- Failure dialog: `FUN_00411100` → MessageBoxW, then the installer exits
- Wine builtin DLLs carry no Authenticode signature and Wine has no system catalogs →
  every builtin DLL the installer checks fails. First one hit: `gdiplus.dll`

## Attempt: genuine Microsoft DLLs (runs 3–5)
Source: Windows 7 SP1 x86 `windows6.1-kb976932-x86.exe` (md5 4bf28fc00d86c936c89e2d91ef46758b),
extracted to `~/.var/app/com.usebottles.bottles/data/bottles/temp/sp1-x86`.
The DLLs/catalog actually used are copied into the project: `ms-dlls/x86/` (+ `SHA256SUMS`).
Script: `scripts/install_ms_dlls.sh` (every `ms-dlls/x86/*.dll` → `syswow64`, every
`ms-dlls/x86/catroot/*.cat` → `system32\catroot\{127d0a1d-...}` and `{F750E6C3-...}`, overrides
native,builtin). Helper: `scripts/find_catalog.py` (Authenticode hash → .cat).

- All SP1 system DLLs are catalog-signed only (no embedded signature). gdiplus/winhttp/webio/msftedit
  hashes are in `microsoft-windows-foundation-package~31bf3856ad364e35~x86~~6.1.7601.17514.cat`
- Run 3 (soda-9.0-1 = Wine 9.0 TkG): catalog found but hash never matches — Wine 9.0's
  `CryptCATAdminCalcHashFromFileHandle` hashes the whole file instead of the PE Authenticode hash.
  Fixed upstream between wine-9.5 and wine-9.10 (`pe_image_hash`).
- Runner switched to **soda-11.0-10 (Wine 11.0)**. Pre-install snapshot: `baseline/pre-install/`
- Run 4: gdiplus.dll **passes** (catalog). Then native Msftedit crashes (needs real msls31) —
  LineInst does not verify Msftedit, so it is left builtin.
- Run 5: next failure `C:\windows\syswow64\dwmapi.dll — NO_SIGNATURE`.
  dwmapi.dll and msimg32.dll are **not** in Win7 SP1.

Verified DLLs = the delay-load imports: gdiplus ✅, dwmapi ❌, msimg32 ❌ (expected), winhttp (native SP1 + webio ready, not reached yet).

## Attempt: Windows 11 DLLs (runs 6–7)
Source: `Windows11_Client_x64_th-th_26300_9457.iso` → `sources/install.wim` image 1 (build 26100.9457),
extracted to `~/.var/app/com.usebottles.bottles/data/bottles/temp/win11-iso/` (install.wim 7.8 GB + `extract/`).
Win11 has no gdiplus in SysWOW64 (WinSxS only) → kept the SP1 gdiplus.

| DLL (SysWOW64) | Embedded sig | Catalog |
|---|---|---|
| dwmapi.dll | yes | Client-Desktop-Required-WOW64-Package0010 …9457.cat (also 2 others) |
| msimg32.dll | **no** | Client-Desktop-Required-WOW64-Package0010 …9457.cat, CoreSystem-DXG-Common-WOW64 …9444.cat |
| winhttp.dll / webio.dll | yes | OneCore-CoreSystem-Core-WOW64-merged …9444.cat |

- Run 6 (Win11 catalog in catroot): **Wine crashes** (c0000005) inside
  `CryptCATAdminEnumCatalogFromHash` while enumerating the Win11 catalog: it dereferences
  `member->pIndirectData` without a NULL check, and Win10/11 catalogs contain members that
  have no SPC_INDIRECT_DATA. Same code is still in Wine master (crypt.c ~line 547). Because every
  catalog in catroot is scanned, one Win11 .cat breaks every lookup (gdiplus too).
- Run 7 (Win11 catalog removed): gdiplus ✅ (SP1 cat), **dwmapi ✅ passes on its embedded
  signature** — then Win11 dwmapi calls `ntdll.SbSelectProcedure`, which Wine does not implement
  → abort. So Win11 dwmapi cannot run on Wine 11.
- msimg32 (Win11) needs its catalog → blocked by the Wine catalog crash above.
- Reverted: dwmapi back to Wine builtin; Win11 dwmapi/winhttp/webio + Win11 .cat kept in
  `ms-dlls/x86-win11-alt/` (not installed by the script). `ms-dlls/x86/` = gdiplus, winhttp,
  webio (SP1) + msimg32 (Win11) + SP1 catalog.

### What is left for the genuine-DLL route
1. dwmapi: a Microsoft-signed 32-bit dwmapi that does not need `SbSelectProcedure`
   (older Windows, e.g. 7/8.1/early 10), signed either inside the file or by an old-format catalog.
2. msimg32: either an embedded-signed/old-catalog copy from older Windows, or a Wine whose
   `CryptCATAdminEnumCatalogFromHash` skips members with `pIndirectData == NULL`
   (a one-line fix; not in any Wine release yet as of master on 2026-11-25).

Bottle diff after run 1: no files installed; only
`HKCU\Software\Microsoft\Windows\CurrentVersion\Wintrust\Trust Providers\Software Publishing "State"`
and `windows\system32\catroot` touched.

## Fixing Wine (runs 8–19) → installer succeeds
Runner **soda-11.0-10-line** = soda-11.0-10 + the changes below (built by `scripts/build_line_runner.sh`;
base runner untouched, files hard-linked, replaced files unlinked first).

| Problem (where it showed) | Fix | Kind |
|---|---|---|
| Win10/11 catalogs: `CryptCATOpen` given a PROV_RSA_FULL context can't hash SHA-256 → `inner` NULL → crash in `CryptCATEnumerateMember` | `CryptCATAdminEnumCatalogFromHash` passes hProv 0; `CryptCATEnumerateMember` returns NULL if not decoded | source, `patches/0001` (wintrust) |
| Catalog v2 members carry `CAT_MEMBERINFO2` (1.3.6.1.4.1.311.12.2.3) and hash-only SHA1 entries without indirect data → "corrupted"/NULL deref | accept MEMBERINFO2; reference tag from SubjectIdentifier; match hash-only members by tag; check CryptDecodeObject results | source, `patches/0001` |
| Win11 dwmapi imports `ntdll.SbSelectProcedure` (switchback) | stub returning NULL (dwmapi then uses its default path) | binary stub in i386 ntdll (`add_pe_export_stub.py`), source equivalent `patches/0002` |
| Win11 dwmapi talks to DWM over ALPC | `NtAlpc*` stubs → STATUS_NOT_IMPLEMENTED | binary stubs, i386 ntdll |
| Win11 dwmapi private user32 APIs (`IsThreadDesktopComposited`, `IsTopLevelWindow`, `GetWindowCompositionAttribute`, `DwmGetDxSharedSurface`) | stubs returning FALSE/0 | binary stubs, i386 user32 |
| Win7 winhttp imports `dnsapi.DnsGetProxyInformation`/`DnsFreeProxyName` | stubs (ERROR_CALL_NOT_IMPLEMENTED / void) | binary stubs, i386 dnsapi |
| Win7 SP1 winhttp offers only SSL3/TLS1.0 → LINE CDN refuses | KB3140245 winhttp/webio (6.1.7601.23375) + `DefaultSecureProtocols=0xA80` | genuine MS update, `install_ms_dlls.sh` |
| After TLS handshake winhttp asks `SECPKG_ATTR_ENDPOINT_BINDINGS`; cert is `ecdsa-with-SHA384` whose OID info Algid is `CALG_OID_INFO_CNG_ONLY` → `CryptHashCertificate(0xffffffff)` fails → winhttp drops the connection (ERROR_WINHTTP_CANNOT_CONNECT 12029) | map CNG hash name (SHA384/SHA512) to CALG | source, `patches/0003` (secur32) |

KB3140245 x86 (`ms-dlls/source/…msu`, sha1 cdafb409…) stores winhttp/webio as PA30 intra-package deltas
(winhttp = manifest ⊕ "0", webio = winhttp ⊕ "1"). Wine's msdelta is all stubs, so they were rebuilt with
`scripts/apply_delta.c` + native x64 msdelta.dll from the Win11 image; SHA1s match the package manifest.
Catalog: `package_1_for_kb3140245~31bf3856ad364e35~x86~~6.1.1.0.cat`.

Debug aids: `scripts/winhttp_probe.c` (same WinHTTP sequence as LineInst), LineInst status codes are
posted as WM_USER+3 (`-2` = installer.json empty, `-3` = no URL for this OS, `-4` = no temp path) and
download progress as WM_USER+1 (0–100). Build both with winegcc from `wine-src/build` (see PROGRESS.md).

### Result (run 19)
- Bootstrapper downloads `https://desktop.line-scdn.net/win/bin/real/installer/LineInst.exe` to
  `%TEMP%\LineInst_<tick>_<pid>.exe`, runs it with `/M`
- Installs **LINE 26.6.0.4004** to `C:\users\<user>\AppData\Local\LINE` (137 MB, Qt6), shortcuts,
  `line:`/`lineb:` URL handlers, Uninstall key, `HKCU\Software\LINE Corporation\LINE`, `Software\Naver\LINE`
- Launches LineAppMgr.exe → LineLauncher.exe (32-bit) → `LINE.exe` (**64-bit**)
- Full diff: `analysis/diff-preinstall-vs-postinstall.txt` (`scripts/diff_snapshots.py`)

## Blocker 2 — LINE.exe (x64) has the same DLL signature check
```
Security verification failed.
The following files failed security verification:
Restore binary process will be start.
File : C:\windows\system32\CRYPT32.dll
Reason : NO_SIGNATURE
```
The reported DLL is the 64-bit Wine builtin `crypt32.dll`. REA's normal import scan found no
direct CRYPT32 import in `LINE.exe`; delay-load coverage was partial. The origin of the load and
the selection rule for verification are still unknown. In the reproduced run log, the launcher
started `LineUpdater.exe --restore 0 th real`; the updater started the launcher with
`--updated 26.6.0.4004`, and the security error recurred.

The genuine Microsoft x64 DLL extracted from `install.wim` image 1 has an embedded
PKCS#7 signature record and matching hashes in the build 26100.9457 catalog. REA did not
validate the chain or timestamp. Its normal import table requires eight names absent from
the current runner's x64 `ntdll.dll` export table. See `PROGRESS.md` for the names and fingerprints.

## Building the small Windows tools (winegcc from wine-src/build)
```bash
cd wine-src/build
# 32-bit WinHTTP probe (needs: make dlls/winhttp/i386-windows/libwinhttp.a and the i386 libs below)
tools/winegcc/winegcc -o OUT/winhttp_probe.exe --wine-objdir . -b i686-windows -mconsole -municode \
  -I../valve-wine/include -I../valve-wine/include/msvcrt -Iinclude -D_UCRT ../../scripts/winhttp_probe.c \
  dlls/winhttp/i386-windows/libwinhttp.a dlls/winecrt0/i386-windows/libwinecrt0.a dlls/ucrtbase/i386-windows/libucrtbase.a \
  dlls/kernel32/i386-windows/libkernel32.a dlls/ntdll/i386-windows/libntdll.a libs/compiler-rt/i386-windows/libcompiler-rt.a
# 64-bit apply_delta (use with native x64 msdelta.dll next to it, WINEDLLOVERRIDES=msdelta=n)
tools/winegcc/winegcc -o OUT/apply_delta.exe --wine-objdir . -b x86_64-windows -mconsole \
  -I../valve-wine/include -I../valve-wine/include/msvcrt -Iinclude -D_UCRT ../../scripts/apply_delta.c \
  dlls/winecrt0/x86_64-windows/libwinecrt0.a dlls/ucrtbase/x86_64-windows/libucrtbase.a \
  dlls/kernel32/x86_64-windows/libkernel32.a dlls/ntdll/x86_64-windows/libntdll.a libs/compiler-rt/x86_64-windows/libcompiler-rt.a
```
Put OUT in `~/.var/app/com.usebottles.bottles/data/bottles/temp/` so the flatpak can run it.

## Reproducibility check (2026-11-25)
`scripts/setup_line_bottle.sh LINE-repro --run` on a brand-new bottle reproduced the result exactly:
LINE 26.6.0.4004 installed (137 MB), then LINE.exe stops at the CRYPT32.dll signature dialog.
Log: `analysis/setup-LINE-repro-run.log`.

## LINE.exe signature check — runtime analysis (2026-11-25, `analysis/lineexe1-run.log`)
- `LINE.exe` (x64, 31 MB, sha256 ce2f4b88…548447) and `LineAppMgr.exe` are **Themida-protected**
  (`.themida` + `.boot` sections). The check's strings are not in any file on disk (encrypted inside
  Themida), so static decompilation isn't practical. LineLauncher/LineUpdater/LineConnector/LineDiag
  are not protected; LineUpdater only has OpenSSL + WinVerifyTrust strings (not the same module).
- Observed at runtime with `WINEDEBUG=+wintrust,+loaddll` (thread of LINE.exe):
  1. ~70 DLLs are loaded first (Wine builtins + Qt6 etc.) without any check
  2. `WinVerifyTrust` on `…\LINE\bin\26.6.0.4004\libcrypto-1_1-x64.dll` (not loaded yet) → 0 (LY-signed)
  3. `WinVerifyTrust` on `C:\windows\system32\CRYPT32.dll` → TRUST_E_NOSIGNATURE, then the same
     catalog fallback as the installer (`CryptCATAdminCalcHashFromFileHandle` on the **file on disk**,
     SHA1, `CryptCATAdminEnumCatalogFromHash`) → no match → dialog, stops at the first failure
- libcrypto/libssl don't import CRYPT32; only LineLauncher/LineUpdater do. So LINE.exe checks its own
  list of files (libcrypto first, then CRYPT32, …), apparently before loading them. Entries after
  CRYPT32 are unknown until CRYPT32 passes.
- "Restore binary": LineLauncher runs `LineUpdater.exe --restore 0 th real`, which re-downloads the full
  `LINE.zip`, redeploys `bin\26.6.0.4004\` and relaunches → same failure (loop on every start).
- Test bottle `LINE-repro`: both `LineUpdater.exe` copies (`LINE\bin\` and `LINE\bin\26.6.0.4004\`) set to
  `chmod 000` (user's request) so the "Restore binary" step can't re-download/overwrite LINE's files
  between probes. Undo with `chmod 755`. If LINE.exe itself verifies LineUpdater.exe, that check will
  now fail on read — watch for it in the probe output.

## "On-disk" MS DLLs for LINE.exe — works (2026-11-25, LINE-repro, logs `analysis/lineexe*-run.log`, `lineexe-loop*.log`)
Hypothesis confirmed: LINE.exe hashes the **file on disk** at `C:\windows\system32\<name>.dll`.
Placing the genuine Win11 (26100.9457) x64 DLL there while forcing `DllOverrides <name>=builtin`
keeps Wine's own code running (loaddll shows `builtin`) and the check passes.
`scripts/install_ondisk_ms_dlls.sh` does it (extracts from install.wim, finds the catalog, saves the
Wine placeholder to `analysis/ondisk-backup/<bottle>/`); `scripts/probe_lineexe.sh` runs one probe.

LINE.exe's full check list (order observed; all pass now):
| # | File | How it passes |
|---|---|---|
| 1 | `LINE\bin\26.6.0.4004\libcrypto-1_1-x64.dll` | LY Corporation signature (shipped) |
| 2 | `system32\CRYPT32.dll` | on-disk Win11, embedded signature |
| 3 | `LINE\bin\LineLauncher.exe` / `LineUpdater.exe` | LY signature (shipped) |
| 4 | `system32\WINHTTP.dll` | on-disk Win11, embedded |
| 5 | `system32\VERSION.dll` | on-disk Win11 |
| 6 | `system32\USERENV.dll` | on-disk Win11 |
| 7 | `system32\dwmapi.dll` | on-disk Win11, embedded |
| 8 | `system32\MSIMG32.dll` | on-disk Win11, catalog `Microsoft-Windows-Client-Desktop-Required-Package0415…9457.cat` |
| 9 | `LINE\bin\26.6.0.4004\libssl-1_1-x64.dll` | LY signature (shipped) |
Catalogs used: OneCore-CoreSystem-Core-merged …9457 + Client-Desktop-Required-Package0415 …9457 (amd64).
Files kept in `ms-dlls/x64-ondisk/`.

After the checks LINE.exe continues normally: `LineConnector.exe --register` (runs
`powershell -c "get-appxpackage -name LINE | remove-appxpackage"`, exit 3), loads Qt `qwindows` +
imageformats, starts `LineUpdater.exe --update 26.6.0.4004 th real 0` (exit 1, LineUpdater is chmod 000)
and stays running (no dialog after 60 s+).
- End-to-end check: `scripts/setup_line_bottle.sh LINE-e2e --run` on a brand-new bottle → LINE installed,
  LINE.exe started with no signature dialog, LineUpdater locked (`analysis/setup-LINE-e2e.out`, `setup-LINE-e2e-run.log`).
- Applied to the main `LINE` bottle (2026-11-25): `install_ondisk_ms_dlls.sh LINE` + `lock_line_updater.sh LINE`;
  probe `analysis/lineexe-main1.log` shows all 9 checks passing, LINE.exe runs (`lineexe-main-ui.log`).
- Gotcha fixed in the script: overrides must be set BEFORE copying native files into system32, otherwise
  any Wine process (even `reg.exe`) loads the native DLL; native userenv then aborts on `profapi.dll.101`.
- DllOverrides are per-name for both bitnesses, so dwmapi/msimg32/winhttp are now `builtin` for the 32-bit
  installer as well (the syswow64 MS files then act as "on-disk" too). LINE-e2e proved the installer still works.

## Interactive usage testing started (2026-11-25, 22:47 Asia/Bangkok)
- Selected test bottle: `LINE-repro`. An existing `LINE.exe` process (host PID 38798) is running there; a separate process (40556) belongs to `LINE-e2e`. Neither process was restarted or terminated.
- REA `capture_process_scenario` ran a read-only Python probe of these selected processes. Evidence: `ev_67dfbfac63558cdc9b9fa1aa5a8446cee714274126b44dcbeab64dff8913c51b`, saved in `analysis/runtime-prelogin-20261125.rea.json`. The capture owns only the short-lived probe, not either LINE process.
- Existing stderr log for LINE-repro: `analysis/lineexe-ui1.log`. A bounded diagnostic search found no `Unhandled`, `unimplemented function`, `Security verification failed`, `Restore binary`, or `MSGBOX_OnInit` matches in that log. This does not establish successful login or absence of other errors.
- Both copies of `LineUpdater.exe` in LINE-repro still have mode `000`. Bottles declares network, PulseAudio, X11/Wayland and device access; actual sound/camera functionality remains untested.
- REA native UI observation is unavailable on this Linux host (macOS-only); no desktop control connector is exposed. X11 window-property discovery returned no matching LINE window. Current visible UI and authentication state remain unknown; user confirmation is pending.
- Next checks, in order: user completes login; text send/receive (prefer Keep Memo or a user-chosen test chat); image/file send and download; sticker rendering; notifications while unfocused; audio call and video call with a willing test contact. All functional outcomes remain **untested** until observed or reported by the user. Sending messages and initiating calls require the user to choose the destination and action.
- User reported no visible LINE window and requested killing all LINE processes and reopening. Fresh `flatpak run ... wineserver -k` attempts returned exit 1 without stopping the old processes. REA then terminated processes with an exact `WINEPREFIX` match to LINE/LINE-repro/LINE-e2e (SIGTERM, then identity-checked SIGKILL for two remaining winedevice processes); the final prefix scan was empty. Evidence: `ev_22a98f6db7984e335d1c23db6c84dc5cd46488d970c9362497dea3a831e3131b`, saved as `analysis/runtime-restart-kill-20261125.rea.json`. REA reported an unverified capture-owned process (PID 51686, EACCES reading environ); the scan is not proof of cleanup outside the selected Wine prefixes.
- Reopened only LINE-repro through LineLauncher; new LINE.exe host PID 51783. Fresh log: `analysis/lineexe-login-restart-20261125.log`. Initial diagnostic search found no signature/restore dialog or unhandled/unimplemented-function match. Visible window and login result still require user confirmation.
- The user's first screenshot showed `MFPlat.DLL — NO_SIGNATURE`, also captured in `analysis/lineexe-login-restart-20261125.log:12591`. REA found no embedded signature table in the Wine DLL (same SHA-256 as the runner, evidence `ev_8cb20d075f3cdb6dc6567745b9dc0ecabc5281698a775109cc997d02a98fe5ba`). The Windows 11 26100.9457 x64 DLL from local `install.wim` image 1 has an embedded PKCS#7 record (`ev_05a0ff580906ab6d1c242c237a893cb257d2121a1ffed8bffec331b75869ce13`). Installed via `install_ondisk_ms_dlls.sh LINE-repro mfplat`. The subsequent LINE trace shows MFPlat loaded as builtin and its file verification returning `00000000` (`analysis/lineexe-login-mfplat-20261125.log:40617`). A separate Wine trust probe agreed (`analysis/mfplat-winverifytrust-20261125.log`).
- The second screenshot showed `dxgi.dll — NO_SIGNATURE`, also captured at `analysis/lineexe-login-mfplat-20261125.log:88308`. REA found no embedded table in the Wine DLL (`ev_9406f0ffd8a99f3961b3cce05e54c9a65cd760dc05097482768acabd7def4f1b`); the x64 copy from the same Windows image contains PKCS#7 (`ev_527cdbe183f1a504f226c07d67557802889842e42241712bb9ae4eb50120fe5d`) and its Authenticode digest matches the existing Package0415 catalog. Installed via `install_ondisk_ms_dlls.sh LINE-repro dxgi`. REA captured a separate `WinVerifyTrust` probe against the installed DXGI file in this prefix returning `0x00000000` (revocation checks omitted, evidence `ev_f54c83bf77733b14416c78fdd2f6cb160cd5814372f2a505b65256e4ae3ed004` saved in `analysis/runtime-dxgi-winverifytrust-20261125.rea.json`). LINE was restarted with `analysis/lineexe-login-dxgi-20261125.log` for the user's retry. Login and later features remain unconfirmed.
- Both Microsoft DLLs are cached in `ms-dlls/x64-ondisk/` and its `SHA256SUMS`. Wine copies are in `analysis/ondisk-backup/LINE-repro/`. The two new DLLs were applied to LINE-repro only. The setup script's existing default DLL inventory includes them on future runs. The handoff archive has not been rebuilt.
- On the restart with both DLLs, LINE's own `WinVerifyTrust` calls returned `00000000` for MFPlat and DXGI (`analysis/lineexe-login-dxgi-20261125.log:40617` and `:40696`). The LINE window remained open and the log contained no new `MSGBOX_OnInit` line at the time of inspection.
- The user confirmed LINE in `LINE-repro` was working after that restart (2026-11-25). No individual results were reported for chat, images/files, stickers, notifications, or audio/video calls.

## Emoji fonts in LINE-repro (2026-11-26)

- REA showed LINE's shipped `Qt6Gui.dll` imports `DWriteCreateFactory` from `DWrite.dll` (`ev_5097cd5ef698e85d11efb43e3f1daa21d947d06daab3247331276fe76f396aee`). The launch log `analysis/line-emoji-launch-20261126.log` shows the LINE process loading Wine's builtin DWrite.
- A small DirectWrite probe under the same runner and bottle found that the three emoji/symbol families were absent from the system collection despite their files being in `C:\windows\Fonts` (`analysis/line-emoji-dwrite-before-20261126.log`). Wine builds the DirectWrite collection from `HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts`, so the three existing files were registered there by filename.
- The repeated probe found all three families, each with a glyph for U+1F52E, U+1F525 and U+1F64F (`analysis/line-emoji-dwrite-after-20261126.log`). `IDWriteFactory2::TranslateColorGlyphRun` succeeded for all three glyphs with Segoe UI Emoji and returned no color layers with Noto Color Emoji and Segoe UI Symbol in that particular API. This probe does not establish which font LINE selects or what it draws in the chat. LINE was reopened and the original message awaits visual confirmation.
- The user saw no icons after the first restart. A second probe of `IDWriteFontFallback::MapCharacters` in the running bottle, with base family Tahoma and locale `th-TH`, mapped none of the three characters (`analysis/line-emoji-fallback-before-20261126.log`). Wine's built-in mapping for this range names Noto Sans Symbols2, Noto Sans Symbols 2 and Noto Emoji. The latter was missing. Installed the monochrome Noto Emoji from Google Fonts as `C:\windows\Fonts\NotoEmoji.ttf` (SHA-256 `de6c18832938afc99caf132b39d6a30a19bac7f2e812e28db2535b4608d27551`) and registered it under the same Fonts key. A fresh probe in the same running bottle selected Noto Emoji for all three (`analysis/line-emoji-fallback-after-20261126.log`). The active chat was left open for the user. LINE must be reopened to verify its own rendering with the new font.
- The user subsequently reported that pasted 🔮🔥🙏 were blank in the composer as well. A synthetic QPainter probe using LINE's own Qt 6.6.3 DLLs and Windows platform plugin reproduced the blanks with the native backend for the tested UI fonts. Selecting `fontengine=directwrite` through `[Platforms] WindowsArguments` in the probe's `qt.conf` drew all three icons in monochrome and retained Thai rendering. Side-by-side source images are `analysis/line-emoji-qt-native-20261126.png` and `analysis/line-emoji-qt-directwrite-20261126.png`. The first test's platform-plugin dialog came from the probe and was dismissed by stopping its isolated Flatpak instance. The successful probe staged the same Qt binaries and platform plugin together.
- Added that `qt.conf` beside `LINE.exe` in `LINE-repro` and launched LINE again (`analysis/line-emoji-qt-directwrite-launch-20261126.log`). This change is scoped to the app runtime directory. The user confirmed success on 2026-11-26 and supplied a screenshot showing monochrome 🔮🔥🙏 in both the original message and the composer. The handoff records how to reproduce the change for a new app version.

## Wine compatibility patch for Qt color emoji (2026-11-26)

- The raw DirectWrite probe confirmed `TranslateColorGlyphRun` succeeds for the three Segoe UI Emoji characters, but `GetCurrentRun` initially returns `E_NOT_VALID_STATE` until a `MoveNext` call. Qt 6.6.3 calls `GetCurrentRun` first in its Windows color glyph renderer. Qt's opt-in DirectWrite font database did not activate that color path in the synthetic tests. The native font database did.
- Patch `0004` primes the legacy color enumerator on the first `GetCurrentRun` only for executables opted in via `HKCU\Software\Wine\AppDefaults\<exe>\DirectWrite`, DWORD `PrimeColorGlyphRun=1`. MoveNext-first remains valid and exhaustion never re-primes. Both sequences returned identical color layer counts (8, 4, 4 for the three glyphs). With the new DLL and native font mode, the QPainter test using LINE's Qt 6.6.3 and Segoe UI Emoji produced colored pixels for all three in the real LINE-repro prefix. Evidence: `analysis/line-emoji-dwrite-patch-opt-in-20261126.log` and `analysis/line-emoji-color-patch-20261126.png`. The REA import evidence for the built PE is `ev_beeeddb945f0e4fbb3f9807558d8fbb616f5fc43673b3f45e43a2e8f7e0e3233`.
- Installed the patched x64 `dwrite.dll` into the custom runner and the matching prefix copy, left the original runner hash intact, and opted in only `LINE.exe`. Set its `qt.conf` to `fontengine=native` for the next launch. Backups are in `analysis/dwrite-backup/LINE-repro/`. The running LINE process was left open. Color in LINE's actual chat has not yet been observed after a restart.
- After the user closed LINE, launched it again and verified that PID 58998 mapped the patched x64 `dwrite.dll` from `soda-11.0-10-line` (`analysis/line-emoji-color-patch-launch-20261126.LU40Z9.log`). The opt-in DWORD and native font mode persisted. Visual confirmation in LINE remains pending.
## Fresh build and sign-in readiness (2026-11-27)

- Built the release in new workspaces with network isolation. The snapshot route and the `--installed-line-dir` route both produced the verified `.run` hash. The latter used a program-only directory fixture, generated the pinned install-language setting, and rejected an altered `LINE.exe`. [Rebuild log](fresh-rebuild-20261127.log)
- Installed the same `.run` in a Debian 13.8 Slim rootfs with loopback only, then launched the installed `line-offline` as UID 1000 using the host network in a separate namespace setup. LINE displayed the pre-authentication QR pattern on isolated Xvfb. The test saved summary output and left account confirmation to the user. [Readiness log](fresh-login-readiness-20261127.log)
