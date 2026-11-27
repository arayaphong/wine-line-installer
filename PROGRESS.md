# LINE on Wine (Bottles): progress

> ถ้าจะทำงานต่อในเครื่องหรือแชทใหม่ ให้เริ่มที่ [README](README.md) และ [ขั้นตอนสร้างตัวติดตั้งใหม่](.agents/skills/line-offline-install/references/rebuild.md)
> (สรุปความรู้ทั้งหมด, คำสั่งตั้งค่าทั้งหมดในคำสั่งเดียว และแผนงานถัดไป)

Last updated: 2026-11-27

## เป้าหมาย
ติดตั้ง LINE ผ่าน Wine ใน Bottles ให้ได้และเปิดใช้งานได้ พร้อมบันทึกว่า LINE ต้องการอะไรบ้าง
(เปรียบเทียบ bottle ก่อนและหลังติดตั้ง) โดยใช้ DLL ของ Microsoft ที่มีลายเซ็นจริง ไม่แพตช์ตัวติดตั้ง
ถ้า Wine มีบั๊กหรือขาดฟังก์ชัน ให้แก้ที่ Wine

## สถานะตอนนี้
- ✅ **ชุดติดตั้งออฟไลน์ เฟส 1:** ตรึง Debian 13.8 Slim x86_64, เก็บ image พร้อม SHA-256 และทดสอบนำเข้ากับเปิด shell แบบแยกเครือข่ายแล้ว บัญชีไฟล์อยู่ใน `offline/phase1/inventory.json`
- ✅ **ชุดติดตั้งออฟไลน์ เฟส 2:** ใช้ Wine 11.0 แบบ standalone บน image เดิม สร้าง prefix `win64` ออฟไลน์ รัน `cmd.exe` ได้ทั้ง `AMD64` และ `x86` และเปิด Notepad บน Xvfb ได้ เก็บ runner และ `.deb` ไว้ใน `offline/phase2/` พร้อม [สคริปต์ตรวจซ้ำ](offline/phase2/verify.sh) และ [บันทึกผล](offline/phase2/standalone-wine-validation.log)
- ✅ **ชุดติดตั้งออฟไลน์ เฟส 3:** สร้างชุดไฟล์ LINE 26.6.0.4004 ขนาด 94.2 MB พร้อม DLL และ catalog ติดตั้งจากไฟล์ใน prefix ใหม่บน Debian ที่ตัดเครือข่าย และเปิดถึงหน้าเข้าสู่ระบบแล้ว [ผลทดสอบ](offline/phase3/debian-line-validation.log) · [ภาพก่อนลงฟอนต์ไทย](offline/phase3/line-startup.png)
- ✅ **ฟอนต์ไทยในชุดติดตั้งออฟไลน์ เฟส 4:** เพิ่ม Noto Sans Thai Regular และ Bold ลง archive ให้สคริปต์ติดตั้งและลงทะเบียนใน Wine prefix อัตโนมัติ ทดสอบแล้วว่าหน้าเข้าสู่ระบบแสดงตัวอักษรไทยบน Debian Slim ที่ตัดเครือข่าย [ผลทดสอบ](offline/phase4/thai-font-validation.log) · [ภาพภาษาไทยใน LINE](offline/phase4/line-startup-thai.png)
- ✅ **อีโมจิสี เฟส 4:** รวม Segoe UI Emoji และตั้งให้ LINE ใช้ `fontengine=native` กับ Wine patch 0004 วาง `🔮🔥🙏` ในช่องอีเมลของหน้าเข้าสู่ระบบแล้วขึ้นเป็นสีครบทั้งสามตัว [ภาพทดสอบ](offline/phase5/line-login-emoji.png)
- ✅ **ตัวติดตั้งออฟไลน์ เฟส 5:** รวมไฟล์เป็น `.run` ไฟล์เดียว ทดสอบติดตั้งบน Debian 13.8 Slim ที่ตัดเครือข่าย เปิด LINE ด้วยผู้ใช้ปกติ และเห็นภาษาไทยกับอีโมจิสี [SHA-256 ของตัวติดตั้ง](offline/phase5/LINE-offline-26.6.0.4004-linux-x86_64.run.sha256) · [ผลทดสอบ](offline/phase5/debian-offline-validation.log)
- ✅ **ยืนยันการติดตั้งจากไฟล์เดียว เฟส 6:** คัดลอก `.run` เข้า Debian 13.8 Slim เปล่าที่ตัดเครือข่ายโดยไม่มี host mount ติดตั้งและเปิด LINE ได้ โปรไฟล์เดิมถูกใช้หลังเปิดใหม่ และ `🔮🔥🙏` เป็นสีทั้งสองรอบ เขียน `SKILL.md` สำหรับทำซ้ำแล้ว [ผลทดสอบ](offline/phase6/clean-debian-validation.log) · [SKILL.md](.agents/skills/line-offline-install/SKILL.md)
- ✅ **ทำซ้ำตั้งแต่ไฟล์ต้นทางจนพร้อมยืนยันบัญชี:** สร้าง `.run` จากโฟลเดอร์ใหม่แล้วได้ hash เดิม ติดตั้งบน Debian ใหม่และเห็น QR เมื่อเปิดเครือข่าย ปรับ skill ให้พาจากวัตถุดิบจนถึงการที่เจ้าของบัญชียืนยันและเห็นรายการแชท [ผลสร้างซ้ำ](analysis/fresh-rebuild-20261127.log) · [ผลก่อนยืนยันบัญชี](analysis/fresh-login-readiness-20261127.log) · [SKILL.md](.agents/skills/line-offline-install/SKILL.md)
- ✅ **ติดตั้งสำเร็จ:** LINE 26.6.0.4004 ลงที่ `C:\users\arme\AppData\Local\LINE` ใน bottle `LINE`
- ✅ **`LINE.exe` เปิดถึงหน้า login แล้ว (ใน `LINE-repro`):** ใช้วิธีวาง DLL x64 ของ Win11 บนดิสก์ (crypt32, winhttp, version, userenv, dwmapi, msimg32)
  ให้ Wine รัน builtin ของตัวเอง และล็อก LineUpdater ด้วย `chmod 000` [บันทึกการทดสอบกับ LINE.exe](analysis/NOTES.md)
- **bottle เดิม `LINE` และ `LINE-e2e`:** เคยทดสอบเปิด LINE.exe ผ่านแล้ว และย้ายไปถังขยะตามคำขอ (2026-11-25)
- ✅ **ผู้ใช้ยืนยันว่า LINE ใน `LINE-repro` ใช้งานได้แล้ว (2026-11-25):** แก้ `NO_SIGNATURE` ด้วย DLL x64 ของ Microsoft สำหรับ `MFPlat.DLL` และ `dxgi.dll` แล้ว LINE ตรวจทั้งสองไฟล์ผ่าน ดู `analysis/lineexe-login-dxgi-20261125.log` ยังไม่มีผลทดสอบแยกตามฟังก์ชัน
- ซิงก์ฟอนต์จาก Fontconfig ของเครื่องลง `C:\windows\Fonts` ใน `LINE-repro` แล้ว (2026-11-25) รวม 1,188 ไฟล์ที่ไม่ซ้ำ มี 270 ไฟล์ที่รองรับภาษาไทย ทดสอบอ่าน Noto Sans Thai และ Noto Sans Thai Looped ผ่านภายใน Bottles Flatpak การแสดงผลใน LINE ยังไม่ได้ทดสอบหลังเปิดโปรแกรมใหม่
- ✅ **แก้อีโมจิเป็นช่องว่างใน `LINE-repro` (2026-11-26):** ลงทะเบียน Noto Emoji รุ่นขาวดำเป็นฟอนต์สำรอง และเพิ่ม `qt.conf` ข้าง `LINE.exe` เพื่อสลับ Qt เป็น DirectWrite ผู้ใช้ยืนยันว่า 🔮🔥🙏 แสดงครบทั้งในข้อความเดิมและช่องพิมพ์ [บันทึกการทดสอบอีโมจิ](analysis/NOTES.md#emoji-fonts-in-line-repro-2026-11-26)
- เพิ่มแพตช์ Wine `0004` และเปิดใช้เฉพาะ `LINE.exe` ใน `LINE-repro` ทดสอบกับ Qt ชุดเดียวกับ LINE แล้ววาด 🔮🔥🙏 เป็นสีได้ในโหมด `fontengine=native` เปิด LINE ใหม่และยืนยันว่าโหลด DLL ที่แพตช์แล้ว รอผลในแชทจริง
- ✅ **มี snapshot ครบ 3 ช่วง:** bottle ว่าง, ก่อนติดตั้ง และหลังติดตั้ง
  (ผลเปรียบเทียบอยู่ที่ `analysis/diff-preinstall-vs-postinstall.txt`)

## สิ่งที่ตัวติดตั้งต้องการ (สรุป)
1. **runner:** `soda-11.0-10-line` = soda-11.0-10 + แก้ Wine (รายละเอียดใน `analysis/NOTES.md` หัวข้อ "Fixing Wine")
   - wintrust: อ่าน catalog ของ Win10/11 ได้ → `patches/0001`
   - secur32: endpoint binding สำหรับใบรับรอง ECDSA-SHA384 → `patches/0003`
   - ntdll/user32/dnsapi (i386): เพิ่ม stub export ที่ DLL ของ Microsoft ต้องเรียก (source เทียบเท่าของ SbSelectProcedure อยู่ที่ `patches/0002`)
2. **DLL 32 บิตของ Microsoft ใน `syswow64`** (`ms-dlls/x86/`) พร้อม catalog:

   | DLL | แหล่ง | ลายเซ็น |
   |---|---|---|
   | gdiplus | Win7 SP1 | catalog foundation-package (SP1) |
   | dwmapi | Win11 26100.9457 | ฝังในไฟล์ |
   | msimg32 | Win11 26100.9457 | catalog Client-Desktop-Required-WOW64 (Win11) |
   | winhttp, webio | KB3140245 (5.1.7601.23375) | catalog package_1_for_kb3140245 |
3. **registry:** `DefaultSecureProtocols=0xA80` (TLS 1.0–1.2) สำหรับ winhttp

## ทำงานต่อ
### สร้างสภาพแวดล้อมใหม่ตั้งแต่ต้น
คำสั่งเดียว: `bash scripts/setup_line_bottle.sh LINE --run` (ทดสอบแล้วกับ bottle ใหม่ `LINE-repro`)
ขั้นตอนข้างล่างคือสิ่งที่สคริปต์ทำ เก็บไว้เผื่อต้องทำทีละขั้น
1. ติดตั้ง runner soda-11.0-10 ผ่าน Bottles
   (หรือใช้ `scripts/bottles_deps.py install-runner soda-11.0-10` ซึ่งต้องคัดลอกสคริปต์ไปไว้ใน temp ของ Bottles ก่อน)
2. build DLL ที่แก้แล้ว (ถ้ายังไม่มีใน `wine-src/out/`):
   ```bash
   cd wine-src/build && make -j16 dlls/wintrust/{i386,x86_64}-windows/wintrust.dll dlls/secur32/{i386,x86_64}-windows/secur32.dll
   ```
   แล้วคัดลอกไปไว้ที่ `wine-src/out/<arch>/`
   - source มาจาก ValveSoftware/wine tag `experimental-wine-bleeding-edge-11.0-428201-20260904-pdf1645-w0509a0-dd7ac25-v35bdee`
     (ฐานของ soda-11.0-10) แล้ว apply `patches/0001` และ `0003`
   - การตั้งค่า build: `autoreconf`, `tools/make_requests`, `tools/make_specfiles`, รัน `dlls/winevulkan/make_vulkan -x vk.xml -X video.xml`
     แล้ว configure ด้วย `--enable-archs=i386,x86_64 --disable-tests --without-x ...` (ใช้ clang + lld-link)
3. `bash scripts/build_line_runner.sh` เพื่อสร้าง runner `soda-11.0-10-line`
4. สร้าง bottle (win64, custom) แล้วตั้ง runner เป็น `soda-11.0-10-line`:
   `bottles-cli edit -b LINE --runner soda-11.0-10-line`
5. `bash scripts/install_ms_dlls.sh LINE`
6. รัน `LineInst.exe` ใน bottle (คำสั่งรันพร้อม log อยู่ด้านล่าง)

### ขั้นต่อไป: ทำให้ LINE.exe เปิดได้
- **วิเคราะห์ `LINE.exe` ด้วย REA:** หาว่าตรวจ DLL ตัวไหนบ้าง (ดูเหมือนตรวจทุก module ที่โหลด ไม่ใช่แค่ delay-load)
  และ "Restore binary process" ทำอะไร
- **DLL 64 บิตที่ต้องมีลายเซ็น:** ถ้าต้องใช้ crypt32 64 บิตที่เซ็นแล้ว แนวทางเดิม (ใช้ DLL ของ MS) อาจเป็นไปไม่ได้
  สำหรับ DLL แกนกลางอย่าง crypt32, kernel32 และ ntdll ต้องตัดสินใจร่วมกับผู้ใช้
- **คำสั่งเปิด LINE:**
  `wine 'C:\users\arme\AppData\Local\LINE\bin\LineLauncher.exe'`

### คำสั่งรันพร้อม log
```bash
D=$HOME/.var/app/com.usebottles.bottles/data/bottles
flatpak run --command=bash com.usebottles.bottles -c "export WINEPREFIX=$D/bottles/LINE WINEDEBUG=+msgbox,+loaddll,+process,+message,err,fixme-all; $D/runners/soda-11.0-10-line/bin/wine $D/temp/LineInst.exe" > analysis/installN-run.log 2>&1
```
- **ดูผล:** `grep -E 'msgbox:MSGBOX|WM_USER\+[13] dispatched|NtCreateUserProcess' analysis/installN-run.log`
- **ปิดโปรแกรมที่ค้าง:** `wineserver -k` ของ runner เดียวกัน

## โครงสร้างไฟล์
| ที่อยู่ | เนื้อหา |
|---|---|
| `LineInst.exe` | ตัวติดตั้งต้นฉบับ (sha256 `5dbceadb…0a2462`) ไม่ได้แก้ไข |
| `analysis/NOTES.md` | ผลวิเคราะห์ทางเทคนิคทั้งหมด |
| `analysis/install*-run.log`, `probe1.log` | log ของการรันแต่ละรอบ |
| `analysis/diff-preinstall-vs-postinstall.txt` | สิ่งที่ LINE ติดตั้ง/เปลี่ยน |
| `baseline/` | snapshot ของ bottle ว่าง (soda-9.0-1) |
| `baseline/pre-install/` | snapshot ก่อนติดตั้ง (soda-11.0-10 + DLL ของ SP1) มีสำเนา SP1 ของผู้ใช้ด้วย |
| `baseline/post-install/` | snapshot หลังติดตั้ง LINE สำเร็จ |
| `ms-dlls/x86/` | DLL และ catalog ที่ลงใน bottle จริง |
| `ms-dlls/x86-win11-alt/` | winhttp/webio และ catalog OneCore ของ Win11 ที่ไม่ได้ใช้ (ต้องพึ่ง internal API ของ Windows มากเกินไป) |
| `ms-dlls/x86-sp1-old/` | winhttp/webio ของ SP1 ที่ถูกแทนด้วย KB3140245 |
| `ms-dlls/source/` | `windows6.1-kb3140245-x86_…msu` |
| `patches/` | patch แบบ source ของ Wine (0001 wintrust, 0002 ntdll, 0003 secur32) |
| `wine-src/valve-wine/` | source ของ Valve Wine ที่ apply patch แล้ว |
| `wine-src/build/` | build tree |
| `wine-src/out/` | DLL ที่ใช้ใน runner (+ `SHA256SUMS`) |
| `README.md` และ `AGENTS.md` | จุดเริ่มต้นสำหรับนำโปรเจกต์ไปทำต่อในเครื่องใหม่ |
| `scripts/setup_line_bottle.sh` | ตั้งค่าทั้งหมดในคำสั่งเดียว (runner, bottle, DLL, รันตัวติดตั้ง) |
| `scripts/build_wine_dlls.sh` | clone และ patch source ของ Valve Wine แล้ว build wintrust/secur32 ไปไว้ที่ `wine-src/out` |
| `scripts/make_handoff_bundle.sh` | ส่งออกซอร์สที่ commit แล้วเป็น `.tar.zst` |
| `scripts/build_line_runner.sh` | สร้าง runner `soda-11.0-10-line` |
| `scripts/install_ondisk_ms_dlls.sh` | วาง DLL x64 ของ MS บนดิสก์ + override builtin (สำหรับการตรวจของ LINE.exe) |
| `scripts/probe_lineexe.sh` | รัน LINE แล้วสรุปไฟล์ที่ตรวจและผลการตรวจ |
| `scripts/lock_line_updater.sh` | `chmod 000`/`755` ให้ LineUpdater.exe |
| `ms-dlls/x64-ondisk/` | DLL x64 ของ Win11 และ catalog สำหรับวางบนดิสก์ |
| `scripts/install_ms_dlls.sh` | ลง DLL/catalog/override/registry ใน bottle |
| `scripts/add_pe_export_stub.py` | เพิ่ม stub export ให้ PE32 DLL |
| `scripts/find_catalog.py` | หาว่า `.cat` ไฟล์ไหนมี Authenticode hash ของ DLL |
| `scripts/diff_snapshots.py` | เปรียบเทียบ snapshot สองชุด |
| `scripts/apply_delta.c`, `scripts/winhttp_probe.c` | เครื่องมือ Windows ที่ build ด้วย winegcc |
| `scripts/bottles_deps.py` | ใช้ backend ของ Bottles (dependency/runner) |

### สิ่งที่อยู่นอกโปรเจกต์ (`~/.var/app/com.usebottles.bottles/data/bottles/`)
- `bottles/LINE-repro`: bottle ที่ใช้งานอยู่ (runner soda-11.0-10-line) ผู้ใช้ยืนยันว่า LINE ใช้งานได้
- `runners/soda-11.0-10`, `runners/soda-11.0-10-line`: runner ต้นฉบับ และ runner ที่แก้แล้ว (hard link กับต้นฉบับ)
- `runners/soda-9.0-1`: runner เดิม ไม่ได้ใช้แล้ว
- `temp/LineInst.exe`, `temp/winhttp_probe.exe`, `temp/bottles_deps.py`: ต้องอยู่ตรงนี้เพราะ flatpak มองไม่เห็น `~/Projects`
- `temp/win11-iso/` (install.wim 7.8GB + extract), `temp/sp1-x86/`, `temp/windows6.1-kb976932-x86.exe`, `temp/kb3140245/`:
  ไฟล์ทำงานชั่วคราว ของที่จำเป็นคัดลอกเข้าโปรเจกต์แล้ว ลบได้

## ข้อควรรู้
- **override อยู่ใน registry:** DLL override ตั้งไว้ใน `HKCU\Software\Wine\DllOverrides` ของ prefix
  ไม่ได้อยู่ใน `bottle.yml` GUI ของ Bottles จึงไม่แสดง
- **ห้ามใช้ Msftedit ของ Microsoft:** ตัวนี้ต้องใช้ msls31 ของจริง และตัวติดตั้งก็ไม่ได้ตรวจลายเซ็น Msftedit
- **ชื่อผู้ใช้ใน prefix:** Temp ของ soda ใช้ชื่อ `steamuser` ส่วนโฟลเดอร์ผู้ใช้เป็น `arme` จึงเห็นทั้งสองชื่อปนกันได้
- **error ที่ไม่ต้องสนใจ:** `xrandr14_get_adapters Failed to get adapters`, `libGLX_nvidia` และ `lsteamclient disabled`
# REA environment repair — 2026-11-25

- Running MCP server: REA 6.8.0; its selected Ghidra 12.2 is outside the supported 12.1.x line, and its Java 17 selection is incompatible.
- Extracted the existing cached package `ghidra-12.1.2-2.1-x86_64_v3.pkg.tar.zst` into `tools/ghidra-12.1.2/`; no download or system package changes.
- `bash scripts/rea.sh doctor --provider ghidra --format json` passes with Ghidra 12.1.2 and `/usr/lib/jvm/java-27-openjdk`.
- A compiled test ELF imported and completed Ghidra auto-analysis. REA's subsequent bridge startup failed at `UnixDomainSockets.bind` with `Operation not permitted` inside this shell sandbox; full REA decompilation is not yet verified.
- `scripts/configure_rea_codex.sh` updates only `GHIDRA_INSTALL_DIR` and `JAVA_HOME` under `[mcp_servers.rea.env]`, with a backup. Checked shell syntax and ran against a temporary copy of the real config; diff changes exactly these two values, and repeat execution makes no changes.
- To apply those settings on a machine using REA with Codex, run `bash scripts/configure_rea_codex.sh` from the project root and reconnect REA or restart Codex. This was optional for Wine diagnostics.
- After reconnecting, check `binary_session` before using Ghidra. The system installation `/opt/ghidra` remains unchanged.

## ตรวจ `CRYPT32.dll` ด้วย REA

- `LINE-repro` และ runner มี `crypt32.dll` x64 ตรงกันที่ SHA-256 `543e5c5ae1f9ccd15c7792478337c924ac473ee8c5598445a5d8418c41973437` ไม่มีตารางลายเซ็น PE และไม่มี hash ตรงใน catalog ที่สแกนจาก Windows image 1
- ใช้ `7zz` ที่ติดมากับ Bottles Flatpak ดึงเฉพาะ `1/Windows/System32/crypt32.dll` จาก `temp/win11-iso/install.wim` โดยไม่ดาวน์โหลดหรือแก้ bottle ไฟล์มี SHA-256 `c720af58976a3624dbc5b74ec4e470d8fec8a4645dc06947906c49e929862dc3` REA พบ PKCS#7 ที่มีใบรับรองระบุ `Microsoft Windows` และ `scripts/find_catalog.py` พบ Authenticode hash ใน `Microsoft-OneCore-CoreSystem-Core-merged-Package~31bf3856ad364e35~amd64~~10.0.26100.9457.cat` ยังไม่ได้ตรวจ certificate chain และ timestamp
- Import จาก `ntdll.dll` ของ Microsoft DLL ขาด 8 export ใน runner ปัจจุบัน ได้แก่ `EvtIntReportEventAndSourceAsync`, `RtlPublishWnfStateData`, `RtlQueryWnfStateData`, `RtlSubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfNotificationWaitForCompletion`, `ShipAssert`, `RtlIsStateSeparationEnabled` และ `EtwEventWriteFull` โปรแกรมทดสอบ `LoadLibraryW` บน prefix ชั่วคราวถูกหยุดที่ `Bad system call` ก่อนเรียก loader จึงไม่มีผลทดสอบรันจริง
- REA ตรวจ `LINE.exe` พบ 87 DLL ในตาราง import ปกติ ไม่มี `CRYPT32.dll` โดยตรง ตาราง delay-load อ่านได้ไม่ครบ ใน `analysis/setup-LINE-repro-run.log` บรรทัด 12187 และ 12361 เห็น updater ถูกเรียกด้วย `--restore` แล้วเปิด launcher ซ้ำ จากนั้นล้มด้วย `NO_SIGNATURE` อีก การวิเคราะห์ว่า LINE เลือก module ใดมาตรวจยังค้างอยู่
- ตรวจ export ซ้ำใน runner `soda-11.0-10` และ `soda-9.0-1` ที่ติดตั้งไว้ ทั้งสองรุ่นขาดฟังก์ชันชุดเดียวกัน
