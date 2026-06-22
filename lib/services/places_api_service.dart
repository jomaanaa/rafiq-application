import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────
class AccessiblePlace {
  final String id;
  final String name;
  final String address;
  final String type;
  final LatLng location;
  final bool hasWheelchairAccess;
  final bool hasElevator;
  final bool hasRamp;
  final bool hasToilet;
  final bool hasParking;
  double? distanceKm;

  AccessiblePlace({
    required this.id,
    required this.name,
    required this.address,
    required this.type,
    required this.location,
    this.hasWheelchairAccess = false,
    this.hasElevator = false,
    this.hasRamp = false,
    this.hasToilet = false,
    this.hasParking = false,
    this.distanceKm,
  });

  List<Map<String, dynamic>> get facilityChips {
      final chips = <Map<String, dynamic>>[];
      if (hasWheelchairAccess) chips.add({'icon': Icons.accessible_rounded,    'label': 'Wheelchair'});
      if (hasElevator)         chips.add({'icon': Icons.elevator_outlined,     'label': 'Elevator'});
      if (hasRamp)             chips.add({'icon': Icons.trending_up_rounded,   'label': 'Ramp'});
      if (hasToilet)           chips.add({'icon': Icons.wc_outlined,           'label': 'Toilet'});
      if (hasParking)          chips.add({'icon': Icons.local_parking_rounded, 'label': 'Parking'});
      return chips;
    }

  bool get hasAnyFeature =>
      hasWheelchairAccess || hasElevator || hasRamp || hasToilet || hasParking;
}

// ─────────────────────────────────────────────────────────────────────────────
//  PLACE TYPE CONFIG
// ─────────────────────────────────────────────────────────────────────────────
class OsmPlaceType {
  final String   label;
  final IconData icon;           // was: String emoji
  final List<List<String>> osmTags;
  const OsmPlaceType(this.label, this.icon, this.osmTags);
}

const osmPlaceTypes = [
  OsmPlaceType('All',         Icons.map_rounded,              []),
  OsmPlaceType('Hospitals',   Icons.local_hospital_rounded,   [
    ['amenity', 'hospital'],
    ['amenity', 'clinic'],
    ['amenity', 'pharmacy'],
    ['amenity', 'dentist'],
    ['amenity', 'doctors'],
  ]),
  OsmPlaceType('Malls',       Icons.shopping_bag_rounded,     [
    ['shop', 'mall'],
    ['shop', 'department_store'],
    ['shop', 'supermarket'],
    ['landuse', 'retail'],
  ]),
  OsmPlaceType('Museums',     Icons.account_balance_rounded,  [
    ['tourism', 'museum'],
    ['tourism', 'gallery'],
    ['tourism', 'attraction'],
    ['historic', 'monument'],
  ]),
  OsmPlaceType('Restaurants', Icons.restaurant_rounded,       [
    ['amenity', 'restaurant'],
    ['amenity', 'cafe'],
    ['amenity', 'fast_food'],
    ['amenity', 'food_court'],
    ['amenity', 'ice_cream'],
    ['amenity', 'juice_bar'],
    ['amenity', 'bakery'],
  ]),
  OsmPlaceType('Parks',       Icons.park_rounded,             [
    ['leisure', 'park'],
    ['leisure', 'garden'],
    ['leisure', 'playground'],
    ['leisure', 'nature_reserve'],
    ['landuse', 'recreation_ground'],
  ]),
  OsmPlaceType('Transit',     Icons.directions_transit_rounded, [
    ['public_transport', 'station'],
    ['railway', 'station'],
    ['railway', 'halt'],
    ['amenity', 'bus_station'],
    ['highway', 'bus_stop'],
  ]),
  OsmPlaceType('Hotels',      Icons.hotel_rounded,            [
    ['tourism', 'hotel'],
    ['tourism', 'hostel'],
    ['tourism', 'guest_house'],
    ['tourism', 'apartment'],
  ]),
];

// ─────────────────────────────────────────────────────────────────────────────
//  SERVICE
// ─────────────────────────────────────────────────────────────────────────────
class PlacesApiService {

  static const _headers = {
    'User-Agent': 'AccessibilityMapApp/1.0 (accessibility helper app)',
    'Accept': 'application/json',
    'Content-Type': 'application/x-www-form-urlencoded',
  };

  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  // Result cap per element type (node / way / relation).
  // 200 per type gives a generous result set without hammering the server.
  static const int _resultCap = 200;

  static Future<List<AccessiblePlace>> fetchNearby({
    required double lat,
    required double lng,
    int radiusMeters = 5000,
    int typeIndex = 0,
    String? keyword,
  }) async {
    final query = _buildQuery(lat, lng, radiusMeters, typeIndex);
    debugPrint('Overpass query:\n$query');

    http.Response? response;
    String? lastError;

    for (final endpoint in _endpoints) {
      try {
        debugPrint('Trying POST: $endpoint');

        response = await http
            .post(
              Uri.parse(endpoint),
              headers: _headers,
              body: 'data=${Uri.encodeComponent(query)}',
            )
            .timeout(const Duration(seconds: 40));

        debugPrint('Response status: ${response.statusCode}');

        if (response.statusCode == 200) break;

        if (response.statusCode == 429) {
          debugPrint('Rate limited, waiting 3s...');
          await Future.delayed(const Duration(seconds: 3));
        }

        lastError = 'HTTP ${response.statusCode} from $endpoint';
      } catch (e) {
        lastError = e.toString();
        debugPrint('Endpoint error ($endpoint): $e');
      }
    }

    if (response == null || response.statusCode != 200) {
      throw Exception(
        'Could not reach the map data service.\n'
        'Please check your internet connection and try again.\n'
        'Detail: $lastError',
      );
    }

    final json     = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = json['elements'] as List<dynamic>;
    debugPrint('Overpass returned ${elements.length} elements');

    final places = elements
        .map((e) => _parseElement(e as Map<String, dynamic>, lat, lng))
        .where((p) => p != null)
        .cast<AccessiblePlace>()
        .toList();

    debugPrint('Parsed ${places.length} named places');

    if (keyword != null && keyword.isNotEmpty) {
      final q = keyword.toLowerCase();
      return places
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.address.toLowerCase().contains(q) ||
              p.type.toLowerCase().contains(q))
          .toList();
    }

    return places;
  }

  // ── Query builder ─────────────────────────────────────────────────────────

  static String _buildQuery(double lat, double lng, int radius, int typeIndex) {
    final around = 'around:$radius,$lat,$lng';
    final type   = osmPlaceTypes[typeIndex];

    if (type.osmTags.isEmpty) {
      // "All" — broad sweep.
      // node + way + relation so chain restaurants stored as relations show up.
      return '''
[out:json][timeout:45];
(
  node["amenity"~"^(hospital|clinic|pharmacy|dentist|doctors|restaurant|cafe|fast_food|food_court|ice_cream|juice_bar|bakery|university|school|bank|atm|place_of_worship|theatre|cinema|library|community_centre|bus_station|parking)\$"]($around);
  way["amenity"~"^(hospital|clinic|pharmacy|restaurant|cafe|fast_food|food_court|university|school|bank|place_of_worship|theatre|cinema|library|bus_station|parking)\$"]($around);
  relation["amenity"~"^(hospital|clinic|pharmacy|restaurant|cafe|fast_food|food_court|university|school|bank|place_of_worship|theatre|cinema|library|bus_station)\$"]($around);

  node["tourism"~"^(museum|hotel|hostel|guest_house|attraction|gallery|apartment)\$"]($around);
  way["tourism"~"^(museum|hotel|hostel|guest_house|attraction|gallery|apartment)\$"]($around);
  relation["tourism"~"^(museum|hotel|hostel|guest_house|attraction|gallery|apartment)\$"]($around);

  node["leisure"~"^(park|garden|playground|sports_centre|fitness_centre|swimming_pool|nature_reserve)\$"]($around);
  way["leisure"~"^(park|garden|playground|sports_centre|fitness_centre|swimming_pool|nature_reserve)\$"]($around);
  relation["leisure"~"^(park|garden|playground|sports_centre|fitness_centre|swimming_pool|nature_reserve)\$"]($around);

  node["shop"~"^(mall|department_store|supermarket|convenience|bakery)\$"]($around);
  way["shop"~"^(mall|department_store|supermarket)\$"]($around);
  relation["shop"~"^(mall|department_store|supermarket)\$"]($around);

  node["public_transport"="station"]($around);
  way["public_transport"="station"]($around);
  relation["public_transport"="station"]($around);

  node["railway"~"^(station|halt)\$"]($around);
  way["railway"~"^(station|halt)\$"]($around);
  relation["railway"~"^(station|halt)\$"]($around);

  node["landuse"~"^(commercial|retail)\$"]($around)["name"];
  way["landuse"~"^(commercial|retail)\$"]($around)["name"];
  relation["landuse"~"^(commercial|retail)\$"]($around)["name"];

  node["office"~"^(company|government|educational)\$"]($around)["name"];
  way["office"~"^(company|government|educational)\$"]($around)["name"];
  relation["office"~"^(company|government|educational)\$"]($around)["name"];

  node["building"~"^(university|college|school|commercial)\$"]($around)["name"];
  way["building"~"^(university|college|school|commercial)\$"]($around)["name"];
  relation["building"~"^(university|college|school|commercial)\$"]($around)["name"];
);
out center bb $_resultCap;
''';
    }

    // Specific type — query every tag combination for that type,
    // including relations.
    final buffer = StringBuffer('[out:json][timeout:45];\n(\n');
    for (final tag in type.osmTags) {
      buffer.writeln('  node["${tag[0]}"="${tag[1]}"]($around);');
      buffer.writeln('  way["${tag[0]}"="${tag[1]}"]($around);');
      buffer.writeln('  relation["${tag[0]}"="${tag[1]}"]($around);');
    }
    buffer.writeln(');\nout center bb $_resultCap;');
    return buffer.toString();
  }

  // ── Element parser ────────────────────────────────────────────────────────

  static AccessiblePlace? _parseElement(
      Map<String, dynamic> el, double userLat, double userLng) {
    final tags = (el['tags'] as Map<String, dynamic>?) ?? {};

    double? lat, lng;
    final elType = el['type'] as String? ?? '';

    if (elType == 'node') {
      lat = (el['lat'] as num?)?.toDouble();
      lng = (el['lon'] as num?)?.toDouble();
  } else if ((elType == 'way' || elType == 'relation') &&
            el['center'] != null) {
    lat = (el['center']['lat'] as num?)?.toDouble();
    lng = (el['center']['lon'] as num?)?.toDouble();
  } else if (elType == 'relation' && el['bounds'] != null) {
    final b      = el['bounds'] as Map<String, dynamic>;
    final minLat = (b['minlat'] as num?)?.toDouble();
    final maxLat = (b['maxlat'] as num?)?.toDouble();
    final minLon = (b['minlon'] as num?)?.toDouble();
    final maxLon = (b['maxlon'] as num?)?.toDouble();
    if (minLat != null && maxLat != null && minLon != null && maxLon != null) {
      lat = (minLat + maxLat) / 2;
      lng = (minLon + maxLon) / 2;
    }
  }
  if (lat == null || lng == null) return null;

    // Prefer English name, fall back to Arabic or any name
    final name = (tags['name:en'] as String? ??
                  tags['name'] as String?    ??
                  tags['name:ar'] as String? ??
                  tags['brand:en'] as String? ??  // chain brand fallback
                  tags['brand'] as String?    ??
                  '').trim();
    if (name.isEmpty) return null;

    // Address — graceful fallback chain
    final street  = (tags['addr:street']      as String? ?? '');
    final housenr = (tags['addr:housenumber'] as String? ?? '');
    final suburb  = (tags['addr:suburb']      as String? ?? '');
    final city    = (tags['addr:city']        as String? ?? '');
    final parts   = <String>[];
    if (housenr.isNotEmpty && street.isNotEmpty) {
      parts.add('$housenr $street');
    } else if (street.isNotEmpty) {
      parts.add(street);
    }
    if (suburb.isNotEmpty) parts.add(suburb);
    if (city.isNotEmpty)   parts.add(city);
    final address = parts.isEmpty ? 'Egypt' : parts.join(', ');

    // Accessibility flags — more OSM tag variants covered
    final wheelchair = tags['wheelchair'] == 'yes' ||
                       tags['wheelchair'] == 'limited';
    final elevator   = tags['elevator']  == 'yes' ||
                       tags['highway']   == 'elevator';
    final ramp       = tags['ramp']              == 'yes' ||
                       tags['ramp:wheelchair']   == 'yes' ||
                       tags['kerb']              == 'lowered' ||
                       tags['kerb']              == 'flush';
    final toilet     = tags['toilets:wheelchair'] == 'yes' ||
                       tags['wheelchair:toilet']  == 'yes'  ||
                       (tags['amenity'] == 'toilets' && wheelchair);
    final parking    = tags['parking:condition']  == 'disabled'  ||
                       tags['capacity:disabled']  != null        ||
                       (tags['amenity'] == 'parking' && wheelchair);

    return AccessiblePlace(
      id:                  '${elType}_${el['id']}',
      name:                name,
      address:             address,
      type:                _resolveType(tags),
      location:            LatLng(lat, lng),
      hasWheelchairAccess: wheelchair,
      hasElevator:         elevator,
      hasRamp:             ramp,
      hasToilet:           toilet,
      hasParking:          parking,
      distanceKm:          _haversine(userLat, userLng, lat, lng),
    );
  }

  // ── Type resolver ─────────────────────────────────────────────────────────

  static String _resolveType(Map<String, dynamic> tags) {
    const checks = [
      ['amenity', 'hospital',           'Hospital'],
      ['amenity', 'clinic',             'Clinic'],
      ['amenity', 'pharmacy',           'Pharmacy'],
      ['amenity', 'dentist',            'Dentist'],
      ['amenity', 'doctors',            'Medical Centre'],
      ['amenity', 'restaurant',         'Restaurant'],
      ['amenity', 'cafe',               'Café'],
      ['amenity', 'fast_food',          'Fast Food'],
      ['amenity', 'food_court',         'Food Court'],
      ['amenity', 'ice_cream',          'Ice Cream'],
      ['amenity', 'juice_bar',          'Juice Bar'],
      ['amenity', 'bakery',             'Bakery'],
      ['amenity', 'bank',               'Bank'],
      ['amenity', 'atm',                'ATM'],
      ['amenity', 'school',             'School'],
      ['amenity', 'university',         'University'],
      ['amenity', 'library',            'Library'],
      ['amenity', 'theatre',            'Theatre'],
      ['amenity', 'cinema',             'Cinema'],
      ['amenity', 'bus_station',        'Bus Station'],
      ['amenity', 'parking',            'Parking'],
      ['amenity', 'toilets',            'Public Toilets'],
      ['amenity', 'place_of_worship',   'Place of Worship'],
      ['amenity', 'community_centre',   'Community Centre'],
      ['shop',    'mall',               'Shopping Mall'],
      ['shop',    'department_store',   'Department Store'],
      ['shop',    'supermarket',        'Supermarket'],
      ['shop',    'convenience',        'Convenience Store'],
      ['shop',    'bakery',             'Bakery'],
      ['tourism', 'museum',             'Museum'],
      ['tourism', 'hotel',              'Hotel'],
      ['tourism', 'hostel',             'Hostel'],
      ['tourism', 'guest_house',        'Guest House'],
      ['tourism', 'apartment',          'Serviced Apartment'],
      ['tourism', 'attraction',         'Attraction'],
      ['tourism', 'gallery',            'Gallery'],
      ['leisure', 'park',               'Park'],
      ['leisure', 'garden',             'Garden'],
      ['leisure', 'playground',         'Playground'],
      ['leisure', 'sports_centre',      'Sports Centre'],
      ['leisure', 'fitness_centre',     'Gym'],
      ['leisure', 'swimming_pool',      'Swimming Pool'],
      ['leisure', 'nature_reserve',     'Nature Reserve'],
      ['public_transport', 'station',   'Transit Station'],
      ['railway', 'station',            'Train Station'],
      ['railway', 'halt',               'Train Stop'],
      ['landuse', 'retail',             'Shopping Area'],
      ['landuse', 'recreation_ground',  'Recreation Area'],
      ['historic',  'monument',          'Monument'],
      ['landuse',   'commercial',        'Commercial Area'],
      ['landuse',   'retail',            'Shopping Area'],
      ['office',    'company',           'Company'],
      ['office',    'government',        'Government Office'],
      ['office',    'educational',       'Educational Institution'],
      ['building',  'university',        'University'],
      ['building',  'college',           'College'],
      ['building',  'commercial',        'Commercial Building'],
    ];

    for (final c in checks) {
      if (tags[c[0]] == c[1]) return c[2];
    }
    return 'Place';
  }

  // ── Haversine distance ────────────────────────────────────────────────────

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r    = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a    = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_rad(lat1)) * _cos(_rad(lat2)) *
        _sin(dLon / 2) * _sin(dLon / 2);
    return r * 2 * _asin(_sqrt(a));
  }

  static double _rad(double d)  => d * 3.141592653589793 / 180;
  static double _sin(double x)  => x - x*x*x/6.0 + x*x*x*x*x/120.0;
  static double _cos(double x)  => 1.0 - x*x/2.0 + x*x*x*x/24.0;
  static double _asin(double x) => x + x*x*x/6.0 + 3.0*x*x*x*x*x/40.0;
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double g = x / 2;
    for (int i = 0; i < 20; i++) g = (g + x / g) / 2;
    return g;
  }
}