import 'dart:convert';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:http/http.dart' as http;
import 'package:rafiq/auth/api_service.dart';
import 'package:flutter/foundation.dart';

class DriverApi {
  static String get _base => ApiService.baseUrl;

  // ── Request a driver booking ──────────────────────────────────────────────
  // Called by ApiService.requestDriverBooking (see bottom of this file).
  static Future<Map<String, dynamic>> requestDriverBooking({
    required int patientId,
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
    required String pickupAddress,
    required String destination,
    required String requestType, // 'instant' | 'scheduled'
    DateTime? schedDate,
    TimeOfDay? schedTime,
    double distanceKm = 0,
    double totalFare = 0,
  }) async {
    try {
      String? svcDate, svcTime;
      if (schedDate != null) {
        svcDate =
            '${schedDate.year}-${schedDate.month.toString().padLeft(2, '0')}'
            '-${schedDate.day.toString().padLeft(2, '0')}';
      }
      if (schedTime != null) {
        svcTime =
            '${schedTime.hour.toString().padLeft(2, '0')}:'
            '${schedTime.minute.toString().padLeft(2, '0')}';
      }

      final res = await http.post(
        Uri.parse('$_base/request_driver_booking.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'patient_id':    patientId,
          'pickup_lat':    pickupLat,
          'pickup_lng':    pickupLng,
          'dest_lat':      destLat,
          'dest_lng':      destLng,
          'pickup_address': pickupAddress,
          'destination':   destination,
          'request_type':  requestType,
          if (svcDate != null) 'service_date': svcDate,
          if (svcTime != null) 'service_time': svcTime,
          'distance_km':   distanceKm,
          'total_fare':    totalFare,
        }),
      ).timeout(const Duration(seconds: 15));

      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'ok': false, 'error': 'Connection error: $e'};
    }
  }

  // ── Poll booking status ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getBookingStatus(
      int bookingId, int patientId) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/get_booking_status.php'
            '?booking_id=$bookingId&patient_id=$patientId'),
      ).timeout(const Duration(seconds: 8));
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'ok': false, 'error': '$e'};
    }
  }

  // ── Cancel pending booking ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> cancelDriverRequest(
      int bookingId, int patientId) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/cancel_driver_request.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'booking_id': bookingId, 'patient_id': patientId}),
      ).timeout(const Duration(seconds: 8));
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'ok': false, 'error': '$e'};
    }
  }

  // ── Get live tracking row ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getTrackingData(int bookingId) async {
    try {
      final res = await http.get(
        Uri.parse(
            '$_base/tracking_api.php?action=get&booking_id=$bookingId&_t=${DateTime.now().millisecondsSinceEpoch}'),
      ).timeout(const Duration(seconds: 8));
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'ok': false, 'error': '$e'};
    }
  }

  // ── Driver: push GPS location ─────────────────────────────────────────────
  static Future<bool> updateDriverLocation(
      int bookingId, double lat, double lng) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/tracking_api.php?action=update_location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'booking_id': bookingId, 'lat': lat, 'lng': lng}),
      ).timeout(const Duration(seconds: 8));
      return (jsonDecode(res.body) as Map)['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Driver: change trip status ────────────────────────────────────────────
  static Future<bool> updateTripStatus(int bookingId, String status) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/tracking_api.php?action=update_status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'booking_id': bookingId, 'status': status}),
      ).timeout(const Duration(seconds: 8));
      return (jsonDecode(res.body) as Map)['ok'] == true;
    } catch (_) {
      return false;
    }
  }

static Future<Map<String, dynamic>?> getActiveBooking(int patientId) async {
  try {
    final url = '$_base/get_active_booking.php?patient_id=$patientId';
    debugPrint('getActiveBooking URL: $url'); // add this
    final res = await http.get(
      Uri.parse(url),
    ).timeout(const Duration(seconds: 8));
    debugPrint('getActiveBooking response: ${res.body}'); // add this
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['ok'] == true ? body : null;
  } catch (e) {
    debugPrint('getActiveBooking error: $e'); // add this
    return null;
  }
}
}