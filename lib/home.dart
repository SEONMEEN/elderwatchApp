import 'package:flutter/material.dart';
import 'detailbox.dart';
import 'fromhealth.dart';
import 'bottom_menu.dart';
import 'services/realtime_database_service.dart';
import 'models/health_data.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _db = RealtimeDatabaseService();
  int _selectedIndex = 0;

  /// ✅ ดึงค่าล่าสุดมาใช้เป็น initialData เพื่อให้ UI มีค่าโชว์ทันที
  HealthData? _initial;

  void _onMenuTap(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 1:
        Navigator.pushNamed(context, '/edit');
        break;
      case 2:
        Navigator.pushNamed(context, '/profile');
        break;
      default:
    }
  }

  @override
  void initState() {
    super.initState();
    _db.debugPrintLatest(); // debug ดูใน console

    // ดึงค่าล่าสุดแบบ one-shot มาเป็นค่าเริ่มต้น
    _db.getLatestOnce().then((v) {
      if (!mounted) return;
      setState(() => _initial = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: StreamBuilder<HealthData?>(
        stream: _db.latestHealthFromLogFast(),
        initialData: _initial, // ✅ ใส่ initialData
        builder: (context, snapshot) {
          // รวมค่า: ใช้ของ stream ก่อน ถ้าไม่มีค่อยใช้ one-shot
          final h = snapshot.data ?? _initial;

          // กำลังโหลดและยังไม่มีค่าเริ่มต้นเลย
          if (h == null &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ผิดพลาด
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('โหลดข้อมูลผิดพลาด: ${snapshot.error}'),
              ),
            );
          }

          // ยังไม่มีข้อมูล (เช่น อุปกรณ์ยังไม่ส่งขึ้น /log)
          if (h == null) {
            return SingleChildScrollView(
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const _HeaderBar(),
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'ยังไม่มีข้อมูลล่าสุดจาก log\n(ลองรีเฟรชหรือรออุปกรณ์ส่งข้อมูล)',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _db.debugPrintLatest();
                        setState(() {}); // กระตุ้น build ใหม่
                      },
                      child: const Text('รีเฟรช'),
                    ),
                    const SizedBox(height: 16),

                    // ค่า default เพื่อให้ UI ไม่โล่ง
                    Detailbox(
                      "อัตราการเต้นของหัวใจ",
                      300,
                      0,
                      null,
                      "ครั้งต่อนาที",
                      const Color.fromRGBO(253, 227, 227, 1),
                      "heartrate",
                      enablePrediction: true,
                    ),
                    const SizedBox(height: 30),
                    Detailbox(
                      'ออกซิเจนในเลือด',
                      300,
                      0,
                      null,
                      "%",
                      const Color.fromRGBO(227, 242, 253, 1),
                      "oxygen",
                      enablePrediction: false,
                    ),
                    const SizedBox(height: 30),
                    Detailbox(
                      "Event Status",
                      300,
                      null,
                      "assets/images/status_normal.png",
                      "Normal",
                      const Color.fromRGBO(232, 254, 233, 1),
                      "status",
                      enablePrediction: false,
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          }

          // ✅ มีข้อมูลล่าสุดแล้ว: แสดงจริง
          final int heartRate = h.heartRate;
          final int spo2 = h.spo2;
          final bool fell = h.fell;
          final String status = fell ? "⚠️ FALL DETECTED" : "Normal";

          return SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const _HeaderBar(),

                  // HR
                  Detailbox(
                    "อัตราการเต้นของหัวใจ",
                    300,
                    heartRate,
                    null,
                    "ครั้งต่อนาที",
                    const Color.fromRGBO(253, 227, 227, 1),
                    "heartrate",
                  ),
                  const SizedBox(height: 30),

                  // SpO2
                  Detailbox(
                    'ออกซิเจนในเลือด',
                    300,
                    spo2,
                    null,
                    "%",
                    const Color.fromRGBO(227, 242, 253, 1),
                    "oxygen",
                  ),
                  const SizedBox(height: 30),

                  // Event/Fall
                  Detailbox(
                    "Event Status",
                    300,
                    null,
                    fell
                        ? "assets/images/status_warning.png"
                        : "assets/images/status_normal.png",
                    status,
                    const Color.fromRGBO(232, 254, 233, 1),
                    "status",
                  ),

                  const SizedBox(height: 12),

                  // แสดงเวลาที่อัปเดตล่าสุด (ถ้าโมเดล HealthData มี timestamp เป็นวินาที)
                  if ((h.timestamp) != null && h.timestamp > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Updated: ${DateTime.fromMillisecondsSinceEpoch(h.timestamp * 1000)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomMenuBar(
        currentIndex: _selectedIndex,
        onTap: _onMenuTap,
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Image.asset(
              "assets/images/icon.png",
              width: 500,
              height: 80,
              fit: BoxFit.contain,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => Fromhealth()),
                );
              },
              child: const SizedBox(width: 80, height: 80), // touch area
            ),
          ),
        ],
      ),
    );
  }
}
