import 'package:flutter/material.dart';

class Detailbox extends StatelessWidget {
  String title;
  double width;
  final num? value;
  final String? image;
  final String? unitorstatus;
  final Color color;
  String type;

  Detailbox(
    this.title,
    this.width,
    this.value,
    this.image,
    this.unitorstatus,
    this.color,
    this.type,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(2),
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
                    (unitorstatus != null && unitorstatus == "Normal")
                        ? "ปกติ"
                        : (unitorstatus != null && unitorstatus == "Fall")
                        ? "ล้ม"
                        : "ชัก",
                    style: TextStyle(
                      color:
                          (unitorstatus != null && unitorstatus == "Normal")
                              ? const Color.fromRGBO(56, 142, 60, 1)
                              : Colors.red,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else ...[
                  Row(
                    // บังคับให้ Row จัด baseline แทน center
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,

                    children: [
                      //heart rate
                      if (type == "heartrate") ...[
                        Text(
                          (value! > 100) ? "ผิดปกติ" : "ปกติ",
                          style: TextStyle(
                            color:
                                (value != null && value! > 100)
                                    ? Colors.red
                                    : const Color.fromRGBO(56, 142, 60, 1),
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "$value $unitorstatus",
                          style: TextStyle(
                            color:
                                (value != null && value! > 100)
                                    ? Colors.red
                                    : const Color.fromRGBO(56, 142, 60, 1),
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 50),
                      ],
                      // oxygen
                      if (type == "oxygen") ...[
                        Text(
                          (value! > 100 || value! < 90) ? "ผิดปกติ" : "ปกติ",
                          style: TextStyle(
                            color:
                                (value != null && (value! > 100 || value! < 90))
                                    ? Colors.red
                                    : const Color.fromRGBO(56, 142, 60, 1),
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "$value $unitorstatus",
                          style: TextStyle(
                            color:
                                (value != null && (value! > 100 || value! < 90))
                                    ? Colors.red
                                    : const Color.fromRGBO(56, 142, 60, 1),
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ],
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
