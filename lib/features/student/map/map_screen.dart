import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/utils/mock_data.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // สร้าง Controller สำหรับควบคุมแผนที่ (เช่น การเลื่อนกล้อง)
  final MapController _mapController = MapController();
  
  // พิกัดเริ่มต้นที่คุณต้องการ (14.163687, 101.3628841) มจพ. ปราจีนบุรี
  final LatLng centerLocation = const LatLng(14.163687, 101.3628841);

  // รายชื่ออาคารเป้าหมายใน มจพ. ปราจีนบุรี (ข้อมูลจำลองเส้นทาง)
  final List<Map<String, dynamic>> targetBuildings = [
    {'name': 'อาคารบริหาร (จุดจอด)', 'lat': 14.163687, 'lng': 101.362884},
    {'name': 'คณะวิศวกรรมศาสตร์', 'lat': 14.164300, 'lng': 101.364400},
    {'name': 'หอพักนักศึกษา', 'lat': 14.162000, 'lng': 101.361000},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตำแหน่งรถ (แผนที่)'),
      ),
      body: Stack(
        children: [
          // 1. แผนที่แสดงเต็มจอเป็นพื้นหลัง
          FlutterMap(
            mapController: _mapController, // ผูก Controller
            options: MapOptions(
              initialCenter: centerLocation,
              initialZoom: 16.0, // ขยายภาพออกเล็กน้อยเพื่อให้เห็นภาพรวมรถ
            ),
            children: [
              // แสดงแผนที่จาก OpenStreetMap
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.kmutnb_bus',
              ),
              // วาดเส้นทาง (Polyline) เชื่อมจากตำแหน่งรถไปยังอาคารเป้าหมาย
              PolylineLayer(
                polylines: [
                  if (MockData.buses.isNotEmpty)
                    Polyline(
                      points: [
                        LatLng(MockData.buses[0].latitude, MockData.buses[0].longitude),
                        LatLng(targetBuildings[0]['lat'], targetBuildings[0]['lng']), // รถคันที่ 1 วิ่งมาตึกบริหาร
                        LatLng(targetBuildings[2]['lat'], targetBuildings[2]['lng']), // รถคันที่ 1 จะไปหอพักต่อ
                      ],
                      color: Colors.blue.withOpacity(0.8), // เส้นสีให้ตรงกับรถคันที่ 1 (สีน้ำเงิน)
                      strokeWidth: 5.0,
                    ),
                  if (MockData.buses.length > 1)
                    Polyline(
                      points: [
                        LatLng(MockData.buses[1].latitude, MockData.buses[1].longitude),
                        LatLng(targetBuildings[1]['lat'], targetBuildings[1]['lng']), // รถคันที่ 2 วิ่งไปวิศวะ
                      ],
                      color: Colors.green.withOpacity(0.8), // เส้นสีให้ตรงกับรถคันที่ 2 (สีเขียว)
                      strokeWidth: 5.0,
                    ),
                ],
              ),
              // ปักหมุดจำลองตำแหน่งอาคารและรถบัส
              MarkerLayer(
                markers: [
                  // ปักหมุดอาคารเป้าหมาย (ทำเป็นหมุดไอคอนตึก)
                  ...targetBuildings.map((building) => Marker(
                        point: LatLng(building['lat'], building['lng']),
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.assured_workload, // ไอคอนตึก
                          color: Colors.indigo,
                          size: 32,
                        ),
                      )),
                  // แสดงรถที่กำลังวิ่งอยู่บนแผนที่พร้อมสีที่ต่างกัน
                  ...MockData.buses.asMap().entries.map((entry) {
                    final index = entry.key;
                    final bus = entry.value;
                    
                    // สร้างลิสต์สี เพื่อสุ่มหรือให้แต่ละคันมีสีไม่ซ้ำกัน
                    final List<Color> busColors = [Colors.blue, Colors.green, Colors.purple, Colors.orange];
                    final markerColor = busColors[index % busColors.length];

                    return Marker(
                      point: LatLng(bus.latitude, bus.longitude),
                      width: 45,
                      height: 45,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: markerColor, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Icon(
                          Icons.directions_bus,
                          color: markerColor,
                          size: 24,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // 2. เมนูรายชื่อรถแบบเลื่อนขึ้นลงได้ (Draggable Scrollable Sheet)
          DraggableScrollableSheet(
            initialChildSize: 0.35, // ป๊อปอัปเริ่มต้นที่ 35%
            minChildSize: 0.12,    // เลื่อนปิดลงไปเหลือ 12%
            maxChildSize: 0.8,     // ดึงขึ้นมาดูได้มากสุด 80% ของจอ
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor, // ปรับสีตามโหมดมืดสว่าง
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                // เปลี่ยนเป็น ListView ครอบทั้งหมดเพื่อให้ส่วนหัวก็สามารถใช้นิ้วลาก/ลากเลื่อนได้
                child: ListView.builder(
                  controller: scrollController, // เชื่อมตัวจัดการเลื่อนของ Sheet เข้ากับ List
                  itemCount: MockData.buses.length + 1, // บวก 1 สำหรับส่วน Header (ขีดๆ ด้านบน)
                  itemBuilder: (context, index) {
                    // แถวที่ 0 ให้แสดงผลเป็น Header
                    if (index == 0) {
                      return Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 50,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'รถที่กำลังมาถึง (คลิกเพื่อดูตำแหน่ง)',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // แถวต่อๆ ไปคือข้อมูลรถ
                    final busIndex = index - 1;
                    final bus = MockData.buses[busIndex];
                    
                    // ให้สีไอคอนในลิสต์ตรงกับสีหมุดบนแผนที่
                    final List<Color> busColors = [Colors.blue, Colors.green, Colors.purple, Colors.orange];
                    final avatarColor = busColors[busIndex % busColors.length];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        // เพิ่ม onTap เพื่อลากแผนที่ไปหารถคันนั้น
                        onTap: () {
                          _mapController.move(
                            LatLng(bus.latitude, bus.longitude), 
                            17.5 // ระดับการซูมเมื่อกดไปที่รถ
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: avatarColor.withOpacity(0.15),
                          child: Icon(Icons.directions_bus, color: avatarColor),
                        ),
                        title: Text('ป้ายทะเบียน: ${bus.licensePlate}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('คนขับ: ${bus.driverName} (${bus.driverPhone})'),
                            Text('สถานะ: ${bus.status}', style: const TextStyle(color: Colors.green)),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('ETA', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(bus.eta, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
