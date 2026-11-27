# เตรียมและสร้างตัวติดตั้ง LINE จากต้นทาง

คำสั่งในหน้านี้รันจากรากโปรเจกต์ ใช้เครื่อง Linux x86_64 ที่มี Python 3.11 ขึ้นไป, Bash, GNU tar, gzip, xz และ `zstd` สำหรับแตก archive เตรียม Git, autoconf, flex, bison, Perl, make, GCC, Clang, lld-link และ binutils สำหรับบิลด์ Wine ส่วนไดรเวอร์ X11 ใช้ development headers ของ Xlib, Xext, Xfixes, Xrender, Xrandr, XInput, Xinerama, Xcursor, Xcomposite, Xxf86vm, OpenGL และ EGL เลือกเครื่องมือที่สร้างไดรเวอร์สำหรับ glibc 2.41 ของ Debian 13 ได้ ตอนติดตั้งใช้ `sh` กับ `.run` ที่สร้างได้

## 1. รวบรวมไฟล์ต้นทาง

ใช้ checkout ของโปรเจกต์ที่ไฟล์บิลด์ตรงกับรายการใน `project-pins/build-source.sha256` ของ archive คืนไฟล์รุ่นที่อาจหาไม่ได้ภายหลังและไฟล์ที่สกัดจากสื่อติดตั้ง Windows แล้ว ตรวจ SHA-256 ของ archive จากไฟล์คู่กัน และตรวจไฟล์ข้างในด้วย `sha256sum -c SHA256SUMS` หลังแตก archive [บัญชีเฟส 1](../../../../offline/phase1/inventory.json) · [SHA-256 ของ archive ฉบับอัปเดต](../../../../offline/phase1/line-installer-downloads-26.6.0.4004.tar.zst.sha256)

| วัตถุดิบ | ตำแหน่งหรือวิธีใช้ |
|---|---|
| Soda ฐาน `soda-11.0-10` สำหรับ x86_64 | ใช้ `soda-11.0-10-x86_64.tar.xz` จาก upstream release และส่งพาธให้สคริปต์บิลด์ในขั้น 2 [รุ่นและ checksum](../../../../patches/README.md) |
| ซอร์ส Valve Wine | สคริปต์ดึง tag ที่ตรึงไว้ลง `wine-src/valve-wine` เมื่อยังไม่มี checkout ตรวจ commit `0509a0b64a4852741364c95bcdc67ae8f74ef11d` ก่อน apply แพตช์ |
| ไฟล์โปรแกรม LINE | `line/installed-program/` ใน archive ที่แตกแล้ว ใช้กับ `--installed-line-dir` และ `offline/phase3/payload-files.sha256` |
| LineMediaPlayer 1.2.0.662 | ใช้ `line/media-player/LineMediaPlayer-1.2.0.662.zip` จาก archive ที่แตกแล้ว ส่งพาธด้วย `--media-player-zip` หรือคัดลอก ZIP ไปไว้ที่ `baseline/inputs/LineMediaPlayer-1.2.0.662.zip` [SHA-256 ของไฟล์ใน ZIP](../../../../offline/phase3/media-player-files.sha256) |
| DLL และ catalog ของ Microsoft | คืน `microsoft/dlls/x86/` และ `microsoft/dlls/x64-ondisk/` จาก archive ไปที่ `ms-dlls/x86/` และ `ms-dlls/x64-ondisk/` |
| ฟอนต์ | คืน `fonts/thai-fonts/` และ `fonts/emoji-fonts/` จาก archive ไปที่ `offline/phase4/thai-fonts/` และ `offline/phase4/emoji-fonts/` |
| แพ็กเกจ Debian amd64 และ i386 | คืน `debian/runtime-debs/` และ `debian/media-parser-debs/` จาก archive ไปที่โฟลเดอร์ชื่อเดียวกันใต้ `offline/phase2/` พร้อม `SHA256SUMS` ชุดแรกมี Mesa และ GStreamer ชุดหลังเป็นต้นทางของตัวอ่านสตรีม H.264 และ AAC |
| Debian 13.8 Slim `linux/amd64` | คืนไฟล์ใน `debian/base-image/` ไปที่ `offline/phase1/` สำหรับทดสอบใน Docker |
| แพ็กเกจทดสอบ | คืน `debian/gui-test-debs/` ไปที่ `offline/phase2/gui-test-debs/` และ `debian/emoji-test-debs/` ไปที่ `offline/phase4/emoji-test-debs/` |

Debian base ใช้ manifest `sha256:ab3b3c8c5159eebfca4376430132d53c4d425f869c765ecbe47177a030da575d` หากต้องดึง image ใหม่ให้ใช้ digest นี้สำหรับ `linux/amd64` ตั้งชื่อ `line-offline-test:debian-13-slim-amd64` แล้วใช้ `docker save` เก็บไปใช้แบบออฟไลน์ ตรวจเวอร์ชัน `libc6:amd64` กับ `libc6:i386` ให้ตรงกับชุด `.deb` ที่ตรึงไว้ [แผนแพ็กเกจ Debian](../../../../offline/phase2/combined-runtime-package-plan.txt) · [ผลตรวจ image](../../../../offline/phase1/debian-base-validation.log)

ฟอนต์ที่ใช้คือ Noto Sans Thai 2.002 Regular/Bold พร้อม `OFL.txt` และ `seguiemj.ttf` จาก Windows ของผู้ใช้ ตรวจ SHA-256 ในทั้งสองโฟลเดอร์ด้วย `sha256sum -c SHA256SUMS` สคริปต์จะลงทะเบียนฟอนต์และตั้ง `fontengine=native` กับ `PrimeColorGlyphRun=1` ใน Wine prefix ใหม่ [ฟอนต์ Noto Sans Thai ต้นทาง](https://github.com/notofonts/thai/releases/tag/NotoSansThai-v2.002) · [OFL.txt ฉบับที่ใช้](https://github.com/notofonts/thai/blob/f8f3f024703f9d939d02f4e2fe16f1d5a39ca963/OFL.txt) · [ขั้นลง LINE และฟอนต์](../../../../offline/phase3/install-line.sh)

## 2. แพตช์และบิลด์ Wine ในรอบสร้าง `.run`

เตรียม Soda ฐานและ checkout Valve Wine ในขั้นที่มีเครือข่าย จากนั้นรันคำสั่งนี้ สคริปต์ตรวจ SHA-256 ของ Soda และ revision ของ Wine แล้วใช้แพตช์ `0001`–`0005` สร้าง DLL กับ `winex11.so` สำหรับ x86_64 Unix และประกอบ runner ในไดเรกทอรีชั่วคราว ผลลัพธ์คือ `offline/phase2/soda-11.0-10-line.runtime.tar.gz` พร้อม checksum สำหรับบิลด์รอบนี้ [revision และเหตุผลของแพตช์](../../../../patches/README.md)

```bash
bash offline/phase2/build-runtime.sh /path/to/soda-11.0-10-x86_64.tar.xz
```

หลังจัดเตรียมเครื่องมือและซอร์สแล้ว รันขั้น 2–3 แบบตัดเครือข่ายได้ Runner ที่ประกอบแล้วเป็นผลลัพธ์ขั้นกลางของงาน build เก็บแพตช์และวิธีตรวจผลไว้ใน repo

## 3. สร้าง payload แล้วประกอบ `.run`

ใช้พาธ `line/installed-program/` และ ZIP ตัวเล่นจาก archive โดยตรงหลังคืน DLL, catalog, ฟอนต์ และแพ็กเกจ Debian ตามขั้น 1

```bash
archive_dir=/path/to/line-installer-downloads-26.6.0.4004
python3 offline/phase3/build-payload.py \
  --installed-line-dir "$archive_dir/line/installed-program" \
  --media-player-zip "$archive_dir/line/media-player/LineMediaPlayer-1.2.0.662.zip"
bash offline/phase5/build.sh
(cd offline/phase5 && sha256sum -c LINE-offline-26.6.0.4004-linux-x86_64.run.sha256)
```

ตัว build ตรวจไฟล์โปรแกรม LINE 184 ไฟล์และไฟล์ตัวเล่น 130 ไฟล์จาก SHA-256 ที่ตรึงไว้ และใช้ `installLang=th` ผลลัพธ์ `.run` กับ `.sha256` อยู่ใต้ `offline/phase5/` ให้ทดสอบ `.run` รอบนี้ตามขั้น 4 เครื่องมือคอมไพล์และการแพ็กอาจทำให้ checksum ต่างจากชุดอ้างอิงแม้ใช้ซอร์ส revision เดิม [รายการตรวจไฟล์โปรแกรม](../../../../offline/phase3/payload-files.sha256)

## 4. ทวนผลก่อนส่งไปติดตั้ง

ใช้ Docker Engine และ ImageMagick สำหรับทดสอบด้วย Debian เปล่า

```bash
docker load -i offline/phase1/debian-13-slim-amd64.image.tar
bash offline/phase5/verify.sh offline/phase6
```

ตัวทดสอบคัดลอกเฉพาะ `.run` เข้า container ที่ตัดเครือข่าย ตรวจ checksum และไลบรารีของ `winex11.so` กับ WineGStreamer จากนั้นเพิ่มเครื่องมือจอทดสอบ ตรวจอีโมจิในช่องอีเมล และตรวจการลงตัวเล่นทั้งใน Wine prefix ใหม่และ prefix เดิม ตัวทดสอบเปิด `LineMediaPlayer.exe standalone=1` บน Xvfb ที่เปิด GLX เพื่อตรวจการเริ่ม Direct3D 11 การยืนยันบัญชีทำใน Debian ที่ต่ออินเทอร์เน็ตได้ตาม [ขั้นเข้าสู่ระบบจริง](../SKILL.md) [ผลทดสอบติดตั้งออฟไลน์](../../../../offline/phase6/clean-debian-validation.log)

ทดสอบเล่น MP4 โดยลากไฟล์เข้า `LineMediaPlayer.exe standalone=1` บน X11 หรือ XWayland ให้ Qt ใช้ Direct3D 11 ตามค่าเริ่มต้น หากรันใน Docker ให้เชื่อม socket PulseAudio หรือ PipeWire-Pulse ของโฮสต์และกำหนด `PULSE_SERVER` ไปที่ socket ใน container เพื่อทดสอบเสียงกับเดสก์ท็อปจริง

ทดสอบแพตช์ `0005` บน GNOME ที่ใช้ Mutter และ XWayland แยกจาก Xvfb เปิด LINE ด้วย `.run` ที่เพิ่งสร้าง แล้วใช้หน้าต่างอื่นบังและเปิด LINE กลับมาด้านหน้า เงาต้องหายเมื่อถูกบังและกลับมาพร้อมหน้าต่าง LINE [ผลทดสอบเงา](../../../../patches/0005-mutter-xwayland-validation.txt)

### จุดตรวจเมื่อเจออาการที่เคยพบ

- ถ้าติดตั้งค้างที่เงื่อนไข `libc6` ให้เทียบ `dpkg-query -W libc6:amd64` กับชุด `.deb` ใช้ Debian base ที่ตรึงไว้และรักษาเวอร์ชันของแพ็กเกจ amd64 กับ i386 ให้ตรงกัน
- ถ้าพบ `NO_SIGNATURE` ให้ตรวจชื่อ DLL ในข้อความและ checksum ของ DLL กับ catalog ในชุดที่ตรงสถาปัตยกรรม สคริปต์ติดตั้งตั้งค่า `HKCU\Software\Wine\DllOverrides` ก่อนคัดลอกไฟล์ Microsoft ที่ลงลายเซ็นไว้ ชุดนี้ใช้ `builtin` สำหรับ `crypt32`, `dwmapi`, `dxgi`, `mfplat`, `msimg32`, `userenv`, `version`, `winhttp`, `wininet`, `winmm` และ `native,builtin` สำหรับ `gdiplus`, `webio` [คำสั่งติดตั้ง DLL และ catalog](../../../../offline/phase3/install-line.sh)
- ถ้าภาษาไทยหรืออีโมจิสีผิด ให้ตรวจว่า prefix ใช้ฟอนต์ที่เก็บไว้และไฟล์ `qt.conf` ข้าง `LINE.exe` ตั้ง `fontengine=native` พร้อม `PrimeColorGlyphRun=1` สำหรับ Wine แพตช์ 0004 [การตั้งค่าที่ใช้จริง](../../../../offline/phase3/install-line.sh)
- ถ้าหน้าเข้าสู่ระบบแสดงปัญหาเครือข่าย ให้ตรวจอินเทอร์เน็ตและ DNS จาก Debian ที่รัน LINE แล้วเปิด QR ใหม่ ในรอบทดสอบออฟไลน์ผลที่ต้องเห็นคือหน้าต่าง LINE กับฟอนต์ตามเกณฑ์ รันการยืนยันบัญชีในรอบที่มีเครือข่าย [ผลทดสอบการแสดง QR](../../../../analysis/fresh-login-readiness-20261127.log)

## กู้วัตถุดิบเมื่อ archive หาย

ใช้ snapshot `baseline/post-install/LINE-postinstall.tar.zst` ที่ SHA-256 ตรงกับบัญชีเฟส 1 ได้ โดยติดตั้ง `unzstd` แล้วรัน `python3 offline/phase3/build-payload.py` ในขั้น 3 หากมีโฟลเดอร์ `AppData/Local/LINE` จากการลง LINE รุ่นเดียวกันก่อนเข้าบัญชี ให้ส่งพาธนั้นกับ `--installed-line-dir` [บัญชีไฟล์ต้นทาง](../../../../offline/phase1/inventory.json)

การกู้ชุด Windows จากต้นทางใช้ Windows 11 build 26100.9457 จาก `install.wim` image 1, Windows 7 SP1 (`KB976932`) สำหรับ `gdiplus.dll` x86 และ KB3140245 x86 สำหรับ `winhttp.dll` กับ `webio.dll` ใช้ `scripts/apply_delta.c` คู่กับ `msdelta.dll` เมื่อต้องแตก PA30 delta แล้วตรวจ DLL และ catalog กับบัญชีเฟส 1 [บันทึกการสกัดและตรวจไฟล์](../../../../analysis/NOTES.md)

สำหรับเส้นทางติดตั้ง LINE ทางออนไลน์เดิม ใช้ `LOCK_UPDATER=0 bash scripts/setup_line_bottle.sh LINE-source --run` ใน bottle ชั่วคราวเมื่อเตรียม `LineInst.exe`, DLL และ catalog พร้อมแล้ว เซิร์ฟเวอร์เป็นผู้เลือกรุ่นที่จะดาวน์โหลด เมื่อถึงหน้าล็อกอินให้ปิด LINE และตรวจ `AppData/Local/LINE` ของ bottle นั้นกับ manifest ก่อนใช้เป็นวัตถุดิบ [สคริปต์ติดตั้งจาก bootstrapper](../../../../scripts/setup_line_bottle.sh) · [รายการตรวจไฟล์โปรแกรม](../../../../offline/phase3/payload-files.sha256)
