import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bottom_menu.dart';
import 'main.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Fromhealth extends StatefulWidget {
  @override
  _FromhealthState createState() => _FromhealthState();
}

class _FromhealthState extends State<Fromhealth> {
  final String icon = "assets/images/icon.png";
  int _selectedIndex = 1;

  // ใช้ UID จริงจากผู้ใช้ที่ล็อกอิน (ต้องล็อกอินก่อนถึงเข้าหน้านี้ได้)
  late final String _docId = FirebaseAuth.instance.currentUser!.uid;

  // ---- state / controllers
  final TextEditingController _ageCtrl = TextEditingController();
  String? _gender; // label ไทย: ชาย/หญิง
  String? _selectedChestPain; // label ไทย
  String? _fbs; // ใช่/ไม่ใช่
  String? _exang; // มี/ไม่มี
  int? _thalachFromDB; // ถ้ามีค่าใน DB จะใช้ค่านี้
  bool _loading = true;

  // ---- dropdown lists
  final List<String> _genders = ['ชาย', 'หญิง'];
  final List<String> _chestPainTypes = [
    'เจ็บหน้าอกแบบปกติ (Typical Angina)',
    'เจ็บหน้าอกผิดปกติ (Atypical Angina)',
    'เจ็บหน้าอกไม่เกี่ยวกับหัวใจ (Non-anginal Pain)',
    'ไม่มีอาการเจ็บหน้าอก (Asymptomatic)',
  ];
  final List<String> _fbsTypes = ['ใช่', 'ไม่ใช่'];
  final List<String> _exangTypes = ['มี', 'ไม่มี'];

  @override
  void initState() {
    super.initState();
    _loadExisting(); // โหลดค่าที่เคยบันทึกไว้ทันที
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    super.dispose();
  }

  // ========= map label -> ตัวเลข (UCI Heart)
  int? _mapSex(String? g) => g == null ? null : (g == 'ชาย' ? 1 : 0);
  int? _mapCp(String? cp) =>
      cp == null ? null : _chestPainTypes.indexOf(cp); // 0..3
  int? _mapYesNo(String? v) => v == null ? null : (v == 'ใช่' ? 1 : 0);
  int? _mapExang(String? v) => v == null ? null : (v == 'มี' ? 1 : 0);

  // ========= map ตัวเลขจาก DB -> label ไทย (ใช้ตอน prefill)
  String? _sexLabel(dynamic v) {
    final n = v is num ? v.toInt() : int.tryParse('$v');
    if (n == null) return null;
    return n == 1 ? 'ชาย' : 'หญิง';
  }

  String? _cpLabel(dynamic v) {
    final n = v is num ? v.toInt() : int.tryParse('$v');
    if (n == null) return null;
    return (n >= 0 && n < _chestPainTypes.length) ? _chestPainTypes[n] : null;
  }

  String? _yesNoLabel(dynamic v) {
    final n = v is num ? v.toInt() : int.tryParse('$v');
    if (n == null) return null;
    return n == 1 ? 'ใช่' : 'ไม่ใช่';
  }

  String? _exangLabel(dynamic v) {
    final n = v is num ? v.toInt() : int.tryParse('$v');
    if (n == null) return null;
    return n == 1 ? 'มี' : 'ไม่มี';
  }

  int? get _ageInt {
    if (_ageCtrl.text.trim().isEmpty) return null;
    return int.tryParse(_ageCtrl.text.trim());
  }

  int? get _thalachEstimate {
    final a = _ageInt;
    if (a == null) return null;
    return 220 - a;
  }

  Future<void> _loadExisting() async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('heart_assessments')
              .doc(_docId)
              .get();

      final data = snap.data();
      final input = (data?['input'] ?? {}) as Map<String, dynamic>;

      if (input.isNotEmpty) {
        _ageCtrl.text = (input['age'] ?? '').toString();
        _gender = _sexLabel(input['sex']);
        _selectedChestPain = _cpLabel(input['cp']);
        _fbs = _yesNoLabel(input['fbs']);
        _exang = _exangLabel(input['exang']);
        final t = input['thalach'];
        _thalachFromDB = t is num ? t.toInt() : int.tryParse('$t');
      }
    } catch (e) {
      debugPrint('Load existing failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onMenuTap(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/home');
        break;
      case 1:
        // หน้าปัจจุบัน
        break;
      case 2:
        Navigator.pushNamed(context, '/profile'); // หรือ '/security' ถ้ามี
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildFormContainer(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomMenuBar(
        currentIndex: _selectedIndex,
        onTap: _onMenuTap,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 100,
      color: const Color.fromARGB(255, 255, 255, 255),
      child: Stack(
        children: [
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: Image.asset(icon, width: 500, height: 80),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyApp()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContainer() {
    final inner =
        _loading
            ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
            : Column(
              children: [
                _buildAgeField(),
                const SizedBox(height: 20),
                _buildDropdownField(
                  label: "เพศ",
                  items: _genders,
                  value: _gender,
                  onChanged: (v) => setState(() => _gender = v),
                ),
                const SizedBox(height: 20),
                _buildDropdownField(
                  label: "ประเภทของอาการเจ็บหน้าอก",
                  items: _chestPainTypes,
                  value: _selectedChestPain,
                  onChanged: (v) => setState(() => _selectedChestPain = v),
                ),
                const SizedBox(height: 20),
                _buildDropdownField(
                  label: "ระดับน้ำตาลในเลือด > 120 mg/dl",
                  items: _fbsTypes,
                  value: _fbs,
                  onChanged: (v) => setState(() => _fbs = v),
                ),
                const SizedBox(height: 20),
                _buildDropdownField(
                  label: "มีอาการเจ็บหน้าอกจากการออกกำลังกายหรือไม่",
                  items: _exangTypes,
                  value: _exang,
                  onChanged: (v) => setState(() => _exang = v),
                ),
                const SizedBox(height: 24),
                _buildSummaryCard(),
                const SizedBox(height: 24),
                Center(child: _buildSaveButton()),
              ],
            );

    return Container(
      width: 330,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(227, 228, 253, 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: inner,
          ),
        ),
      ),
    );
  }

  Widget _buildAgeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "อายุ",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 280,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFFAFAFA)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          ),
          child: TextFormField(
            controller: _ageCtrl,
            onChanged: (_) => setState(() {}), // อัปเดตสรุบทันที
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A202C),
            ),
            decoration: const InputDecoration(
              hintText: "กรุณากรอกอายุของคุณ",
              hintStyle: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.cake_outlined,
                  color: Color(0xFF6366F1),
                  size: 22,
                ),
              ),
              suffixIcon: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  "ปี",
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required List<String> items,
    String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 280,
          height: 56,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(
              hintText: 'กรุณาเลือก',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            value: value,
            items:
                items
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: const TextStyle(fontSize: 14)),
                      ),
                    )
                    .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final sexNum = _mapSex(_gender);
    final cpNum = _mapCp(_selectedChestPain);
    final fbsNum = _mapYesNo(_fbs);
    final exangNum = _mapExang(_exang);
    final age = _ageInt;
    final thalach = _thalachFromDB ?? _thalachEstimate; // ใช้ค่าจาก DB ก่อน

    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "สรุปข้อมูลที่เลือก",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _row("UID", _docId), // แสดง UID ที่นี่
          _row("อายุ", age?.toString() ?? "-"),
          _row(
            "เพศ",
            _gender ?? "-",
            sub: sexNum == null ? null : "(sex=$sexNum)",
          ),
          _row(
            "อาการเจ็บหน้าอก",
            _selectedChestPain ?? "-",
            sub: cpNum == null ? null : "(cp=$cpNum)",
          ),
          _row(
            "FBS > 120 mg/dl",
            _fbs ?? "-",
            sub: fbsNum == null ? null : "(fbs=$fbsNum)",
          ),
          _row(
            "เจ็บหน้าอกจากการออกกำลังกาย",
            _exang ?? "-",
            sub: exangNum == null ? null : "(exang=$exangNum)",
          ),
          _row("thalach", thalach?.toString() ?? "-"),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {String? sub}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(k)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (sub != null)
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: () async {
        final age = _ageInt;
        final dataOK =
            age != null &&
            _gender != null &&
            _selectedChestPain != null &&
            _fbs != null &&
            _exang != null;

        if (!dataOK) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('กรอก/เลือกข้อมูลให้ครบก่อนนะ')),
          );
          return;
        }

        final payload = {
          'age': age,
          'sex': _mapSex(_gender),
          'cp': _mapCp(_selectedChestPain),
          'fbs': _mapYesNo(_fbs),
          'exang': _mapExang(_exang),
          'thalach': _thalachFromDB ?? _thalachEstimate, // เก็บค่าที่โชว์
        };

        try {
          await FirebaseFirestore.instance
              .collection('heart_assessments')
              .doc(_docId)
              .set({
                'input': payload,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('บันทึกเรียบร้อย')));
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
        }

        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('สรุปข้อมูลที่บันทึก'),
                content: Text(payload.toString()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ปิด'),
                  ),
                ],
              ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromRGBO(215, 239, 220, 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
      ),
      child: const Text(
        "บันทึก",
        style: TextStyle(fontSize: 15, color: Color.fromARGB(255, 0, 0, 0)),
      ),
    );
  }
}
