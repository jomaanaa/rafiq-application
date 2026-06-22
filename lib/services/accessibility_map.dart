import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'places_api_service.dart';
import 'package:rafiq/auth/api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
//  THEME
// ─────────────────────────────────────────────────────────────────────────────
class _T {
  static const primary     = Color(0xFF404066);
  static const primary2    = Color(0xFF5F62B3);
  static const primaryDark = Color(0xFF2B2C41);
  static const bg          = Color(0xFFF6F8FF);
  static const card        = Color(0xFFFFFFFF);
  static const textColor   = Color(0xFF23263A);
  static const muted       = Color(0xFF70778D);
  static const border      = Color(0xFFE7EAF3);
  static const chip        = Color(0xFFF1F4FF);
  static const chipBorder  = Color(0xFFDDE3FF);
  static const shadow      = Color(0x1A2B2C41);
  static const success     = Color(0xFF1FA971);
  static const danger      = Color(0xFFE05252);
  static const star        = Color(0xFFFFC22A);

  static BoxDecoration get panel => BoxDecoration(
    color: card,
    border: Border.all(color: border),
    borderRadius: BorderRadius.circular(24),
    boxShadow: const [BoxShadow(color: shadow, blurRadius: 30, offset: Offset(0, 12))],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ACCESSIBILITY FILTER OPTIONS
// ─────────────────────────────────────────────────────────────────────────────
enum _Filter { wheelchair, elevator, ramp, toilet, parking }

final _filterMeta = {
  _Filter.wheelchair: (Icons.accessible_rounded,        'Wheelchair'),
  _Filter.elevator:   (Icons.elevator_outlined,         'Elevator'),
  _Filter.ramp:       (Icons.trending_up_rounded,       'Ramp'),
  _Filter.toilet:     (Icons.wc_outlined,               'Toilet'),
  _Filter.parking:    (Icons.local_parking_rounded,     'Parking'),
};


class _FullscreenMap extends StatefulWidget {
  final LatLng initialCenter;
  final LatLng? userLocation;
  final List<AccessiblePlace> places;
  final void Function(AccessiblePlace) onReview;

  const _FullscreenMap({
    required this.initialCenter,
    required this.userLocation,
    required this.places,
    required this.onReview,
  });

  @override
  State<_FullscreenMap> createState() => _FullscreenMapState();
}

class _FullscreenMapState extends State<_FullscreenMap> {
  AccessiblePlace? _selected;
  final _ctrl = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            FlutterMap(
              mapController: _ctrl,
              options: MapOptions(
                initialCenter: widget.initialCenter,
                initialZoom: 14,
                onTap: (_, __) => setState(() => _selected = null),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                ),
                if (widget.userLocation != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: widget.userLocation!,
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E86DE),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6)
                          ],
                        ),
                      ),
                    ),
                  ]),
                MarkerLayer(
                  markers: widget.places.map((p) => Marker(
                    point: p.location,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selected = p);
                        _ctrl.move(p.location, 15);
                      },
                      child: Icon(
                        Icons.location_on_rounded,
                        color: _selected?.id == p.id
                            ? const Color(0xFF6E6BFF)
                            : _T.primary,
                        size: _selected?.id == p.id ? 42 : 32,
                        shadows: const [
                          Shadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 3))
                        ],
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),

            // ── Close button ──────────────────────────────────────────────
            Positioned(
              top: 12, right: 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 8)
                    ],
                  ),
                  child: const Icon(Icons.fullscreen_exit_rounded,
                      color: _T.primaryDark),
                ),
              ),
            ),

            // ── Place count badge ─────────────────────────────────────────
            Positioned(
              top: 12, left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8)
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.location_on_rounded,
                      size: 14, color: _T.primary),
                  const SizedBox(width: 5),
                  Text('${widget.places.length} places',
                      style: const TextStyle(
                          color: _T.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),

            // ── Popup ─────────────────────────────────────────────────────
            if (_selected != null)
              Positioned(
                left: 12, right: 12, bottom: 12,
                child: _buildPopup(_selected!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopup(AccessiblePlace p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.border),
        boxShadow: const [
          BoxShadow(color: _T.shadow, blurRadius: 16, offset: Offset(0, 6))
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name,
                style: const TextStyle(
                    color: _T.primaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(p.address,
                style: const TextStyle(color: _T.muted, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: p.facilityChips
                  .map((c) => _chip(c['icon'] as IconData, c['label'] as String))
                  .toList(),
            ),
            if (p.distanceKm != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.place_rounded, size: 13, color: _T.success),
                const SizedBox(width: 4),
                Text('${p.distanceKm!.toStringAsFixed(2)} km away',
                    style: const TextStyle(
                        color: _T.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
            ],
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);          // close fullscreen first
                widget.onReview(p);              // then open review sheet
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _T.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.edit_rounded, size: 13, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Leave a Review',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),
        GestureDetector(
          onTap: () => setState(() => _selected = null),
          child: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.close_rounded, color: _T.muted, size: 20),
          ),
        ),
      ]),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _T.chip,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _T.chipBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: const Color(0xFF39406E)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF39406E))),
        ]),
      );
}
// ─────────────────────────────────────────────────────────────────────────────
//  REVIEWED PLACE MODEL
// ─────────────────────────────────────────────────────────────────────────────
class ReviewedPlace {
  final int          placeId;
  final String       name;
  final String       type;
  final String       address;
  final double       latitude;
  final double       longitude;
  final bool         elevator;
  final bool         ramp;
  final bool         toilet;
  final bool         parking;
  final bool         wheelchair;
  final List<String> comments;
  final double       userRating;
  final int          reviewCount;
  final String       status;

  const ReviewedPlace({
    required this.placeId,
    required this.name,
    required this.type,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.elevator,
    required this.ramp,
    required this.toilet,
    required this.parking,
    required this.wheelchair,
    required this.comments,
    required this.userRating,
    required this.reviewCount,
    required this.status,
  });

  double get accessibilityScore {
    int count = 0;
    if (wheelchair) count++;
    if (elevator)   count++;
    if (ramp)       count++;
    if (toilet)     count++;
    if (parking)    count++;
    return count.toDouble();
  }

  double get blendedRating {
    final accessScale = accessibilityScore;
    if (userRating == 0) return accessScale;
    return (userRating * 0.6) + (accessScale * 0.4);
  }

  List<Map<String, dynamic>> get facilityChips {
    final chips = <Map<String, dynamic>>[];
    if (wheelchair) chips.add({'icon': Icons.accessible_rounded,    'label': 'Wheelchair'});
    if (elevator)   chips.add({'icon': Icons.elevator_outlined,     'label': 'Elevator'});
    if (ramp)       chips.add({'icon': Icons.trending_up_rounded,   'label': 'Ramp'});
    if (toilet)     chips.add({'icon': Icons.wc_outlined,           'label': 'Toilet'});
    if (parking)    chips.add({'icon': Icons.local_parking_rounded, 'label': 'Parking'});
    return chips;
  }

  factory ReviewedPlace.fromJson(Map<String, dynamic> j) {
    bool parseBool(dynamic v) =>
        v == true || v == 'true' || v == 1 || v == '1';

    List<String> parseComments(dynamic raw) {
      if (raw is List) {
        return raw
            .map((e) => e?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
      if (raw is String && raw.isNotEmpty) {
        final clean = raw.replaceAll(RegExp(r'\[osm:[^\]]*\]\s*'), '').trim();
        return clean.isEmpty ? [] : [clean];
      }
      return [];
    }

    return ReviewedPlace(
      placeId:     int.tryParse(j['place_id']?.toString()    ?? '0') ?? 0,
      name:        j['name']?.toString()                             ?? '',
      type:        j['type']?.toString()                             ?? 'Place',
      address:     j['address']?.toString()                          ?? '',
      latitude:    double.tryParse(j['latitude']?.toString()  ?? '0') ?? 0,
      longitude:   double.tryParse(j['longitude']?.toString() ?? '0') ?? 0,
      elevator:    parseBool(j['elevator']),
      ramp:        parseBool(j['ramp']),
      toilet:      parseBool(j['toilet']),
      parking:     parseBool(j['parking']),
      wheelchair:  parseBool(j['wheelchair']),
      comments:    parseComments(j['comments']),
      userRating:  double.tryParse(j['rating']?.toString()    ?? '0') ?? 0,
      reviewCount: int.tryParse(j['review_count']?.toString() ?? '0') ?? 0,
      status:      j['status']?.toString()                            ?? 'active',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AccessibilityMapScreen extends StatefulWidget {
  const AccessibilityMapScreen({super.key});

  @override
  State<AccessibilityMapScreen> createState() => _AccessibilityMapScreenState();
}

class _AccessibilityMapScreenState extends State<AccessibilityMapScreen>
    with TickerProviderStateMixin {

  late TabController _tabController;

  final _mapController    = MapController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late  AnimationController _heroAnim;

  void _focusOnMap(double lat, double lng, String name) {
    _tabController.animateTo(0);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _mapController.move(LatLng(lat, lng), 16);
      }
    });
  }

  // ── Explore tab state ────────────────────────────────────────────────────
  List<AccessiblePlace> _allPlaces      = [];
  List<AccessiblePlace> _filteredPlaces = [];
  final Set<_Filter>    _activeFilters  = {};
  int    _selectedTypeIndex = 0;
  String _sortMode          = 'nearest';

  bool     _isLoading    = false;
  String?  _errorMessage;
  LatLng?  _userLocation;
  AccessiblePlace? _selectedPlace;

  bool _filtersExpanded = false;
  bool _listExpanded    = false;
  bool _mapExpanded = false;
  static const int _previewCount = 4;

  // ── Community tab state ──────────────────────────────────────────────────
  List<ReviewedPlace> _reviewedPlaces  = [];
  bool                _reviewedLoading = false;
  String?             _reviewedError;
  String              _communitySort   = 'rating';

  static const _egypt = LatLng(30.0444, 31.2357);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == 1 && _reviewedPlaces.isEmpty) {
        _fetchReviewedPlaces();
      }
    });

    _heroAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _locateAndFetch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _heroAnim.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _locateAndFetch() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final pos = await _getLocation();
      if (mounted) {
        setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(_userLocation!, 14);
        });
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
    await _fetchPlaces();
  }

  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services disabled');

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) throw Exception('Permission denied');
    }
    if (perm == LocationPermission.deniedForever) {
      throw Exception('Permission permanently denied');
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // ── Fetch (Explore) ───────────────────────────────────────────────────────

  Future<void> _fetchPlaces() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final keyword = _searchController.text.trim();
      LatLng center = _userLocation ?? _egypt;

      AccessiblePlace? syntheticLandmark;
      if (keyword.isNotEmpty) {
        final geocoded = await _geocode(keyword);
        if (geocoded != null) {
          center = geocoded;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(center, 15);
          });
          syntheticLandmark = AccessiblePlace(
            id:       'landmark_search',
            name:     keyword,
            address:  'Searched location',
            type:     'Landmark',
            location: geocoded,
            distanceKm: 0,
          );
        }
      }

      List<AccessiblePlace> results = await PlacesApiService.fetchNearby(
        lat:          center.latitude,
        lng:          center.longitude,
        radiusMeters: keyword.isNotEmpty ? 10000 : 5000,
        typeIndex:    _selectedTypeIndex,
        keyword:      null,
      );

      if (results.isNotEmpty) {
        final osmIds = results.map((p) => p.id).toList();
        final dbData = await ApiService.getPlaceFeatures(osmIds);

        if (dbData.isNotEmpty) {
          results = results.map((p) {
            final overlay = dbData[p.id];
            if (overlay == null) return p;
            bool get(String key) => overlay[key] == true || overlay[key] == 'true';
            return AccessiblePlace(
              id:                  p.id,
              name:                p.name,
              address:             p.address,
              type:                p.type,
              location:            p.location,
              distanceKm:          p.distanceKm,
              hasWheelchairAccess: get('wheelchair') || p.hasWheelchairAccess,
              hasElevator:         get('elevator')   || p.hasElevator,
              hasRamp:             get('ramp')       || p.hasRamp,
              hasToilet:           get('toilet')     || p.hasToilet,
              hasParking:          get('parking')    || p.hasParking,
            );
          }).toList();
        }
      }

      if (syntheticLandmark != null) {
        results = [syntheticLandmark, ...results];
      }
      if (mounted) setState(() => _allPlaces = results);
      _applyLocalFilters();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<LatLng?> _geocode(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&limit=1'
        '&countrycodes=eg'
        '&addressdetails=1'
        '&accept-language=en',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'AccessibilityMapApp/1.0 (accessibility helper app)',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List<dynamic>;
        if (results.isNotEmpty) {
          final lat = double.tryParse(results[0]['lat']?.toString() ?? '');
          final lng = double.tryParse(results[0]['lon']?.toString() ?? '');
          if (lat != null && lng != null) return LatLng(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('Geocode error: $e');
    }
    return null;
  }

  // ── Fetch (Community) ────────────────────────────────────────────────────

  Future<void> _fetchReviewedPlaces() async {
    setState(() { _reviewedLoading = true; _reviewedError = null; });
    try {
      final raw    = await ApiService.getReviewedPlaces();
      final places = raw.map((j) => ReviewedPlace.fromJson(j)).toList();
      _sortCommunity(places, _communitySort);
      if (mounted) setState(() => _reviewedPlaces = places);
    } catch (e) {
      if (mounted) setState(() => _reviewedError = e.toString());
    } finally {
      if (mounted) setState(() => _reviewedLoading = false);
    }
  }

  void _sortCommunity(List<ReviewedPlace> list, String mode) {
    if (mode == 'rating') {
      list.sort((a, b) => b.blendedRating.compareTo(a.blendedRating));
    } else if (mode == 'name_asc') {
      list.sort((a, b) => a.name.compareTo(b.name));
    } else if (mode == 'accessibility') {
      list.sort((a, b) => b.accessibilityScore.compareTo(a.accessibilityScore));
    }
  }

  // ── Filtering + Sorting (Explore) ─────────────────────────────────────────

  void _applyLocalFilters() {
    var list = _allPlaces.where((p) {
      final matchW = !_activeFilters.contains(_Filter.wheelchair) || p.hasWheelchairAccess;
      final matchE = !_activeFilters.contains(_Filter.elevator)   || p.hasElevator;
      final matchR = !_activeFilters.contains(_Filter.ramp)       || p.hasRamp;
      final matchT = !_activeFilters.contains(_Filter.toilet)     || p.hasToilet;
      final matchP = !_activeFilters.contains(_Filter.parking)    || p.hasParking;
      return matchW && matchE && matchR && matchT && matchP;
    }).toList();

    if (_sortMode == 'nearest' && _userLocation != null) {
      list.sort((a, b) => (a.distanceKm ?? 9999).compareTo(b.distanceKm ?? 9999));
    } else if (_sortMode == 'name_asc') {
      list.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sortMode == 'name_desc') {
      list.sort((a, b) => b.name.compareTo(a.name));
    }

    if (mounted) setState(() => _filteredPlaces = list);
  }

  void _toggleFilter(_Filter f) {
    setState(() =>
        _activeFilters.contains(f) ? _activeFilters.remove(f) : _activeFilters.add(f));
    _applyLocalFilters();
  }

  // ── Review Bottom Sheet ───────────────────────────────────────────────────

  void _openReviewSheet(AccessiblePlace place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(
        place: place,
        onSubmitted: () {
          if (_reviewedPlaces.isNotEmpty) _fetchReviewedPlaces();
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildHero(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTabBar(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildExploreTab(),
                  _buildCommunityTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _T.chip,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.chipBorder),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _T.primary,
          borderRadius: BorderRadius.circular(11),
          boxShadow: const [
            BoxShadow(color: Color(0x3040406E), blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: _T.muted,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 16),
                SizedBox(width: 6),
                Text('Explore'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_rounded, size: 16),
                SizedBox(width: 6),
                Text('Community'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Explore Tab ───────────────────────────────────────────────────────────

  Widget _buildExploreTab() {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(children: [
              const SizedBox(height: 4),
              _buildInlineSearch(),
              const SizedBox(height: 10),
              _AccordionSection(
                title: 'Filters',
                subtitle: _activeFilters.isEmpty && _selectedTypeIndex == 0
                    ? 'All places · Any type'
                    : '${_selectedTypeIndex > 0 ? osmPlaceTypes[_selectedTypeIndex].label : "Any type"}'
                      '${_activeFilters.isNotEmpty ? " · ${_activeFilters.length} access filter${_activeFilters.length > 1 ? "s" : ""}" : ""}',
                leadingIcon: Icons.tune_rounded,
                isExpanded: _filtersExpanded,
                onToggle: () => setState(() => _filtersExpanded = !_filtersExpanded),
                child: _buildFilterBody(),
              ),
              const SizedBox(height: 14),
              _buildMapPanel(),
              const SizedBox(height: 14),
              _buildResultsPanel(),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Inline Search ─────────────────────────────────────────────────────────

  Widget _buildInlineSearch() {
    return Container(
      decoration: _T.panel,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search places…',
              hintStyle: const TextStyle(color: _T.muted, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: _T.muted, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: _T.muted, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _locateAndFetch();
                      })
                  : null,
              filled: true,
              fillColor: _T.bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _T.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF9EA4FF), width: 1.5),
              ),
            ),
            onSubmitted: (_) => _fetchPlaces(),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _locateAndFetch,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: _userLocation != null ? _T.success : _T.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              _userLocation != null
                  ? Icons.my_location_rounded
                  : Icons.location_searching_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _sortDropdown(),
      ]),
    );
  }

  // ── Filter Body (inside accordion) ───────────────────────────────────────

  Widget _buildFilterBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        const Text('Place Type',
            style: TextStyle(color: _T.muted, fontSize: 12,
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(osmPlaceTypes.length, (i) {
              final t      = osmPlaceTypes[i];
              final active = _selectedTypeIndex == i;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedTypeIndex = i);
                    _fetchPlaces();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: active ? _T.primary : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: active ? _T.primary : const Color(0xFFDBE0EE)),
                      boxShadow: active
                          ? [const BoxShadow(
                              color: Color(0x2240406E), blurRadius: 10,
                              offset: Offset(0, 4))]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, size: 15, color: active ? Colors.white : _T.primaryDark),
                        const SizedBox(width: 6),
                        Text(t.label,
                            style: TextStyle(
                                color: active ? Colors.white : _T.primaryDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 14),

        const Text('Accessibility',
            style: TextStyle(color: _T.muted, fontSize: 12,
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _Filter.values.map((f) {
            final meta   = _filterMeta[f]!;
            final active = _activeFilters.contains(f);
            return GestureDetector(
              onTap: () => _toggleFilter(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? _T.primary : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: active ? _T.primary : const Color(0xFFDBE0EE)),
                  boxShadow: active
                      ? [const BoxShadow(
                          color: Color(0x2240406E), blurRadius: 10,
                          offset: Offset(0, 4))]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(meta.$1, size: 14,
                        color: active ? Colors.white : _T.primaryDark),
                    const SizedBox(width: 5),
                    Text(meta.$2,
                        style: TextStyle(
                            color: active ? Colors.white : _T.primaryDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        if (_activeFilters.isNotEmpty || _selectedTypeIndex != 0) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _activeFilters.clear();
                _selectedTypeIndex = 0;
              });
              _fetchPlaces();
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.refresh_rounded, size: 14, color: _T.danger),
              SizedBox(width: 4),
              Text('Clear all filters',
                  style: TextStyle(
                      color: _T.danger, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ]),
    );
  }

  // ── Community Tab ─────────────────────────────────────────────────────────

  Widget _buildCommunityTab() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(children: [
              _buildCommunityPanel(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityPanel() {
    return Container(
      decoration: _T.panel,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFEEF1F7))),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Community Reviews',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: _T.primaryDark)),
                Text(
                  _reviewedPlaces.isEmpty
                      ? 'Places reviewed by users'
                      : '${_reviewedPlaces.length} reviewed places',
                  style: const TextStyle(fontSize: 12, color: _T.muted),
                ),
              ]),
            ),
            if (_reviewedLoading)
              const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _T.primary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _T.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _communitySort,
                  style: const TextStyle(
                      color: _T.textColor, fontSize: 12, fontWeight: FontWeight.w700),
                  icon: const Icon(Icons.expand_more_rounded, color: _T.muted, size: 18),
                  items: const [
                    DropdownMenuItem(value: 'rating',        child: Text('Top Rated')),
                    DropdownMenuItem(value: 'accessibility', child: Text('Most Accessible')),
                    DropdownMenuItem(value: 'name_asc',      child: Text('A → Z')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _communitySort = v;
                      final sorted = List<ReviewedPlace>.from(_reviewedPlaces);
                      _sortCommunity(sorted, v);
                      _reviewedPlaces = sorted;
                    });
                  },
                ),
              ),
            ),
          ]),
        ),

        if (_reviewedLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Column(children: [
              CircularProgressIndicator(color: _T.primary, strokeWidth: 2.5),
              SizedBox(height: 16),
              Text('Loading community reviews…',
                  style: TextStyle(color: _T.muted, fontSize: 13)),
            ]),
          )
        else if (_reviewedError != null && _reviewedPlaces.isEmpty)
          _emptyState(Icons.warning_amber_rounded, _reviewedError!)
        else if (_reviewedPlaces.isEmpty)
          Column(children: [
            _emptyState(Icons.chat_bubble_outline_rounded,
                'No community reviews yet.\nBe the first to review a place!'),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: GestureDetector(
                onTap: () => _tabController.animateTo(0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _T.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('Go to Explore',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ),
              ),
            ),
          ])
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _reviewedPlaces.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _buildReviewedCard(_reviewedPlaces[i]),
          ),
      ]),
    );
  }

  // ── Community Card ────────────────────────────────────────────────────────

  Widget _buildReviewedCard(ReviewedPlace p) {
    final blended = p.blendedRating;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBEDF5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Name + rating
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: _T.primaryDark),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(p.address,
                  style: const TextStyle(color: _T.muted, fontSize: 12, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _starRow(p.userRating),
            const SizedBox(height: 2),
            Text(p.userRating == 0 ? '—' : p.userRating.toStringAsFixed(1),
                style: const TextStyle(
                    color: _T.star, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        ]),

        const SizedBox(height: 10),

        // Type + accessibility badge
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _T.chip,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _T.chipBorder),
            ),
            child: Text(p.type,
                style: const TextStyle(
                    color: _T.primary2, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8FFF4),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFB6F0D8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.accessible_rounded,
                    size: 11, color: _T.success),
                const SizedBox(width: 4),
                Text(
                  '${p.accessibilityScore.toInt()}/5 features',
                  style: const TextStyle(
                      color: _T.success, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _T.chip,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _T.chipBorder),
            ),
            child: Text(
              '${p.reviewCount} review${p.reviewCount == 1 ? '' : 's'}',
              style: const TextStyle(
                  color: _T.muted, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ]),

        // Facility chips
        if (p.facilityChips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: p.facilityChips
                .map((c) => _iconChip(c['icon'] as IconData, c['label'] as String))
                .toList(),
          ),
        ] else ...[
          const SizedBox(height: 10),
          _iconChip(Icons.info_outline_rounded, 'No accessibility features recorded'),
        ],

        // ── Individual comment bubbles ──────────────────────────────────
        if (p.comments.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Reviews',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _T.muted,
                  letterSpacing: 0.4)),
          const SizedBox(height: 6),
          ...p.comments.asMap().entries.map((entry) {
            final idx     = entry.key;
            final comment = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26, height: 26,
                    margin: const EdgeInsets.only(top: 1, right: 8),
                    decoration: BoxDecoration(
                      color: _T.chip,
                      shape: BoxShape.circle,
                      border: Border.all(color: _T.chipBorder),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${idx + 1}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _T.primary2),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: _T.chip,
                        borderRadius: const BorderRadius.only(
                          topLeft:     Radius.circular(4),
                          topRight:    Radius.circular(12),
                          bottomLeft:  Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        comment,
                        style: const TextStyle(
                            color: _T.primaryDark,
                            fontSize: 12,
                            height: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

  // Score breakdown row
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFBFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _T.border),
          ),
          child: Row(children: [
            _scoreTag(Icons.star_rounded, 'Avg Rating',
                p.userRating == 0 ? '—' : p.userRating.toStringAsFixed(1), _T.star),
            const SizedBox(width: 8),
            _scoreTag(Icons.accessible_rounded, 'Accessibility',
                '${p.accessibilityScore.toInt()}/5', _T.success),
            const SizedBox(width: 8),
            _scoreTag(Icons.workspace_premium_rounded, 'Blended',
                blended.toStringAsFixed(1), _T.primary2),
          ]),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _focusOnMap(p.latitude, p.longitude, p.name),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: _T.chip,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _T.chipBorder),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Icon(Icons.center_focus_strong_rounded, size: 14, color: _T.primary),
              SizedBox(width: 6),
              Text('View on Map',
                  style: TextStyle(
                      color: _T.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _scoreTag(IconData icon, String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 9,
                fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
      ]),
    ),
  );

  Widget _starRow(double rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final fill = (rating - i).clamp(0.0, 1.0);
        return Icon(
          fill >= 1.0
              ? Icons.star_rounded
              : fill > 0
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
          color: _T.star,
          size: size,
        );
      }),
    );
  }

// ── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHero() {
    return FadeTransition(
      opacity: _heroAnim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -0.08), end: Offset.zero)
            .animate(CurvedAnimation(parent: _heroAnim, curve: Curves.easeOut)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF20233C), Color(0xFF353B69), Color(0xFF6470D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF242742).withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Eyebrow pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.map_outlined, size: 11, color: Colors.white),
                    SizedBox(width: 6),
                    Text('ACCESSIBILITY MAP',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Find Accessible Places',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -0.4)),
              const SizedBox(height: 6),
              Text(
                'Discover nearby places and community accessibility reviews.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              // Stats row
              Row(
                children: [
                  _heroStat('5', 'Features'),
                  const SizedBox(width: 8),
                  _heroStat('Live', 'Map'),
                  const SizedBox(width: 8),
                  _heroStat('100%', 'Free'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroStat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            const SizedBox(height: 1),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.65),
                    letterSpacing: 0.2)),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
        ),
      );

  Widget _heroBadge(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.14),
      border: Border.all(color: Colors.white.withOpacity(0.18)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ),
  );

  // ── Map Panel ─────────────────────────────────────────────────────────────
Widget _buildMapPanel() {
  return Container(
    decoration: _T.panel.copyWith(borderRadius: BorderRadius.circular(24)),
    clipBehavior: Clip.antiAlias,
    child: Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
        width: double.infinity,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEEF1F7))),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('Map View',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _T.primaryDark)),
              Text('${_filteredPlaces.length} places shown',
                  style: const TextStyle(fontSize: 12, color: _T.muted)),
            ]),
          ),
          if (_isLoading)
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _T.primary)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                barrierColor: Colors.black87,
                builder: (_) => _FullscreenMap(
                  initialCenter: _userLocation ?? _egypt,
                  userLocation: _userLocation,
                  places: _filteredPlaces,
                  onReview: _openReviewSheet,
                ),
              );
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _T.chip,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _T.chipBorder),
              ),
              child: const Icon(Icons.fullscreen_rounded,
                  color: _T.primaryDark, size: 18),
            ),
          ),
        ]),
      ),
      SizedBox(
        height: 320,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation ?? _egypt,
            initialZoom: 14,
            onTap: (_, __) => setState(() => _selectedPlace = null),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
            ),
            if (_userLocation != null)
              MarkerLayer(markers: [
                Marker(
                  point: _userLocation!,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E86DE),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 6)
                      ],
                    ),
                  ),
                ),
              ]),
            MarkerLayer(
              markers: _filteredPlaces
                  .map((p) => Marker(
                        point: p.location,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedPlace = p);
                            _mapController.move(p.location, 15);
                          },
                          child: Icon(
                            Icons.location_on_rounded,
                            color: _selectedPlace?.id == p.id
                                ? const Color(0xFF6E6BFF)
                                : _T.primary,
                            size: _selectedPlace?.id == p.id ? 42 : 32,
                            shadows: const [
                              Shadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 3))
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
      if (_selectedPlace != null) _buildMapPopup(_selectedPlace!),
    ]),
  );
}

  Widget _buildMapPopup(AccessiblePlace p) {
    final reviewed = _reviewedPlaces
        .where((r) => r.placeId.toString() == p.id || r.name == p.name)
        .firstOrNull;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.border),
        boxShadow: const [
          BoxShadow(color: _T.shadow, blurRadius: 16, offset: Offset(0, 6))
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name,
                style: const TextStyle(
                    color: _T.primaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(p.address,
                style: const TextStyle(color: _T.muted, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: p.facilityChips
                  .map((c) => _iconChip(c['icon'] as IconData, c['label'] as String))
                  .toList(),
            ),
            if (p.distanceKm != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.place_rounded,
                    size: 13, color: _T.success),
                const SizedBox(width: 4),
                Text('${p.distanceKm!.toStringAsFixed(2)} km away',
                    style: const TextStyle(
                        color: _T.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
            ],
            if (reviewed != null && reviewed.userRating > 0) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.star_rounded, size: 13, color: _T.star),
                const SizedBox(width: 4),
                Text(reviewed.userRating.toStringAsFixed(1),
                    style: const TextStyle(
                        color: _T.star,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Text('(${reviewed.reviewCount} review${reviewed.reviewCount == 1 ? '' : 's'})',
                    style: const TextStyle(
                        color: _T.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
            ],
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _openReviewSheet(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _T.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.edit_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Leave a Review',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ]),
        ),
        GestureDetector(
          onTap: () => setState(() => _selectedPlace = null),
          child: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.close_rounded, color: _T.muted, size: 20),
          ),
        ),
      ]),
    );
  }

  // ── Results Panel (with Show More) ───────────────────────────────────────

  Widget _buildResultsPanel() {
    final showToggle  = _filteredPlaces.length > _previewCount;
    final visibleList = _listExpanded
        ? _filteredPlaces
        : _filteredPlaces.take(_previewCount).toList();

    return Container(
      decoration: _T.panel,
      child: Column(children: [
        _panelHeader(
          'Places (${_filteredPlaces.length})',
          _activeFilters.isEmpty
              ? 'All results'
              : '${_activeFilters.length} filter(s) active',
        ),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Column(children: [
              CircularProgressIndicator(color: _T.primary, strokeWidth: 2.5),
              SizedBox(height: 16),
              Text('Searching nearby places…',
                  style: TextStyle(color: _T.muted, fontSize: 13)),
            ]),
          )
        else if (_errorMessage != null && _filteredPlaces.isEmpty)
          _emptyState(Icons.warning_amber_rounded, _errorMessage!)
        else if (_filteredPlaces.isEmpty)
          _emptyState(Icons.search_off_rounded,
              'No places found nearby.\nTry a different place type or filter.')
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            itemCount: visibleList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _buildPlaceCard(visibleList[i], i + 1),
          ),

          if (showToggle)
            GestureDetector(
              onTap: () => setState(() => _listExpanded = !_listExpanded),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: _T.chip,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _T.chipBorder),
                ),
                alignment: Alignment.center,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    _listExpanded
                        ? 'Show less'
                        : 'Show all ${_filteredPlaces.length} places',
                    style: const TextStyle(
                        color: _T.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _listExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _T.primary, size: 18),
                  ),
                ]),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ]),
    );
  }

  // ── Reusable widgets ──────────────────────────────────────────────────────

  Widget _emptyState(IconData icon, String message) => Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          Icon(icon, size: 40, color: _T.muted),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _T.muted, fontSize: 14, height: 1.5)),
        ]),
      );

  Widget _buildPlaceCard(AccessiblePlace p, int index) {
    final isSelected = _selectedPlace?.id == p.id;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedPlace = p);
        _mapController.move(p.location, 15);
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _T.primary2 : const Color(0xFFEBEDF5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [const BoxShadow(
                  color: Color(0x205F62B3), blurRadius: 20, offset: Offset(0, 6))]
              : [],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: _T.chip, borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Text('$index',
                  style: const TextStyle(
                      color: _T.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _T.primaryDark),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(p.address,
                    style: const TextStyle(
                        color: _T.muted, fontSize: 12, height: 1.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),

          const SizedBox(height: 12),

          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _T.chip,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _T.chipBorder),
              ),
              child: Text(p.type,
                  style: const TextStyle(
                      color: _T.primary2,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
            if (p.distanceKm != null) ...[
              const SizedBox(width: 8),
              Row(children: [
                const Icon(Icons.place_rounded, size: 12, color: _T.success),
                const SizedBox(width: 3),
                Text('${p.distanceKm!.toStringAsFixed(2)} km',
                    style: const TextStyle(
                        color: _T.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]),
            ],
          ]),

          if (p.facilityChips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: p.facilityChips
                  .map((c) => _iconChip(c['icon'] as IconData, c['label'] as String))
                  .toList(),
            ),
          ] else ...[
            const SizedBox(height: 10),
            _iconChip(Icons.info_outline_rounded, 'No accessibility info yet'),
          ],

          const SizedBox(height: 14),

          Row(children: [
            const Spacer(),
            _smallBtn(Icons.center_focus_strong_rounded, 'Focus Map',
                _T.chip, _T.primaryDark, () {
              _mapController.move(p.location, 15);
              _scrollController.animateTo(0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut);
            }),
            const SizedBox(width: 8),
            _smallBtn(Icons.edit_rounded, 'Review',
                _T.primary, Colors.white, () => _openReviewSheet(p)),
          ]),
        ]),
      ),
    );
  }

  Widget _panelHeader(String title, String sub) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEF1F7))),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _T.primaryDark)),
            Text(sub, style: const TextStyle(fontSize: 12, color: _T.muted)),
          ]),
        ),
        if (_isLoading)
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _T.primary)),
      ]),
    );
  }

  /// Chip with a Material icon (replaces the old emoji _chip)
  Widget _iconChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _T.chip,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _T.chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: const Color(0xFF39406E)),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF39406E))),
          ],
        ),
      );

  Widget _smallBtn(IconData icon, String label, Color bg, Color textCol,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: textCol),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: textCol,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _sortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortMode,
          style: const TextStyle(
              color: _T.textColor, fontSize: 12, fontWeight: FontWeight.w700),
          icon: const Icon(Icons.expand_more_rounded, color: _T.muted, size: 18),
          items: const [
            DropdownMenuItem(value: 'nearest',   child: Text('Nearest')),
            DropdownMenuItem(value: 'name_asc',  child: Text('A → Z')),
            DropdownMenuItem(value: 'name_desc', child: Text('Z → A')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _sortMode = v);
            _applyLocalFilters();
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ACCORDION SECTION WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _AccordionSection extends StatelessWidget {
  final String     title;
  final String     subtitle;
  final IconData   leadingIcon;   // ← was: leadingEmoji (String)
  final bool       isExpanded;
  final VoidCallback onToggle;
  final Widget     child;

  const _AccordionSection({
    required this.title,
    required this.subtitle,
    required this.leadingIcon,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: _T.card,
        border: Border.all(color: _T.border),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: _T.shadow, blurRadius: 20, offset: Offset(0, 8))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isExpanded ? _T.primary : _T.chip,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    leadingIcon,
                    size: 18,
                    color: isExpanded ? Colors.white : _T.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _T.primaryDark)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11,
                            color: _T.muted,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ]),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: _T.muted, size: 22),
                ),
              ]),
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(height: 1, color: _T.border),
                child,
              ],
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  REVIEW BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewSheet extends StatefulWidget {
  final AccessiblePlace place;
  final VoidCallback? onSubmitted;
  const _ReviewSheet({required this.place, this.onSubmitted});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  bool? _wheelchair;
  bool? _elevator;
  bool? _ramp;
  bool? _toilet;
  bool? _parking;

  int _starRating = 0;

  final _commentController = TextEditingController();
  bool    _isSubmitting  = false;
  String? _resultMessage;
  bool    _isSuccess     = false;

  @override
  void initState() {
    super.initState();
    _wheelchair = null;
    _elevator   = null;
    _ramp       = null;
    _toilet     = null;
    _parking    = null;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_wheelchair == null && _elevator == null &&
        _ramp == null && _toilet == null &&
        _parking == null && _starRating == 0) {
      setState(() {
        _resultMessage =
            'Please rate at least one accessibility feature or give a star rating.';
        _isSuccess = false;
      });
      return;
    }

    setState(() { _isSubmitting = true; _resultMessage = null; });

    final result = await ApiService.submitPlaceReview(
      osmId:      widget.place.id,
      name:       widget.place.name,
      type:       widget.place.type,
      address:    widget.place.address,
      latitude:   widget.place.location.latitude,
      longitude:  widget.place.location.longitude,
      wheelchair: _wheelchair,
      elevator:   _elevator,
      ramp:       _ramp,
      toilet:     _toilet,
      parking:    _parking,
      rating:     _starRating > 0 ? _starRating : null,
      comment:    _commentController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isSubmitting  = false;
        _isSuccess     = result['success'] == true;
        _resultMessage = _isSuccess
            ? 'Thank you! Your review has been saved.'
            : (result['message'] ?? 'Something went wrong. Please try again.');
      });

      if (_isSuccess) {
        widget.onSubmitted?.call();
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF6F8FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE3FF),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F4FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.edit_rounded,
                  size: 22, color: _T.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Leave a Review',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2B2C41))),
                Text(p.name,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF70778D)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),

          const SizedBox(height: 24),

          const Text('Overall Rating',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF70778D),
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          const Text('How would you rate this place overall?',
              style: TextStyle(fontSize: 12, color: Color(0xFF70778D))),
          const SizedBox(height: 12),
          _buildStarPicker(),

          const SizedBox(height: 24),

          const Text('Accessibility Features',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF70778D),
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          const Text('Tap each feature to mark it as present or absent',
              style: TextStyle(fontSize: 12, color: Color(0xFF70778D))),
          const SizedBox(height: 14),

          _featureToggle(Icons.accessible_rounded,    'Wheelchair Accessible', _wheelchair,
              (v) => setState(() => _wheelchair = v)),
          _featureToggle(Icons.elevator_outlined,     'Elevator', _elevator,
              (v) => setState(() => _elevator = v)),
          _featureToggle(Icons.trending_up_rounded,   'Ramp', _ramp,
              (v) => setState(() => _ramp = v)),
          _featureToggle(Icons.wc_outlined,           'Accessible Toilet', _toilet,
              (v) => setState(() => _toilet = v)),
          _featureToggle(Icons.local_parking_rounded, 'Accessible Parking', _parking,
              (v) => setState(() => _parking = v)),

          const SizedBox(height: 20),

          const Text('Additional Comments (optional)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF70778D),
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g. Ramp is steep, elevator was out of service…',
              hintStyle:
                  const TextStyle(color: Color(0xFF70778D), fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE7EAF3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF9EA4FF), width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (_resultMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _isSuccess
                    ? const Color(0xFFE6F9F2)
                    : const Color(0xFFFFEDED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _isSuccess
                        ? const Color(0xFF1FA971)
                        : const Color(0xFFE05252)),
              ),
              child: Row(children: [
                Icon(
                  _isSuccess
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  size: 16,
                  color: _isSuccess
                      ? const Color(0xFF1FA971)
                      : const Color(0xFFE05252),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_resultMessage!,
                      style: TextStyle(
                          color: _isSuccess
                              ? const Color(0xFF1FA971)
                              : const Color(0xFFE05252),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: GestureDetector(
              onTap: _isSubmitting ? null : _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF404066), Color(0xFF6E6BFF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF404066).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ],
                ),
                alignment: Alignment.center,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.send_rounded,
                              size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Submit Review',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildStarPicker() {
    const labels = ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EAF3)),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final star = i + 1;
            return GestureDetector(
              onTap: () =>
                  setState(() => _starRating = _starRating == star ? 0 : star),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Icon(
                  star <= _starRating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: star <= _starRating
                      ? const Color(0xFFFFC22A)
                      : const Color(0xFFDBE0EE),
                  size: 40,
                ),
              ),
            );
          }),
        ),
        if (_starRating > 0) ...[
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              labels[_starRating],
              key: ValueKey(_starRating),
              style: const TextStyle(
                  color: Color(0xFFFFC22A),
                  fontSize: 14,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ] else
          const SizedBox(height: 4),
        if (_starRating == 0)
          const Text('Tap a star to rate',
              style: TextStyle(color: Color(0xFFB0B8D0), fontSize: 12)),
      ]),
    );
  }

  Widget _featureToggle(
      IconData icon, String label, bool? value, ValueChanged<bool?> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value == null
              ? const Color(0xFFE7EAF3)
              : value
                  ? const Color(0xFF1FA971)
                  : const Color(0xFFE05252),
          width: value == null ? 1 : 1.5,
        ),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: value == null
                ? _T.chip
                : value
                    ? const Color(0xFFE8FFF4)
                    : const Color(0xFFFFEDED),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: value == null
                ? _T.primary
                : value
                    ? const Color(0xFF1FA971)
                    : const Color(0xFFE05252),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2B2C41))),
        ),
        Row(children: [
          _toggleBtn(Icons.check_rounded, _T.success, value == true,
              () => onChanged(value == true ? null : true)),
          const SizedBox(width: 8),
          _toggleBtn(Icons.close_rounded, _T.danger, value == false,
              () => onChanged(value == false ? null : false)),
        ]),
      ]),
    );
  }

  Widget _toggleBtn(IconData icon, Color iconColor, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF1F4FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active
                  ? const Color(0xFF5F62B3)
                  : const Color(0xFFE7EAF3)),
        ),
        alignment: Alignment.center,
        child: Icon(icon,
            size: 18,
            color: active ? iconColor : const Color(0xFFB0B8D0)),
      ),
    );
  }
}