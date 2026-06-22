import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rafiq/auth/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const _navy   = Color(0xFF1E2040);
const _purple = Color(0xFF353B69);
const _accent = Color(0xFF6470D2);
const _a2     = Color(0xFF494788);
const _light  = Color(0xFFEEF0FF);
const _bg     = Color(0xFFF4F5FB);
const _card   = Color(0xFFFFFFFF);
const _text   = Color(0xFF1E2040);
const _muted  = Color(0xFF6B7080);
const _border = Color(0x24647ED2);

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE SIZE INSIDE THE BUBBLE — change this one value to resize Helpy
// ─────────────────────────────────────────────────────────────────────────────
const double _helpyBubblePadding = 4.0; // lower = bigger image, higher = smaller

// ─────────────────────────────────────────────────────────────────────────────
// API CONFIG
// ─────────────────────────────────────────────────────────────────────────────
const _kApiUrl = 'http://10.13.114.211/Api/chatbot_api.php';

// ─────────────────────────────────────────────────────────────────────────────
// QUICK SUGGESTION CHIPS
// ─────────────────────────────────────────────────────────────────────────────
const _chips = [
  (icon: Icons.map_outlined,              label: 'Find accessible places',  q: 'How do I find accessible places near me?'),
  (icon: Icons.directions_car_outlined,   label: 'Book a driver',           q: 'How do I book a driver?'),
  (icon: Icons.medical_services_outlined, label: 'Book a doctor',           q: 'How do I book a doctor for a home visit?'),
  (icon: Icons.emergency_outlined,        label: 'Emergency help',          q: 'I am in an emergency. What should I do?'),
  (icon: Icons.location_on_outlined,      label: 'Using the map',           q: 'How do I use the map and its filters?'),
  (icon: Icons.accessible_outlined,       label: 'Wheelchair support',      q: 'I use a wheelchair. How can Rafiq help me?'),
  (icon: Icons.visibility_outlined,       label: 'Visual impairment',       q: 'I am visually impaired. Is Rafiq accessible?'),
  (icon: Icons.hearing_outlined,          label: 'Hearing impaired',        q: 'I am deaf or hard of hearing. What services are available?'),
  (icon: Icons.favorite_border_rounded,   label: 'Book a caregiver',        q: 'How do I book a caregiver?'),
  (icon: Icons.local_shipping_outlined,   label: 'Booking status',          q: 'How do I track my booking status?'),
  (icon: Icons.credit_card_outlined,      label: 'Payment options',         q: 'What payment methods does Rafiq accept?'),
  (icon: Icons.report_outlined,           label: 'Report wrong info',       q: 'How do I report incorrect information on the map?'),
  (icon: Icons.work_outline_rounded,      label: 'Join as provider',        q: 'How can I join Rafiq as a service provider?'),
  (icon: Icons.lock_outline_rounded,      label: 'Privacy & safety',        q: 'Is my personal data safe on Rafiq?'),
  (icon: Icons.support_agent_outlined,    label: 'Contact support',         q: 'How do I contact Rafiq support?'),
];

// ─────────────────────────────────────────────────────────────────────────────
// MESSAGE MODEL
// ─────────────────────────────────────────────────────────────────────────────
enum _Role { user, bot, typing }

class _Msg {
  final _Role role;
  final String text;
  final DateTime time;
  _Msg({required this.role, required this.text}) : time = DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class RafiqChatbotScreen extends StatefulWidget {
  final String? initialMessage;
  const RafiqChatbotScreen({super.key, this.initialMessage});

  @override
  State<RafiqChatbotScreen> createState() => _RafiqChatbotScreenState();
}

class _RafiqChatbotScreenState extends State<RafiqChatbotScreen>
    with TickerProviderStateMixin {
  final _scrollCtrl = ScrollController();
  final _inputCtrl  = TextEditingController();
  final _inputFocus = FocusNode();
  final List<_Msg>  _messages = [];

  final List<Map<String, String>> _history = [];

  bool _busy        = false;
  bool _heroVisible = true;
  late AnimationController _heroAnim;
  late Animation<double>   _heroFade;
  late Animation<double>   _heroHeight;

  @override
  void initState() {
    super.initState();
    _heroAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _heroFade   = CurvedAnimation(parent: _heroAnim, curve: Curves.easeOut);
    _heroHeight = CurvedAnimation(parent: _heroAnim, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _heroAnim.dispose();
    super.dispose();
  }

  void _collapseHero() {
    if (!_heroVisible) return;
    setState(() => _heroVisible = false);
    _heroAnim.forward();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    text = text.trim();
    if (text.isEmpty || _busy) return;

    _inputCtrl.clear();
    _collapseHero();

    setState(() {
      _busy = true;
      _messages.add(_Msg(role: _Role.user, text: text));
      _messages.add(_Msg(role: _Role.typing, text: ''));
    });
    _scrollToBottom();

    final reply = await ApiService.sendChatMessage(
      message: text,
      history: _history,
    ) ?? "I'm having a connection issue right now. Please try again, or email support@rafiq.eg";

    _history.add({'role': 'user',  'content': text});
    _history.add({'role': 'model', 'content': reply});
    if (_history.length > 40) _history.removeRange(0, _history.length - 40);

    setState(() {
      _messages.removeLast();
      _messages.add(_Msg(role: _Role.bot, text: reply));
      _busy = false;
    });
    _scrollToBottom();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            _buildHeroBanner(),
            Expanded(child: _buildMessageList()),
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.arrow_back_rounded, size: 15, color: _purple),
                  SizedBox(width: 6),
                  Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _purple,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_purple, _accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.26),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6), // lower = bigger
                    child: Image.asset('assets/images/helpy.png', fit: BoxFit.contain),
                  ),                
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Helpy',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _navy,
                          letterSpacing: -.3,
                        ),
                      ),
                      Row(
                        children: [
                          _LiveDot(),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Ask me anything',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 64),
        ],
      ),
    );
  }

  // ── Hero banner ───────────────────────────────────────────────────────────
  Widget _buildHeroBanner() {
    return AnimatedBuilder(
      animation: _heroAnim,
      builder: (_, __) {
        if (_heroAnim.isCompleted) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor:
                _heroVisible ? 1.0 : (1.0 - _heroHeight.value),
            child: Opacity(
              opacity: _heroVisible ? 1.0 : (1.0 - _heroFade.value),
              child: _HeroBanner(),
            ),
          ),
        );
      },
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────
  Widget _buildMessageList() {
    if (_messages.isEmpty) return const SizedBox.expand();
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        if (msg.role == _Role.typing) return _TypingBubble();
        if (msg.role == _Role.user)   return _UserBubble(msg: msg);
        return _BotBubble(msg: msg);
      },
    );
  }

  // ── Bottom panel ──────────────────────────────────────────────────────────
  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.05),
            blurRadius: 22,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChips(),
          _buildInputBar(),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ── Quick suggestion chips ────────────────────────────────────────────────
  Widget _buildChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 7),
          child: Text(
            'QUICK SUGGESTIONS — OR TYPE YOUR OWN BELOW',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: _muted,
              letterSpacing: .06 * 10,
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            itemCount: _chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (_, i) {
              final chip = _chips[i];
              return GestureDetector(
                onTap: _busy ? null : () => _send(chip.q),
                child: AnimatedOpacity(
                  opacity: _busy ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _light,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _accent.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(chip.icon, size: 13, color: _purple),
                        const SizedBox(width: 6),
                        Text(
                          chip.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Text input + send button ──────────────────────────────────────────────
  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 50, maxHeight: 120),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _accent.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _inputCtrl,
                focusNode: _inputFocus,
                maxLines: null,
                maxLength: 1000,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
                decoration: const InputDecoration(
                  hintText: "Type any question — I'm a real AI…",
                  hintStyle: TextStyle(
                    color: Color(0xFFA5A8C8),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  contentPadding: EdgeInsets.fromLTRB(16, 14, 16, 14),
                  border: InputBorder.none,
                  counterText: '',
                ),
                onSubmitted: (_) => _send(_inputCtrl.text),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: (_inputCtrl.text.trim().isEmpty || _busy)
                ? null
                : () => _send(_inputCtrl.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: (_inputCtrl.text.trim().isEmpty || _busy)
                    ? null
                    : const LinearGradient(
                        colors: [_a2, _accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: (_inputCtrl.text.trim().isEmpty || _busy)
                    ? _border
                    : null,
                borderRadius: BorderRadius.circular(15),
                boxShadow: (_inputCtrl.text.trim().isEmpty || _busy)
                    ? []
                    : [
                        BoxShadow(
                          color: _accent.withOpacity(0.32),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Icon(
                Icons.send_rounded,
                color: (_inputCtrl.text.trim().isEmpty || _busy)
                    ? _muted.withOpacity(0.5)
                    : Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, _purple, _accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                    height: 1.15,
                  ),
                  children: [
                    const TextSpan(
                      text: "Hi 👋  I'm Helpy",
                      style: TextStyle(color: Colors.white),
                    ),
                    WidgetSpan(
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFC4CAFF), Colors.white],
                        ).createShader(bounds),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'I can answer any question,\nnot just the suggestions below. Try me!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.78),
                  height: 1.65,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER BUBBLE
// ─────────────────────────────────────────────────────────────────────────────
class _UserBubble extends StatelessWidget {
  final _Msg msg;
  const _UserBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.74,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_a2, _accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.65,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2F3060), Color(0xFF4A3FA0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: _card, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _navy.withOpacity(0.11),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 43),
            child: Text(
              _fmt(msg.time),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: _muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOT BUBBLE
// ─────────────────────────────────────────────────────────────────────────────
class _BotBubble extends StatelessWidget {
  final _Msg msg;
  const _BotBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── Helpy avatar ──────────────────────────────────────────────
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_purple, _accent],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(_helpyBubblePadding), // ← tweak here
                  child: Image.asset('assets/images/helpy.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.74,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: _navy.withOpacity(0.09),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _MarkdownText(text: msg.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 43),
            child: Text(
              _fmt(msg.time),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: _muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPING INDICATOR
// ─────────────────────────────────────────────────────────────────────────────
class _TypingBubble extends StatefulWidget {
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _anims = List.generate(3, (i) {
      final start = i * 0.18;
      return Tween(begin: 0.0, end: -8.0).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, start + 0.4, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Helpy avatar ────────────────────────────────────────────────
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_purple, _accent],
              ),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(_helpyBubblePadding), // ← tweak here
              child: Image.asset('assets/images/helpy.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: _navy.withOpacity(0.09),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Transform.translate(
                        offset: Offset(0, _anims[i].value),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF9598C0),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE DOT
// ─────────────────────────────────────────────────────────────────────────────
class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _opacity = Tween(begin: 1.0, end: 0.35).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARKDOWN TEXT RENDERER
// ─────────────────────────────────────────────────────────────────────────────
class _MarkdownText extends StatelessWidget {
  final String text;
  const _MarkdownText({required this.text});

  @override
  Widget build(BuildContext context) {
    final lines   = text.split('\n');
    final widgets = <Widget>[];
    int i = 0;

    while (i < lines.length) {
      final line    = lines[i];
      final ulMatch = RegExp(r'^[*\-•]\s+(.*)').firstMatch(line);
      final olMatch = RegExp(r'^\d+\.\s+(.*)').firstMatch(line);

      if (ulMatch != null) {
        final items = <String>[];
        while (i < lines.length) {
          final m = RegExp(r'^[*\-•]\s+(.*)').firstMatch(lines[i]);
          if (m == null) break;
          items.add(m.group(1)!);
          i++;
        }
        widgets.add(_buildList(items, ordered: false));
      } else if (olMatch != null) {
        final items = <String>[];
        int n = 1;
        while (i < lines.length) {
          final m = RegExp(r'^\d+\.\s+(.*)').firstMatch(lines[i]);
          if (m == null) break;
          items.add('${n++}. ${m.group(1)!}');
          i++;
        }
        widgets.add(_buildList(items, ordered: true, prefixed: true));
      } else {
        if (line.trim().isNotEmpty) {
          if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 5));
          widgets.add(_inlineText(line.trim()));
        }
        i++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildList(List<String> items,
      {required bool ordered, bool prefixed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ordered ? '' : '• ',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                    height: 1.65,
                  ),
                ),
                Expanded(child: _inlineText(item)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _inlineText(String raw) {
    final spans   = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.*?)\*\*|\*(.*?)\*|`(.*?)`');
    int last = 0;

    for (final match in pattern.allMatches(raw)) {
      if (match.start > last) {
        spans.add(TextSpan(text: raw.substring(last, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else if (match.group(3) != null) {
        spans.add(WidgetSpan(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2FF),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              match.group(3)!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.8,
                color: _purple,
              ),
            ),
          ),
        ));
      }
      last = match.end;
    }
    if (last < raw.length) spans.add(TextSpan(text: raw.substring(last)));

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _text,
          height: 1.65,
        ),
        children: spans,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UTILITIES
// ─────────────────────────────────────────────────────────────────────────────
String _fmt(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}