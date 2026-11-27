---
name: line-offline-install
description: Reproduce LINE 26.6.0.4004 on fresh Debian. Use to build the patched Wine runtime from pinned upstream sources and create the offline installer, restore the archived LINE inputs, verify Thai and fullwidth text with color emoji, and guide the user through LINE account confirmation.
---

# ทำ LINE บน Linux ใหม่ตั้งแต่ต้นจนเข้าบัญชี

เริ่มที่ Debian 13 amd64 เปล่า ใช้ Debian 13.8 Slim ของโปรเจกต์เป็นฐานทดสอบ ตัวติดตั้งรุ่นนี้คู่กับ `libc6:amd64` เวอร์ชัน `2.41-12+deb13u5` และใช้ X11 หรือ XWayland ตอนเปิดหน้าต่าง LINE ใช้ Terminal ที่มีสิทธิ์ root สำหรับติดตั้งแพ็กเกจ แล้วใช้บัญชี desktop ปกติเปิดโปรแกรม

## เตรียมวัตถุดิบและประกอบตัวติดตั้ง

เปิด checkout ที่มี `offline/phase1/inventory.json` คืนไฟล์โปรแกรม LINE, ZIP ตัวเล่นสื่อทางการ, DLL และ catalog ที่สกัดไว้, ฟอนต์ไทยและอีโมจิ, `fonts/cjk-fonts/` และแพ็กเกจ Debian จาก archive ตามพาธในคู่มือ เตรียม Soda ฐานและซอร์ส Valve Wine ตามรุ่นที่ตรึงไว้ [ขั้นเตรียมไฟล์](references/rebuild.md)

รัน `offline/phase2/build-runtime.sh` เพื่อ apply แพตช์ บิลด์ DLL และสร้าง Wine runner ในรอบเดียวกับการสร้างตัวติดตั้ง จากนั้นสร้าง payload ด้วย `offline/phase3/build-payload.py --installed-line-dir` โดยชี้ไปที่ `line/installed-program/` ใน archive ที่แตกแล้ว แล้วประกอบ `.run` ด้วย `offline/phase5/build.sh` ตรวจ checksum ของผลลัพธ์รอบนั้นและทวนผลบน Debian ใหม่ [ขั้นตอนสร้างและทดสอบ](references/rebuild.md) · [เหตุผลของแพตช์](../../../patches/README.md)

ถ้ามี `.run` ที่สร้างไว้แล้ว ให้เทียบ SHA-256 กับไฟล์คู่กัน แล้วใช้ขั้นติดตั้งบนเครื่องเปล่าได้ทันที เมื่อโจทย์คือสร้างตัวติดตั้งขึ้นใหม่ ให้รันขั้น build จากวัตถุดิบก่อนเสมอ

## ติดตั้งบน Debian ใหม่

1. ตรวจ `dpkg --print-architecture` และ `dpkg-query -W libc6:amd64` ให้ตรงกับชุดแพ็กเกจ ติดตั้งจาก `.run` ที่ตรวจ checksum แล้ว ใช้ `sudo sh` ตามด้วยพาธไฟล์ ถ้า Terminal เป็น root อยู่แล้วให้ใช้ `sh` ตามด้วยพาธเดียวกัน
2. เปิด `line-offline` จาก desktop ด้วยผู้ใช้ปกติ การเปิดครั้งแรกสร้าง Wine prefix ที่ `${XDG_DATA_HOME:-$HOME/.local/share}/line-offline/wine` แล้วลง LINE พร้อมตัวเล่นสื่อ, DLL overrides, catalog, ฟอนต์ไทย, Noto Sans CJK JP และ Segoe UI Emoji สคริปต์ตั้งให้ Wine ใช้ Noto Sans CJK JP แทน `MS UI Gothic` ในรายการฟอนต์สำรองของ Qt เปิดครั้งต่อไปด้วยบัญชีและตำแหน่งเดิม
3. วาง `ภาษาไทย ｊｕｎｅ 🔮🔥🙏` ในช่องอีเมลของหน้าเข้าสู่ระบบ ตรวจว่าอ่านตัวอักษรไทยและตัวอักษรแบบเต็มความกว้างทั้งสี่ตัวได้ และอีโมจิทั้งสามตัวเป็นสี จากนั้นล้างช่องนั้นก่อนเข้าบัญชี ถ้าต้องยืนยันตัวติดตั้งออฟไลน์จาก Debian เปล่า ให้รันตัวทดสอบตาม [ขั้นตอนสร้างใหม่](references/rebuild.md)

## เข้าสู่ระบบจริงและตรวจผล

1. ใช้ Debian ที่ออกอินเทอร์เน็ตได้สำหรับขั้นนี้ เปิด `line-offline` ใน session เดิม แล้วรอ QR บนหน้าต่าง LINE ถ้า QR หมดอายุให้กดสร้างใหม่ ถ้าใช้ Docker ให้ตรวจว่า container ที่ผู้ใช้จะลงชื่อเข้าใช้มีทางออกเครือข่ายและใช้ profile ที่ตั้งใจเก็บไว้
2. ให้เจ้าของบัญชีสแกน QR จากแอป LINE บนมือถือหลักและกด **เข้าสู่ระบบ** บนเครื่องนั้น หาก PC แสดงรหัสยืนยัน ให้ผู้ใช้กรอกรหัสใน LINE บนมือถือหลัก ถ้า LINE แจ้งให้เปิด **อนุญาตให้เข้าสู่ระบบ** ให้เปิดในหน้า **ตั้งค่า → บัญชี** บนมือถือ แล้วลองใหม่ [คู่มือเข้าสู่ระบบ LINE บน PC](https://help.line.me/line/smartphone?contentId=50001182&lang=th) · [การแก้ปัญหาอนุญาตให้เข้าสู่ระบบ](https://help.line.me/line/chrome/?contentId=50001462&lang=en)
3. ยืนยันจากผู้ใช้หรือหน้าต่างที่ได้รับอนุญาตว่าเปิดถึงรายการแชทของบัญชีจริง ปิด LINE แล้วเปิดจากบัญชี Linux เดิมเพื่อตรวจว่าใช้ข้อมูลใน prefix เดิม ถ้าผู้ใช้เลือกลักษณะเข้าสู่ระบบอัตโนมัติ ให้ยืนยันว่าเปิดกลับมาถึงรายการแชทได้ด้วย

บันทึกสถานะ **พร้อมให้ผู้ใช้ยืนยันบัญชี** เมื่อเห็น QR และบันทึก **ล็อกอินสำเร็จ** เมื่อเห็นรายการแชทจริง เก็บผลที่ไม่เปิดเผย QR รหัสยืนยัน รหัสผ่าน หรือข้อมูลแชท ผลที่พิสูจน์แล้วสำหรับ `.run` รุ่นนี้ครอบคลุมการติดตั้งออฟไลน์ การเปิด LINE ซ้ำ ตัวอักษรไทยและตัวอักษรแบบเต็มความกว้างพร้อมอีโมจิสี และการแสดง QR เมื่อเปิดเครือข่าย [ผลติดตั้งออฟไลน์](../../../offline/phase6/clean-debian-validation.log) · [ผลทดสอบก่อนยืนยันบัญชี](../../../analysis/fresh-login-readiness-20261127.log)
