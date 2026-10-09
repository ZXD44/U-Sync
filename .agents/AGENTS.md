# 🤖 U-Sync Agent Guidelines & Knowledge Base (AGENTS.md)

ไฟล์นี้จัดทำขึ้นเพื่อให้ AI Agent ทุกตัวเข้าใจโครงสร้าง สถาปัตยกรรม กฎเหล็ก และแนวทางการพัฒนาของโปรเจกต์ **ยูซิงค์ (U-Sync)** ได้อย่างถูกต้อง รวดเร็ว และไม่ทำลายระบบเดิม

---

## 📌 1. ภาพรวมโปรเจกต์ (Project Overview)

* **ชื่อแอป:** ยูซิงค์ (U-Sync)
* **ประเภท:** Mobile Application (Flutter / Dart สำหรับ Android)
* **เป้าหมายหลัก:** รับชมวิดีโอและฟังเพลง YouTube พร้อมกันแบบเรียลไทม์ ซิงค์ระดับเสี้ยววินาทีผ่าน Firebase Realtime Database
* **รูปแบบดีไซน์:** Neo-Pastel Bento Grid (รองรับ Dynamic Light & Dark Mode)
* **ขนาด APK เป้าหมาย:** ≤ 35 MB (ใช้ R8 ProGuard + ARM64/ARMv7 ABI Filtering)

---

## 🛡️ 2. กฎเหล็กที่ห้ามทำลาย (Core Invariants & Rules)

### 1. ระบบ Theme (Light / Dark Mode)
* **ห้าม Hardcode สีตายตัว:** ใช้ค่าสีจาก `AppColors` ใน [app_theme.dart](file:///home/zirconx/Documents/U-Sync/lib/theme/app_theme.dart) เท่านั้น เช่น `AppColors.cardBg`, `AppColors.textPrimary`, `AppColors.textSecondary`, `AppColors.background`
* **การรีเฟรชธีม:** ทุกหน้าจอ (`StatefulWidget`) ต้องดักฟัง `ThemeService.isDarkModeNotifier.addListener(_onThemeChanged)` และถอด listener ใน `dispose()` เสมอ

### 2. ระบบซิงค์เวลาวิดีโอ (Continuous Sync Engine)
* **การคำนวณตำแหน่งเวลา:** ใช้ `FirebaseSyncService.calculateCompensatedTime(state)` ซึ่งอิงตาม Server Time Offset เสมอ
* **เวลาเล่นต่อเนื่อง (Continuous Timeline):** เมื่อสถานะเป็น `PLAYING` เวลาจะเดินหน้าต่อไปตามเวลาจริง (Wall-clock) เสมอ แม้ผู้ใช้จะพับแอป ดับหน้าจอ หรือออกจากห้องชั่วคราว
* **ห้ามส่ง `PAUSED` ตอนปิดจอ/ออกห้อง:** ใน `WatchPartyScreen` เมื่อเกิด `AppLifecycleState.paused` หรือใน `dispose()` ต้องมี Flag ป้องกันไม่ให้ส่งคำสั่ง `PAUSED` ไปทับสถานะของห้องบน Firebase

### 3. สิทธิ์หัวห้องและเจ้าของห้อง (Host vs Owner Hierarchy)
* **`ownerId` (เจ้าของห้องถาวร):** บันทึกรหัสเครื่องของผู้สร้างห้อง ไม่มีวันเปลี่ยนแปลง
* **`hostId` (หัวห้องปฏิบัติการ):** ควบคุมการเล่น/ตั้งรหัสผ่าน หากหัวห้องหลุด จะโอนให้สมาชิกคนถัดไปชั่วคราว
* **Owner Reclaim:** เมื่อเจ้าของห้องตัวจริง (`ownerId`) กลับเข้ามาในห้อง ระบบจะคืนสิทธิ์หัวห้องให้เจ้าของห้องทันทีโดยอัตโนมัติ
* **Non-host Viewers:** สมาชิกทั่วไปห้ามส่งคำสั่ง Update State ไปยัง Firebase (ยกเว้นแชท, เพิ่มคิว, รีแอคชัน)

### 4. นโยบาย 1 คน ต่อ 1 ห้อง (Strict 1 Room Per Device)
* แต่ละเครื่องสร้างห้องได้สูงสุด 1 ห้องพร้อมกัน
* เมื่อผู้ใช้สร้างห้องใหม่ ต้องเรียก `cleanOldRoomsForDevice` เพื่อลบห้องเก่าที่ตกค้างของเครื่องนั้นออกทันที
* ปุ่ม "ต้องการสร้างห้องใหม่แทนห้องเดิม" ในหน้าแรก ต้องลบห้องเดิมออกจาก Firebase ทันที

### 5. ระบบนับถอยหลังลบห้องว่าง 10 วินาที (10s Auto-Purge)
* เมื่อสมาชิกเหลือ 0 คน ระบบจะตั้ง `deleteAt = now + 10s`
* เมื่อมีคนกลับเข้าห้อง ต้องลบฟิลด์ `deleteAt` ทันทีเพื่อยกเลิกการนับถอยหลัง

### 6. การซิงค์เลขเวอร์ชัน (Version Synchronization)
* เมื่อเปลี่ยนเลขเวอร์ชัน ต้องอัปเดตทั้ง **3 จุด** ให้ตรงกันเสมอ:
  1. [pubspec.yaml](file:///home/zirconx/Documents/U-Sync/pubspec.yaml) (`version: x.y.z+build`)
  2. [lib/services/update_service.dart](file:///home/zirconx/Documents/U-Sync/lib/services/update_service.dart) (`static const String currentVersion = 'x.y.z';`)
  3. [build_apk.sh](file:///home/zirconx/Documents/U-Sync/build_apk.sh)

### 7. กฎความเร็ว Zero-Delay Sync Engine (Sub-second Invariant)
* **ห้ามใส่ Debounce กับการ Play / Pause:** คำสั่ง `PLAYING` และ `PAUSED` ต้องส่งตรงเข้า Firebase ทันที (`0ms latency`) เพื่อให้ผู้ร่วมห้องตอบสนองทันที
* **เกณฑ์ Drift Threshold ที่ยอมรับได้:** ตั้งค่าไม่เกิน `0.4s` เพื่อรักษาความเป๊ะของการรับชมร่วมกัน
* **Active Guard Interval:** ตรวจสอบความคลาดเคลื่อนทุก `1 วินาที`

### 8. การจัดการ Stream Subscription และ StreamController (Leak & Crash Prevention)
* ทุก `StreamSubscription` ในหน้าจอ ต้องเก็บในตัวแปรและสั่ง `.cancel()` ใน `dispose()` เสมอ
* ทุกครั้งก่อน `_streamController.add(event)` ใน Service ต้องเช็ค `if (!_streamController.isClosed)` เสมอเพื่อป้องกัน Bad state crash ตอนสลับห้องเร็ว

---

## 📂 3. แผนผังโฟลเดอร์และหน้าที่ของแต่ละไฟล์ (Codebase Map)

| ไฟล์ / โฟลเดอร์ | หน้าที่สำคัญ |
|---|---|
| `lib/theme/app_theme.dart` | กำหนด Design Tokens, โทนสีทั้ง Light/Dark, Gradient, Card Shadows |
| `lib/services/firebase_sync_service.dart` | หัวใจหลักของ Realtime DB: จัดการห้อง, Presence, 10s Auto-purge, ซิงค์เวลา NTP |
| `lib/services/theme_service.dart` | จัดการการเปิด/ปิด Dark Mode บันทึกผ่าน `SharedPreferences` |
| `lib/services/update_service.dart` | เช็ก GitHub Releases ล่าสุด, ดาวน์โหลด APK, สั่งติดตั้งผ่าน Android FileProvider |
| `lib/services/stats_service.dart` | บันทึกชั่วโมงดูจริง, กราฟสัปดาห์, จัดเก็บประวัติดูคลิป |
| `lib/services/youtube_search_service.dart` | ค้นหาคลิป YouTube ในแอป และแปลง URL รูปแบบต่างๆ เป็น Video ID 11 หลัก |
| `lib/screens/home_screen.dart` | หน้าแรก: สร้างห้อง, สลับห้องเดิม, หมวดหมู่ยอดนิยม, ห้องโปรด |
| `lib/screens/rooms_browser_screen.dart` | หน้าสำรวจห้องสด: ค้นหา, ฟิลเตอร์ห้อง, แถบ Rejoin ห้องเดิมแบบกะทัดรัด |
| `lib/screens/watch_party_screen.dart` | หน้าห้องฉาย: YouTube Player, Chat, Video Queue, Emoji Reactions, PiP, Subtitles |
| `build_apk.sh` | สคริปต์ Build Release APK (ARM64+ARMv7) และอัปโหลดขึ้น GitHub Release |

---

## 🗄️ 4. Firebase Realtime Database Schema

```json
{
  "rooms": {
    "<roomId>": {
      "state": {
        "videoId": "string",
        "status": "PLAYING | PAUSED | BUFFERING",
        "currentTime": 0.0,
        "playbackRate": 1.0,
        "updatedBy": "<deviceId>",
        "timestamp": 1740000000000,
        "roomName": "string",
        "hostId": "<deviceId>",
        "ownerId": "<deviceId>",
        "isLocked": false,
        "password": "",
        "deleteAt": 1740000010000
      },
      "members": {
        "<deviceId>": {
          "nickname": "string",
          "online": true,
          "lastSeen": 1740000000000
        }
      },
      "messages": {
        "<msgId>": {
          "senderId": "<deviceId>",
          "senderName": "string",
          "text": "string",
          "timestamp": 1740000000000
        }
      },
      "reaction": {
        "emoji": "string",
        "sender": "<deviceId>",
        "senderName": "string",
        "timestamp": 1740000000000
      },
      "queue": {
        "<queueId>": {
          "id": "string",
          "videoId": "string",
          "title": "string",
          "addedBy": "string",
          "addedAt": 1740000000000
        }
      }
    }
  }
}
```

---

## 🛠️ 5. ขั้นตอนการคอมไพล์และทดสอบ (Build & Verification Workflow)

1. **ตรวจสอบความถูกต้องของโค้ด:**
   ```bash
   export PATH="/home/zirconx/development/flutter/bin:$PATH"
   flutter analyze
   ```
2. **คอมไพล์ APK ขนาดกะทัดรัด (ARM64 + ARMv7 พร้อม R8 Shrink):**
   ```bash
   ./build_apk.sh --build
   ```
3. **อัปโหลด Release ขึ้น GitHub:**
   ```bash
   ./build_apk.sh --github
   ```

---

## 💡 6. เช็กลิสต์สำคัญสำหรับ Agent เมื่อแก้ไขโค้ด (Agent Checklist)

* [ ] ตรวจสอบว่าไม่มีการใช้ค่าสีแบบตายตัว (Hardcoded Color) ในหน้าใดๆ
* [ ] ตรวจสอบว่าทุก `Timer` และ `StreamSubscription` มีการสั่ง `.cancel()` ใน `dispose()`
* [ ] ตรวจสอบว่า `WakelockPlus.disable()` และ `PipService.setPartyActive(false)` ถูกเรียกเมื่อออกจากห้อง
* [ ] ตรวจสอบว่า `flutter analyze` ผ่าน 100% ไม่มี warning หรือ error
* [ ] หากมีการเพิ่มฟีเจอร์หรือแก้ไข ให้บันทึกการเปลี่ยนแปลงลงใน [README.md](file:///home/zirconx/Documents/U-Sync/README.md) และปรับเลขเวอร์ชันให้ถูกต้อง
