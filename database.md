# โครงสร้างฐานข้อมูล (Database Structure) - KMUTNB Shuttle Tracker
**🚨 AI Assistant & Developer Rules:**
1. **Always read this file (`database.md`) before analyzing, designing, or implementing any features that require database connectivity.**
2. **Strictly adhere to the database schema and structure defined in this file.** Do not invent new collections, fields, or modify existing data types without permission.

โปรเจคนี้ใช้ฐานข้อมูล Firebase 2 ประเภทควบคู่กัน เพื่อประสิทธิภาพสูงสุดและควบคุมให้อยู่ในโควต้าการใช้งานฟรี (Spark Plan)

---

## 1. Cloud Firestore
ใช้สำหรับเก็บข้อมูลโครงสร้าง ประวัติ และผู้ใช้งาน (ข้อมูลที่ไม่มีการเปลี่ยนแปลงบ่อยระดับวินาที และต้องการการค้นหาที่ซับซ้อน)

### Collection: `users` (ข้อมูลสมาชิกทั้งหมด)
* `uid`: (Document ID จาก Firebase Auth)
* `username`: (String) รหัสนักศึกษา หรือรหัสพนักงาน เช่น "s6706021410516"
* `role`: (String) สิทธิ์การใช้งาน "student" | "driver" | "admin"
* `name`: (String) ชื่อ-นามสกุล เช่น "จิดาภา ทีปรักษพันธ์"
* `phone`: (String) เบอร์โทรศัพท์ (เว้นว่างได้ถ้าเป็นนักศึกษา)
* `created_at`: (Timestamp) เวลาที่สมัครสมาชิก
* `fcm_token`: (String) รหัสประจำเครื่องสำหรับใช้ส่งแจ้งเตือน (Push Notification)
* **`status`: (Bolean) สถานะบัญชีผู้ใช้ "active" (ใช้งานปกติ) | "inactive" (ระงับการใช้งาน)**

### Collection: `buses` (ข้อมูลรถรับส่ง)
* `bus_id`: (Document ID) เช่น "bus_01"
* `license_plate`: (String) ป้ายทะเบียนรถ เช่น "ฮภ 1234"
* `driver_id`: (String) อ้างอิง uid ของคนขับจากคอลเลกชัน users
* `status`: (String) สถานะรถ "พร้อมให้บริการ" | "หยุดให้บริการ" | "ซ่อมบำรุง" | "เติมน้ำมัน"

### Collection: `schedules` (ตารางเวลารอบรถ)
* `schedule_id`: (Document ID)
* `bus_id`: (String) อ้างอิง ID ของรถที่จะวิ่งในรอบนี้
* `start_time`: (String) เวลาเริ่มวิ่ง เช่น "08:00"
* `end_time`: (String) เวลาสิ้นสุด เช่น "08:30"
* `route_name`: (String) ชื่อเส้นทาง เช่น "สายใน"

### Collection: `ticket_reports` (รายงานจำนวนตั๋วกระดาษรายวัน)
* `report_id`: (Document ID)
* `driver_id`: (String) อ้างอิง uid ของคนขับ
* `bus_id`: (String) อ้างอิง ID รถ
* `ticket_count`: (Number) จำนวนตั๋วที่เก็บได้ เช่น 45
* `round_time`: (String) รอบเวลาที่ขับ เช่น "08:00"
* `timestamp`: (Timestamp) วันและเวลาที่ส่งรายงาน

### Collection: `issue_reports` (การแจ้งปัญหาจากนักศึกษา)
* `issue_id`: (Document ID)
* `student_id`: (String) อ้างอิง uid ของนักศึกษา
* `topic`: (String) หัวข้อปัญหา เช่น "รถไม่มาตรงเวลา"
* `description`: (String) รายละเอียดปัญหา
* `status`: (String) สถานะการแก้ปัญหา "pending" (รอดำเนินการ) | "resolved" (แก้ไขแล้ว)
* `timestamp`: (Timestamp) วันและเวลาที่แจ้งเรื่อง

---

## 2. Firebase Realtime Database
ใช้สำหรับรับข้อมูลพิกัด GPS จากบอร์ด ESP8266 บนรถแบบเรียลไทม์ (อัปเดตทุก 3-5 วินาที)

### JSON Tree Structure:
```json
{
  "tracking": {
    "bus_01": {
      "lat": 13.819054,
      "lng": 100.514210,
      "speed": 35.5,
      "status": "พร้อมให้บริการ",
      "driver_id": "uid_ของคนขับ",
      "last_updated": 1710332282000 
    },
    "bus_02": {
      "lat": 13.820120,
      "lng": 100.515530,
      "speed": 0,
      "status": "เติมน้ำมัน",
      "driver_id": "uid_ของคนขับ",
      "last_updated": 1710332281000
    }
  }
}