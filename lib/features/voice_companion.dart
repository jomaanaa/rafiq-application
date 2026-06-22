import 'package:flutter/material.dart';

class AiVoiceCompanion extends StatefulWidget {
  const AiVoiceCompanion({super.key});

  @override
  State<AiVoiceCompanion> createState() => _AiVoiceCompanionState();
}

class _AiVoiceCompanionState extends State<AiVoiceCompanion> {
  final List<Map<String, String>> _chatMessages = [
    {
      "sender": "assistant",
      "text": "Good morning! I'm Rafiq Voice Companion. I understand English, Arabic (عربي), and Franco Arabic. Click the microphone or type a command. Say 'help' to see everything I can do."
    }
  ];
  
  final TextEditingController _textController = TextEditingController();
  bool _isListening = false;

  void _handleVoiceInputSimulate() {
    setState(() {
      _isListening = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isListening = false;
          _chatMessages.add({"sender": "user", "text": "show my scheduled medical profile"});
          _chatMessages.add({
            "sender": "assistant",
            "text": "Routing you to your primary profile fields... Opening your medical file parameters now."
          });
        });
      }
    });
  }

  void _sendMessage() {
    final txt = _textController.text.trim();
    if (txt.isEmpty) return;
    _textController.clear();

    setState(() {
      _chatMessages.add({"sender": "user", "text": txt});
    });

    // Handle standard script actions
    String responseText = "I captured '$txt'. Tell me 'help' to review structural routing parameters.";
    if (txt.toLowerCase() == 'help') {
      responseText = "Commands list: 'home', 'bookings', 'profile', 'ocr reader', 'sign assistant', 'high contrast'.";
    } else if (txt.toLowerCase().contains('profile')) {
      responseText = "Opening medical profile parameters right away.";
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _chatMessages.add({"sender": "assistant", "text": responseText});
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FB),
      appBar: AppBar(
        title: const Text('AI Voice Companion', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: const Color(0xFF1E2040),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Informative Context Banner Header Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: const Color(0xFF353B69),
            child: Row(
              children: [
                const Icon(Icons.spatial_audio_off, color: Color(0xFF6470D2)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Acoustic tracking node listening layer is operational.',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                )
              ],
            ),
          ),

          // Core Scrollable Message Bubbles Listing Container
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _chatMessages.length,
              itemBuilder: (context, idx) {
                final msg = _chatMessages[idx];
                final isUser = msg["sender"] == "user";
                return Align(
                  alignment: isUser ? Alignment.topRight : Alignment.topLeft,
                  child: Container(
                    // Move maxWidth inside BoxConstraints
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF6470D2) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Text(
                      msg["text"] ?? "",
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF1E2040),
                        fontWeight: isUser ? FontWeight.bold : FontWeight.w600,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Fixed Microphone Action Area Controls Row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F5FB),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              decoration: const InputDecoration(
                                hintText: "Type voice instruction command...",
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send, color: Color(0xFF6470D2)),
                            onPressed: _sendMessage,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _handleVoiceInputSimulate,
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: _isListening ? const Color(0xFFDC2626) : const Color(0xFF6470D2),
                      child: Icon(
                        _isListening ? Icons.hearing : Icons.mic,
                        color: Colors.white,
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}