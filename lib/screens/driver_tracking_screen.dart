// // lib/screens/driver_tracking_screen.dart
// // ─────────────────────────────────────────────────────────────────────────────
// //  Live tracking screen for the driver.
// //  Shows map with pickup + destination pins, driver's live GPS pin,
// //  phase buttons (On my way → Arrived → Start Trip → Complete),
// //  and passenger info + fare.
// //  Matches existing DriverSessionsScreen style exactly.
// // ─────────────────────────────────────────────────────────────────────────────

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:latlong2/latlong.dart';
// import '../auth/api_service.dart';

// class DriverTrackingScreen extends StatefulWidget {
//   final int    bookingId;
//   final int    driverId;
//   final double pickupLat;
//   final double pickupLng;
//   final double destLat;
//   final double destLng;
//   final String pickupAddress;
//   final String destination;
//   final String passengerName;
//   final String passengerPhone;
//   final double fare;

//   const DriverTrackingScreen({
//     super.key,
//     required this.bookingId,
//     required this.driverId,
//     required this.pickupLat,
//     required this.pickupLng,
//     required this.destLat,
//     required this.destLng,
//     required this.pickupAddress,
//     required this.destination,
//     required this.passengerName,
//     required this.passengerPhone,
//     required this.fare,
//   });

//   @override
//   State<DriverTrackingScreen> createState() => _DriverTrackingScreenState();
// }

// class _DriverTrackingScreenState extends State<DriverTrackingScreen> {
//   // ── Colours (matches DriverSessionsScreen) ───────────────────────────────
//   static const kPrimary = Color(0xff2E2E5D);
//   static const kPurple  = Color(0xff5B58EB);
//   static const kGreen   = Color(0xff1F9D5A);
//   static const kMuted   = Color(0xff7A84A3);
//   static const kBg      = Color(0xffF7F8FC);

//   // ── Phase ─────────────────────────────────────────────────────────────────
//   // Phases: waiting → arriving → arrived → in_trip → completed
//   String _phase = 'waiting';
//   bool   _phaseLoading = false;

//   // ── GPS ───────────────────────────────────────────────────────────────────
//   StreamSubscription<Position>? _gpsSub;
//   LatLng? _driverPos;
//   bool    _gpsActive = false;

//   // ── Map ───────────────────────────────────────────────────────────────────
//   final _mapController = MapController();

//   late final LatLng _pickup;
//   late final LatLng _dest;

//   @override
//   void initState() {
//     super.initState();
//     _pickup = LatLng(widget.pickupLat, widget.pickupLng);
//     _dest   = LatLng(widget.destLat,   widget.destLng);
//     // Centre map to show both pins
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _mapController.move(_pickup, 13);
//     });
//   }

//   @override
//   void dispose() {
//     _gpsSub?.cancel();
//     super.dispose();
//   }

//   // ── GPS helpers ───────────────────────────────────────────────────────────
//   Future<void> _startGPS() async {
//     final svc = await Geolocator.isLocationServiceEnabled();
//     if (!svc) { _snack('Please turn on GPS'); return; }
//     var perm = await Geolocator.checkPermission();
//     if (perm == LocationPermission.denied) {
//       perm = await Geolocator.requestPermission();
//     }
//     if (perm == LocationPermission.deniedForever) return;

//     setState(() => _gpsActive = true);
//     _gpsSub = Geolocator.getPositionStream(
//       locationSettings: const LocationSettings(
//         accuracy: LocationAccuracy.high,
//         distanceFilter: 10,
//       ),
//     ).listen((pos) async {
//       final ll = LatLng(pos.latitude, pos.longitude);
//       setState(() => _driverPos = ll);
//       _mapController.move(ll, 15);
//       // Broadcast to server
//       await ApiService.updateDriverLocation(
//           widget.bookingId, pos.latitude, pos.longitude);
//     });
//   }

//   void _stopGPS() {
//     _gpsSub?.cancel();
//     _gpsSub = null;
//     setState(() => _gpsActive = false);
//   }

//   // ── Phase change ──────────────────────────────────────────────────────────
//   Future<void> _setPhase(String newPhase) async {
//     setState(() => _phaseLoading = true);

//     // Map phase → booking status
//     final statusMap = {
//       'arriving':    'accepted',
//       'arrived':     'arrived',
//       'in_trip':     'in_trip',
//       'completed':   'completed',
//     };

//     final bookingStatus = statusMap[newPhase] ?? newPhase;
//     await ApiService.updateBookingStatus(widget.bookingId, bookingStatus);

//     if (newPhase == 'arriving') await _startGPS();
//     if (newPhase == 'completed') _stopGPS();

//     if (mounted) setState(() { _phase = newPhase; _phaseLoading = false; });
//   }

//   // ── Phase config ──────────────────────────────────────────────────────────
//   Map<String, dynamic> _phaseCfg() {
//     switch (_phase) {
//       case 'waiting':
//         return {
//           'label':  'Ready to go',
//           'sub':    'Tap "I\'m on my way" to start sharing location',
//           'color':  kMuted,
//           'bg':     kMuted.withOpacity(0.1),
//         };
//       case 'arriving':
//         return {
//           'label':  'On the way',
//           'sub':    'Sharing your location with passenger',
//           'color':  kPurple,
//           'bg':     kPurple.withOpacity(0.1),
//         };
//       case 'arrived':
//         return {
//           'label':  'You\'ve arrived',
//           'sub':    'Waiting for passenger to board',
//           'color':  const Color(0xffF59E0B),
//           'bg':     const Color(0xffFFFBEB),
//         };
//       case 'in_trip':
//         return {
//           'label':  'Trip in progress',
//           'sub':    'Driving to destination',
//           'color':  kGreen,
//           'bg':     kGreen.withOpacity(0.1),
//         };
//       case 'completed':
//         return {
//           'label':  'Trip completed! 🎉',
//           'sub':    'Great job!',
//           'color':  kPrimary,
//           'bg':     kPrimary.withOpacity(0.08),
//         };
//       default:
//         return {'label': _phase, 'sub': '', 'color': kMuted, 'bg': kBg};
//     }
//   }

//   // ─────────────────────────────────────────────────────────────────────────
//   //  BUILD
//   // ─────────────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     final cfg = _phaseCfg();
//     final bottom = MediaQuery.of(context).padding.bottom;

//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(children: [

//         // ── Map ─────────────────────────────────────────────────────────────
//         FlutterMap(
//           mapController: _mapController,
//           options: MapOptions(
//             initialCenter: _pickup,
//             initialZoom: 13,
//           ),
//           children: [
//             TileLayer(
//               urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//               userAgentPackageName: 'com.rafiq.app.v2',
//             ),
//             // Route line
//             PolylineLayer(polylines: [
//               Polyline(
//                 points: [_pickup, _dest],
//                 color: kPurple.withOpacity(0.5),
//                 strokeWidth: 4,
//                 isDotted: true,
//               ),
//               if (_driverPos != null)
//                 Polyline(
//                   points: [_driverPos!, _pickup],
//                   color: kGreen.withOpacity(0.6),
//                   strokeWidth: 3,
//                   isDotted: true,
//                 ),
//             ]),
//             MarkerLayer(markers: _buildMarkers()),
//           ],
//         ),

//         // ── App bar ──────────────────────────────────────────────────────────
//         Positioned(
//           top: MediaQuery.of(context).padding.top + 8,
//           left: 16,
//           child: GestureDetector(
//             onTap: () => Navigator.pop(context),
//             child: Container(
//               padding: const EdgeInsets.all(10),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(14),
//                 boxShadow: [BoxShadow(
//                     color: Colors.black.withOpacity(0.15),
//                     blurRadius: 10)],
//               ),
//               child: const Icon(Icons.arrow_back_ios_new_rounded,
//                   size: 18, color: kPrimary),
//             ),
//           ),
//         ),

//         // ── GPS indicator ─────────────────────────────────────────────────
//         Positioned(
//           top: MediaQuery.of(context).padding.top + 8,
//           right: 16,
//           child: Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(14),
//               boxShadow: [BoxShadow(
//                   color: Colors.black.withOpacity(0.15), blurRadius: 10)],
//             ),
//             child: Row(mainAxisSize: MainAxisSize.min, children: [
//               Container(
//                 width: 8, height: 8,
//                 decoration: BoxDecoration(
//                   color: _gpsActive ? kGreen : Colors.grey,
//                   shape: BoxShape.circle,
//                 ),
//               ),
//               const SizedBox(width: 6),
//               Text(
//                 _gpsActive ? 'GPS Active' : 'GPS Off',
//                 style: TextStyle(
//                   fontSize: 12, fontWeight: FontWeight.w800,
//                   color: _gpsActive ? kGreen : Colors.grey,
//                 ),
//               ),
//             ]),
//           ),
//         ),

//         // ── Bottom sheet ─────────────────────────────────────────────────
//         Align(
//           alignment: Alignment.bottomCenter,
//           child: Container(
//             padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
//               boxShadow: [BoxShadow(
//                   color: Colors.black.withOpacity(0.12),
//                   blurRadius: 30, offset: const Offset(0, -8))],
//             ),
//             child: Column(mainAxisSize: MainAxisSize.min, children: [

//               // Drag bar
//               Center(child: Container(
//                 width: 40, height: 4,
//                 decoration: BoxDecoration(
//                     color: Colors.grey.shade200,
//                     borderRadius: BorderRadius.circular(4)),
//               )),
//               const SizedBox(height: 16),

//               // Status banner
//               AnimatedContainer(
//                 duration: const Duration(milliseconds: 300),
//                 padding: const EdgeInsets.all(14),
//                 decoration: BoxDecoration(
//                   color: cfg['bg'] as Color,
//                   borderRadius: BorderRadius.circular(16),
//                   border: Border.all(
//                       color: (cfg['color'] as Color).withOpacity(0.25)),
//                 ),
//                 child: Row(children: [
//                   Container(
//                     width: 10, height: 10,
//                     decoration: BoxDecoration(
//                         color: cfg['color'] as Color,
//                         shape: BoxShape.circle),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                     Text(cfg['label'] as String,
//                         style: const TextStyle(fontSize: 15,
//                             fontWeight: FontWeight.w900, color: kPrimary)),
//                     const SizedBox(height: 2),
//                     Text(cfg['sub'] as String,
//                         style: const TextStyle(fontSize: 12,
//                             fontWeight: FontWeight.w700, color: kMuted)),
//                   ])),
//                 ]),
//               ),

//               const SizedBox(height: 14),

//               // Passenger info row
//               Container(
//                 padding: const EdgeInsets.all(14),
//                 decoration: BoxDecoration(
//                   color: kBg,
//                   borderRadius: BorderRadius.circular(16),
//                   border: Border.all(color: const Color(0xffE8EDF6)),
//                 ),
//                 child: Row(children: [
//                   Container(
//                     width: 44, height: 44,
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(
//                           colors: [kPrimary, kPurple]),
//                       borderRadius: BorderRadius.circular(14),
//                     ),
//                     child: const Icon(Icons.person_rounded,
//                         color: Colors.white, size: 22),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                     Text(widget.passengerName.isNotEmpty
//                             ? widget.passengerName : 'Passenger',
//                         style: const TextStyle(fontSize: 15,
//                             fontWeight: FontWeight.w900, color: kPrimary)),
//                     if (widget.passengerPhone.isNotEmpty)
//                       Text(widget.passengerPhone,
//                           style: const TextStyle(fontSize: 12,
//                               color: kMuted, fontWeight: FontWeight.w600)),
//                   ])),
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 12, vertical: 6),
//                     decoration: BoxDecoration(
//                         color: kGreen.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(10)),
//                     child: Text(
//                       '${widget.fare.toStringAsFixed(2)} EGP',
//                       style: const TextStyle(fontSize: 13,
//                           fontWeight: FontWeight.w900,
//                           color: kGreen),
//                     ),
//                   ),
//                 ]),
//               ),

//               const SizedBox(height: 14),

//               // Route info
//               Row(children: [
//                 Expanded(child: _routeTile(
//                     Icons.my_location_rounded,
//                     'Pickup', widget.pickupAddress, kGreen)),
//                 const SizedBox(width: 10),
//                 Expanded(child: _routeTile(
//                     Icons.location_on_rounded,
//                     'Destination', widget.destination, kPrimary)),
//               ]),

//               const SizedBox(height: 14),

//               // Phase button
//               if (_phase != 'completed') _buildPhaseButton(),

//               if (_phase == 'completed')
//                 Container(
//                   width: double.infinity,
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                   decoration: BoxDecoration(
//                     color: kGreen.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(16),
//                     border: Border.all(color: kGreen.withOpacity(0.3)),
//                   ),
//                   child: const Center(
//                     child: Text('✅  Trip Complete',
//                         style: TextStyle(fontSize: 15,
//                             fontWeight: FontWeight.w900, color: kGreen)),
//                   ),
//                 ),
//             ]),
//           ),
//         ),
//       ]),
//     );
//   }

//   // ── Phase button ──────────────────────────────────────────────────────────
//   Widget _buildPhaseButton() {
//     String label;
//     String next;
//     Color  color;
//     IconData icon;

//     switch (_phase) {
//       case 'waiting':
//         label = "I'm on my way";  next = 'arriving';
//         color = kPurple;          icon = Icons.directions_car_rounded;
//         break;
//       case 'arriving':
//         label = "I've Arrived";   next = 'arrived';
//         color = const Color(0xffF59E0B); icon = Icons.flag_rounded;
//         break;
//       case 'arrived':
//         label = 'Start Trip';     next = 'in_trip';
//         color = kPrimary;         icon = Icons.play_arrow_rounded;
//         break;
//       case 'in_trip':
//         label = 'Complete Trip';  next = 'completed';
//         color = kGreen;           icon = Icons.check_rounded;
//         break;
//       default:
//         return const SizedBox.shrink();
//     }

//     return GestureDetector(
//       onTap: _phaseLoading ? null : () => _phase == 'in_trip'
//           ? _confirmComplete(next)
//           : _setPhase(next),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         width: double.infinity,
//         padding: const EdgeInsets.symmetric(vertical: 16),
//         decoration: BoxDecoration(
//           color: _phaseLoading ? color.withOpacity(0.5) : color,
//           borderRadius: BorderRadius.circular(18),
//           boxShadow: [BoxShadow(
//               color: color.withOpacity(0.3),
//               blurRadius: 12, offset: const Offset(0, 4))],
//         ),
//         child: _phaseLoading
//             ? const Center(child: SizedBox(
//                 width: 22, height: 22,
//                 child: CircularProgressIndicator(
//                     color: Colors.white, strokeWidth: 2.5)))
//             : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
//                 Icon(icon, color: Colors.white, size: 20),
//                 const SizedBox(width: 8),
//                 Text(label, style: const TextStyle(
//                     fontSize: 15, fontWeight: FontWeight.w900,
//                     color: Colors.white)),
//               ]),
//       ),
//     );
//   }

//   void _confirmComplete(String next) {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         title: const Text('Complete Trip?',
//             style: TextStyle(fontWeight: FontWeight.w900, color: kPrimary)),
//         content: const Text('This will mark the trip as completed.',
//             style: TextStyle(color: kMuted, fontWeight: FontWeight.w600)),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context),
//               child: const Text('Cancel')),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//                 backgroundColor: kGreen,
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12))),
//             onPressed: () { Navigator.pop(context); _setPhase(next); },
//             child: const Text('Complete',
//                 style: TextStyle(color: Colors.white,
//                     fontWeight: FontWeight.w800)),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Route tile ────────────────────────────────────────────────────────────
//   Widget _routeTile(IconData icon, String label, String value, Color color) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: kBg,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xffE8EDF6)),
//       ),
//       child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Icon(icon, size: 16, color: color),
//         const SizedBox(width: 8),
//         Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//           Text(label, style: const TextStyle(fontSize: 10,
//               fontWeight: FontWeight.w900, color: kMuted,
//               letterSpacing: 0.5)),
//           const SizedBox(height: 3),
//           Text(value.isNotEmpty ? value : '—',
//               style: const TextStyle(fontSize: 12,
//                   fontWeight: FontWeight.w800, color: kPrimary),
//               maxLines: 2, overflow: TextOverflow.ellipsis),
//         ])),
//       ]),
//     );
//   }

//   // ── Map markers ───────────────────────────────────────────────────────────
//   List<Marker> _buildMarkers() {
//     final markers = <Marker>[
//       // Pickup
//       Marker(
//         point: _pickup,
//         width: 44, height: 44,
//         child: Container(
//           decoration: BoxDecoration(
//             color: kGreen,
//             shape: BoxShape.circle,
//             border: Border.all(color: Colors.white, width: 3),
//             boxShadow: [BoxShadow(
//                 color: kGreen.withOpacity(0.4), blurRadius: 8)],
//           ),
//           child: const Icon(Icons.person_pin_rounded,
//               color: Colors.white, size: 20),
//         ),
//       ),
//       // Destination
//       Marker(
//         point: _dest,
//         width: 44, height: 56,
//         child: Column(children: [
//           Container(
//             width: 40, height: 40,
//             decoration: BoxDecoration(
//               color: kPrimary,
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.white, width: 2),
//               boxShadow: [BoxShadow(
//                   color: kPrimary.withOpacity(0.4), blurRadius: 8)],
//             ),
//             child: const Icon(Icons.location_on_rounded,
//                 color: Colors.white, size: 20),
//           ),
//           const Icon(Icons.arrow_drop_down, color: kPrimary, size: 18),
//         ]),
//       ),
//     ];

//     // Driver pin
//     if (_driverPos != null) {
//       markers.add(Marker(
//         point: _driverPos!,
//         width: 52, height: 52,
//         child: Container(
//           decoration: BoxDecoration(
//             gradient: const LinearGradient(
//                 colors: [kPrimary, kPurple]),
//             shape: BoxShape.circle,
//             border: Border.all(color: Colors.white, width: 3),
//             boxShadow: [BoxShadow(
//                 color: kPurple.withOpacity(0.4), blurRadius: 10)],
//           ),
//           child: const Icon(Icons.directions_car_rounded,
//               color: Colors.white, size: 24),
//         ),
//       ));
//     }

//     return markers;
//   }

//   void _snack(String msg) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//       content: Text(msg),
//       backgroundColor: kPrimary,
//       behavior: SnackBarBehavior.floating,
//     ));
//   }
// }