# 🎬 ยูซิงค์ (U-Sync) - Real-time YouTube Watch Party App

<p align="center">
  <img src="https://raw.githubusercontent.com/ZXD44/U-Sync/main/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" width="96" height="96" alt="U-Sync Logo"><br>
  <b>แอปพลิเคชันมือถือ (Android APK) สำหรับดูคลิปและฟังเพลง YouTube พร้อมกันแบบ Real-time</b><br>
  สตรีมภาพและเสียงตรงจาก YouTube CDN และซิงค์สถานะการเล่นระดับเสี้ยววินาทีผ่าน <b>Firebase Realtime Database</b><br>
  ดีไซน์สไตล์ <b>Neo-Pastel Bento Grid</b> รองรับทั้ง <b>Light Mode</b> และ <b>Dark Mode</b> สวยงาม ลื่นไหล และประหยัดแบตเตอรี่
</p>

---

## 📱 ข้อมูล Release APK ล่าสุด

* 📍 **โฟลเดอร์เก็บไฟล์:** `/home/zirconx/Documents/U-Sync/release/`
* 📦 **ขนาดไฟล์ APK:** **~34.5 MB** (ลดขนาดลง 37.5% ด้วย R8 ProGuard Shrinking + ABI Filtering)
* 📱 **สถาปัตยกรรม:** ARM64-v8a + ARMv7 (รองรับมือถือ Android ทุกรุ่น)
* 🏷️ **เวอร์ชันล่าสุด:** **v1.0.10**
* 🚀 **ลิงก์ดาวน์โหลด GitHub Release:** [ZXD44/U-Sync Releases](https://github.com/ZXD44/U-Sync/releases)
* ⚡ **สคริปต์คอมไพล์ & ปล่อยเวอร์ชัน:** `./build_apk.sh`

---

## 🌟 ฟังก์ชันและฟีเจอร์เด่น (Key Features)

### 1. ⏱️ ระบบซิงค์วิดีโอแบบไร้รอยต่อ (NTP Server Time Compensation)
* คำนวณเวลาจริงของเซิร์ฟเวอร์ด้วย `.info/serverTimeOffset`
* เมื่อคลิปกำลังเล่น จะคำนวณตำแหน่งเวลาเป้าหมาย:
  $$\text{Target Time} = \text{currentTime} + \left(\frac{\text{ServerNow} - \text{timestamp}}{1000}\right) \times \text{playbackRate}$$
* **Continuous Timeline (เวลาไม่เคยหยุด):** เมื่อพับแอป ดับหน้าจอ หรือออกจากห้องชั่วคราว วิดีโอจะยังคงเดินหน้าต่อไปตามเวลาจริง เมื่อกลับเข้าห้องใหม่จะเล่นต่อทันทีโดยไม่ต้องเริ่มใหม่

### 2. 🛡️ จำกัด 1 คน ต่อ 1 ห้อง (Strict 1 Room Per Device Policy)
* ผู้ใช้แต่ละเครื่องสามารถเป็นเจ้าของห้องได้สูงสุด 1 ห้องในเวลาเดียวกัน
* เมื่อสร้างห้องใหม่ ระบบจะลบห้องเก่าที่เคยสร้างไว้ออกทันทีเพื่อป้องกันห้องค้างและลดภาระเซิร์ฟเวอร์
* มีปุ่ม **"ต้องการสร้างห้องใหม่แทนห้องเดิม"** ในหน้าแรกสำหรับสลับห้องได้ทันที

### 3. ⏳ ระบบนับถอยหลังลบห้องว่าง 10 วินาที (10s Auto-Purge)
* เมื่อสมาชิกทุกคนออกจากห้อง (`0 คนออนไลน์`) ระบบจะเริ่มนับถอยหลัง 10 วินาที
* หากมีคนกลับเข้าห้องภายใน 10 วินาที ระบบจะยกเลิกการลบและใช้งานต่อได้ทันที
* ช่วยให้ฐานข้อมูล Firebase คลีน รวดเร็ว และไม่แลค

### 4. 🌙 รองรับ Light & Dark Mode สมบูรณ์แบบ (Dynamic Theme Engine)
* สลับโหมดสว่าง / โหมดมืดได้ทันทีผ่านปุ่ม Toggle ในหน้าโปรไฟล์
* **Light Mode:** โทนสีพาสเทล Neo-Pastel สดใส สบายตา
* **Dark Mode:** โทนสี Deep Slate / Dark Purple คมชัด ไม่แสบตา และประหยัดแบตเตอรี่หน้าจอ OLED

### 5. 📴 รองรับการฟังเพลงตอนดับหน้าจอ (Screen-off Resilience)
* เพิ่มสิทธิ์ `FOREGROUND_SERVICE` และ `FOREGROUND_SERVICE_MEDIA_PLAYBACK`
* ดักจับวงจรชีวิตแอปด้วย `WidgetsBindingObserver` เมื่อผู้ใช้ล็อกหน้าจอมือถือ ระบบจะไม่ส่งคำสั่ง Pause ไปยังเซิร์ฟเวอร์ และจะ Re-sync เวลาให้ทันทีเมื่อเปิดจอกลับมา

### 6. 🔲 โหมดหน้าต่างลอย (Picture-in-Picture / PiP)
* รองรับหน้าต่างลอยขนาด 16:9 ขณะสลับไปใช้งานแอปพลิเคชันอื่น
* มีปุ่มย่อเป็นหน้าต่างลอยได้ทันทีในหน้าห้องดูคลิป

### 7. 📲 ระบบอัปเดตแอปอัตโนมัติในตัว (In-App Self-Updater)
* ตรวจสอบ Release ล่าสุดจาก GitHub API อัตโนมัติ
* แสดง Changelog รายละเอียดการอัปเดต ดาวน์โหลดไฟล์ APK และเปิดหน้าจอติดตั้งผ่าน Android `FileProvider` ได้ทันที

### 8. 🔍 ค้นหาคลิป YouTube ในแอป (Live YouTube Search)
* ค้นหาคลิปด้วยคีย์เวิร์ดหรือวางลิงก์ YouTube (Desktop, Mobile, Shorts, Video ID)
* เพิ่มคลิปเข้าคิวส่วนกลาง (`Playlist Queue`) พร้อมระบบเล่นคลิปถัดไปอัตโนมัติ

### 9. 💬 แชทสด & ส่ง Reaction เด้งลอย (Live Chat & Emoji Reactions)
* แชทสดแบบเรียลไทม์ (จำกัด 50 ข้อความล่าสุด ป้องกันแรมบวม)
* กดส่ง Reaction (❤️, 🍿, 😂, 🔥, 👏, 😭, 🎬, ✨) แอนิเมชันเด้งลอยทะลุจอพร้อม Haptic Feedback

---

## 🏗️ โครงสร้างโปรเจกต์ (Project Structure)

```
lib/
├── main.dart                          # จุดเริ่มต้นแอป, Firebase Init, Navigation Tabs (4 แท็บ)
├── theme/
│   └── app_theme.dart                 # Neo-Pastel Design Tokens, Colors, Gradients, Typography
├── models/
│   ├── room_state.dart                # สถานะวิดีโอ (videoId, status, currentTime, hostId, ownerId, deleteAt)
│   ├── room_info.dart                 # ข้อมูลสรุปห้องสำหรับ RoomsBrowserScreen
│   ├── member_presence.dart           # สถานะสมาชิก (online, nickname, lastSeen)
│   ├── chat_message.dart              # ข้อความแชทสด (senderId, senderName, text, timestamp)
│   ├── room_reaction.dart             # อีโมจิลอย (emoji, sender, senderName, timestamp)
│   └── queue_item.dart                # ข้อมูลคิววิดีโอ (id, videoId, title, addedBy, addedAt)
├── services/
│   ├── firebase_sync_service.dart     # หัวใจหลัก: จัดการ Realtime DB, ซิงค์เวลา, Presence, 10s Countdown, Owner Reclaim
│   ├── theme_service.dart             # จัดการ Light/Dark Mode Persistence ผ่าน SharedPreferences
│   ├── update_service.dart            # ระบบตรวจสอบและอัปเดตแอปผ่าน GitHub Releases
│   ├── youtube_search_service.dart    # ดึงผลค้นหาคลิป YouTube สด & แปลง URL
│   ├── stats_service.dart             # สถิติการใช้งานจริง, เวลารวม, กราฟสัปดาห์, อวตาร
│   ├── favorites_service.dart         # บันทึกห้องโปรด (SharedPreferences)
│   ├── pip_service.dart               # จัดการ Picture-in-Picture Platform Channel
│   ├── device_service.dart            # สร้างและจัดเก็บ Device UUID และชื่อเล่น
│   └── url_helper.dart                # ดึง Video ID จากลิงก์ YouTube ทุกประเภท
├── screens/
│   ├── home_screen.dart               # แท็บ 1: เมนูหลัก, สร้างห้อง, สลับห้องเดิม, หมวดหมู่ยอดนิยม, ห้องโปรด
│   ├── rooms_browser_screen.dart      # แท็บ 2: รายการห้องสด, แถบ Rejoin ด่วน, ค้นหา/กรองห้อง
│   ├── stats_screen.dart              # แท็บ 3: สถิติดูจริง, กราฟสัปดาห์, ประวัติดู
│   ├── profile_screen.dart            # แท็บ 4: เปลี่ยนชื่อ, สลับธีมมืด/สว่าง, เลือก 12 อวตาร, เครดิต ZirconX
│   └── watch_party_screen.dart        # หน้าห้องฉาย: เครื่องเล่น YouTube, แชท, คิวคลิป, สมาชิก, อิโมจิ, ซับไทย
└── widgets/
    ├── sync_status_badge.dart         # ป้ายแสดงสถานะการเชื่อมต่อ & ปิง
    ├── floating_reactions.dart        # แอนิเมชันอีโมจิลอยทะลุจอ
    └── youtube_search_modal.dart      # โมดอลค้นหาคลิป YouTube ในแอป
```

---

## 🗄️ โครงสร้างฐานข้อมูล Firebase Realtime Database (RTDB Schema)

```json
{
  "rooms": {
    "<roomId>": {
      "state": {
        "videoId": "dQw4w9WgXcQ",
        "status": "PLAYING",           // "PLAYING" | "PAUSED" | "BUFFERING"
        "currentTime": 45.2,          // วินาทีที่เริ่มเล่น/หยุด
        "playbackRate": 1.0,
        "updatedBy": "<deviceId>",
        "timestamp": 1740000000000,    // Firebase Server Timestamp (มิลลิวินาที)
        "roomName": "ห้องดูหนังวันหยุด",
        "hostId": "<deviceId>",       // หัวห้องปัจจุบัน (สามารถโอนได้)
        "ownerId": "<deviceId>",      // เจ้าของห้องตัวจริง (ถาวร ไม่เปลี่ยน)
        "isLocked": false,
        "password": "",
        "deleteAt": 1740000010000      // (Optional) เวลาที่จะถูกลบถ้าห้องว่าง (10 วินาที)
      },
      "members": {
        "<deviceId>": {
          "nickname": "ZirconX",
          "online": true,
          "lastSeen": 1740000000000
        }
      },
      "messages": {
        "<msgId>": {
          "senderId": "<deviceId>",
          "senderName": "ZirconX",
          "text": "สนุกมากเลย!",
          "timestamp": 1740000000000
        }
      },
      "reaction": {
        "emoji": "🔥",
        "sender": "<deviceId>",
        "senderName": "ZirconX",
        "timestamp": 1740000000000
      },
      "queue": {
        "<queueId>": {
          "id": "<queueId>",
          "videoId": "kJQP7kiw5Fk",
          "title": "เพลงใหม่อัปเดต",
          "addedBy": "ZirconX",
          "addedAt": 1740000000000
        }
      }
    }
  }
}
```

---

## 🚀 วิธีการใช้งานสคริปต์ Build & Release (`build_apk.sh`)

สคริปต์แบบ Interactive จัดการทุกกระบวนการในคำสั่งเดียว:

```bash
# เปิดเมนูหลัก
./build_apk.sh

# หรือเรียกใช้งานแบบด่วนด้วย Flag
./build_apk.sh --build    # คอมไพล์ APK ลง release/U-Sync.apk
./build_apk.sh --install  # คอมไพล์และติดตั้งลงมือถือผ่าน USB ADB
./build_apk.sh --github   # สร้างและอัปโหลดขึ้น GitHub Release พร้อมกรอก Release Notes
./build_apk.sh --all      # ทำครบทุกขั้นตอน (Build + GitHub + Install)
```

---

## 🛠️ รายการ Dependencies หลัก

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.15.2
  firebase_database: ^11.3.10
  youtube_player_flutter: ^9.1.3
  wakelock_plus: ^1.2.10
  shared_preferences: ^2.3.5
  http: ^1.2.2
  fluttertoast: ^8.2.14
  uuid: ^4.5.1
```

---

## 👨‍💻 ข้อมูลผู้พัฒนา (Developer)

* **ผู้พัฒนา:** **ZirconX**
* **โปรเจกต์:** U-Sync (ยูซิงค์)
* **เวอร์ชัน:** 1.0.4
* **ปีที่พัฒนา:** 2026
