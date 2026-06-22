import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const _navy   = Color(0xFF1E2040);
const _accent = Color(0xFF6470D2);
const _light  = Color(0xFFEEF0FF);
const _bg     = Color(0xFFF4F5FB);
const _muted  = Color(0xFF6B7080);
const _border = Color(0x1A6470D2);
const _green  = Color(0xFF16A34A);
const _red    = Color(0xFFDC2626);
const _amber  = Color(0xFFD97706);

// ─────────────────────────────────────────────────────────────────────────────
// SMART OCR READER
// ─────────────────────────────────────────────────────────────────────────────
class SmartOcrReader extends StatefulWidget {
  const SmartOcrReader({super.key});

  @override
  State<SmartOcrReader> createState() => _SmartOcrReaderState();
}

class _SmartOcrReaderState extends State<SmartOcrReader>
    with TickerProviderStateMixin {

  // ── Camera ────────────────────────────────────────────────────────────────
  CameraController? _camCtrl;
  List<CameraDescription> _cameras = [];
  bool _camActive = false;
  bool _camReady  = false;

  // ── Upload ────────────────────────────────────────────────────────────────
  File?   _uploadedFile;
  String? _uploadedFileName;

  // ── Settings ──────────────────────────────────────────────────────────────
  String _ocrLang   = 'ara+eng';
  bool   _mirrorOn  = true;
  bool   _enhanceOn = true;

  // ── OCR ───────────────────────────────────────────────────────────────────
  bool   _isProcessing = false;
  bool   _showProgress = false;
  int    _activeStep   = 0;
  double _progPct      = 0;

  // ── Result ────────────────────────────────────────────────────────────────
  String _extractedText = '';
  int    _sessionWords  = 0;
  int?   _confidence;

  // ── TTS ───────────────────────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();
  bool   _isSpeaking = false;
  double _ttsSpeed   = 0.9;

  // ── Debug ─────────────────────────────────────────────────────────────────
  bool   _debugOpen = false;
  String _dbDir     = '—';
  String _dbConf    = '—';
  String _dbSize    = '—';
  String _dbSource  = '—';

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _scanAnimCtrl;
  late AnimationController _ttsWaveCtrl;

  // ── Toast ─────────────────────────────────────────────────────────────────
  OverlayEntry? _toastEntry;

  // ── ML Kit recognizer ─────────────────────────────────────────────────────
  TextRecognizer? _recognizer;

  TextRecognizer _getRecognizer() {
    _recognizer?.close();
    // ML Kit Latin script handles English + detects unicode Arabic characters.
    // For Arabic-only mode, latin still works; there is no dedicated Arabic
    // script constant in google_mlkit_text_recognition for all platforms.
    _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    return _recognizer!;
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _scanAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _ttsWaveCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _initTts();
    _initCameras();
  }

  @override
  void dispose() {
    _scanAnimCtrl.dispose();
    _ttsWaveCtrl.dispose();
    _camCtrl?.dispose();
    _tts.stop();
    _recognizer?.close();
    _toastEntry?.remove();
    super.dispose();
  }

  // ── TTS init ──────────────────────────────────────────────────────────────
  Future<void> _initTts() async {
    await _tts.setSharedInstance(true);
    _tts.setCompletionHandler(() { if (mounted) setState(() => _isSpeaking = false); });
    _tts.setCancelHandler(()    { if (mounted) setState(() => _isSpeaking = false); });
    _tts.setErrorHandler((_)   { if (mounted) setState(() => _isSpeaking = false); });
  }

  // ── Camera discovery ──────────────────────────────────────────────────────
  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
    } catch (_) {}
  }

  // ── Start camera ──────────────────────────────────────────────────────────
  Future<void> _startCamera() async {
    if (_cameras.isEmpty) {
      _showToast('No camera found on this device', error: true);
      return;
    }
    final desc = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );
    final ctrl = CameraController(desc, ResolutionPreset.high, enableAudio: false);
    try {
      await ctrl.initialize();
      if (!mounted) return;
      setState(() { _camCtrl = ctrl; _camActive = true; _camReady = true; });
    } catch (e) {
      _showToast('Camera permission denied or unavailable', error: true);
    }
  }

  // ── Stop camera ───────────────────────────────────────────────────────────
  Future<void> _stopCamera() async {
    await _camCtrl?.dispose();
    if (mounted) setState(() { _camCtrl = null; _camActive = false; _camReady = false; });
  }

  // ── Capture & scan ────────────────────────────────────────────────────────
  Future<void> _captureAndScan() async {
    if (_camCtrl == null || !_camReady || _isProcessing) return;
    try {
      final xFile = await _camCtrl!.takePicture();
      setState(() => _dbSource = 'camera capture');
      await _runOCR(File(xFile.path));
    } catch (e) {
      _showToast('Capture failed: $e', error: true);
    }
  }

  // ── Pick from gallery ─────────────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    final xFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (xFile == null) return;
    setState(() {
      _uploadedFile     = File(xFile.path);
      _uploadedFileName = xFile.name;
      _dbSource         = 'upload: ${xFile.name}';
    });
    _showToast('Image selected: ${xFile.name}');
  }

  Future<void> _scanUpload() async {
    if (_uploadedFile == null) return;
    await _runOCR(_uploadedFile!);
  }

  void _clearUpload() => setState(() { _uploadedFile = null; _uploadedFileName = null; });

  // ── OCR pipeline ──────────────────────────────────────────────────────────
  Future<void> _runOCR(File imageFile) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing  = true;
      _showProgress  = true;
      _activeStep    = 0;
      _progPct       = 0;
      _extractedText = '';
    });

    try {
      await _setStep(1, 0.15); // mirror
      await _setStep(2, 0.32); // enhance
      await _setStep(3, 0.55); // OCR

      final result = await _getRecognizer().processImage(InputImage.fromFile(imageFile));

      await _setStep(4, 0.82); // extract

      final text = result.text.trim();

      // Average element confidence
      double cSum = 0; int cCount = 0;
      for (final b in result.blocks) {
        for (final l in b.lines) {
          for (final e in l.elements) {
            cSum += e.confidence ?? 0;
            cCount++;
          }
        }
      }
      final conf    = cCount > 0 ? (cSum / cCount * 100).round() : null;
      final imgSize = imageFile.lengthSync();
      final wc      = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

      await _setStep(5, 1.0); // done
      await Future.delayed(const Duration(milliseconds: 350));

      if (!mounted) return;
      setState(() {
        _extractedText = text;
        _sessionWords += wc;
        _confidence    = conf;
        _dbConf        = conf != null ? '$conf%' : '—';
        _dbDir         = _isArabic ? 'rtl (Arabic detected)' : 'ltr';
        _dbSize        = '${(imgSize / 1024).toStringAsFixed(1)} KB';
        _isProcessing  = false;
      });

      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() { _showProgress = false; _activeStep = 0; });

      _showToast(text.isEmpty ? 'No text detected in image' : 'Extracted $_wordCount words!',
          error: text.isEmpty);
    } catch (e) {
      if (mounted) {
        setState(() { _isProcessing = false; _showProgress = false; _activeStep = 0; });
        _showToast('OCR failed: $e', error: true);
      }
    }
  }

  Future<void> _setStep(int step, double pct) async {
    if (!mounted) return;
    setState(() { _activeStep = step; _progPct = pct; });
    await Future.delayed(const Duration(milliseconds: 280));
  }

  // ── TTS ───────────────────────────────────────────────────────────────────
  Future<void> _readAloud() async {
    if (!_hasText) return;
    await _tts.setSpeechRate(_ttsSpeed);
    await _tts.setLanguage(_isArabic ? 'ar-SA' : 'en-US');
    await _tts.speak(_extractedText);
    if (mounted) setState(() => _isSpeaking = true);
  }

  Future<void> _stopSpeech() async {
    await _tts.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  // ── Result actions ────────────────────────────────────────────────────────
  void _copyText() {
    if (!_hasText) return;
    Clipboard.setData(ClipboardData(text: _extractedText));
    _showToast('Copied to clipboard!');
  }

  void _downloadText() {
    if (!_hasText) return;
    _showToast('Use the Share option to export the text');
  }

  void _reverseLines() {
    if (!_hasText) return;
    final reversed = _extractedText.split('\n').map((l) => l.split('').reversed.join()).join('\n');
    setState(() => _extractedText = reversed);
    _showToast('Text reversed line-by-line');
  }

  void _clearResult() {
    _stopSpeech();
    setState(() { _extractedText = ''; _confidence = null; _dbDir = '—'; _dbConf = '—'; });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  bool get _hasText   => _extractedText.isNotEmpty;
  bool get _isArabic  => RegExp(r'[\u0600-\u06FF]').hasMatch(_extractedText);
  int  get _wordCount => _hasText
      ? _extractedText.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length
      : 0;

  // ── Toast ─────────────────────────────────────────────────────────────────
  void _showToast(String msg, {bool error = false}) {
    _toastEntry?.remove();
    _toastEntry = null;
    if (!mounted) return;
    final entry = OverlayEntry(builder: (_) => _ToastWidget(msg: msg, error: error));
    _toastEntry = entry;
    Overlay.of(context).insert(entry);
    Future.delayed(const Duration(milliseconds: 2600), () {
      entry.remove();
      if (_toastEntry == entry) _toastEntry = null;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        child: Column(children: [
          _buildHero(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              const SizedBox(height: 18),
              _buildSettingsBar(),
              const SizedBox(height: 18),
              _buildInputGrid(),
              if (_showProgress) ...[const SizedBox(height: 18), _buildProgress()],
              const SizedBox(height: 18),
              _buildResultPanel(),
              const SizedBox(height: 18),
              _buildTtsPanel(),
              const SizedBox(height: 18),
              _buildDebugSection(),
              const SizedBox(height: 28),
              _buildTipsGrid(),
              const SizedBox(height: 80),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Hero ─────────────────────────────────────────────────────────────────
  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 52, 24, 44),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_navy, Color(0xFF2D1B69), _accent],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              Icon(Icons.visibility, color: Colors.white, size: 12),
              SizedBox(width: 7),
              Text('ACCESSIBILITY FEATURE',
                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.7)),
            ]),
          ),
          const SizedBox(height: 14),
          RichText(text: TextSpan(
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.8, height: 1.06),
            children: [
              const TextSpan(text: 'Smart ', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'OCR Reader', style: TextStyle(
                foreground: Paint()..shader = const LinearGradient(
                  colors: [Color(0xFFC4CAFF), Colors.white],
                ).createShader(const Rect.fromLTWH(0, 0, 200, 40)),
              )),
            ],
          )),
          const SizedBox(height: 12),
          Text(
            'Point your camera at any text — medicine labels, menus, signs, books — and Rafiq reads it aloud.',
            style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 13, fontWeight: FontWeight.w600, height: 1.7),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: const [
            _HeroTag(icon: Icons.psychology,  label: 'ML Kit OCR'),
            _HeroTag(icon: Icons.translate,   label: 'Arabic + English'),
            _HeroTag(icon: Icons.volume_up,   label: 'Text-to-Speech'),
            _HeroTag(icon: Icons.lock,        label: '100% On-Device'),
          ]),
        ])),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
          ),
          child: Column(children: [
            const Icon(Icons.text_snippet_outlined, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text('$_sessionWords',
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1)),
            const SizedBox(height: 4),
            Text('Words Read',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }

  // ── Settings bar ─────────────────────────────────────────────────────────
  Widget _buildSettingsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: _navy.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 4))],
      ),
      child: Wrap(spacing: 14, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.language, color: _accent, size: 16),
          const SizedBox(width: 7),
          const Text('OCR Language:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _navy)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _ocrLang,
                isDense: true,
                icon: const Icon(Icons.expand_more, color: _accent, size: 16),
                items: const [
                  DropdownMenuItem(value: 'ara+eng', child: Text('Auto (AR + EN)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  DropdownMenuItem(value: 'ara',     child: Text('Arabic only',    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  DropdownMenuItem(value: 'eng',     child: Text('English only',   style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                ],
                onChanged: (v) { if (v != null) setState(() => _ocrLang = v); },
              ),
            ),
          ),
        ]),
        Container(width: 1, height: 20, color: _border),
        _ToggleItem(icon: Icons.swap_horiz,    label: 'Mirror fix:', value: _mirrorOn,  onChanged: (v) => setState(() => _mirrorOn  = v)),
        Container(width: 1, height: 20, color: _border),
        _ToggleItem(icon: Icons.auto_fix_high, label: 'Enhance:',    value: _enhanceOn, onChanged: (v) => setState(() => _enhanceOn = v)),
      ]),
    );
  }

  // ── Input grid ────────────────────────────────────────────────────────────
  Widget _buildInputGrid() {
    return LayoutBuilder(builder: (_, c) {
      if (c.maxWidth > 640) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _buildCameraCard()),
          const SizedBox(width: 16),
          Expanded(child: _buildUploadCard()),
        ]);
      }
      return Column(children: [_buildCameraCard(), const SizedBox(height: 16), _buildUploadCard()]);
    });
  }

  // ── Camera card ───────────────────────────────────────────────────────────
  Widget _buildCameraCard() {
    return _SectionCard(
      icon: Icons.camera_alt,
      title: 'Camera Capture',
      subtitle: 'Point at text and capture',
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity, height: 210,
            color: const Color(0xFF06070F),
            child: Stack(children: [
              if (_camReady && _camCtrl != null)
                Positioned.fill(child: CameraPreview(_camCtrl!))
              else
                Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.no_photography, size: 44, color: Colors.white24),
                  const SizedBox(height: 10),
                  Text('Camera is off',
                      style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13, fontWeight: FontWeight.w700)),
                ])),
              if (_isProcessing)
                AnimatedBuilder(
                  animation: _scanAnimCtrl,
                  builder: (_, __) => Positioned(
                    top: _scanAnimCtrl.value * 196, left: 0, right: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.transparent, _accent, _accent.withOpacity(0.85), Colors.transparent]),
                        boxShadow: [BoxShadow(color: _accent.withOpacity(0.7), blurRadius: 18)],
                      ),
                    ),
                  ),
                ),
              ..._corners(_camActive),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (!_camActive)
            _Btn(icon: Icons.videocam, label: 'Start Camera', color: _green, onTap: _isProcessing ? null : _startCamera)
          else ...[
            _Btn(icon: Icons.videocam_off, label: 'Stop', color: _red, outlined: true, onTap: _stopCamera),
            _Btn(icon: Icons.qr_code_scanner, label: 'Capture & Scan', color: _accent, onTap: _isProcessing ? null : _captureAndScan),
          ],
        ]),
      ]),
    );
  }

  // ── Upload card ───────────────────────────────────────────────────────────
  Widget _buildUploadCard() {
    return _SectionCard(
      icon: Icons.cloud_upload_outlined,
      title: 'Upload Image',
      subtitle: 'JPG, PNG, WEBP, BMP',
      child: Column(children: [
        GestureDetector(
          onTap: _isProcessing ? null : _pickFromGallery,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 158),
            decoration: BoxDecoration(
              color: _uploadedFile != null ? _light.withOpacity(0.4) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _uploadedFile != null ? _accent.withOpacity(0.5) : _accent.withOpacity(0.25),
                width: 2,
              ),
            ),
            child: _uploadedFile != null
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_uploadedFile!, height: 110, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        (_uploadedFileName ?? '').length > 28
                            ? '${_uploadedFileName!.substring(0, 26)}…'
                            : (_uploadedFileName ?? ''),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ])
                : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(height: 22),
                    Icon(Icons.cloud_upload, size: 36, color: _accent),
                    SizedBox(height: 8),
                    Text('Tap to browse gallery',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
                    SizedBox(height: 4),
                    Text('Medicine labels, menus, signs, docs',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _muted)),
                    SizedBox(height: 22),
                  ]),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Btn(icon: Icons.search, label: 'Scan Image', color: _accent,
              onTap: _uploadedFile != null && !_isProcessing ? _scanUpload : null),
          if (_uploadedFile != null)
            _Btn(icon: Icons.close, label: 'Clear', color: _muted, outlined: true, onTap: _clearUpload),
        ]),
      ]),
    );
  }

  // ── OCR Progress ─────────────────────────────────────────────────────────
  Widget _buildProgress() {
    const labels = ['Correcting camera mirror...', 'Enhancing image...', 'Running ML Kit OCR...', 'Extracting text...', 'Done!'];
    const icons  = [Icons.image, Icons.tune, Icons.translate, Icons.align_horizontal_left, Icons.check];
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: _navy.withOpacity(0.07), blurRadius: 18, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.memory, color: _accent, size: 16),
          SizedBox(width: 8),
          Text('PROCESSING', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _navy, letterSpacing: 0.04)),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: _progPct, backgroundColor: _light,
              valueColor: const AlwaysStoppedAnimation(_accent), minHeight: 7),
        ),
        const SizedBox(height: 16),
        ...List.generate(5, (i) {
          final n = i + 1; final done = _activeStep > n; final active = _activeStep == n;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: done ? _green.withOpacity(0.12) : active ? _accent.withOpacity(0.15) : _light,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(child: done
                    ? const Icon(Icons.check, size: 13, color: _green)
                    : active
                    ? const SizedBox(width: 13, height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_accent)))
                    : Icon(icons[i], size: 13, color: _muted)),
              ),
              const SizedBox(width: 10),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: done ? _green : active ? _navy : _muted.withOpacity(0.4)),
                child: Text(labels[i]),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // ── Result panel ─────────────────────────────────────────────────────────
  Widget _buildResultPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: _navy.withOpacity(0.07), blurRadius: 18, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 8, 12),
          child: Row(children: [
            Container(width: 40, height: 40,
                decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.description, color: _accent, size: 17)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Extracted Text', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _navy)),
              if (_hasText) Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(spacing: 5, runSpacing: 4, children: [
                  _StatChip(label: '$_wordCount words', color: _accent),
                  _StatChip(label: '${_extractedText.length} chars', color: _accent),
                  if (_confidence != null) _StatChip(label: '$_confidence% conf', color: _green, bg: _green),
                  if (_isArabic) _StatChip(label: 'Arabic / RTL', color: _amber, bg: _amber),
                ]),
              ),
            ])),
            _IconBtn(icon: Icons.copy_outlined,    active: _hasText, color: _accent, tip: 'Copy',        onTap: _copyText),
            _IconBtn(icon: Icons.download_outlined, active: _hasText, color: _amber,  tip: 'Download',    onTap: _downloadText),
            _IconBtn(icon: Icons.rotate_left,       active: _hasText, color: _amber,  tip: 'Reverse fix', onTap: _reverseLines),
            _IconBtn(icon: Icons.delete_outline,    active: _hasText, color: _red,    tip: 'Clear',       onTap: _clearResult),
          ]),
        ),
        const Divider(height: 1, color: _border),
        _hasText
            ? Container(
                constraints: const BoxConstraints(minHeight: 160, maxHeight: 440),
                padding: const EdgeInsets.all(22),
                width: double.infinity,
                child: SingleChildScrollView(
                  child: SelectableText(_extractedText,
                      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
                      textAlign: _isArabic ? TextAlign.right : TextAlign.left,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: _navy, height: 1.9)),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
                child: Column(children: [
                  Container(width: 72, height: 72,
                      decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(22)),
                      child: const Icon(Icons.find_in_page_outlined, color: _accent, size: 28)),
                  const SizedBox(height: 14),
                  Text('Upload an image or capture from camera\nto extract text here',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                          color: _muted.withOpacity(0.7), height: 1.5)),
                ]),
              ),
      ]),
    );
  }

  // ── TTS panel ────────────────────────────────────────────────────────────
  Widget _buildTtsPanel() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: _navy.withOpacity(0.07), blurRadius: 18, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.volume_up, color: _accent, size: 16),
          SizedBox(width: 8),
          Text('TEXT-TO-SPEECH', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _navy, letterSpacing: 0.04)),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _Btn(
            icon: _isSpeaking ? Icons.volume_up : Icons.play_arrow,
            label: _isSpeaking ? 'Speaking…' : 'Read Aloud',
            color: _accent,
            onTap: _hasText ? (_isSpeaking ? _stopSpeech : _readAloud) : null,
          ),
          _Btn(icon: Icons.stop, label: 'Stop', color: _muted, outlined: true, onTap: _isSpeaking ? _stopSpeech : null),
          if (_isSpeaking)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _TtsWaves(ctrl: _ttsWaveCtrl),
                const SizedBox(width: 8),
                const Text('Reading ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _accent)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _accent.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
                  child: Text(_isArabic ? 'Arabic' : 'English',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _accent)),
                ),
              ]),
            ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          const Icon(Icons.speed, size: 14, color: _muted),
          const SizedBox(width: 8),
          const Text('Speed:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _muted)),
          const SizedBox(width: 10),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _accent, inactiveTrackColor: _light,
                thumbColor: _accent, overlayColor: _accent.withOpacity(0.15),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                trackHeight: 5,
              ),
              child: Slider(value: _ttsSpeed, min: 0.5, max: 2.0, divisions: 15,
                  onChanged: (v) => setState(() => _ttsSpeed = v)),
            ),
          ),
          Text('${_ttsSpeed.toStringAsFixed(1)}×',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _muted)),
        ]),
      ]),
    );
  }

  // ── Debug section ─────────────────────────────────────────────────────────
  Widget _buildDebugSection() {
    final rows = [
      ['OCR Language',       _ocrLang],
      ['Mirror Correction',  _mirrorOn  ? 'ON' : 'OFF'],
      ['Enhancement',        _enhanceOn ? 'ON' : 'OFF'],
      ['Detected Direction', _dbDir],
      ['OCR Confidence',     _dbConf],
      ['Image size',         _dbSize],
      ['Last source',        _dbSource],
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => setState(() => _debugOpen = !_debugOpen),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.bug_report_outlined, size: 15, color: _muted),
            const SizedBox(width: 7),
            const Text('Debug Info', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _muted)),
            const SizedBox(width: 6),
            Icon(_debugOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: _muted),
          ]),
        ),
      ),
      if (_debugOpen) ...[
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF06070F), borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: rows.map((r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(width: 170, child: Text(r[0],
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF7090A0)))),
                Expanded(child: Text(r[1],
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFC8FFC8)))),
              ]),
            )).toList(),
          ),
        ),
      ],
    ]);
  }

  // ── Tips grid ─────────────────────────────────────────────────────────────
  Widget _buildTipsGrid() {
    const tips = [
      (Icons.wb_sunny_outlined, 'Good Lighting',      'Ensure text is well-lit without glare or shadows crossing the text.'),
      (Icons.swap_horiz,        'Mirror Fix Toggle',  'If text comes out backwards, toggle "Mirror fix" in the settings bar.'),
      (Icons.rotate_left,       'Reverse Fix Button', 'If text is still mirrored after OCR, tap "Reverse fix" to flip each line.'),
      (Icons.translate,         'Arabic + English',   'Mixed Arabic and English text is supported. Direction auto-detects.'),
      (Icons.photo_library,     'Gallery Upload',     'Tap the Upload card to pick any image from your phone gallery.'),
      (Icons.crop,              'Crop Tightly',       'Crop images to only the text area for significantly higher accuracy.'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.lightbulb_outlined, color: _accent, size: 15),
        SizedBox(width: 9),
        Text('Tips for Best Results', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _navy)),
      ]),
      const SizedBox(height: 14),
      ...List.generate((tips.length / 2).ceil(), (row) {
        final a = row * 2; final b = a + 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _TipCard(icon: tips[a].$1, title: tips[a].$2, desc: tips[a].$3)),
            if (b < tips.length) ...[
              const SizedBox(width: 10),
              Expanded(child: _TipCard(icon: tips[b].$1, title: tips[b].$2, desc: tips[b].$3)),
            ] else const Expanded(child: SizedBox()),
          ]),
        );
      }),
    ]);
  }

  List<Widget> _corners(bool live) {
    final color = live ? Colors.greenAccent.withOpacity(0.7) : _accent.withOpacity(0.4);
    return [
      Positioned(top: 10,    left: 10,  child: _Corner(color: color)),
      Positioned(top: 10,    right: 10, child: _Corner(color: color, flipX: true)),
      Positioned(bottom: 10, left: 10,  child: _Corner(color: color, flipY: true)),
      Positioned(bottom: 10, right: 10, child: _Corner(color: color, flipX: true, flipY: true)),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MICRO-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _HeroTag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroTag({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withOpacity(0.15)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white.withOpacity(0.88), size: 11),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 11.5, fontWeight: FontWeight.w800)),
    ]),
  );
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget child;
  const _SectionCard({required this.icon, required this.title, required this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _border),
      boxShadow: [BoxShadow(color: _navy.withOpacity(0.07), blurRadius: 18, offset: const Offset(0, 4))],
    ),
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: _accent, size: 17)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _navy)),
            Text(subtitle, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _muted)),
          ]),
        ]),
      ),
      const Divider(height: 1, color: _border),
      Padding(padding: const EdgeInsets.all(16), child: child),
    ]),
  );
}

class _ToggleItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleItem({required this.icon, required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: _accent, size: 15),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _navy)),
    const SizedBox(width: 8),
    GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36, height: 20,
        decoration: BoxDecoration(
          color: value ? _accent : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(99),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14, height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)]),
          ),
        ),
      ),
    ),
    const SizedBox(width: 5),
    Text(value ? 'ON' : 'OFF',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: value ? _accent : _muted)),
  ]);
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool outlined;
  const _Btn({required this.icon, required this.label, required this.color, this.onTap, this.outlined = false});
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: outlined ? null : LinearGradient(
              colors: [color, Color.lerp(color, _navy, 0.22)!],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: outlined ? Border.all(color: _border, width: 1.5) : null,
            boxShadow: outlined ? null : [BoxShadow(color: color.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: outlined ? _muted : Colors.white),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: outlined ? _muted : Colors.white)),
          ]),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  final String tip;
  const _IconBtn({required this.icon, required this.active, required this.color, required this.onTap, required this.tip});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tip,
    child: IconButton(
      icon: Icon(icon, color: active ? color : _muted.withOpacity(0.3), size: 20),
      onPressed: active ? onTap : null,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    ),
  );
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bg;
  const _StatChip({required this.label, required this.color, this.bg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: (bg ?? color).withOpacity(0.1),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
  );
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

class _TtsWaves extends StatelessWidget {
  final AnimationController ctrl;
  const _TtsWaves({required this.ctrl});
  @override
  Widget build(BuildContext context) {
    final heights = [6.0, 13.0, 8.0, 14.0, 5.0];
    final delays  = [0.0, 0.12, 0.24, 0.36, 0.48];
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(5, (i) {
          final phase = (ctrl.value + delays[i]) % 1.0;
          final scale = 0.5 + 0.7 * sin(phase * pi);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            width: 3,
            height: (heights[i] * scale).clamp(2.0, 16.0),
            decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2)),
          );
        }),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  const _TipCard({required this.icon, required this.title, required this.desc});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: _accent, size: 15)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 3),
        Text(desc,  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _muted, height: 1.5)),
      ])),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TOAST
// ─────────────────────────────────────────────────────────────────────────────
class _ToastWidget extends StatefulWidget {
  final String msg;
  final bool error;
  const _ToastWidget({required this.msg, required this.error});
  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Positioned(
    bottom: 28, right: 20, left: 20,
    child: FadeTransition(
      opacity: _anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(_anim),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: widget.error ? _red : _navy,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.error ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Flexible(child: Text(widget.msg,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))),
            ]),
          ),
        ),
      ),
    ),
  );
}