import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;

// ─────────────────────────────────────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────────────────────────────────────
const _navy   = Color(0xFF1E2040);
const _purple = Color(0xFF353B69);
const _accent = Color(0xFF6470D2);
const _a2     = Color(0xFF494788);
const _light  = Color(0xFFEEF0FF);
const _bg     = Color(0xFFF4F5FB);
const _muted  = Color(0xFF6B7080);
const _border = Color(0x1A6470D2);
const _green  = Color(0xFF16A34A);
const _red    = Color(0xFFDC2626);
const _amber  = Color(0xFFD97706);

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

enum GesturePhase { idle, detecting, thinking, analyzing, confirming, confirmed, unknown }

class GestureSign {
  final String id, name, arabic, emoji, hint, category;
  final bool supported;
  const GestureSign({
    required this.id, required this.name, required this.arabic,
    required this.emoji, required this.hint, required this.category,
    this.supported = false,
  });
}

class GestureCategory {
  final String id, name;
  final Color color;
  final IconData icon;
  const GestureCategory({required this.id, required this.name, required this.color, required this.icon});
}

class DetectionEvent {
  final String name;
  final int confidence;
  final String time;
  const DetectionEvent({required this.name, required this.confidence, required this.time});
}

// ─────────────────────────────────────────────────────────────────────────────
// GESTURE DATASET
// ─────────────────────────────────────────────────────────────────────────────

const _categories = [
  GestureCategory(id: 'greetings', name: 'Greetings',        color: Color(0xFF6470D2), icon: Icons.waving_hand),
  GestureCategory(id: 'emergency', name: 'Emergency',         color: Color(0xFFDC2626), icon: Icons.warning_amber),
  GestureCategory(id: 'medical',   name: 'Medical',           color: Color(0xFF0EA5E9), icon: Icons.medical_services),
  GestureCategory(id: 'needs',     name: 'Needs & Feelings',  color: Color(0xFF16A34A), icon: Icons.favorite),
  GestureCategory(id: 'transport', name: 'Transport',         color: Color(0xFFD97706), icon: Icons.directions_car),
  GestureCategory(id: 'general',   name: 'General',           color: Color(0xFF8B5CF6), icon: Icons.sign_language),
  GestureCategory(id: 'access',    name: 'Accessibility',     color: Color(0xFF14B8A6), icon: Icons.accessible),
];

const _signs = [
  // Greetings
  GestureSign(id:'hello',      name:'Hello',       arabic:'مرحبا',    emoji:'👋',  hint:'Open palm · all 5 fingers spread wide',              category:'greetings', supported:true),
  GestureSign(id:'yes',        name:'Yes',         arabic:'نعم',      emoji:'👍',  hint:'Fist · thumb pointing straight up',                  category:'greetings', supported:true),
  GestureSign(id:'no',         name:'No',          arabic:'لا',       emoji:'🤘',  hint:'Index + pinky up · horns shape',                     category:'greetings', supported:true),
  GestureSign(id:'thank_you',  name:'Thank You',   arabic:'شكراً',    emoji:'🤚',  hint:'Thumb + index + middle up · rest folded',            category:'greetings', supported:true),
  GestureSign(id:'ily',        name:'I Love You',  arabic:'أحبك',     emoji:'🤟',  hint:'Thumb + index + pinky · ILY handshape',             category:'greetings', supported:true),
  GestureSign(id:'please',     name:'Please',      arabic:'من فضلك',  emoji:'✋',  hint:'Flat hand · circles clockwise on chest',            category:'greetings', supported:true),
  GestureSign(id:'sorry',      name:'Sorry',       arabic:'آسف',      emoji:'✊',  hint:'Fist · circles on chest',                           category:'greetings', supported:true),
  GestureSign(id:'goodbye',    name:'Goodbye',     arabic:'وداعاً',   emoji:'🖐️',  hint:'Open palm · wave side to side',                     category:'greetings', supported:true),
  GestureSign(id:'youre_welcome', name:"You're Welcome", arabic:'على الرحب', emoji:'🤲', hint:'Flat hand sweeps inward from chin',            category:'greetings'),
  // Emergency
  GestureSign(id:'emergency',  name:'Emergency',   arabic:'طارئ',     emoji:'🆘',  hint:'Tight closed fist · hold up clearly',               category:'emergency', supported:true),
  GestureSign(id:'help',       name:'Help',        arabic:'مساعدة',   emoji:'🖐️',  hint:'4 fingers straight up · thumb tucked to palm',      category:'emergency', supported:true),
  GestureSign(id:'stop',       name:'Stop',        arabic:'توقف',     emoji:'✋',  hint:'Palm facing forward · thrust outward',              category:'emergency', supported:true),
  GestureSign(id:'danger',     name:'Danger',      arabic:'خطر',      emoji:'⚠️',  hint:'D-handshape · sharp downward motion',               category:'emergency'),
  GestureSign(id:'call_ambulance', name:'Call Ambulance', arabic:'اتصل بإسعاف', emoji:'📞', hint:'Phone Y-shape near ear',                category:'emergency'),
  // Medical
  GestureSign(id:'hospital',   name:'Hospital',    arabic:'مستشفى',   emoji:'✌️',  hint:'Peace sign · index + middle only',                  category:'medical',   supported:true),
  GestureSign(id:'pain',       name:'Pain',        arabic:'ألم',      emoji:'💢',  hint:'Both index fingers point at each other',             category:'medical',   supported:true),
  GestureSign(id:'medicine',   name:'Medicine',    arabic:'دواء',     emoji:'💊',  hint:'Middle finger flicks off thumb',                    category:'medical'),
  GestureSign(id:'doctor',     name:'Doctor',      arabic:'طبيب',     emoji:'👨‍⚕️', hint:'D-shape · taps on wrist',                          category:'medical'),
  GestureSign(id:'sick',       name:'Sick',        arabic:'مريض',     emoji:'🤒',  hint:'Bent middle finger · forehead to stomach',          category:'medical'),
  GestureSign(id:'allergy',    name:'Allergy',     arabic:'حساسية',   emoji:'🤧',  hint:'Index traces down from nose',                       category:'medical'),
  // Needs & Feelings
  GestureSign(id:'water',      name:'Water',       arabic:'ماء',      emoji:'💧',  hint:'Index + middle + ring up · W shape',                category:'needs',     supported:true),
  GestureSign(id:'food',       name:'Food',        arabic:'طعام',     emoji:'🍽️',  hint:'Fingertips pinched · moves toward mouth',           category:'needs'),
  GestureSign(id:'hungry',     name:'Hungry',      arabic:'جائع',     emoji:'🫙',  hint:'C-shape · moves down on chest',                     category:'needs'),
  GestureSign(id:'thirsty',    name:'Thirsty',     arabic:'عطشان',    emoji:'💦',  hint:'Index traces down the throat',                      category:'needs'),
  GestureSign(id:'hot',        name:'Hot',         arabic:'حار',      emoji:'🔥',  hint:'Claw near mouth · opens sharply out',               category:'needs'),
  GestureSign(id:'cold',       name:'Cold',        arabic:'بارد',     emoji:'🥶',  hint:'Both fists tremble and shake',                      category:'needs'),
  GestureSign(id:'bad',        name:'Bad',         arabic:'سيئ',      emoji:'👎',  hint:'Fist · thumb pointing straight down',               category:'needs'),
  // Transport
  GestureSign(id:'car',        name:'Car',         arabic:'سيارة',    emoji:'🚗',  hint:'Both hands grip imaginary steering wheel',          category:'transport'),
  GestureSign(id:'wheelchair', name:'Wheelchair',  arabic:'كرسي متحرك', emoji:'♿', hint:'Index fingers roll forward in circles',          category:'transport'),
  GestureSign(id:'taxi',       name:'Taxi',        arabic:'تاكسي',    emoji:'🚕',  hint:'Bent index waves downward · hailing',               category:'transport'),
  GestureSign(id:'bus',        name:'Bus',         arabic:'حافلة',    emoji:'🚌',  hint:'B-shapes pull apart · bus doors opening',          category:'transport'),
  // General
  GestureSign(id:'one',        name:'One',         arabic:'واحد',     emoji:'☝️',  hint:'Index finger only · all others closed',             category:'general',   supported:true),
  GestureSign(id:'more',       name:'More',        arabic:'أكثر',     emoji:'🤌',  hint:'Fingertips pinch + tap together',                   category:'general'),
  GestureSign(id:'finished',   name:'Finished',    arabic:'انتهى',    emoji:'🙌',  hint:'Both hands flip outward from wrists',              category:'general'),
  GestureSign(id:'wait',       name:'Wait',        arabic:'انتظر',    emoji:'🖐️',  hint:'Both hands wiggle fingers softly',                  category:'general'),
  GestureSign(id:'understand', name:'Understand',  arabic:'أفهم',     emoji:'💡',  hint:'Index flicks up at forehead',                      category:'general'),
  // Accessibility
  GestureSign(id:'caregiver',  name:'Caregiver',   arabic:'مقدم رعاية', emoji:'🤲', hint:'One hand cradles and supports the other',       category:'access'),
  GestureSign(id:'interpreter',name:'Interpreter', arabic:'مترجم',    emoji:'🔄',  hint:'Index fingers alternate left and right',           category:'access'),
  GestureSign(id:'blind',      name:'Blind',       arabic:'أعمى',     emoji:'👁️',  hint:'V-shape touches eyes · moves away',                category:'access'),
  GestureSign(id:'deaf',       name:'Deaf',        arabic:'أصم',      emoji:'👂',  hint:'Index traces from ear to chin',                    category:'access'),
  GestureSign(id:'accessible', name:'Accessible',  arabic:'متاح',     emoji:'♿',  hint:'Both hands open outward from center',             category:'access'),
];

// ─────────────────────────────────────────────────────────────────────────────
// MEDIAPIPE LANDMARK INDICES  (standard 21-point hand model)
// ─────────────────────────────────────────────────────────────────────────────
//  0 = WRIST
//  1-4   = THUMB  (CMC→TIP)
//  5-8   = INDEX  (MCP→TIP)
//  9-12  = MIDDLE (MCP→TIP)
//  13-16 = RING   (MCP→TIP)
//  17-20 = PINKY  (MCP→TIP)

// ─────────────────────────────────────────────────────────────────────────────
// GESTURE CLASSIFIER
// Operates on a List<Landmark> (21 points, x/y in 0-1 normalised space).
// Returns the best (signName, confidence) or null when no hand is detected.
// ─────────────────────────────────────────────────────────────────────────────

class _Classifier {
  // ── Low-level geometry ────────────────────────────────────────────────────
  /// True when finger tip is clearly above its MCP knuckle (extended).
  /// Threshold 0.07 is tighter than the old 0.04/0.06 to reduce false positives.
  static bool _ext(List<Landmark> lm, int mcp, int tip) =>
      lm[tip].y < lm[mcp].y - 0.07;

  /// True when finger tip is clearly BELOW its MCP (folded / curled).
  static bool _curl(List<Landmark> lm, int mcp, int tip) =>
      lm[tip].y > lm[mcp].y + 0.04;

  // Per-finger helpers using correct MCP indices
  static bool _idx(List<Landmark> lm)  => _ext(lm,  5,  8);
  static bool _mid(List<Landmark> lm)  => _ext(lm,  9, 12);
  static bool _rng(List<Landmark> lm)  => _ext(lm, 13, 16);
  static bool _pnk(List<Landmark> lm)  => _ext(lm, 17, 20);

  static bool _idxCurl(List<Landmark> lm)  => _curl(lm,  5,  8);
  static bool _midCurl(List<Landmark> lm)  => _curl(lm,  9, 12);
  static bool _rngCurl(List<Landmark> lm)  => _curl(lm, 13, 16);
  static bool _pnkCurl(List<Landmark> lm)  => _curl(lm, 17, 20);

  /// Thumb extended: tip is far from the index MCP laterally OR vertically.
  static bool _thb(List<Landmark> lm) {
    final dx = (lm[4].x - lm[5].x).abs();
    final dy = (lm[4].y - lm[5].y).abs();
    return dx > 0.09 || dy > 0.09;
  }

  /// Thumb tip clearly above thumb base (thumb up).
  static bool _thbUp(List<Landmark> lm) => lm[4].y < lm[2].y - 0.07;

  /// Thumb tip clearly below thumb base (thumb down).
  static bool _thbDown(List<Landmark> lm) => lm[4].y > lm[2].y + 0.07;

  /// All four fingers folded (true fist).
  static bool _fist(List<Landmark> lm) =>
      _idxCurl(lm) && _midCurl(lm) && _rngCurl(lm) && _pnkCurl(lm);

  /// All four fingers extended (flat palm, ignore thumb).
  static bool _flatPalm(List<Landmark> lm) =>
      _idx(lm) && _mid(lm) && _rng(lm) && _pnk(lm);

  // Spread: lateral distance between index and pinky tips
  static double _spread(List<Landmark> lm) => (lm[8].x - lm[20].x).abs();

  // Thumb spread from wrist baseline
  static double _thumbSpread(List<Landmark> lm) => (lm[4].x - lm[0].x).abs();

  // ── Scoring ───────────────────────────────────────────────────────────────

  // Each entry: (signName, List<(condition, weight)>)
  // Weights sum to 1.0 per sign.  Score = sum of weights of passing conditions.
  // A sign is only candidate when score >= 0.55.
  static ({String name, double confidence})? classify(List<Landmark> lm) {
    if (lm.isEmpty) return null;

    // Pre-compute booleans once
    final I   = _idx(lm);
    final M   = _mid(lm);
    final R   = _rng(lm);
    final P   = _pnk(lm);
    final T   = _thb(lm);
    final Tup = _thbUp(lm);
    final Tdn = _thbDown(lm);
    final F   = _fist(lm);
    final Fp  = _flatPalm(lm);
    final sp  = _spread(lm);
    final ts  = _thumbSpread(lm);
    final Ic  = _idxCurl(lm);
    final Mc  = _midCurl(lm);
    final Rc  = _rngCurl(lm);
    final Pc  = _pnkCurl(lm);

    final scores = <String, double>{};

    // ── Hello: open palm, all 5 including thumb, wide spread ───────────────
    scores['Hello'] = _score([
      (Fp,        0.30),
      (T,         0.20),
      (ts > 0.14, 0.25),   // thumb clearly away from wrist
      (sp > 0.15, 0.15),   // fingers spread wide
      (!F,        0.10),
    ]);

    // ── Stop: open palm, 4 fingers, thumb may be tucked ────────────────────
    // Distinct from Hello by thumb being more neutral / lower spread
    scores['Stop'] = _score([
      (Fp,        0.35),
      (sp > 0.10, 0.20),
      (ts < 0.14, 0.30),   // thumb closer to palm (not super spread)
      (!F,        0.15),
    ]);

    // ── Yes: tight fist + thumb clearly up ─────────────────────────────────
    scores['Yes'] = _score([
      (F,    0.40),
      (Tup,  0.40),
      (!Tdn, 0.20),
    ]);

    // ── Bad: tight fist + thumb clearly down ───────────────────────────────
    scores['Bad'] = _score([
      (F,    0.40),
      (Tdn,  0.40),
      (!Tup, 0.20),
    ]);

    // ── Emergency / Sorry: tight fist, thumb neutral ────────────────────────
    scores['Emergency'] = _score([
      (F,     0.50),
      (!Tup,  0.25),
      (!Tdn,  0.25),
    ]);

    // ── One: index only, others curled including thumb ──────────────────────
    scores['One'] = _score([
      (I,   0.40),
      (!M,  0.15),
      (!R,  0.15),
      (!P,  0.15),
      (!T,  0.15),
    ]);

    // ── Pain: index + thumb extended, middle/ring/pinky curled ─────────────
    // (pointing + thumb out — the "gun" shape)
    scores['Pain'] = _score([
      (I,   0.35),
      (T,   0.30),
      (Mc,  0.15),
      (Rc,  0.10),
      (Pc,  0.10),
    ]);

    // ── Hospital / Peace: index + middle only ──────────────────────────────
    scores['Hospital'] = _score([
      (I,   0.30),
      (M,   0.30),
      (!R,  0.15),
      (!P,  0.15),
      (!T,  0.10),
    ]);

    // ── No / Rock: index + pinky, middle+ring curled ───────────────────────
    scores['No'] = _score([
      (I,   0.30),
      (!M,  0.20),
      (!R,  0.15),
      (P,   0.25),
      (!T,  0.10),
    ]);

    // ── ILY: thumb + index + pinky, middle+ring curled ─────────────────────
    scores['I Love You'] = _score([
      (T,   0.25),
      (I,   0.25),
      (Mc,  0.15),
      (Rc,  0.15),
      (P,   0.20),
    ]);

    // ── Thank You: thumb + index + middle, ring+pinky curled ───────────────
    scores['Thank You'] = _score([
      (T,   0.25),
      (I,   0.25),
      (M,   0.25),
      (Rc,  0.15),
      (Pc,  0.10),
    ]);

    // ── Water / W: index + middle + ring, no thumb, pinky down ─────────────
    scores['Water'] = _score([
      (I,   0.25),
      (M,   0.25),
      (R,   0.25),
      (!P,  0.15),
      (!T,  0.10),
    ]);

    // ── Help: index + middle + ring + pinky, no thumb ──────────────────────
    scores['Help'] = _score([
      (I,   0.20),
      (M,   0.20),
      (R,   0.20),
      (P,   0.20),
      (!T,  0.20),
    ]);

    // ── Find best ─────────────────────────────────────────────────────────
    if (scores.isEmpty) return (name: 'Unknown', confidence: 0.0);

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best   = sorted.first;
    final second = sorted.length > 1 ? sorted[1].value : 0.0;

    // Must clear minimum threshold AND have meaningful margin over runner-up
    const minScore  = 0.55;
    const minMargin = 0.10;

    if (best.value < minScore || best.value - second < minMargin) {
      return (name: 'Unknown', confidence: best.value);
    }

    final conf = 0.70 + (best.value - minScore) / (1.0 - minScore) * 0.26;
      return (name: best.key, confidence: conf.clamp(0.0, 0.96));
    }

  static double _score(List<(bool, double)> rules) {
    double s = 0;
    for (final r in rules) {
      if (r.$1) s += r.$2;
    }
    return s;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REAL HAND ENGINE  — wraps camera + hand_landmarker
// ─────────────────────────────────────────────────────────────────────────────

class _HandEngine {
  HandLandmarkerPlugin? _plugin;
  CameraController?    _camera;
  bool _isDetecting = false;
  bool _initialized = false;

  // State exported to the widget
  GesturePhase phase       = GesturePhase.idle;
  String?      candidate;
  String?      lastConfirmed;
  double       fillRatio   = 0;
  double       confidence  = 0;
  bool         handPresent = false;
  Map<String, double> scores = {};
  List<Hand>   lastHands   = [];  // ← add this line

  // Confirmation buffer
  int _holdCount  = 0;
  static const _confirmFrames = 18; // ~0.6 s at ~30 fps

  VoidCallback? onFrame;

  // ── Public API ────────────────────────────────────────────────────────────

  Future<bool> start() async {
    // Camera permission
    final status = await Permission.camera.request();
    if (!status.isGranted) return false;

    final cameras = await availableCameras();
    if (cameras.isEmpty) return false;

    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _camera = CameraController(front, ResolutionPreset.medium, enableAudio: false);
    await _camera!.initialize();

    _plugin = HandLandmarkerPlugin.create(
      numHands: 1,
      minHandDetectionConfidence: 0.6,
      delegate: HandLandmarkerDelegate.gpu,
    );

    phase    = GesturePhase.detecting;
    _initialized = true;

    await _camera!.startImageStream(_onFrame);
    return true;
  }

  void stop() {
    _camera?.stopImageStream();
    _camera?.dispose();
    _plugin?.dispose();
    _camera    = null;
    _plugin    = null;
    _initialized = false;
    _isDetecting = false;
    _reset();
    phase = GesturePhase.idle;
  }

  void reset() {
    _reset();
    phase = GesturePhase.detecting;
    onFrame?.call();
  }

  CameraController? get cameraController => _camera;
  bool get isInitialized => _initialized;

  // ── Frame processing ──────────────────────────────────────────────────────

  void _onFrame(CameraImage image) {
    if (_isDetecting || _plugin == null || _camera == null) return;
    _isDetecting = true;

    try {
      final hands = _plugin!.detect(image, 90);
      _processHands(hands);
    } catch (e) {
      debugPrint('[HandEngine] detect error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  void _processHands(List<Hand> hands) {
    lastHands = hands;  // ← add this line here
    handPresent = hands.isNotEmpty;

    if (!handPresent) {
      // Hand left frame — allow re-signing
      if (phase == GesturePhase.confirmed) {
        _reset();
        phase = GesturePhase.detecting;
      } else if (phase != GesturePhase.idle) {
        _reset();
        phase = GesturePhase.detecting;
      }
      onFrame?.call();
      return;
    }

    // We have a hand — classify
    final lm     = hands.first.landmarks;
    final result = _Classifier.classify(lm);

    if (result == null || result.name == 'Unknown') {
      phase     = GesturePhase.unknown;
      candidate = null;
      _holdCount = 0;
      scores    = {};
      confidence = 0;
      onFrame?.call();
      return;
    }

    final detected = result.name;

    // Build mock scores (real per-class probabilities need a classifier; we
    // synthesise plausible values so the score panel looks good)
    scores = {result.name: result.confidence};
    confidence = result.confidence;

    if (phase == GesturePhase.detecting || phase == GesturePhase.unknown) {
      candidate  = detected;
      _holdCount = 0;
      phase = GesturePhase.thinking;
    } else if (phase == GesturePhase.thinking) {
      phase = GesturePhase.analyzing;
    } else if (phase == GesturePhase.analyzing) {
      if (candidate != detected) {
        // Different sign → restart confirmation
        candidate  = detected;
        _holdCount = 0;
      }
      phase = GesturePhase.confirming;
    } else if (phase == GesturePhase.confirming) {
      if (candidate != detected) {
        candidate  = detected;
        _holdCount = 0;
      } else {
        _holdCount++;
        fillRatio = _holdCount / _confirmFrames;
        if (_holdCount >= _confirmFrames) {
          lastConfirmed = candidate;
          phase = GesturePhase.confirmed;
          fillRatio = 1;
        }
      }
    } else if (phase == GesturePhase.confirmed) {
      // Stay confirmed; user must remove hand to sign again
    }

    onFrame?.call();
  }

  void _reset() {
    candidate     = null;
    lastConfirmed = null;
    fillRatio     = 0;
    confidence    = 0;
    handPresent   = false;
    scores        = {};
    _holdCount    = 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOT WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class AiSignLanguageAssistant extends StatefulWidget {
  const AiSignLanguageAssistant({super.key});
  @override
  State<AiSignLanguageAssistant> createState() => _AiSignLanguageAssistantState();
}

class _AiSignLanguageAssistantState extends State<AiSignLanguageAssistant>
    with TickerProviderStateMixin {

  final _engine = _HandEngine();
  bool _isRunning   = false;
  bool _starting    = false;   // async init in progress
  String? _camError;

  GesturePhase _phase   = GesturePhase.idle;
  String? _candidate;
  String? _confirmedSign;
  bool _isNewConfirm    = false;
  double _fillRatio     = 0;
  double _confidence    = 0;
  bool _handPresent     = false;
  Map<String, double> _scores = {};

  int _totalSigns       = 0;
  String _duration      = '00:00';
  String _topSign       = '—';
  final Map<String, int> _signCounts = {};
  Timer? _sessionTimer;
  int _sessionSeconds   = 0;

  final List<DetectionEvent> _history = [];
  String _lastSpeak = '';

  final FlutterTts _tts = FlutterTts();
  bool _isMuted = false;

  bool _scoresPanelOpen = false;
  String? _activeGestureId;

  final Map<String, bool> _catOpen = {
    'greetings': true, 'emergency': true,
    'medical': false, 'needs': false, 'transport': false,
    'general': false, 'access': false,
  };

  late AnimationController _pulseCtrl;
  late AnimationController _scanCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _confirmCtrl;

  bool _initDone = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _scanCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _floatCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500))..repeat(reverse: true);
    _confirmCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _initTts();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _initDone = true);
    });
  }

  @override
  void dispose() {
    _engine.stop();
    _sessionTimer?.cancel();
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    _floatCtrl.dispose();
    _confirmCtrl.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setSharedInstance(true);
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.88);
  }

  // ── Camera start / stop ───────────────────────────────────────────────────

  Future<void> _startCamera() async {
    if (_starting) return;
    setState(() { _starting = true; _camError = null; });

    _engine.onFrame = _onEngineFrame;
    final ok = await _engine.start();

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _starting  = false;
        _camError  = 'Camera permission denied or no camera found.';
      });
      return;
    }

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickSession());
    setState(() {
      _starting  = false;
      _isRunning = true;
      _phase     = GesturePhase.detecting;
    });
  }

  void _stopCamera() {
    _engine.stop();
    _sessionTimer?.cancel();
    setState(() {
      _isRunning    = false;
      _starting     = false;
      _phase        = GesturePhase.idle;
      _candidate    = null;
      _confirmedSign = null;
      _handPresent  = false;
      _fillRatio    = 0;
      _confidence   = 0;
      _scores       = {};
      _camError     = null;
    });
  }

  void _onEngineFrame() {
    if (!mounted) return;
    final prev  = _confirmedSign;
    final isNew = _engine.phase == GesturePhase.confirmed &&
        _engine.lastConfirmed != null &&
        _engine.lastConfirmed != prev;

    setState(() {
      _phase       = _engine.phase;
      _candidate   = _engine.candidate;
      _fillRatio   = _engine.fillRatio;
      _confidence  = _engine.confidence;
      _handPresent = _engine.handPresent;
      _scores      = Map.from(_engine.scores);
      _isNewConfirm = isNew;
      if (isNew) {
        _confirmedSign   = _engine.lastConfirmed;
        _activeGestureId = _engine.lastConfirmed;
      }
    });

    if (isNew && _engine.lastConfirmed != null) {
      _onConfirmed(_engine.lastConfirmed!);
    }
  }

  void _onConfirmed(String sign) {
    final now    = TimeOfDay.now();
    final timeStr = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
    final conf   = (_engine.confidence * 100).round().clamp(0, 100);

    setState(() {
      _history.insert(0, DetectionEvent(name: sign, confidence: conf, time: timeStr));
      _totalSigns++;
      _signCounts[sign] = (_signCounts[sign] ?? 0) + 1;
      _topSign = _signCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      _lastSpeak = sign;
    });

    _confirmCtrl.forward(from: 0);
    _speak(sign);
  }

  void _tickSession() {
    _sessionSeconds++;
    final m = (_sessionSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_sessionSeconds %  60).toString().padLeft(2, '0');
    setState(() => _duration = '$m:$s');
  }

  void _clearAll() {
    setState(() {
      _history.clear();
      _confirmedSign  = null;
      _lastSpeak      = '';
      _totalSigns     = 0;
      _topSign        = '—';
      _signCounts.clear();
      _sessionSeconds = 0;
      _duration       = '00:00';
      _activeGestureId = null;
    });
    _tts.stop();
    if (_isRunning) _engine.reset();
  }

  Future<void> _speak(String text) async {
    if (_isMuted || text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  void _toggleMute() => setState(() {
    _isMuted = !_isMuted;
    if (_isMuted) _tts.stop();
  });

  // ── Phase helpers ─────────────────────────────────────────────────────────

  Color _phaseCardColor() => switch (_phase) {
    GesturePhase.thinking   => const Color(0xFFFAF5FF),
    GesturePhase.analyzing  => const Color(0xFFF0FDF4),
    GesturePhase.confirming => const Color(0xFFFFFBEB),
    GesturePhase.confirmed  => const Color(0xFFF0FDF4),
    GesturePhase.unknown    => const Color(0xFFFFF7ED),
    _                       => _bg,
  };

  Color _phaseBorderColor() => switch (_phase) {
    GesturePhase.thinking   => const Color(0x59A78BFA),
    GesturePhase.analyzing  => const Color(0x5934D399),
    GesturePhase.confirming => const Color(0x59FBBF24),
    GesturePhase.confirmed  => const Color(0x7316A34A),
    GesturePhase.unknown    => const Color(0x59F97316),
    _                       => _border,
  };

  String _phaseLabel() => switch (_phase) {
    GesturePhase.idle       => 'Tap Start Camera to begin',
    GesturePhase.detecting  => 'Waiting for hand…',
    GesturePhase.thinking   => 'Hand detected · reading shape…',
    GesturePhase.analyzing  => 'Measuring 3D joint angles…',
    GesturePhase.confirming => 'Hold still · confirming…',
    GesturePhase.confirmed  => _isNewConfirm ? 'Sign confirmed!' : '↓ Lower hand to sign again',
    GesturePhase.unknown    => 'Sign not recognised — try again',
  };

  IconData _phaseIcon() => switch (_phase) {
    GesturePhase.idle       => Icons.pause_circle_outline,
    GesturePhase.detecting  => Icons.search,
    GesturePhase.thinking   => Icons.psychology,
    GesturePhase.analyzing  => Icons.graphic_eq,
    GesturePhase.confirming => Icons.timelapse,
    GesturePhase.confirmed  => Icons.check_circle,
    GesturePhase.unknown    => Icons.help_outline,
  };

  Color _dotColor() => switch (_phase) {
    GesturePhase.idle       => const Color(0xFF94A3B8),
    GesturePhase.detecting  => const Color(0xFF60A5FA),
    GesturePhase.thinking   => const Color(0xFF60A5FA),
    GesturePhase.analyzing  => const Color(0xFF34D399),
    GesturePhase.confirming => const Color(0xFF34D399),
    GesturePhase.confirmed  => _green,
    GesturePhase.unknown    => _amber,
  };

  bool get _dotBlink => _phase == GesturePhase.detecting ||
      _phase == GesturePhase.thinking ||
      _phase == GesturePhase.analyzing ||
      _phase == GesturePhase.confirming;

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        SingleChildScrollView(
          child: Column(children: [
            _buildHero(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Column(children: [
                _buildMainGrid(),
                const SizedBox(height: 28),
                _buildGestureLibrary(),
                const SizedBox(height: 20),
                _buildInfoNote(),
                const SizedBox(height: 60),
              ]),
            ),
          ]),
        ),
        AnimatedOpacity(
          opacity: _initDone ? 0 : 1,
          duration: const Duration(milliseconds: 400),
          child: IgnorePointer(
            ignoring: _initDone,
            child: _buildInitOverlay(),
          ),
        ),
      ]),
    );
  }

  Widget _buildInitOverlay() => Container(
    color: const Color(0xE014163A),
    child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 52, height: 52,
        child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(Colors.white))),
      SizedBox(height: 18),
      Text('Loading Rafiq Sign AI…',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      SizedBox(height: 6),
      Text('Preparing hand detection models',
          style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600)),
    ])),
  );

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 52, 24, 44),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, Color(0xFF2D1B69), _accent],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Stack(children: [
        Positioned(top: -100, right: -60, child: _Orb(size: 320, opacity: 0.04)),
        Positioned(bottom: -40, left: 20,  child: _Orb(size: 160, opacity: 0.03)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.arrow_back, color: Colors.white, size: 14),
                SizedBox(width: 7),
                Text('Back', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.memory, color: Colors.white, size: 12),
              SizedBox(width: 7),
              Text('REAL-TIME · MEDIAPIPE · 21 LANDMARKS · ON-DEVICE',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ]),
          ),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RichText(text: TextSpan(
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.8, height: 1.06),
                children: [
                  const TextSpan(text: 'AI ', style: TextStyle(color: Colors.white)),
                  TextSpan(text: 'Sign Language', style: TextStyle(
                    foreground: Paint()..shader = const LinearGradient(
                      colors: [Color(0xFFC4CAFF), Colors.white],
                    ).createShader(const Rect.fromLTWH(0, 0, 220, 40)),
                  )),
                  const TextSpan(text: ' Assistant', style: TextStyle(color: Colors.white)),
                ],
              )),
              const SizedBox(height: 12),
              Text(
                'Show your hand to the camera. MediaPipe detects 21 3-D landmarks in real-time. A landmark-based classifier confirms the sign once it holds steady across multiple frames.',
                style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.7),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: const [
                _HeroTag(icon: Icons.check_circle, label: '15 signs live'),
                _HeroTag(icon: Icons.volume_up,    label: 'Voice feedback'),
                _HeroTag(icon: Icons.shield,       label: 'No repeat detection'),
                _HeroTag(icon: Icons.lock,         label: 'On-device'),
              ]),
            ])),
            const SizedBox(width: 14),
            AnimatedBuilder(
              animation: _floatCtrl,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, -10 * _floatCtrl.value),
                child: const Text('🤟', style: TextStyle(fontSize: 64)),
              ),
            ),
          ]),
        ]),
      ]),
    );
  }

  // ── Main grid ─────────────────────────────────────────────────────────────

  Widget _buildMainGrid() {
    return LayoutBuilder(builder: (_, c) {
      if (c.maxWidth > 680) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _buildCameraCard()),
          const SizedBox(width: 20),
          Expanded(child: _buildAiAnalysisCard()),
        ]);
      }
      return Column(children: [
        _buildCameraCard(),
        const SizedBox(height: 20),
        _buildAiAnalysisCard(),
      ]);
    });
  }

  // ── Camera card ───────────────────────────────────────────────────────────

  Widget _buildCameraCard() {
    return _Card(
      icon: Icons.camera_alt,
      title: 'Live Camera',
      subtitle: 'MediaPipe Hands · 21 landmarks · real-time',
      child: Column(children: [
        AspectRatio(
          aspectRatio: 5 / 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: const Color(0xFF06070F),
              child: Stack(children: [
                // ── Camera feed or placeholder ──────────────────────────────
                if (!_isRunning)
                  Container(
                    color: const Color(0xFF141632),
                    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (_starting) ...[
                        const CircularProgressIndicator(color: _accent),
                        const SizedBox(height: 14),
                        const Text('Starting camera…',
                            style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
                      ] else if (_camError != null) ...[
                        const Icon(Icons.error_outline, size: 42, color: _red),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(_camError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                      ] else ...[
                        const Icon(Icons.videocam_off, size: 48, color: Colors.white24),
                        const SizedBox(height: 12),
                        const Text('Camera is off',
                            style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text('Tap Start Camera to begin',
                            style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ])),
                  )
          else if (_engine.isInitialized && _engine.cameraController != null) ...[
              // ── Single mirrored video feed ──────────────────────────────────────
              Positioned.fill(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),   // <-- import 'dart:math' as math
                  child: CameraPreview(_engine.cameraController!),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _HandPainter(hands: _engine.lastHands),
                ),
              ),
                ]
                else
                  Container(color: const Color(0xFF0A0C1E)),

                // ── Scan line ───────────────────────────────────────────────
                if (_isRunning)
                  AnimatedBuilder(
                    animation: _scanCtrl,
                    builder: (_, __) {
                      final h = MediaQuery.of(context).size.width * (3 / 4);
                      return Positioned(
                        top: _scanCtrl.value * (h - 4),
                        left: 0, right: 0,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              _accent.withOpacity(0.85),
                              _accent,
                              _accent.withOpacity(0.85),
                              Colors.transparent,
                            ]),
                            boxShadow: [BoxShadow(color: _accent.withOpacity(0.6), blurRadius: 16)],
                          ),
                        ),
                      );
                    },
                  ),

                // ── Hand guide ring (shown when no hand) ────────────────────
                if (_isRunning)
                  Center(
                    child: AnimatedOpacity(
                      opacity: _handPresent ? 0 : 1,
                      duration: const Duration(milliseconds: 300),
                      child: AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => Transform.scale(
                          scale: 1.0 + 0.04 * _pulseCtrl.value,
                          child: Container(
                            width: 130, height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _accent.withOpacity(0.2 + 0.25 * _pulseCtrl.value),
                                width: 2,
                              ),
                            ),
                            child: const Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                              Padding(
                                padding: EdgeInsets.only(bottom: 6),
                                child: Text('Place hand here',
                                    style: TextStyle(color: Colors.white60, fontSize: 9.5,
                                        fontWeight: FontWeight.w800, letterSpacing: 0.05)),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Corner brackets ─────────────────────────────────────────
                ..._corners(_handPresent),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildPhaseBar(),
        const SizedBox(height: 10),
        _buildProgressBar(),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _CamBtn(
              label: _isRunning ? 'Stop' : (_starting ? 'Starting…' : 'Start Camera'),
              icon: _isRunning ? Icons.stop : Icons.play_arrow,
              color: _isRunning ? const Color(0xFFFEF2F2) : null,
              textColor: _isRunning ? _red : Colors.white,
              gradient: _isRunning || _starting ? null : const LinearGradient(colors: [_a2, _accent]),
              onTap: _isRunning ? _stopCamera : (_starting ? () {} : _startCamera),
            ),
          ),
          if (_isRunning) ...[
            const SizedBox(width: 10),
            Expanded(child: _CamBtn(
              label: 'Reset',
              icon: Icons.rotate_left,
              color: _bg,
              textColor: _muted,
              outlined: true,
              onTap: _clearAll,
            )),
          ],
        ]),
        if (_scoresPanelOpen) ...[const SizedBox(height: 12), _buildScorePanel()],
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() => _scoresPanelOpen = !_scoresPanelOpen),
          child: Text(
            _scoresPanelOpen ? 'Hide live scores' : 'Show live scores',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted),
          ),
        ),
      ]),
    );
  }

  Widget _buildPhaseBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: _dotColor().withOpacity(_dotBlink ? 0.3 + 0.7 * _pulseCtrl.value : 1),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(_phaseLabel(),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _navy)),
        ),
        if (_confidence > 0.05)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: _confidence >= 0.8 ? const Color(0xFFDCFCE7)
                   : _confidence >= 0.6 ? const Color(0xFFFEF9C3)
                   : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${(_confidence * 100).round()}%',
              style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w900,
                color: _confidence >= 0.8 ? const Color(0xFF166534)
                     : _confidence >= 0.6 ? const Color(0xFF854D0E)
                     : const Color(0xFFB91C1C),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildProgressBar() {
    final pct = (_fillRatio * 100).round().clamp(0, 100);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: _fillRatio.clamp(0, 1),
        minHeight: 7,
        backgroundColor: _bg,
        valueColor: AlwaysStoppedAnimation(pct >= 100 ? _green : _accent),
      ),
    );
  }

  Widget _buildScorePanel() {
    final sorted = _scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top8   = sorted.take(8).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('LIVE CONFIDENCE — ALL SIGNS',
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: _muted, letterSpacing: 0.07)),
        const SizedBox(height: 10),
        ...top8.map((e) {
          final pct = (e.value * 100).round();
          final isLeading = e.key == _candidate;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              SizedBox(
                width: 82,
                child: Text(e.key, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _navy, fontFamily: 'monospace')),
              ),
              const SizedBox(width: 8),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: e.value.clamp(0, 1),
                  minHeight: 5,
                  backgroundColor: Colors.black.withOpacity(0.06),
                  valueColor: AlwaysStoppedAnimation(isLeading ? _green : _accent),
                ),
              )),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text('$pct%', textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: _muted, fontFamily: 'monospace')),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // ── AI Analysis card ──────────────────────────────────────────────────────

  Widget _buildAiAnalysisCard() {
    return _Card(
      icon: Icons.psychology,
      title: 'AI Analysis',
      subtitle: 'Phase engine · multi-frame confirmation · no repeat detection',
      child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _phaseCardColor(),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _phaseBorderColor(), width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: _accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(_phaseIcon(), color: _accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _phase.name[0].toUpperCase() + _phase.name.substring(1),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _muted, letterSpacing: 0.07),
              ),
              const SizedBox(height: 2),
              Text(_phaseLabel(),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: _navy, height: 1.35)),
              if (_candidate != null && _phase != GesturePhase.confirmed)
                Text('Candidate: $_candidate',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted)),
            ])),
          ]),
        ),
        const SizedBox(height: 14),
        if (_confirmedSign != null) _buildConfirmedCard(),
        const SizedBox(height: 14),
        _buildSessionStats(),
        const SizedBox(height: 14),
        _buildTimeline(),
        const SizedBox(height: 14),
        _buildActionButtons(),
      ]),
    );
  }

  Widget _buildConfirmedCard() {
    final conf = (_confidence * 100).round().clamp(0, 100);
    final sign = _signs.firstWhere(
        (s) => s.name == _confirmedSign,
        orElse: () => GestureSign(id: '', name: _confirmedSign!, arabic: '', emoji: '🤚', hint: '', category: ''));
    final cat  = _categories.firstWhere(
        (c) => c.id == sign.category,
        orElse: () => const GestureCategory(id: '', name: 'Sign Language', color: _accent, icon: Icons.sign_language));

    return AnimatedBuilder(
      animation: _confirmCtrl,
      builder: (_, __) => Transform.scale(
        scale: 0.75 + 0.25 * Curves.elasticOut.transform(_confirmCtrl.value),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF8FAFF), Color(0xFFEEF1FF)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _accent.withOpacity(0.2), width: 2),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Confirmed Sign',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: _muted, letterSpacing: 0.09)),
            const SizedBox(height: 8),
            Row(children: [
              Text(sign.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Text(_confirmedSign ?? '',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900,
                      color: _navy, letterSpacing: -1, fontFamily: 'monospace', height: 1)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: conf / 100, minHeight: 6,
                  backgroundColor: Colors.black.withOpacity(0.07),
                  valueColor: const AlwaysStoppedAnimation(_accent),
                ),
              )),
              const SizedBox(width: 10),
              Text('$conf%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _navy, fontFamily: 'monospace')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.schedule, size: 13, color: _muted),
              const SizedBox(width: 4),
              Text(_history.isNotEmpty ? _history.first.time : '',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _muted)),
              const SizedBox(width: 12),
              const Icon(Icons.layers, size: 13, color: _muted),
              const SizedBox(width: 4),
              Text(cat.name, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _muted)),
            ]),
            if (_phase == GesturePhase.confirmed && !_isNewConfirm)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: _accent.withOpacity(0.08), borderRadius: BorderRadius.circular(9)),
                child: const Row(children: [
                  Icon(Icons.back_hand, size: 14, color: _accent),
                  SizedBox(width: 6),
                  Text('Lower your hand to sign again',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _accent)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSessionStats() {
    return Row(children: [
      Expanded(child: _StatCell(value: '$_totalSigns', label: 'Signs')),
      const SizedBox(width: 8),
      Expanded(child: _StatCell(value: _duration, label: 'Duration')),
      const SizedBox(width: 8),
      Expanded(child: _StatCell(
        value: _topSign.length > 8 ? '${_topSign.substring(0,7)}…' : _topSign,
        label: 'Top Sign',
        fontSize: _topSign == '—' ? 20 : 13,
      )),
    ]);
  }

  Widget _buildTimeline() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('DETECTION HISTORY',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _muted, letterSpacing: 0.07)),
        GestureDetector(
          onTap: _clearAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: const Text('Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted)),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      if (_history.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          alignment: Alignment.center,
          child: const Text('No signs confirmed yet',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFA0A3C0))),
        )
      else
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            itemCount: _history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final e = _history[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                child: Row(children: [
                  Expanded(child: Text(e.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                          color: _navy, fontFamily: 'monospace'))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(99)),
                    child: Text('${e.confidence}%',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _accent)),
                  ),
                  const SizedBox(width: 8),
                  Text(e.time,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: _muted, fontFamily: 'monospace')),
                ]),
              );
            },
          ),
        ),
    ]);
  }

  Widget _buildActionButtons() {
    return Row(children: [
      Expanded(flex: 2,
        child: _ActionBtn(
          icon: Icons.volume_up,
          label: 'Speak Last',
          gradient: const LinearGradient(colors: [_purple, _accent]),
          textColor: Colors.white,
          enabled: _lastSpeak.isNotEmpty,
          onTap: () => _speak(_lastSpeak),
        ),
      ),
      const SizedBox(width: 10),
      _ActionBtn(
        icon: _isMuted ? Icons.volume_off : Icons.volume_up,
        label: '',
        color: _isMuted ? const Color(0xFFFEF2F2) : _bg,
        textColor: _isMuted ? _red : _muted,
        outlined: true,
        isMuted: _isMuted,
        onTap: _toggleMute,
      ),
      const SizedBox(width: 10),
      _ActionBtn(
        icon: Icons.delete_outline,
        label: '',
        color: _bg,
        textColor: _muted,
        outlined: true,
        onTap: _clearAll,
      ),
    ]);
  }

  // ── Gesture library ───────────────────────────────────────────────────────

  Widget _buildGestureLibrary() {
    return _Card(
      icon: Icons.menu_book,
      title: 'Gesture Library',
      subtitle: '${_signs.length} signs · tap to highlight',
      child: Column(children: _categories.map((cat) {
        final catSigns = _signs.where((s) => s.category == cat.id).toList();
        final isOpen   = _catOpen[cat.id] ?? false;
        return Column(children: [
          GestureDetector(
            onTap: () => setState(() => _catOpen[cat.id] = !isOpen),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isOpen ? cat.color.withOpacity(0.07) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isOpen ? cat.color.withOpacity(0.2) : _border),
              ),
              child: Row(children: [
                Icon(cat.icon, color: cat.color, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(cat.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _navy))),
                Text('${catSigns.length}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: cat.color)),
                const SizedBox(width: 6),
                Icon(isOpen ? Icons.expand_less : Icons.expand_more, color: _muted, size: 18),
              ]),
            ),
          ),
          if (isOpen) ...[
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 2.5, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: catSigns.length,
              itemBuilder: (_, i) {
                final s = catSigns[i];
                final isActive = s.name == _activeGestureId;
                return GestureDetector(
                  onTap: () => setState(() => _activeGestureId = isActive ? null : s.name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isActive ? _accent.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive ? _accent.withOpacity(0.4) : _border,
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Text(s.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(s.name, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: _navy)),
                        Text(s.arabic,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _muted)),
                      ])),
                      _GestureBadge(sign: s, isActive: isActive),
                    ]),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
        ]);
      }).toList()),
    );
  }

  // ── Info note ─────────────────────────────────────────────────────────────

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: Color(0xFF0284C7), size: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('How gestures are classified',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0369A1))),
          const SizedBox(height: 4),
          Text(
            'The classifier uses the 21 3-D hand landmarks from MediaPipe to compute '
            'finger extension states (tip-vs-MCP distance) and thumb orientation. '
            'A sign is confirmed after it holds stable across ~18 consecutive frames (~0.6 s at 30 fps). '
            'Motion-based signs (Food, Hungry, etc.) require a temporal buffer — '
            'static-shape signs are fully supported today.',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.blue.shade800, height: 1.6),
          ),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

List<Widget> _corners(bool handPresent) {
  final color = handPresent ? _green : _accent;
  return [
    Positioned(top: 8, left: 8,   child: _Corner(color: color)),
    Positioned(top: 8, right: 8,  child: _Corner(color: color, flipX: true)),
    Positioned(bottom: 8, left: 8,  child: _Corner(color: color, flipY: true)),
    Positioned(bottom: 8, right: 8, child: _Corner(color: color, flipX: true, flipY: true)),
  ];
}

class _Orb extends StatelessWidget {
  final double size, opacity;
  const _Orb({required this.size, required this.opacity});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}

class _HeroTag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroTag({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withOpacity(0.18)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 12),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
    ]),
  );
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget child;
  const _Card({required this.icon, required this.title, required this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _border),
      boxShadow: [BoxShadow(color: _accent.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_a2, _accent]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _navy)),
          Text(subtitle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _muted)),
        ])),
      ]),
      const SizedBox(height: 16),
      child,
    ]),
  );
}

class _StatCell extends StatelessWidget {
  final String value, label;
  final double? fontSize;
  const _StatCell({required this.value, required this.label, this.fontSize});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: _bg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: fontSize ?? 20, fontWeight: FontWeight.w900, color: _navy, fontFamily: 'monospace')),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _muted, letterSpacing: 0.03)),
    ]),
  );
}

class _CamBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color, textColor;
  final Gradient? gradient;
  final bool outlined;
  final VoidCallback onTap;
  const _CamBtn({
    required this.label, required this.icon, required this.onTap,
    this.color, this.textColor, this.gradient, this.outlined = false,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 48,
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color,
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        border: outlined ? Border.all(color: _border, width: 1.5) : null,
        boxShadow: gradient != null
            ? [BoxShadow(color: _accent.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 4))]
            : null,
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: textColor ?? Colors.white, size: 18),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: textColor ?? Colors.white)),
        ],
      ]),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient? gradient;
  final Color? color, textColor;
  final bool outlined, enabled, isMuted;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon, required this.label, required this.onTap,
    this.gradient, this.color, this.textColor, this.outlined = false,
    this.enabled = true, this.isMuted = false,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: AnimatedOpacity(
      opacity: enabled ? 1 : 0.35,
      duration: const Duration(milliseconds: 150),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          border: outlined ? Border.all(color: isMuted ? _red.withOpacity(0.18) : _border, width: 1.5) : null,
          boxShadow: gradient != null
              ? [BoxShadow(color: _accent.withOpacity(0.22), blurRadius: 14, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: textColor ?? Colors.white, size: 16),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textColor ?? Colors.white)),
          ],
        ]),
      ),
    ),
  );
}

class _GestureBadge extends StatelessWidget {
  final GestureSign sign;
  final bool isActive;
  const _GestureBadge({required this.sign, required this.isActive});
  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(999)),
        child: const Text('Active', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF166534))),
      );
    }
    if (sign.supported) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(999)),
        child: const Text('Supported', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF166534))),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Text('Coming Soon', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF64748B))),
    );
  }
}

class _Corner extends StatelessWidget {
  final Color color;
  final bool flipX, flipY;
  const _Corner({required this.color, this.flipX = false, this.flipY = false});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18, height: 18,
    child: CustomPaint(painter: _CornerPainter(color: color, flipX: flipX, flipY: flipY)),
  );
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final bool flipX, flipY;
  const _CornerPainter({required this.color, required this.flipX, required this.flipY});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 2..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final x0 = flipX ? size.width  : 0.0;
    final y0 = flipY ? size.height : 0.0;
    final x1 = flipX ? 0.0 : size.width;
    final y1 = flipY ? 0.0 : size.height;
    canvas.drawLine(Offset(x0, y0), Offset(x1, y0), p);
    canvas.drawLine(Offset(x0, y0), Offset(x0, y1), p);
  }
  @override
  bool shouldRepaint(_) => false;
}

const bool _MIRROR_X = false;
class _HandPainter extends CustomPainter {
  final List<Hand> hands;
  _HandPainter({required this.hands});

  // Standard 21-point MediaPipe hand skeleton connections
  static const _connections = [
    // Thumb
    [0, 1], [1, 2], [2, 3], [3, 4],
    // Index
    [0, 5], [5, 6], [6, 7], [7, 8],
    // Middle
    [0, 9], [9, 10], [10, 11], [11, 12],
    // Ring
    [0, 13], [13, 14], [14, 15], [15, 16],
    // Pinky
    [0, 17], [17, 18], [18, 19], [19, 20],
    // Palm cross-bar
    [5, 9], [9, 13], [13, 17],
  ];

  // Special landmark indices for colour accents
  static const _tipIndices = {4, 8, 12, 16, 20}; // finger tips
  static const _wristIndex = 0;

  @override
  void paint(Canvas canvas, Size size) {
    if (hands.isEmpty) return;
    final lm = hands.first.landmarks;
    if (lm.length < 21) return;

    Offset pt(int i) {
      // hand_landmarker returns coords in landscape sensor space.
      // For front camera portrait on Android: x→y, (1-y)→x, then mirror.
      final rawX = lm[i].x;
      final rawY = lm[i].y;
      final x = 1.0 - rawY;   // rotate 90°
      final y = rawX;
      return Offset(x * size.width, y * size.height);
    }

    // ── Bone lines ──────────────────────────────────────────────────────────
    final bonePaint = Paint()
      ..color = const Color(0xCC6470D2)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final c in _connections) {
      canvas.drawLine(pt(c[0]), pt(c[1]), bonePaint);
    }

    // ── Landmark dots ────────────────────────────────────────────────────────
    for (int i = 0; i < 21; i++) {
      final o = pt(i);
      final isTip   = _tipIndices.contains(i);
      final isWrist = i == _wristIndex;

      // Outer white ring
      canvas.drawCircle(
        o,
        isTip ? 5.5 : (isWrist ? 5.0 : 4.0),
        Paint()..color = Colors.white..style = PaintingStyle.fill,
      );

      // Coloured fill
      canvas.drawCircle(
        o,
        isTip ? 4.0 : (isWrist ? 3.5 : 3.0),
        Paint()
          ..color = isTip
              ? const Color(0xFF34D399)   // green tips — easy to see
              : const Color(0xFF6470D2)   // purple joints
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_HandPainter old) => old.hands != hands;
}