// ============================================================
// lib/admin/admin_api_service.dart
// ============================================================
// ⚠️  Change _base to match your server:
//   Real device       → http://YOUR_PC_LAN_IP/rafiq/admin/admin_api.php
//   Production        → https://yourdomain.com/rafiq/admin/admin_api.php
// ============================================================
 
import 'dart:convert';
import 'package:http/http.dart' as http;
 
class AdminApiService {
  static const String _base =
      'http://10.13.114.211/Api/admin_api.php'; // ← change this
 
  static Uri _uri(String action, {int? id, Map<String, String>? q}) {
    final params = <String, String>{'action': action};
    if (id != null) params['id'] = '$id';
    if (q != null) params.addAll(q);
    return Uri.parse(_base).replace(queryParameters: params);
  }
 
  static Future<T> _get<T>(Uri uri) async {
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    return json.decode(res.body) as T;
  }
 
  static Future<dynamic> _req(String method, Uri uri, [Object? body]) async {
    final req = http.Request(method, uri);
    req.headers['Content-Type'] = 'application/json';
    if (body != null) req.body = json.encode(body);
    final stream = await req.send().timeout(const Duration(seconds: 15));
    final res = await http.Response.fromStream(stream);
    return json.decode(res.body);
  }
 
  // ── Stats ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getStats() =>
      _get<Map<String, dynamic>>(_uri('stats'));
 
  // ── Providers ────────────────────────────────────────────
  static Future<List<dynamic>> getProviders({
    String search = '',
    String status = 'all',
    String category = 'all',
  }) =>
      _get<List<dynamic>>(_uri('providers',
          q: {'search': search, 'status': status, 'category': category}));
 
  static Future<Map<String, dynamic>> getProviderDetail(int id) =>
      _get<Map<String, dynamic>>(_uri('provider_detail', id: id));
 
  static Future<void> updateProviderStatus(int id,
      {required String status, String note = ''}) async {
    await _req('PATCH', _uri('update_provider_status', id: id),
        {'status': status, 'note': note});
  }
 
  // ── Places ───────────────────────────────────────────────
  static Future<List<dynamic>> getPlaces({
    String search = '',
    String type = 'all',
    String status = 'all',
  }) =>
      _get<List<dynamic>>(
          _uri('places', q: {'search': search, 'type': type, 'status': status}));
 
  static Future<dynamic> addPlace(Map<String, dynamic> d) =>
      _req('POST', _uri('add_place'), d);
 
  static Future<dynamic> editPlace(int id, Map<String, dynamic> d) =>
      _req('PUT', _uri('edit_place', id: id), d);
 
  static Future<void> deletePlace(int id) async =>
      _req('DELETE', _uri('delete_place', id: id));
 
  static Future<void> updatePlaceStatus(int id, String status) async =>
      _req('PATCH', _uri('update_place_status', id: id), {'status': status});
 
  // ── Bookings ─────────────────────────────────────────────
  static Future<List<dynamic>> getBookings({
    String search = '',
    String status = 'all',
    String serviceType = 'all',
  }) =>
      _get<List<dynamic>>(_uri('bookings', q: {
        'search': search,
        'status': status,
        'service_type': serviceType,
      }));
 
  // ── Patients ─────────────────────────────────────────────
  static Future<List<dynamic>> getPatients({String search = ''}) =>
      _get<List<dynamic>>(_uri('patients', q: {'search': search}));
}