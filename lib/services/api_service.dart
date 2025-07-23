import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      "http://10.0.2.2/flutter_api"; // Android Emulator

  static Future<List<dynamic>> getUsers() async {
    final res = await http.get(Uri.parse('$baseUrl/get_users.php'));
    return jsonDecode(res.body);
  }

  static Future<String> addUser(String name, String email) async {
    final res = await http.post(
      Uri.parse('$baseUrl/add_user.php'),
      body: {'name': name, 'email': email},
    );
    return res.body;
  }

  static Future<String> deleteUser(String id) async {
    final res = await http.post(
      Uri.parse('$baseUrl/delete_user.php'),
      body: {'id': id},
    );
    return res.body;
  }

  static Future<String> updateUser(String id, String name, String email) async {
    final res = await http.post(
      Uri.parse('$baseUrl/update_user.php'),
      body: {'id': id, 'name': name, 'email': email},
    );
    return res.body;
  }
}
