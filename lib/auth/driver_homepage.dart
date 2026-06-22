import 'package:flutter/material.dart';
import '../auth/api_service.dart';
import '../auth/session_manager.dart';

class DriverHomepage extends StatefulWidget {
  const DriverHomepage({super.key});
  @override
  State createState() => _DriverHomepageState();
}

class _DriverHomepageState extends State<DriverHomepage> {
  List requests = [];
  bool loading  = true;
  String firstName = "Driver";
  String address   = "";

  // ── Palette matching patient homepage ──────────────────────
  static const kPrimary = Color(0xFF4B4F83);
  static const kAccent  = Color(0xFF6470D2);
  static const kDark    = Color(0xFF242742);
  static const kMuted   = Color(0xFF6B7188);
  static const kBg      = Color(0xFFF6F8FD);
  static const kBg2     = Color(0xFFF1F4FB);
  static const kLine    = Color(0xFFE8EBF5);

  @override
  void initState() { super.initState(); loadUser(); loadRequests(); }

  Future loadUser() async {
    var user = await SessionManager.getUser();
    setState(() {
      firstName = user?["firstName"] ?? "Driver";
      address   = user?["address"]   ?? "";
    });
  }

  Future loadRequests() async {
    try {
      var data = await ApiService.getDriverRequests();
      setState(() { requests = data ?? []; loading = false; });

      // ← add this
      for (var r in requests) {
        print("=== BOOKING ${r['booking_id']} ===");
        print("booking_time: ${r['booking_time']}");
        print("service_time: ${r['service_time']}");
        print("date: ${r['date']}");
      }

    } catch (e) { setState(() => loading = false); }
  }

  Future acceptRide(int bookingId) async {
    setState(() { requests.removeWhere((r) => r["booking_id"].toString() == bookingId.toString()); });
    int? driverId = await SessionManager.getUserId();
    await ApiService.driverTakeAction(bookingId, driverId!, "accept");
    await loadRequests();
  }

  Future rejectRide(int bookingId) async {
    setState(() { requests.removeWhere((r) => r["booking_id"].toString() == bookingId.toString()); });
    int? driverId = await SessionManager.getUserId();
    await ApiService.driverTakeAction(bookingId, driverId!, "reject");
    await loadRequests();
  }

  String formatDate(String date) {
    try {
      DateTime d = DateTime.parse(date);
      const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
      return "${d.day} ${months[d.month - 1]} ${d.year}";
    } catch (_) { return date; }
  }

  String formatTime(String time) {
    try {
      List parts = time.split(":");
      int hour   = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      // DB stores UTC+2, Egypt is currently UTC+3 (DST) — add 1 hour
      hour = (hour + 1) % 24;

      String pm = hour >= 12 ? "PM" : "AM";
      hour = hour % 12;
      if (hour == 0) hour = 12;
      String minStr = minute.toString().padLeft(2, '0');
      return "$hour:$minStr $pm";
    } catch (_) { return time; }
  }

    // ← ADD HERE
    bool _isToday(String dateStr) {
      try {
        final d = DateTime.parse(dateStr);
        final now = DateTime.now();
        return d.year == now.year && d.month == now.month && d.day == now.day;
      } catch (_) { return true; }
    }

  

  DateTime? _parseScheduled(Map r) {
    final dateStr = r['date']?.toString() ?? '';
    final timeStr = (r['service_time'] ?? r['booking_time'])?.toString() ?? '';
    if (dateStr.isEmpty || timeStr.isEmpty) return null;
    try { return DateTime.parse('${dateStr.substring(0, 10)} $timeStr'); } catch (_) { return null; }
  }

  String _scheduleType(Map r) {
    final scheduled = _parseScheduled(r);
    if (scheduled == null) return 'now';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final schedDay = DateTime(scheduled.year, scheduled.month, scheduled.day);
    if (schedDay.isBefore(today)) return 'now';
    if (schedDay.isAfter(today))  return 'scheduled';
    if (now.isAfter(scheduled.subtract(const Duration(hours: 1)))) return 'now';
    return 'today';
  }

  Widget _scheduleBadge(Map r) {
    final type = _scheduleType(r);
    switch (type) {
      case 'now':       return _badge('Now',             Icons.circle,              const Color(0xff137043), const Color(0xffEEFAF3));
      case 'today':     return _badge('Scheduled Today', Icons.schedule_rounded,    const Color(0xffB45309), const Color(0xffFFFBEB));
      case 'scheduled': default:
                        return _badge('Scheduled',       Icons.calendar_today_rounded, const Color(0xFF4B4F83), const Color(0xFFEEF2FF));
    }
  }

  Widget _badge(String label, IconData icon, Color textColor, Color bgColor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor, borderRadius: BorderRadius.circular(999),
      border: Border.all(color: textColor.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: textColor),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textColor)),
    ]),
  );

  Widget _paymentBadge(String? method) {
    final isVisa = method?.toString().toLowerCase() == 'visa';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isVisa ? const Color(0xffEEF4FF) : const Color(0xffEEFAF3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: isVisa ? const Color(0xff0b5ed7).withOpacity(0.3) : const Color(0xff146c43).withOpacity(0.3)),
      ),
      child: Text((method ?? 'cash').toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
              color: isVisa ? const Color(0xff0b5ed7) : const Color(0xff146c43))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [kBg, kBg2], stops: [0.0, 0.8],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [

              // Header
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Hi $firstName!",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kDark)),
                  Row(children: [
                    const Icon(Icons.location_on, size: 16, color: kMuted),
                    const SizedBox(width: 4),
                    Text(
                      address.isEmpty ? "Egypt" : address.contains(",") ? address.split(",").last.trim() : address,
                      style: const TextStyle(color: kMuted, fontSize: 13)),
                  ]),
                ]),
                Stack(alignment: Alignment.topRight, children: [
                  const Icon(Icons.notifications_none, size: 28, color: kDark),
                  if (requests.isNotEmpty)
                    Positioned(right: 0, top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text(requests.length.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 11)),
                      )),
                ]),
              ]),

              const SizedBox(height: 18),

              const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("Available Trips", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kDark)),
              ]),

              const SizedBox(height: 12),

              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator(color: kPrimary))
                    : requests.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.directions_car_outlined, size: 48, color: kMuted.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            const Text("No available trips", style: TextStyle(color: kMuted, fontWeight: FontWeight.w600)),
                          ]))
                        : ListView.builder(
                            itemCount: requests.length,
                            itemBuilder: (context, index) {
                              var r = requests[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: kLine),
                                  boxShadow: [BoxShadow(color: kDark.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                                  // Badge header
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F4FB),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                    ),
                                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                      _scheduleBadge(r),
                                      _paymentBadge(r["payment_method"]),
                                    ]),
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text("${r["first_name"]} ${r["last_name"]}",
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kDark)),
                                      const SizedBox(height: 8),
                                      _infoRow(Icons.my_location_rounded,     "Pickup: ${r["address"] ?? "—"}"),
                                      _infoRow(Icons.location_on_rounded,      "Destination: ${r["destination"] ?? "—"}"),
                                      _infoRow(Icons.calendar_today_rounded,   "Date: ${formatDate(r["date"] ?? "")}"),
                                      _infoRow(Icons.access_time_rounded, "Time: ${formatTime((r["booking_time"] ?? r["service_time"]) ?? "")}"),
                                      _infoRow(Icons.attach_money_rounded,     "Total: ${r["payment_total"]} EGP"),
                                      const SizedBox(height: 12),

                                      // Buttons
                                      Row(children: [
                                        Expanded(child: _gradientBtn("Accept", () => acceptRide(int.parse(r["booking_id"].toString())))),
                                        const SizedBox(width: 10),
                                        Expanded(child: _redBtn("Decline", () => rejectRide(int.parse(r["booking_id"].toString())))),
                                      ]),
                                    ]),
                                  ),
                                ]),
                              );
                            },
                          ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [
      Icon(icon, size: 14, color: kMuted),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: kPrimary, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _gradientBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF353B69), Color(0xFF6470D2)]),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: kAccent.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))),
    ),
  );

 Widget _redBtn(String label, VoidCallback onTap) => GestureDetector(
  onTap: onTap,
  child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4FB),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFCDD0E3)),
    ),
    child: Center(child: Text(label,
        style: const TextStyle(color: Color(0xFF6B7188),
            fontWeight: FontWeight.w800, fontSize: 14))),
  ),
);
}