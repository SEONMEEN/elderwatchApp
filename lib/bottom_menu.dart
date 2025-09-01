// lib/widgets/bottom_menu.dart
import 'package:flutter/material.dart';

class BottomMenuBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomMenuBar({Key? key, this.currentIndex = 0, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'หน้าแรก'),
        BottomNavigationBarItem(icon: Icon(Icons.edit), label: 'แก้ไขข้อมูล'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'โปรไฟล์'),
      ],
    );
  }
}
