import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rafiq/driver/driver_api.dart';
import 'package:flutter/material.dart' show TimeOfDay;

class ApiService {
  static const String baseUrl = "http://10.13.114.211/Api";

  // ==========================================
  // 0️⃣ LOGIN LOGIC
  // ==========================================
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        "success": false,
        "message": "Connection failed: $e",
      };
    }
  }

  // ==========================================
  // 1️⃣ USER REGISTRATION LOGIC
  // ==========================================
  static Future<Map<String, dynamic>> addUser(
    Map<String, dynamic> patientData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add_user.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(patientData),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        "success": false,
        "message": "Network error: $e",
      };
    }
  }

static Future<Map<String, dynamic>> addBooking(
  Map<String, dynamic> bookingData,
) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/add_booking.php'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(bookingData),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {'success': false};
  } catch (e) {
    rethrow;
  }
}

  // ==========================================
  // 3️⃣ PROFILE UPDATE
  // ==========================================
  static Future<Map<String, dynamic>> updatePatientProfile(
    Map<String, dynamic> userData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_patient.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(userData),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        "status": "error",
        "message": "Update failed: $e",
      };
    }
  }

  // ==========================================
  // 4️⃣ FETCH DOCTORS LOGIC
  // ==========================================
  static Future<List<Map<String, dynamic>>> getDoctors() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_doctors.php'),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        } else if (decoded is Map && decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(decoded['data']); // ← add this
        }
      }
      return [];
    } catch (e) {
      print("getDoctors error: $e");
      return [];
    }
  }

  // ==========================================
  // FETCH BOOKING DETAILS
  // ==========================================
  static Future<Map<String, dynamic>?> getBookingDetails(
    int bookingId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/get_booking.php?booking_id=$bookingId',
        ),
      );

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);

        if (result != null &&
            result is Map<String, dynamic>) {
          return result;
        }
      }

      return null;
    } catch (e) {
      print('GetBooking exception: $e');
      return null;
    }
  }

  // ==========================================
  // FETCH PATIENTS
  // ==========================================
  static Future<List<Map<String, dynamic>>> getPatients() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_users.php'),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);

        return data
            .map((e) => e as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception(
          'HTTP error: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('GetPatients exception: $e');
      rethrow;
    }
  }

  // ==========================================
  // DOCTOR BOOKINGS
  // ==========================================
  static Future<List<Map<String, dynamic>>>
      getDoctorBookings(
    int doctorId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/get_doctor_bookings.php?provider_id=$doctorId',
        ),
      );

      print(
        'DoctorBookings Status: ${response.statusCode}',
      );

      print(
        'DoctorBookings Body: ${response.body}',
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);

        return data
            .map((e) => e as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception(
          'HTTP error: ${response.statusCode}',
        );
      }
    } catch (e) {
      print(
        'GetDoctorBookings exception: $e',
      );

      rethrow;
    }
  }

  // ==========================================
  // FETCH CAREGIVERS
  // ==========================================
  static Future<List<Map<String, dynamic>>>
      getCaregivers() async {
    try {
      final response = await http.get(
        Uri.parse(
          "$baseUrl/get_caregivers.php",
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["success"] == true) {
          return List<Map<String, dynamic>>.from(
            data["data"],
          );
        }
      }

      return [];
    } catch (e) {
      print(
        "Error fetching caregivers: $e",
      );

      return [];
    }
  }

  // ==========================================
  // CAREGIVER REQUESTS
  // ==========================================
  static Future<List<dynamic>>
      getCaregiverRequests(
    int providerId,
  ) async {
    final response = await http.get(
      Uri.parse(
        "$baseUrl/get_caregiver_requests.php?provider_id=$providerId",
      ),
    );

    final data = jsonDecode(response.body);

    if (data["success"] == true) {
      return data["data"];
    }

    return [];
  }

  // ==========================================
  // FETCH NOTIFICATIONS
  // ==========================================
  static Future<List<Map<String, dynamic>>>
      getPatientNotifications(
    int patientId,
  ) async {
    try {
      var url = Uri.parse(
        "$baseUrl/get_patient_notifications.php?patient_id=$patientId",
      );

      var response = await http.get(url);

      print(response.body);

      var data = jsonDecode(response.body);

      if (data["success"] == true &&
          data["data"] != null) {
        return List<Map<String, dynamic>>.from(
          data["data"],
        );
      }

      return [];
    } catch (e) {
      print("Notification Error: $e");
      return [];
    }
  }

  // ==========================================
  // FETCH INTERPRETERS
  // ==========================================
  static Future<List<Map<String, dynamic>>> getInterpreters() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_interpreters.php'),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded['data'];
        return data.map((e) => e as Map<String, dynamic>).toList();
      }

      throw Exception('HTTP error');
    } catch (e) {
      rethrow;
    }
  }

  // ==========================================
  // FETCH LOGGED-IN PATIENT PROFILE
  // ==========================================
  static Future<Map<String, dynamic>?>
      getPatientProfile(
    int id,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/get_user_profile.php?user_id=$id',
            ),
          )
          .timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['status'] == 'success' ||
            result['success'] == true) {
          return result['data'];
        }
      }
    } catch (e) {
      print("ApiService Error: $e");
    }

    return null;
  }

  // ==========================================
  // WHEELCHAIR RIDE REQUEST
  // ==========================================
  static Future<Map<String, dynamic>>
      requestWheelchairRide(
    Map<String, dynamic> rideData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$baseUrl/ride_request.php',
        ),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(rideData),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        "ok": false,
        "error": "Connection failed: $e",
      };
    }
  }

  // ==========================================
  // BOOKING STATUS MANAGEMENT
  // ==========================================
  static Future updateBookingStatus(
    int bookingId,
    String status,
  ) async {
    try {
      await http.post(
        Uri.parse(
          "$baseUrl/update_booking_status.php",
        ),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "booking_id": bookingId,
          "status": status,
        }),
      );
    } catch (e) {
      print(
        "Error updating status: $e",
      );
    }
  }

  // ==========================================
  // PATIENT BOOKINGS
  // ==========================================
    static Future<List<Map<String, dynamic>>> getPatientBookings(
    int patientId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/get_patient_bookings.php?patient_id=$patientId',
        ),
      );

      print('PatientBookings Status: ${response.statusCode}');
      print('PatientBookings Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // PHP returns a plain list on success, or a map on error
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        } else {
          // it's a map — either an error or empty result
          print('PatientBookings unexpected response: $decoded');
          return [];
        }
      }
      return [];
    } catch (e) {
      print('GetPatientBookings exception: $e');
      return []; // don't rethrow — just return empty so the UI doesn't crash
    }
  }

  // ==========================================
  // FETCH USER BOOKING HISTORY
  // ==========================================
  static Future<List<Map<String, dynamic>>>
      getUserBookings(
    int userId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/get_user_bookings.php?user_id=$userId',
        ),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true &&
            result['data'] is List) {
          return List<Map<String, dynamic>>.from(
            result['data'],
          );
        }
      }

      return [];
    } catch (e) {
      print(
        "ApiService History Error: $e",
      );

      return [];
    }
  }

  // ==========================================
  // FETCH ACCESSIBLE PLACES
  // ==========================================
  static Future<List<Map<String, dynamic>>>
      getAllPlaces() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/get_places.php',
            ),
          )
          .timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final List<dynamic> data =
            jsonDecode(response.body);

        return data
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }

      return [];
    } catch (e) {
      print(
        "ApiService Map Error: $e",
      );

      return [];
    }
  }

  // ==========================================
  // FETCH HOMEPAGE DATA
  // ==========================================
  static Future<Map<String, dynamic>>
      getHomepageData(
    int userId,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/get_homepage_data.php?user_id=$userId',
            ),
          )
          .timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return {"success": false};
    } catch (e) {
      print(
        "Homepage API Error: $e",
      );

      return {"success": false};
    }
  }

  // ==========================================
  // DOCTOR BOOKING STATUS
  // ==========================================
  static Future<Map<String, dynamic>>
      updateDoctorBookingStatus(
    int bookingId,
    String status,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          "$baseUrl/doctor_booking_status.php",
        ),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "booking_id": bookingId,
          "status": status,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        "success": false,
        "message": "Connection error: $e",
      };
    }
  }

  // ==========================================
  // CAREGIVER PROFILE
  // ==========================================
  static Future<Map<String, dynamic>>
      getCaregiverProfile(
    int id,
  ) async {
    final response = await http.post(
      Uri.parse(
        "$baseUrl/get_caregiver_profile.php",
      ),
      body: {
        "user_id": id.toString(),
      },
    );

    return jsonDecode(response.body);
  }

  // ==========================================
  // UPDATE CAREGIVER PROFILE
  // ==========================================
  static Future<Map<String, dynamic>>
      updateCaregiverProfile({
    required int userId,
    required String firstName,
    required String lastName,
    required String phone,
    required String address,
    required String nationalId,
    required String shiftPreference,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          "$baseUrl/update_caregiver_profile.php",
        ),
        headers: {
          "Content-Type":
              "application/x-www-form-urlencoded",
        },
        body: {
          "user_id": userId.toString(),
          "first_name": firstName,
          "last_name": lastName,
          "phone": phone,
          "address": address,
          "national_id": nationalId,
          "shift_preference": shiftPreference,
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        "success": false,
        "message": "error $e",
      };
    }
  }

  // ==========================================
  // ACTIVE SESSIONS
  // ==========================================
  static Future<List?> getActiveSessions(
    int providerId,
  ) async {
    try {
      final res = await http.get(
        Uri.parse(
          '$baseUrl/get_active_sessions.php?provider_id=$providerId',
        ),
      );

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);

        if (d is List) return d;
      }
    } catch (e) {
      print(
        "ACTIVE SESSIONS ERROR: $e",
      );
    }

    return [];
  }

  // ==========================================
  // COMPLETED SESSIONS
  // ==========================================
  static Future<List?> getCompletedSessions(
    int providerId,
  ) async {
    try {
      final res = await http.get(
        Uri.parse(
          '$baseUrl/get_completed_sessions.php?provider_id=$providerId',
        ),
      );

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);

        if (d is List) return d;
      }
    } catch (e) {
      print(
        "COMPLETED SESSIONS ERROR: $e",
      );
    }

    return [];
  }

  // ==========================================
  // PROVIDER EARNINGS
  // ==========================================
  static Future<Map?> getProviderEarnings(
    int providerId,
  ) async {
    try {
      final res = await http.get(
        Uri.parse(
          '$baseUrl/get_provider_earnings.php?provider_id=$providerId',
        ),
      );

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);

        if (d is Map) return d;
      }
    } catch (e) {
      print("EARNINGS ERROR: $e");
    }

    return null;
  }

  // ==========================================
  // PROVIDER TYPE
  // ==========================================
  static Future<String?> getProviderType(
    int userId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          "$baseUrl/get_provider_type.php?user_id=$userId",
        ),
      );

      final data = jsonDecode(response.body);

      if (data["success"] == true) {
        return data["provider_type"];
      }
    } catch (e) {
      print(e);
    }

    return null;
  }

// ==========================================
// BOOKED SLOTS FOR A CAREGIVER ON A DATE
// ==========================================
  static Future<List<Map<String, dynamic>>> getBookedSlots({
    required int providerId,
    required String date,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/get_booked_slots.php?provider_id=$providerId&date=$date',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['booked']);
        }
      }
      return [];
    } catch (e) {
      print("getBookedSlots error: $e");
      return [];
    }
  }

// ==========================================
// PATIENT PROFILE BOOKINGS
// ==========================================
  static Future<List<Map<String, dynamic>>> getProfileBookings(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_profile_bookings.php?user_id=$userId'),
      );
      print('ProfileBookings: ${response.body}');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(decoded['data']);
        }
      }
      return [];
    } catch (e) {
      print('getProfileBookings error: $e');
      return [];
    }
  }

// ==========================================
// SUBMIT REVIEW
// ==========================================
  static Future<Map<String, dynamic>> submitReview({
    required int bookingId,
    required int rating,
    required String review,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/submit_review.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"booking_id": bookingId, "rating": rating, "review": review}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"success": false, "message": "Error: $e"};
    }
  }

// ==========================================
// GET DOCTOR REQUESTS
// ==========================================
  static Future<List>
  getDoctorRequests(
      int providerId) async {
    var response = await http.get(
      Uri.parse(
        "$baseUrl/get_doctor_requests.php?provider_id=$providerId",
      ),
    );
    var data = jsonDecode(response.body);
    if (data["success"]) {
      return data["data"];
    }
    return [];
  }

// ==========================================
// GET DRIVER REQUESTS
// ==========================================
  static Future<List> getDriverRequests() async {
    var response = await http.get(
      Uri.parse(
        "$baseUrl/get_driver_requests.php",
      ),
    );
    var data =
        jsonDecode(response.body);
    if (data["success"]) {
      return data["data"];
    }
    return [];
  }

// ==========================================
// DRIVER TAKE ACTION
// ==========================================
  static Future<bool> driverTakeAction(
      int bookingId,
      int driverId,
      String action,
  ) async {
    var request =
        http.MultipartRequest(
      'POST',
      Uri.parse(
        "$baseUrl/driver_take_action.php",
      ),
    );
    request.fields["booking_id"] =
        bookingId.toString();
    request.fields["driver_id"] =
        driverId.toString();
    request.fields["action"] =
        action;
    var response =
        await request.send();
    return response.statusCode == 200;
  }

// ==========================================
// GET INTERPRETER REQUESTS
// ==========================================
  static Future<List<dynamic>> getInterpreterRequests(
      int providerId,
  ) async {
    final response = await http.get(
      Uri.parse(
        "$baseUrl/get_interpreter_requests.php?provider_id=$providerId",
      ),
    );
    final data = jsonDecode(response.body);
    if (data["success"] == true) {
      return data["data"];
    }
    return [];
  }

// ==========================================
// GET DOCTOR PROFILE
// ==========================================
  static Future<Map?> getDoctorProfile(int userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/get_doctor_profile.php?user_id=$userId'));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d is Map && d['data'] is Map) return d['data'] as Map;
      }
    } catch (_) {}
    return null;
  }

// ==========================================
// UPDATE DOCTOR PROFILE
// ==========================================
  static Future<bool> updateDoctorProfile(Map<String, String> data) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/update_doctor_profile.php'), body: data);
      if (res.statusCode == 200) return jsonDecode(res.body)['success'] == true;
    } catch (_) {}
    return false;
  }

// ==========================================
// GET DOCTOR SESSIONS
// ==========================================
  static Future<List>
  getDoctorSessions(
      int providerId) async {
    var response = await http.get(
      Uri.parse(
        "$baseUrl/get_doctor_sessions.php?provider_id=$providerId",
      ),
    );
    var data = jsonDecode(response.body);
    if (data["success"]) {
      return data["data"];
    }
    return [];
  }

// ==========================================
// GET COMPLETED DOCTOR SESSIONS
// ==========================================
    static Future<List>
  getCompletedDoctorSessions(
      int providerId) async {
    var response = await http.get(
      Uri.parse(
        "$baseUrl/get_completed_doctor_sessions.php?provider_id=$providerId",
      ),
    );
    var data = jsonDecode(response.body);
    if (data["success"]) {
      return data["data"];
    }
    return [];
  }
    

// ==========================================
// GET DRIVER PROFILE
// ==========================================
    static Future<Map?> getDriverProfile(int userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/get_driver_profile.php?user_id=$userId'));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d is Map && d['data'] is Map) return d['data'] as Map;
      }
    } catch (_) {}
    return null;
  }

// ==========================================
// UPDATE DRIVER PROFILE
// ==========================================
  static Future<bool> updateDriverProfile(Map<String, String> data) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/update_driver_profile.php'), body: data);
      if (res.statusCode == 200) return jsonDecode(res.body)['success'] == true;
    } catch (_) {}
    return false;
  }

// ==========================================
// DRIVER ACTIVE TRIPS
// ==========================================
  static Future<List> getDriverActiveTrips(
      int providerId) async {
    var response = await http.get(
      Uri.parse(
        "$baseUrl/get_driver_active_trips.php?provider_id=$providerId",
      ),
    );
    var data = jsonDecode(response.body);
    if (data["success"]) {
      return data["data"];
    }
    return [];
  }

// ==========================================
// DRIVER COMPLETED TRIPS
// ==========================================
  static Future<List> getCompletedDriverTrips(
      int providerId) async {
    var response = await http.get(
      Uri.parse(
        "$baseUrl/get_driver_completed_trips.php?provider_id=$providerId",
      ),
    );
    var data = jsonDecode(response.body);
    if (data["success"]) {
      return data["data"];
    }
    return [];
  }

// ==========================================
// GET INTERPRETER PROFILE
// ==========================================
  static Future<Map?> getInterpreterProfile(int userId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/get_interpreter_profile.php?user_id=$userId'),
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['data'] is Map)  return decoded['data'] as Map;
        if (decoded is Map && decoded['data'] is List) {
          final list = decoded['data'] as List;
          if (list.isNotEmpty) return list[0] as Map;
        }
        if (decoded is Map && decoded['success'] == null) return decoded;
      }
    } catch (_) {}
    return null;
  }

// ==========================================
// UPDATE INTERPRETER PROFILE
// ==========================================
  static Future<bool> updateInterpreterProfile(Map<String, String> data) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/update_interpreter_profile.php'),
        body: data,
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return decoded['success'] == true;
      }
    } catch (_) {}
    return false;
  }

// ==========================================
// GET INTERPRETER SESSIONS
// ==========================================
  static Future<List> getInterpreterSessions(
      int providerId) async {
    var response = await http.get(
      Uri.parse(
        "$baseUrl/get_interpreter_sessions.php?provider_id=$providerId",
      ),
    );
    var data = jsonDecode(response.body);
    if (data["success"]) {
      return data["data"];
    }
    return [];
  }

// ==========================================
// GET COMPLETED INTERPRETER SESSIONS
// ==========================================
    static Future<List>
  getCompletedInterpreterSessions(
      int providerId) async {
    var response = await http.get(
      Uri.parse(
        "$baseUrl/get_completed_interpreter_sessions.php?provider_id=$providerId",
      ),
    );
    var data = jsonDecode(response.body);
    if (data["success"]) {
      return data["data"];
    }
    return [];
  }

// ==========================================
// SUBMIT PLACE ACCESSIBILITY REVIEW
// ==========================================
  static Future<Map<String, dynamic>> submitPlaceReview({
    required String osmId,
    required String name,
    required String type,
    required String address,
    required double latitude,
    required double longitude,
    bool? wheelchair,
    bool? elevator,
    bool? ramp,
    bool? toilet,
    bool? parking,
    int? rating,          // ← this line must be here
    String comment = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/submit_place_review.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "osm_id":    osmId,
          "name":      name,
          "type":      type,
          "address":   address,
          "latitude":  latitude,
          "longitude": longitude,
          if (wheelchair != null) "wheelchair": wheelchair,
          if (elevator   != null) "elevator":   elevator,
          if (ramp       != null) "ramp":        ramp,
          if (toilet     != null) "toilet":      toilet,
          if (parking    != null) "parking":     parking,
          if (rating     != null) "rating":      rating,  // ← NEW
          "comment": comment,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"success": false, "message": "Connection failed: $e"};
    }
  }

// ==========================================
// GET REVIEWED PLACES  (Community tab)
// (add this method alongside submitPlaceReview)
// ==========================================
  static Future<List<Map<String, dynamic>>> getReviewedPlaces() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/get_reviewed_places.php'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      }
      return [];
    } catch (e) {
      print("getReviewedPlaces error: $e");
      return [];
    }
  }

// ==========================================
// GET PLACE FEATURES FOR THE ACCESSIBILITY MAP
// ==========================================
  static Future<Map<String, dynamic>> getPlaceFeatures(List<String> osmIds) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get_place_features.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"osm_ids": osmIds}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
      return {};
    } catch (e) {
      print("getPlaceFeatures error: $e");
      return {};
    }
  }

// ==========================================
// GET NEARBY ACCESSIBLE PLACES
// ==========================================
  static Future<List<Map<String, dynamic>>> getPlacesNearby({
    required double lat,
    required double lng,
    double radiusKm = 5,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/get_places_nearby.php?lat=$lat&lng=$lng&radius=$radiusKm',
        ),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      }
      return [];
    } catch (e) {
      print("getPlacesNearby error: $e");
      return [];
    }
  }

// ==========================================
// REQUEST DRIVER BOOKING
// ==========================================
  static Future<Map<String, dynamic>> requestDriverBooking({
    required int patientId,
    required double pickupLat, required double pickupLng,
    required double destLat,   required double destLng,
    required String pickupAddress, required String destination,
    required String requestType,
    DateTime? schedDate, TimeOfDay? schedTime,
    double distanceKm = 0, double totalFare = 0,
  }) => DriverApi.requestDriverBooking(
    patientId: patientId, pickupLat: pickupLat, pickupLng: pickupLng,
    destLat: destLat, destLng: destLng, pickupAddress: pickupAddress,
    destination: destination, requestType: requestType,
    schedDate: schedDate, schedTime: schedTime,
    distanceKm: distanceKm, totalFare: totalFare,
  );

// ==========================================
// RATE PATIENT
// ==========================================
  static Future<bool> ratePatient({
    required int bookingId,
    required int driverId,
    required int rating,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/rate_patient.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'booking_id': bookingId,
          'driver_id': driverId,
          'driver_patient_rating': rating,
          'driver_patient_comment': '',
        }),
      );
      final data = jsonDecode(res.body);
      return data['success'] == true;
    } catch (_) { return false; }
  }

// ==========================================
// CHATBOT
// ==========================================
  static Future<String?> sendChatMessage({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chatbot_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'history': history,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['reply'] as String?;
        }
      }
      return null;
    } catch (e) {
      print('sendChatMessage error: $e');
      return null;
    }
  }

// ==========================================
// CANCEL BOOKING
// ==========================================
  static Future<bool> cancelBooking({
    required int bookingId,
    required int patientId,
  }) async {
    try {
      print('CANCEL API: bookingId=$bookingId patientId=$patientId');
      final res = await http.post(
        Uri.parse('$baseUrl/cancel_booking.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'booking_id': bookingId,
          'patient_id': patientId,
        }),
      );
      print('CANCEL RESPONSE: ${res.body}');
      final data = jsonDecode(res.body);
      return data['success'] == true;
    } catch (e) {
      print('CANCEL ERROR: $e');
      return false;
    }
  }

  // ==========================================
  // CHECK EMAIL
  // ==========================================
  static Future<bool> isEmailTaken(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/check_email.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      final data = jsonDecode(response.body);
      return data['exists'] == true;
    } catch (_) {
      return false; // if check fails, let it through
    }
  }
}