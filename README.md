# 🎬 ยูซิงค์ (U-Sync) - Real-time YouTube Watch Party App

<p align="center">
  <b>แอปพลิเคชันมือถือ (Android APK) สำหรับดูวิดีโอ YouTube พร้อมกันแบบ Real-time</b><br>
  สตรีมภาพและเสียงตรงจาก YouTube CDN และซิงค์สถานะการเล่นระดับเสี้ยววินาทีผ่าน <b>Firebase Realtime Database</b><br>
  ดีไซน์สไตล์ <b>Neo-Pastel Bento Grid</b> ทันสมัย คลีนตา และใช้งานง่าย
</p>

---

## 📱 ข้อมูล Release APK

* 📍 **โฟลเดอร์เก็บไฟล์:** `/home/zirconx/Documents/U-Sync/release/`
* 📱 **ไฟล์ APK ล่าสุด:** [U-Sync.apk](file:///home/zirconx/Documents/U-Sync/release/U-Sync.apk)
* 📱 **ชื่อแอปบนเครื่อง Android:** **ยูซิงค์**
* ⚡ **สคริปต์คอมไพล์ & ติดตั้ง:** `./build_apk.sh --install`

---

## 🏗️ สถาปัตยกรรมระบบ (System Architecture & Project Structure)

```
lib/
├── main.dart                          # จุดเริ่มต้นแอป, Firebase Init, Tab Navigation (4 Tabs)
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
│   ├── firebase_sync_service.dart     # หัวใจหลัก: จัดการ Realtime DB, ซิงค์เวลา, Presence, 30s Countdown, Owner Reclaim
│   ├── youtube_search_service.dart    # ดึงผลค้นหาคลิป YouTube สด & แปลง URL
│   ├── stats_service.dart             # สถิติการใช้งานจริง, เวลารวม, กราฟสัปดาห์, อวตาร
│   ├── favorites_service.dart         # บันทึกห้องโปรด (SharedPreferences)
│   ├── device_service.dart            # สร้างและจัดเก็บ Device UUID และชื่อเล่น
│   └── url_helper.dart                # ดึง Video ID จากลิงก์ YouTube หลากหลายรูปแบบ
├── screens/
│   ├── home_screen.dart               # แท็บ 1: เมนูหลัก, สร้างห้อง, เข้าห้อง, Rejoin Banner, ห้องโปรด
│   ├── rooms_browser_screen.dart      # แท็บ 2: รายการห้องสด, ตัวนับถอยหลังลบห้อง, ค้นหา/กรอง
│   ├── stats_screen.dart              # แท็บ 3: สถิติดูจริง, กราฟสัปดาห์, ประวัติดู
│   ├── profile_screen.dart            # แท็บ 4: เปลี่ยนชื่อ, เลือก 12 อวตาร, เครดิต ZirconX
│   └── watch_party_screen.dart        # หน้าห้องฉาย: เครื่องเล่น YouTube, แชท, คิวคลิป, สมาชิก, อิโมจิ
└── widgets/
    ├── sync_status_badge.dart         # ป้ายแสดงสถานะการเชื่อมต่อ & ปิง
    ├── floating_reactions.dart        # แอนิเมชันอีโมจิลอยทะลุจอ
    └── youtube_search_modal.dart      # โมดอลค้นหาคลิป YouTube ในแอป
```

---

## 🗄️ โครงสร้างฐานข้อมูล Firebase Realtime Database (RTDB Schema)

โครงสร้างฐานข้อมูลเก็บอยู่ที่ `rooms/{roomId}/` ดังนี้:

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
        "timestamp": 1740000000000,    // Firebase Server Timestamp
        "roomName": "ห้องดูหนังวันหยุด",
        "hostId": "<deviceId>",       // หัวห้องปัจจุบัน (สามารถโอนได้)
        "ownerId": "<deviceId>",      // เจ้าของห้องตัวจริง (ถาวร ไม่เปลี่ยน)
        "isLocked": false,
        "password": "",
        "deleteAt": 1740000030000      // (Optional) เวลาที่จะถูกลบ ถ้าห้องว่าง (30 วินาที)
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

## 🌟 ฟังก์ชันและระบบการทำงานหลัก (Key Mechanisms)

### 1. 🛡️ ระบบจดจำเจ้าของห้อง & สิทธิ์หัวห้อง (Owner vs Host)
* **`ownerId` (เจ้าของห้องถาวร):** บันทึกรหัสเครื่องของผู้สร้างห้อง ไม่มีวันเปลี่ยนแปลง
* **`hostId` (หัวห้องปฏิบัติการ):** ควบคุมการเล่น/ตั้งรหัสผ่าน หากหัวห้องหลุด จะโอนให้สมาชิกคนถัดไปชั่วคราว
* **Owner Reclaim:** เมื่อเจ้าของห้องตัวจริง (`ownerId`) กลับเข้ามาในห้อง ระบบจะ**คืนสิทธิ์หัวห้องให้เจ้าของห้องทันทีโดยอัตโนมัติ**

### 2. ⏳ ระบบนับถอยหลัง 50 วินาทีก่อนลบห้อง (50s Room Deletion Delay)
* เมื่อสมาชิกทุกคนออกจากห้อง (`0 คนออนไลน์`) ห้องจะไม่ถูกลบทันที
* ระบบจะเริ่มนับถอยหลัง 50 วินาที พร้อมเขียน `deleteAt` ลงฐานข้อมูล
* **Rejoin Cancellation:** หากมีผู้ใช้หรือเจ้าของกลับเข้ามาภายใน 50 วินาที → ระบบจะ**ยกเลิกการลบทันที** และห้องจะใช้งานต่อได้ตามปกติ
* แสดงตัวนับถอยหลังแบบเรียลไทม์ทั้งในหน้าแรก (`HomeScreen`) และหน้าสำรวจห้อง (`RoomsBrowserScreen`)

### 3. 🚫 ระบบป้องกันการสร้างห้องซ้ำซ้อน (Rejoin Active Room Protection)
* หากผู้ใช้มีห้องเดิมที่ยังไม่หมดเวลา 50 วินาที ระบบจะล็อกไม่ให้สร้างห้องใหม่เพื่อป้องกันเซิร์ฟเวอร์โหลดเกินและอาการกระตุก
* แสดงแบนเนอร์สีทองบนหน้าแรก แจ้งเตือนเวลาที่เหลือพร้อมปุ่ม **"กลับเข้าห้องเดิม"**

### 4. ⏱️ การคำนวณชดเชยดีเลย์เน็ตเวิร์ก (Latency Compensation)
* คำนวณเวลาจริงของเซิร์ฟเวอร์ด้วย `.info/serverTimeOffset`
* เมื่อคลิปกำลังเล่น จะคำนวณตำแหน่งเวลาเป้าหมาย:
  $$\text{Target Time} = \text{currentTime} + \left(\frac{\text{ServerNow} - \text{timestamp}}{1000}\right) \times \text{playbackRate}$$
* ซิงค์ให้ทุกเครื่องดูตรงกันระดับเสี้ยววินาที

### 5. 🔍 ระบบค้นหาคลิป YouTube ในแอป (Live YouTube Search)
* พิมพ์ค้นหาด้วยชื่อเพลง, ชื่อคลิป หรือศิลปิน มีระบบ Scrape ดึงผลการค้นหาสดพร้อมภาพปกและชื่อคลิป
* รองรับการวางลิงก์ YouTube ทุกประเภท (Desktop, Mobile, Shorts, Live Stream, ID 11 หลัก)

### 6. 📑 คิวคลิปวิดีโอ & เล่นต่อเนื่อง (Playlist Queue & Auto-Advance)
* สมาชิกทุกคนสามารถกดเพิ่มคลิปเข้าคิวส่วนกลางได้
* เมื่อคลิปปัจจุบันเล่นจบ (`PlayerState.ended`) ตัวเล่นจะดึงคลิปแรกในคิวขึ้นมาเล่นต่อให้ทุกคนในห้องโดยอัตโนมัติ

### 7. ⭐ บันทึกห้องโปรด (Favorite Rooms)
* บันทึกห้องที่ชอบลงในเครื่องผ่าน `FavoritesService`
* แสดงในแถบแนวนอนบนหน้าแรก กดเข้าห้องได้ทันที

### 8. 💬 แชทสด & อีโมจิลอย (Reactions & Chat)
* ส่งข้อความแชทสดเก็บประวัติ 50 ข้อความล่าสุด
* ส่ง Reaction (❤️, 🍿, 😂, 🔥, 👏, 😭, 🎬, ✨) เด้งแอนิเมชันลอยบนจอพร้อม Haptic Feedback

### 9. 📊 สถิติการใช้งานจริง 100% (Real Analytics)
* นับเวลาดูสะสมจริงวินาทีต่อวินาทีขณะที่วิดีโอกำลังเล่น
* กราฟแท่งแสดงสถิติการดูแยกรายวันในสัปดาห์ (จันทร์ - อาทิตย์)
* ประวัติการดูคลิปล่าสุด (Watch History)

### 10. 🔒 โหมดรับชมสำหรับผู้ชมทั่วไป (Viewer Mode Lock)
* สมาชิกทั่วไปที่ไม่ใช่หัวห้องจะไม่สามารถกดข้าม (Seek), กรอคลิป (Fast-forward) หรือกดหยุด (Pause) ได้
* มีตัวป้องกันการสัมผัส (Lock Overlay) บนเครื่องเล่นวิดีโอเพื่อรักษาการซิงค์มุมมองให้อ้างอิงตามหัวห้อง 100%
* สมาชิกทั่วไปสามารถแนะนำคลิปเข้าคิว (`+เพิ่มคิวคลิป`) ได้ แต่สิทธิ์การเล่น/เปลี่ยนคลิปทันทีจะสงวนให้หัวห้อง

### 11. 🔄 ระบบรีเฟรช & ซิงค์อัตโนมัติเมื่อสมาชิกเข้าใหม่ (Auto-Sync on Join & Drift Guard)
* เมื่อสมาชิกใหม่เข้าห้อง ระบบจะดึงสถานะล่าสุด (`fetchLatestState`) ทันที พร้อมคำนวณตำแหน่งเวลาเป้าหมายและสั่ง Seek อัตโนมัติ
* มี **Auto-Sync Guard** คอยตรวจจับการคลาดเคลื่อนของเวลา (Drift Check ทุกๆ 2 วินาที) หากเวลาคลาดเคลื่อนเกิน 1 วินาที ระบบจะปรับเวลากลับมาให้ตรงกับหัวห้องโดยอัตโนมัติ

### 12. 🔐 ระบบล็อคห้องส่วนตัวสงวนเฉพาะหัวห้อง (Host-Only Room Lock)
* สิทธิ์การตั้งค่าล็อคห้องและเปลี่ยนรหัสผ่านจะเข้าถึงได้เฉพาะหัวห้อง (`hostId == myDeviceId`) เท่านั้น
* ระบบมี Backend Guard ใน `FirebaseSyncService.toggleRoomLock` ตรวจสอบสิทธิ์กับฐานข้อมูลก่อนบันทึกทุกครั้ง ป้องกันการเข้าถึงโดยไม่ได้รับอนุญาต

### 13. 🔲 เล่นวิดีโอแบบหน้าต่างลอย & พื้นหลัง (Picture-in-Picture / Auto-PiP)
* รองรับโหมดหน้าต่างลอย **Picture-in-Picture (PiP)**: เมื่ออยู่ในห้องดูคลิปแล้วปัดแอปไปหน้าโฮม หรือสลับไปใช้แอปอื่น (เช่น Line, Facebook) วิดีโอและเสียงจะเล่นต่อเนื่องอัตโนมัติบนหน้าต่างลอยขนาด 16:9
* มีปุ่มไอคอนหน้าต่างลอย 🔲 บนแถบเมนูในห้องดูคลิป ให้สามารถกดย่อเป็นหน้าต่างลอยได้ทันทีด้วยตนเอง

### 14. 👤 โปรไฟล์ & เลือก 12 อวตาร (Profile Customization)
* เปลี่ยนชื่อเล่นที่จะแสดงในห้องแชทและรายชื่อสมาชิก
* เลือกภาพอวตารอีโมจิ 12 รูปแบบที่ชอบ

---

## 🧭 การทำงานของ 4 แท็บเมนูหลัก (Navigation Tabs)

| แท็บ | หน้า | รายละเอียดการทำงาน |
| :--- | :--- | :--- |
| 🏠 **แท็บ 1** | `HomeScreen` | เมนูหลัก, สร้างห้องด่วน (สุ่มชื่อ), เข้าห้องด้วยรหัส, Rejoin Banner (นับถอยหลัง 50s), แถบห้องโปรด ⭐, หมวดหมู่แนะนำ |
| 🌐 **แท็บ 2** | `RoomsBrowserScreen` | สำรวจห้องปาร์ตี้ทั้งหมดแบบเรียลไทม์, ตัวนับถอยหลัง 50s ของห้องที่กำลังจะถูกลบ, ค้นหา/กรองห้องสาธารณะ/ล็อค |
| 📊 **แท็บ 3** | `StatsScreen` | สถิติเวลาดูรวมจริง, จำนวนคลิป, Reactions, กราฟสัปดาห์, ประวัติการดูล่าสุด |
| ⚙️ **แท็บ 4** | `ProfileScreen` | แก้ไขชื่อเล่น & เลือก 12 อวตาร, ข้อมูล UUID ประจำเครื่อง, เปิด/ปิดเสียงเอฟเฟกต์, เครดิต ZirconX |

---

## 🛠️ รายการ Dependencies สำคัญ

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.15.2
  firebase_database: ^11.3.10
  youtube_player_flutter: ^9.1.3
  shared_preferences: ^2.3.5
  http: ^1.2.2
  wakelock_plus: ^1.2.10
  fluttertoast: ^8.2.14
```

---

## 👨‍💻 ข้อมูลผู้พัฒนา (Developer)

* **ผู้พัฒนา:** **ZirconX**
* **โปรเจกต์:** U-Sync (ยูซิงค์)
* **ปีที่พัฒนา:** 2026
