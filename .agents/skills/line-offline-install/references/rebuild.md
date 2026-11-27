# เตรียมและสร้างตัวติดตั้ง LINE จากต้นทาง

คำสั่งในหน้านี้รันจากโฟลเดอร์หลักของโปรเจกต์ ยกเว้นคำสั่งที่ระบุโฟลเดอร์เอง เครื่อง build ต้องมี Python 3.11 ขึ้นไป, Bash, GNU tar, gzip และ `unzstd` เมื่อใช้ snapshot งานติดตั้งบน Debian เป้าหมายใช้ `sh` กับตัวติดตั้งที่สร้างได้

## 1. รวบรวมไฟล์ที่ต้องพกไป

หลัง clone ให้เติมวัตถุดิบที่เก็บไว้ในเครื่องหรือจัดหาจากแหล่งต้นทางตามตำแหน่งสัมพัทธ์ข้างล่าง ตรวจ SHA-256 จากไฟล์คู่กันหรือบัญชีเฟส 1 เพื่อให้ build บนเครื่องใหม่ได้โดยมีวัตถุดิบชุดเดิม [บัญชีเฟส 1](../../../../offline/phase1/inventory.json)

| วัตถุดิบ | ตำแหน่งในโปรเจกต์ |
|---|---|
| Debian 13.8 Slim `linux/amd64` ที่ตรึงไว้ | `offline/phase1/debian-13-slim-amd64.image.tar` พร้อม `.sha256` ใช้สำหรับทวนผลใน Docker |
| Wine 11.0 ที่เตรียมแล้ว | `offline/phase2/soda-11.0-10-line.runtime.tar.gz` พร้อม `.sha256` |
| แพ็กเกจ Debian amd64 และ i386 | `offline/phase2/runtime-debs/` พร้อม `SHA256SUMS` และ `offline/phase2/install-runtime-debs.sh` |
| DLL และ catalog ของ Microsoft | `ms-dlls/x86/` และ `ms-dlls/x64-ondisk/` |
| ฟอนต์ที่ตรึงไว้ | `offline/phase4/thai-fonts/` และ `offline/phase4/emoji-fonts/` |
| ไฟล์โปรแกรม LINE | เลือก `baseline/post-install/LINE-postinstall.tar.zst` หรือโฟลเดอร์ `AppData/Local/LINE` จากการติดตั้งใหม่พร้อม `offline/phase3/payload-files.sha256` |
| โค้ดประกอบ payload และตัวติดตั้ง | `offline/phase3/build-payload.py`, `offline/phase3/install-line.sh`, `offline/phase5/build.sh`, `offline/phase5/installer.sh.in` และ `offline/phase5/line-offline` |
| โค้ดและแพ็กเกจสำหรับทดสอบ | `offline/phase5/verify.sh`, `offline/phase2/gui-test-debs/` และ `offline/phase4/emoji-test-debs/` |
| ไฟล์สำหรับเดินเส้นทางตัวติดตั้งออนไลน์เดิม | `LineInst.exe`, `scripts/`, `patches/` และ `wine-src/out/` ถ้ามี |

`offline/phase1/debian-13-slim-amd64.image.tar` ใช้ Debian Official Image manifest `sha256:ab3b3c8c5159eebfca4376430132d53c4d425f869c765ecbe47177a030da575d` ถ้าต้องคืนไฟล์จากคลังบนเครือข่าย ให้ดึง digest นี้สำหรับ `linux/amd64` ตั้งชื่อ `line-offline-test:debian-13-slim-amd64` แล้วใช้ `docker save` เพื่อเก็บ image ไว้ใช้แบบออฟไลน์ เปรียบเทียบ manifest ต้นทางกับบัญชีเฟส 1 เมื่อ export tar ใหม่ รายการแพ็กเกจ Debian มีชื่อและเวอร์ชันของ `.deb` ทุกไฟล์ ให้เรียกคืนจาก APT หรือ Debian Snapshot แล้วตรวจแต่ละไฟล์กับ `SHA256SUMS` โดยเฉพาะ `libc6:amd64` กับ `libc6:i386` ที่ต้องตรงเวอร์ชันกัน [แผนแพ็กเกจ Debian](../../../../offline/phase2/combined-runtime-package-plan.txt) · [ผลตรวจ image](../../../../offline/phase1/debian-base-validation.log)

## 2. คืนวัตถุดิบจากการติดตั้งใหม่เมื่อ snapshot หาย

ใช้ขั้นนี้ในสภาพแวดล้อมเตรียมไฟล์ที่ออกอินเทอร์เน็ตได้ หากต้องดาวน์โหลดไฟล์ใหญ่และยังไม่ได้รับอนุญาต ให้แจ้งชื่อ แหล่ง และขนาดก่อน เริ่มจาก `LineInst.exe` ของ LINE รุ่นที่เก็บไว้ในบัญชีเฟส 1 ตัวนี้เรียกตัวติดตั้งจริงผ่านเครือข่าย ผลที่ LINE แจกอาจต่างจากรุ่นที่ตรึงไว้ [ช่องทางดาวน์โหลด LINE](https://line.me/en/download) · [บันทึกทางเทคนิคของตัวติดตั้ง](../../../../analysis/NOTES.md)

1. คืน DLL ที่มีลายเซ็นและ catalog ตามบัญชีเฟส 1 ไฟล์ x64 ใช้ Windows 11 build 26100.9457 จาก `install.wim` ที่ผู้ใช้มีสิทธิ์ใช้ ไฟล์ x86 ใช้ Windows 7 SP1 (`KB976932`) สำหรับ `gdiplus.dll`, Windows 11 `SysWOW64` สำหรับ `dwmapi.dll` กับ `msimg32.dll` และ KB3140245 x86 สำหรับ `winhttp.dll` กับ `webio.dll` ตัวหลังอยู่ใน PA30 delta ที่แตกได้ด้วย `scripts/apply_delta.c` และ `msdelta.dll` ตรวจ hash ของ DLL และ catalog ก่อนวางในตำแหน่งที่กำหนด [แหล่งและรายการ DLL](../../../../offline/phase1/inventory.json) · [สคริปต์หา catalog](../../../../scripts/find_catalog.py)
2. ทางที่ใช้เก็บไฟล์โปรแกรมจากตัวติดตั้งจริงเริ่มจาก Bottles ที่ติดตั้งจาก Flathub และ bottle ชั่วคราวใหม่ ใช้ `LOCK_UPDATER=0 bash scripts/setup_line_bottle.sh LINE-source --run` เมื่อ DLL และ catalog พร้อม สคริปต์เรียก base runner `soda-11.0-10` และประกอบ `soda-11.0-10-line` ก่อนเริ่ม `LineInst.exe` ถ้า `wine-src/out/` หาย ระบบจะ build จาก Valve Wine commit `0509a0b64a4852741364c95bcdc67ae8f74ef11d` ด้วยแพตช์ 0001–0004 ให้เตรียม Git, autoconf, flex, bison, Python, make, GCC, Clang และ lld-link สำหรับขั้นนี้ ใช้ `LOCK_UPDATER=0` เฉพาะ bottle ชั่วคราวที่กำลังเก็บวัตถุดิบ [สคริปต์ติดตั้งจาก bootstrapper](../../../../scripts/setup_line_bottle.sh) · [สคริปต์ build DLL](../../../../scripts/build_wine_dlls.sh)
3. เมื่อโปรแกรมเปิดถึงหน้าเข้าสู่ระบบ ให้ปิด LINE และเลือก `AppData/Local/LINE` ใต้ `~/.var/app/com.usebottles.bottles/data/bottles/bottles/LINE-source/drive_c/users/` ใน bottle ที่เพิ่งสร้าง ไฟล์หลักของรุ่นที่ตรึงไว้คือ `bin/26.6.0.4004/LINE.exe` ใช้พาธโฟลเดอร์ LINE นี้กับ `--installed-line-dir` ในหัวข้อถัดไป หาก hash ของไฟล์โปรแกรมต่างจากที่ตรึงไว้ ให้เก็บสถานะว่าเป็นรุ่นอื่นและเลือกกู้ไฟล์รุ่นเดิมหรือทดสอบรุ่นใหม่เป็นงานอัปเดต
4. การสร้าง `.run` ให้ได้ hash เดิมต้องใช้ Wine archive และ checksum ที่บันทึกไว้ หากต้องแพ็ก runner ที่ build ขึ้นใหม่ ให้คัดเฉพาะโฟลเดอร์ `soda-11.0-10-line` ใต้ `~/.var/app/com.usebottles.bottles/data/bottles/runners/` เป็นไดเรกทอรี `wine` แล้วเก็บ `offline/phase2/soda-11.0-10-line.runtime.tar.gz` โดยรักษา symlink และสิทธิ์ไฟล์เดิม เก็บ checksum และผลทดสอบทั้ง 32 และ 64 บิตของชุดใหม่แยกจากค่าที่ตรึงไว้ใน Git [รายการไฟล์ runner](../../../../offline/phase1/wine-runner-manifest.json) · [ตัวทดสอบ runtime](../../../../offline/phase2/verify.sh)

ฟอนต์ที่ใช้คือ Noto Sans Thai 2.002 Regular/Bold พร้อม `OFL.txt` และ `seguiemj.ttf` จาก Windows ของผู้ใช้ ตรวจ SHA-256 ในทั้งสองโฟลเดอร์ด้วย `sha256sum -c SHA256SUMS` สคริปต์จะลงทะเบียนฟอนต์และตั้ง `fontengine=native` กับ `PrimeColorGlyphRun=1` ใน Wine prefix ใหม่ [ฟอนต์ Noto Sans Thai ต้นทาง](https://github.com/notofonts/thai/releases/tag/NotoSansThai-v2.002) · [OFL.txt ฉบับที่ใช้](https://github.com/notofonts/thai/blob/f8f3f024703f9d939d02f4e2fe16f1d5a39ca963/OFL.txt) · [ขั้นลง LINE และฟอนต์](../../../../offline/phase3/install-line.sh)

## 3. สร้าง payload แล้วประกอบ `.run`

เมื่อใช้ snapshot เดิมที่ SHA-256 ตรงกับบัญชีเฟส 1

```bash
python3 offline/phase3/build-payload.py
bash offline/phase5/build.sh
```

เมื่อใช้ไฟล์จากการติดตั้งใหม่ ให้เก็บ `offline/phase3/payload-files.sha256` ที่ตรึงไว้ แล้วส่งพาธจริงของโฟลเดอร์ `AppData/Local/LINE` ให้ตัว build

```bash
python3 offline/phase3/build-payload.py --installed-line-dir /path/to/AppData/Local/LINE
bash offline/phase5/build.sh
```

ตัว build ตรวจรายการโปรแกรม LINE 184 ไฟล์จาก manifest ใช้ค่า `installLang=th` สำหรับไฟล์ตั้งภาษาติดตั้ง และบรรจุเฉพาะส่วนของโปรแกรมที่ผ่าน hash ไฟล์บัญชีผู้ใช้และ registry ของ bottle เก็บไว้ในเครื่องต้นทาง ตัวติดตั้งรุ่นที่ผ่านการทดสอบอยู่ใต้ `offline/phase5/` พร้อม `.sha256` [หลักฐานสร้างซ้ำในโฟลเดอร์ใหม่](../../../../analysis/fresh-rebuild-20261127.log)

## 4. ทวนผลก่อนส่งไปติดตั้ง

ใช้ Docker Engine และ ImageMagick สำหรับทดสอบด้วย Debian เปล่า

```bash
docker load -i offline/phase1/debian-13-slim-amd64.image.tar
bash offline/phase5/verify.sh offline/phase6
```

ตัวทดสอบคัดลอกเฉพาะ `.run` เข้า container ที่ตัดเครือข่าย จากนั้นเพิ่มเครื่องมือจอทดสอบ ตรวจอีโมจิในช่องอีเมลและเปิดใหม่ด้วย Wine prefix เดิม การยืนยันบัญชีทำใน Debian ที่ต่ออินเทอร์เน็ตได้ตาม [ขั้นเข้าสู่ระบบจริง](../SKILL.md) ใช้ `.run` ไฟล์เดียวเป็นไฟล์สำหรับติดตั้ง และพก checksum คู่กันเมื่อต้องตรวจความสมบูรณ์ [ผลทดสอบติดตั้งออฟไลน์](../../../../offline/phase6/clean-debian-validation.log)

### จุดตรวจเมื่อเจออาการที่เคยพบ

- ถ้าติดตั้งค้างที่เงื่อนไข `libc6` ให้เทียบ `dpkg-query -W libc6:amd64` กับชุด `.deb` ใช้ Debian base ที่ตรึงไว้และรักษาเวอร์ชันของแพ็กเกจ amd64 กับ i386 ให้ตรงกัน
- ถ้าพบ `NO_SIGNATURE` ให้ตรวจชื่อ DLL ในข้อความและ checksum ของ DLL กับ catalog ในชุดที่ตรงสถาปัตยกรรม สคริปต์ติดตั้งตั้งค่า `HKCU\Software\Wine\DllOverrides` ก่อนคัดลอกไฟล์ Microsoft ที่ลงลายเซ็นไว้ ชุดนี้ใช้ `builtin` สำหรับ `crypt32`, `dwmapi`, `dxgi`, `mfplat`, `msimg32`, `userenv`, `version`, `winhttp`, `wininet`, `winmm` และ `native,builtin` สำหรับ `gdiplus`, `webio` [คำสั่งติดตั้ง DLL และ catalog](../../../../offline/phase3/install-line.sh)
- ถ้าภาษาไทยหรืออีโมจิสีผิด ให้ตรวจว่า prefix ใช้ฟอนต์ที่เก็บไว้และไฟล์ `qt.conf` ข้าง `LINE.exe` ตั้ง `fontengine=native` พร้อม `PrimeColorGlyphRun=1` สำหรับ Wine แพตช์ 0004 [การตั้งค่าที่ใช้จริง](../../../../offline/phase3/install-line.sh)
- ถ้าหน้าเข้าสู่ระบบแสดงปัญหาเครือข่าย ให้ตรวจอินเทอร์เน็ตและ DNS จาก Debian ที่รัน LINE แล้วเปิด QR ใหม่ ในรอบทดสอบออฟไลน์ผลที่ต้องเห็นคือหน้าต่าง LINE กับฟอนต์ตามเกณฑ์ รันการยืนยันบัญชีในรอบที่มีเครือข่าย [ผลทดสอบการแสดง QR](../../../../analysis/fresh-login-readiness-20261127.log)
