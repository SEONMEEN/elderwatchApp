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

  /// ใช้ initialData เพื่อไม่ให้ UI ว่างตอนเริ่ม
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
    _db.debugPrintLatest(); // debug log
    _db.getLatestOnce().then((v) {
      if (!mounted) return;
      setState(() => _initial = v);
    });
  }

  // ======= เกณฑ์ “ชัก” หลังจากล้ม =======
  static const int kSeizureHrThresh = 120; // HR ≥ 120
  static const int kSeizureSpo2Max = 92; // SpO₂ ≤ 92

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: StreamBuilder<HealthData?>(
        stream: _db.latestHealthFromLogFast(),
        initialData: _initial,
        builder: (context, snapshot) {
          final h = snapshot.data ?? _initial;

          if (h == null &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('โหลดข้อมูลผิดพลาด: ${snapshot.error}'),
              ),
            );
          }

          // ยังไม่มีข้อมูลเลย
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
                      "ท่าทางและการเคลื่อนไหว",
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

          // ====== มีข้อมูลล่าสุดแล้ว ======
          final int heartRate = h.heartRate;
          final int spo2 = h.spo2;
          final bool fell = h.fell;

          // ขั้นแรก: ตัดสินล้ม/ไม่ล้มจากข้อมูล (จาก RTDB)
          // ขั้นต่อมา: ถ้าล้มแล้วและ HR/SpO₂ เข้าช่วงเสี่ยง → แสดง “Seizure”
          final bool seizureNow =
              fell && heartRate >= kSeizureHrThresh && spo2 <= kSeizureSpo2Max;

          final String statusText =
              seizureNow ? "Seizure" : (fell ? "Fall" : "Normal");

          final String statusImage =
              seizureNow
                  ? "assets/images/status_seizure.png"
                  : (fell
                      ? "assets/images/status_fall.png"
                      : "assets/images/status_normal.png");

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

                  // Status / Fall / Seizure
                  Detailbox(
                    "ท่าทางและการเคลื่อนไหว",
                    300,
                    null,
                    statusImage,
                    statusText, // 👈 ส่งสถานะเป็นคำสั้นๆ: Normal | Fall | Seizure
                    const Color.fromRGBO(232, 254, 233, 1),
                    "status",
                  ),

                  const SizedBox(height: 12),

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
              child: const SizedBox(width: 80, height: 80),
            ),
          ),
        ],
      ),
    );
  }
}
