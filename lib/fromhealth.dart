import 'package:flutter/material.dart';
import 'main.dart';
import 'package:flutter/services.dart';

class Fromhealth extends StatefulWidget {
  @override
  _FromhealthState createState() => _FromhealthState();
}

class _FromhealthState extends State<Fromhealth> {
  final String icon = "assets/images/icon.png";

  // ข้อมูลสำหรับ dropdown แต่ละตัว
  final List<String> _genders = ['ชาย', 'หญิง'];
  String? _gender;

  final List<String> _chestPainTypes = [
    'เจ็บหน้าอกแบบปกติ (Typical Angina)',
    'เจ็บหน้าอกผิดปกติ (Atypical Angina)',
    'เจ็บหน้าอกไม่เกี่ยวกับหัวใจ (Non-anginal Pain)',
    'ไม่มีอาการเจ็บหน้าอก (Asymptomatic)',
  ];
  String? _selectedChestPain;

  final List<String> _fbsTypes = ['ใช่', 'ไม่ใช่'];
  String? _fbs;
  final List<String> _exangTypes = ['มี', 'ไม่มี'];
  String? _exang;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(246, 222, 216, 1),
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 100,
      color: const Color.fromRGBO(246, 222, 216, 1),
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
              child: Container(
                width: 60,
                height: 30,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: const Icon(
                  Icons.health_and_safety,
                  color: Color.fromRGBO(184, 33, 50, 1),
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContainer() {
    return Container(
      width: 330,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(184, 33, 50, 1),
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
            child: Column(
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
                const SizedBox(height: 30),
                Center(child: _buildSaveButton()),
              ],
            ),
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

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: () {
        print("บันทึกแล้ว");
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromRGBO(184, 33, 50, 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
      ),
      child: const Text(
        "บันทึก",
        style: TextStyle(fontSize: 15, color: Colors.white),
      ),
    );
  }
}
