// lib/main.dart
import 'package:flutter/material.dart';
import 'home.dart'; // เรียกใช้ home.dart
import 'fromhealth.dart'; // ถ้าจะใช้ FromHealth Later
import 'detailbox.dart'; // ถ้าจะใช้ DetailBox Later

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      theme: ThemeData(primarySwatch: Colors.pink),

      // ตรงนี้คือจุดที่เราเริ่มต้นด้วย HomePage()
      home: const HomePage(),
    );
  }
}
