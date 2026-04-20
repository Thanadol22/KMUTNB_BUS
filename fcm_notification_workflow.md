# ระบบแจ้งเตือน FCM Push Notification — คำสั่งสำหรับ AI ฝั่ง PHP

**โปรเจค:** KMUTNB Shuttle Tracker  
**สถานะ:** ฝั่ง Flutter App เตรียมพร้อมแล้ว ✅ — เหลือฝั่ง PHP Server

---

## บริบทที่ AI ต้องรู้

### ฝั่ง Flutter App (เสร็จแล้ว ✅)
- แอปคนขับจะ **บันทึก `fcm_token` ลง Firestore** ที่ `users/{uid}/fcm_token` อัตโนมัติเมื่อ login
- แอปรับ FCM Push Notification ได้ทั้ง Foreground, Background, และ Terminated
- **ไม่ต้องแก้อะไรฝั่ง Flutter อีก**

### โครงสร้าง Firestore ที่เกี่ยวข้อง

#### Collection: `users`
| ฟิลด์ | ชนิด | ตัวอย่าง | หมายเหตุ |
|--------|------|----------|----------|
| `role` | string | `"driver"` | ใช้กรองเฉพาะคนขับ |
| `fcm_token` | string | `"dK3x..."` | Token สำหรับยิง Push (อัปเดตอัตโนมัติจากแอป) |
| `name` | string | `"สมชาย"` | ชื่อคนขับ |
| `status` | string | `"active"` | ต้องเป็น active เท่านั้น |

#### Collection: `schedules`
| ฟิลด์ | ชนิด | ตัวอย่าง | หมายเหตุ |
|--------|------|----------|----------|
| `bus_id` | string | `"bus_01"` | รหัสรถ |
| `start_time` | string | `"08:00"` | เวลาเริ่มรอบ (HH:mm) |
| `end_time` | string | `"08:25"` | เวลาสิ้นสุดรอบ |
| `route_name` | string | `"สายสองแถว มจพ."` | ชื่อเส้นทาง |

#### Collection: `buses`
| ฟิลด์ | ชนิด | ตัวอย่าง | หมายเหตุ |
|--------|------|----------|----------|
| `bus_id` | string | `"bus_01"` | รหัสรถ |
| `driver_id` | string | `"abc123"` | Document ID ของคนขับใน users collection |
| `license_plate` | string | `"กข 1234"` | ทะเบียนรถ |

---

## งานที่ต้องทำ

### งาน 1: สร้างไฟล์ `check_schedule.php`

สร้างไฟล์ PHP ที่ทำงานดังนี้ เรียงตามลำดับ:

#### ขั้นตอน 1: โหลด Service Account Key
- โหลดไฟล์ `service-account.json` (Firebase Service Account Key)
- ไฟล์นี้อยู่ในโฟลเดอร์เดียวกันกับ `check_schedule.php`
- ใช้ข้อมูลจากไฟล์นี้เพื่อสร้าง OAuth2 Access Token

#### ขั้นตอน 2: สร้าง Access Token (JWT → OAuth2)
- สร้าง JWT (JSON Web Token) ด้วยข้อมูลจาก service account:
  - `iss`: ค่า `client_email` จาก service account
  - `scope`: `https://www.googleapis.com/auth/firebase.messaging`
  - `aud`: `https://oauth2.googleapis.com/token`
  - `iat`: เวลาปัจจุบัน (Unix timestamp)
  - `exp`: เวลาปัจจุบัน + 3600 วินาที
- Sign JWT ด้วย `private_key` จาก service account (RS256 algorithm)
- ส่ง JWT ไปแลก Access Token ที่ `https://oauth2.googleapis.com/token`
  - grant_type: `urn:ietf:params:oauth:grant-type:jwt-bearer`
  - assertion: JWT ที่สร้างขึ้น
- **ใช้ library:** `firebase/php-jwt` (ติดตั้งผ่าน Composer: `composer require firebase/php-jwt`)

#### ขั้นตอน 3: ดึงข้อมูล Schedules จาก Firestore
- ใช้ Firestore REST API: `GET https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/schedules`
- Header: `Authorization: Bearer {ACCESS_TOKEN}`
- Parse response เพื่อดึง `start_time`, `bus_id` ของแต่ละ document

#### ขั้นตอน 4: เปรียบเทียบเวลา
- ตั้ง Timezone เป็น `Asia/Bangkok`
- คำนวณ: `$target_time = date('H:i', strtotime('+15 minutes'))`
- วนลูปเช็คทุก schedule ว่า `start_time == $target_time` หรือไม่
- **สำคัญ:** ใช้ range comparison ±1 นาที เพื่อป้องกัน miss:
  ```php
  $now_plus_14 = date('H:i', strtotime('+14 minutes'));
  $now_plus_16 = date('H:i', strtotime('+16 minutes'));
  // ตรงเงื่อนไขถ้า start_time อยู่ระหว่าง +14 ถึง +16 นาที
  ```

#### ขั้นตอน 5: ค้นหาคนขับ
- เมื่อเจอ schedule ที่ตรงเงื่อนไข:
  1. ดึง `bus_id` จาก schedule
  2. ใช้ Firestore REST API ดึง documents จาก `buses` collection ที่มี `bus_id` ตรงกัน
     - ใช้ Structured Query: `POST https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents:runQuery`
     - Body:
       ```json
       {
         "structuredQuery": {
           "from": [{"collectionId": "buses"}],
           "where": {
             "fieldFilter": {
               "field": {"fieldPath": "bus_id"},
               "op": "EQUAL",
               "value": {"stringValue": "bus_01"}
             }
           }
         }
       }
       ```
  3. ดึง `driver_id` จากผลลัพธ์
  4. ใช้ driver_id ดึง document จาก `users/{driver_id}`
  5. ดึง `fcm_token` จาก document

#### ขั้นตอน 6: ส่ง Push Notification ผ่าน FCM HTTP v1 API
- Endpoint: `POST https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send`
- Header:
  - `Authorization: Bearer {ACCESS_TOKEN}`
  - `Content-Type: application/json`
- Body:
  ```json
  {
    "message": {
      "token": "{FCM_TOKEN_ของคนขับ}",
      "notification": {
        "title": "⏰ เตรียมตัวออกรถ!",
        "body": "รถของคุณมีรอบวิ่งในอีก 15 นาที (รอบ 08:00 - 08:25)"
      },
      "android": {
        "priority": "high",
        "notification": {
          "channel_id": "high_importance_channel",
          "sound": "default"
        }
      }
    }
  }
  ```
- **สำคัญ:** `channel_id` ต้องเป็น `"high_importance_channel"` เพื่อให้ตรงกับ channel ที่แอปตั้งไว้

#### ขั้นตอน 7: บันทึก Log
- บันทึก log ทุกครั้งที่ส่ง notification สำเร็จหรือล้มเหลว
- Response format: JSON ที่มี `status`, `message`, `notifications_sent`

#### โค้ดตัวอย่างโครงสร้างหลัก:
```php
<?php
date_default_timezone_set('Asia/Bangkok');
require_once __DIR__ . '/vendor/autoload.php';

use Firebase\JWT\JWT;

// === 1. โหลด Service Account ===
$serviceAccount = json_decode(file_get_contents(__DIR__ . '/service-account.json'), true);
$projectId = $serviceAccount['project_id'];

// === 2. สร้าง Access Token ===
function getAccessToken($serviceAccount) {
    $now = time();
    $payload = [
        'iss' => $serviceAccount['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging https://www.googleapis.com/auth/datastore',
        'aud' => 'https://oauth2.googleapis.com/token',
        'iat' => $now,
        'exp' => $now + 3600,
    ];
    $jwt = JWT::encode($payload, $serviceAccount['private_key'], 'RS256');
    
    $ch = curl_init('https://oauth2.googleapis.com/token');
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
        'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion' => $jwt,
    ]));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    $response = json_decode(curl_exec($ch), true);
    curl_close($ch);
    
    return $response['access_token'] ?? null;
}

// === 3-6. Logic หลัก ===
$accessToken = getAccessToken($serviceAccount);
// ... ดึง schedules, เปรียบเทียบเวลา, หาคนขับ, ยิง FCM
// (ให้ AI เขียนส่วนที่เหลือตาม Logic ด้านบน)
?>
```

---

### งาน 2: จัดเตรียม Environment บน Server

#### ไฟล์ที่ต้องมีบน Server:
```
/your-project-folder/
├── check_schedule.php          ← ไฟล์หลัก
├── service-account.json        ← Firebase Service Account Key  
├── composer.json               ← สำหรับ firebase/php-jwt
└── vendor/                     ← Dependencies (หลัง composer install)
```

#### คำสั่ง Composer:
```bash
composer require firebase/php-jwt
```

#### ความต้องการของ Server:
- PHP 7.4 ขึ้นไป
- cURL extension เปิดใช้งาน
- OpenSSL extension เปิดใช้งาน
- Composer

---

### งาน 3: ตั้ง Cron Job

#### วิธีที่ 1: ใช้ cron-job.org (แนะนำ — ฟรี)
1. ไปที่ https://cron-job.org → สมัครสมาชิก
2. สร้าง Cron Job ใหม่:
   - **URL:** `https://your-server.com/check_schedule.php`
   - **Schedule:** ทุก 1 นาที (`* * * * *`)
   - **Method:** GET
   - **Timeout:** 30 วินาที
3. เปิดใช้งาน

#### วิธีที่ 2: ใช้ crontab บน Server (ถ้ามี SSH access)
```bash
# แก้ไข crontab
crontab -e

# เพิ่มบรรทัดนี้ (เรียกทุก 1 นาที)
* * * * * /usr/bin/php /path/to/check_schedule.php >> /path/to/cron.log 2>&1
```

---

## การดาวน์โหลด Service Account Key

1. ไปที่ https://console.firebase.google.com
2. เลือกโปรเจค KMUTNB Bus
3. คลิก ⚙️ (Settings) → **Project settings**
4. ไปที่แท็บ **Service accounts**
5. คลิก **Generate new private key**
6. ดาวน์โหลดไฟล์ JSON → เปลี่ยนชื่อเป็น `service-account.json`
7. อัปโหลดไปไว้บน Server ในโฟลเดอร์เดียวกันกับ `check_schedule.php`

> ⚠️ **ห้ามเผยแพร่ไฟล์นี้!** ไม่ควร commit ลง Git หรือวางในที่ public ได้

---

## ผลลัพธ์ที่คาดหวัง

เมื่อทุกอย่างทำงาน:
1. Cron Job เรียก `check_schedule.php` ทุก 1 นาที
2. PHP เช็คว่ามีรอบรถที่จะเริ่มในอีก 15 นาทีหรือไม่
3. ถ้ามี → หาคนขับจาก buses → ดึง fcm_token จาก users
4. ยิง FCM Push Notification → คนขับได้รับแจ้งเตือน "⏰ เตรียมตัวออกรถ!"
5. แอปแสดง Notification ทั้งตอนเปิดอยู่และปิดอยู่