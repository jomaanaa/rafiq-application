import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SessionManager {

  /// حفظ بيانات المستخدم
  static Future<void> saveUser(Map<String, dynamic> userData) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('user_session', jsonEncode(userData));

  }


  /// جلب بيانات المستخدم
  static Future<Map<String, dynamic>?> getUser() async {

    final prefs = await SharedPreferences.getInstance();

    String? sessionData = prefs.getString('user_session');

    if (sessionData == null) return null;

    return jsonDecode(sessionData);

  }


  /// جلب user id
  static Future<int?> getUserId() async {

    final user = await getUser();

    if (user != null && user['user_id'] != null) {

      return int.tryParse(user['user_id'].toString());

    }

    return null;

  }


  /// logout
  static Future<void> logout() async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();

  }



  /// حفظ عدد الاشعارات التي تم قراءتها
  static Future<void> saveSeenNotifications(int count) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt("seen_notifications", count);

  }



  /// جلب عدد الاشعارات المقروءة
  static Future<int> getSeenNotifications() async {

    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt("seen_notifications") ?? 0;

  }

}