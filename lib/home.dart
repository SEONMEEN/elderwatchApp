import 'package:flutter/material.dart';
import 'detailbox.dart';
import 'fromhealth.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var heartrate = 62;
  var oxygen = 95;
  var status = "Normal";
  var icon = "assets/images/icon.png";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              SizedBox(height: 20),
              Container(
                height: 100,
                color: const Color.fromARGB(255, 255, 255, 255),
                child: Stack(
                  children: [
                    SizedBox(height: 10),
                    Align(
                      alignment: Alignment.center,
                      child: Image.asset(icon, width: 500, height: 80),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Fromhealth(),
                            ),
                          );
                        },
                        child: Container(
                          width: 60,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(184, 33, 50, 1),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                            ),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Detailbox(
                "อัตราการเต้นของหัวใจ",
                120,
                300,
                heartrate,
                null,
                "ครั้งต่อนาที",
                Color.fromRGBO(253, 227, 227, 1),
              ),
              SizedBox(height: 30),
              Detailbox(
                'ออกซิเจนในเลือด',
                120,
                300,
                oxygen,
                null,
                "%",
                Color.fromRGBO(227, 242, 253, 1),
              ),
              SizedBox(height: 30),
              Detailbox(
                "Event Status",
                220,
                300,
                null,
                "assets/images/status_normal.png",
                'Normal',
                Color.fromRGBO(232, 254, 233, 1),
              ),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
