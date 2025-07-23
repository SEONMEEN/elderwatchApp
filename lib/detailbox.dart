import 'package:flutter/material.dart';

class Detailbox extends StatelessWidget {
  String title;
  double hieght;
  double width;
  final num? value;
  final String? image;
  String unitorstatus;
  final Color color;

  Detailbox(
    this.title,
    this.hieght,
    this.width,
    this.value,
    this.image,
    this.unitorstatus,
    this.color,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: hieght,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            SizedBox(height: 10),
            Row(
              children: [
                SizedBox(width: 10),
                if (image != null) ...[
                  Text(
                    title,
                    style: TextStyle(
                      color: const Color.fromARGB(255, 0, 0, 0),
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ] else ...[
                  Text(
                    title,
                    style: TextStyle(
                      color: const Color.fromARGB(255, 0, 0, 0),
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                SizedBox(width: 20),
                if (image != null) ...[
                  Image.asset(image!, width: 120, height: 140),
                  SizedBox(width: 10),
                  Text(
                    "Normal",
                    style: TextStyle(
                      color: const Color.fromARGB(255, 0, 0, 0),
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ] else ...[
                  Text(
                    "$value",
                    style: TextStyle(
                      color: const Color.fromARGB(255, 0, 0, 0),
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    unitorstatus,
                    style: TextStyle(
                      color: const Color.fromARGB(255, 0, 0, 0),
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
