import 'dart:async';
import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

const _violet = Color(0xFF5137ED);

class _ChatMessage {
  _ChatMessage({required this.role, required this.text, this.pending = false});
  final String role; // 'user' | 'assistant'
  final String text;
  final bool pending;
}

class SoniaChatScreen extends StatefulWidget {
  const SoniaChatScreen({
    super.key,
    required this.scenario,
    required this.targetLanguage,
    required this.nativeLanguage,
    this.voiceKey = 'female',
  });
  final String scenario;
  final String targetLanguage;
  final String nativeLanguage;
  final String voiceKey;

  @override
  State<SoniaChatScreen> createState() => _SoniaChatScreenState();
}

class _SoniaChatScreenState extends State<SoniaChatScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String? _sessionId;
  bool _loading = true;
  bool _sending = false;
  bool _soniaTyping = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await LectureService.instance.startSoniaChat(
        scenario: widget.scenario,
        nativeLanguage: widget.nativeLanguage,
        targetLanguage: widget.targetLanguage,
      );
      _sessionId = result['session_id'] as String?;
      final opening = (result['opening_reply'] as String? ?? '').trim();
      if (mounted) {
        setState(() {
          if (opening.isNotEmpty) {
            _messages.add(_ChatMessage(role: 'assistant', text: opening));
          }
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not start chat. Pull down to retry.';
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || _sessionId == null) return;
    _input.clear();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _sending = true;
      _soniaTyping = true;
      _error = null;
    });
    _scrollToBottom();
    try {
      final result = await LectureService.instance.sendSoniaMessage(
        sessionId: _sessionId!,
        text: text,
      );
      final reply = (result['reply'] as String? ?? '').trim();
      if (mounted) {
        setState(() {
          if (reply.isNotEmpty) {
            _messages.add(_ChatMessage(role: 'assistant', text: reply));
          }
          _sending = false;
          _soniaTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _soniaTyping = false;
          _error = 'Message failed to send. Try again.';
        });
      }
    }
  }

  Future<void> _endChat() async {
    final id = _sessionId;
    if (id != null) {
      unawaited(LectureService.instance.endSoniaChat(sessionId: id));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMunna = widget.voiceKey == 'male';
    final personaName = isMunna ? 'Munna' : 'Sonia';
    final avatarPath = isMunna
        ? '/images/munna_avatar.png'
        : '/images/sonia_avatar.png';
    final bg = isDark ? const Color(0xFF0B0B12) : const Color(0xFFECE5FF);
    final bubbleBgOther = isDark ? const Color(0xFF20202A) : Colors.white;
    final bubbleBgMine = _violet;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildWhatsAppStyleHeader(context, isDark, personaName, avatarPath),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              color: Colors.red.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _violet))
                : RefreshIndicator(
                    onRefresh: _start,
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                      itemCount: _messages.length + (_soniaTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _soniaTyping) {
                          return _typingBubble(bubbleBgOther, isDark);
                        }
                        final m = _messages[index];
                        final mine = m.role == 'user';
                        return _bubble(
                          text: m.text,
                          mine: mine,
                          bgMine: bubbleBgMine,
                          bgOther: bubbleBgOther,
                          isDark: isDark,
                        );
                      },
                    ),
                  ),
          ),
          _buildInputBar(isDark, personaName),
        ],
      ),
    );
  }

    PreferredSizeWidget _buildWhatsAppStyleHeader(
    BuildContext context,
    bool isDark,
    String personaName,
    String avatarPath,
  ) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF15121F) : _violet,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: _endChat,
      ),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.4),
            ),
            child: ClipOval(
              child: Image.network(
                avatarPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white24,
                  alignment: Alignment.center,
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  personaName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _soniaTyping ? '$personaName is typing…' : widget.scenario,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: _endChat,
          tooltip: 'End chat',
        ),
      ],
    );
  }

  Widget _bubble({
    required String text,
    required bool mine,
    required Color bgMine,
    required Color bgOther,
    required bool isDark,
  }) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? bgMine : bgOther,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: mine
                ? Colors.white
                : (isDark ? Colors.white : const Color(0xFF232323)),
            fontSize: 14.5,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _typingBubble(Color bgOther, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgOther,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: SizedBox(
          width: 32,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _Dot(delay: i * 200),
              );
            }),
          ),
        ),
      ),
    );
  }

    Widget _buildInputBar(bool isDark, String personaName) {
    final charCount = _input.text.length;
    const maxChars = 200;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C24) : const Color(0xFFF1EFF7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF2E2E38) : const Color(0xFFE2DEF0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 6,
                  maxLength: maxChars,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                        hintText: 'Message $personaName…',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : const Color(0xFFA09CB5),
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(width: 6),
                  Text(
                    '$charCount/$maxChars',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: charCount >= maxChars
                          ? Colors.redAccent
                          : (isDark ? Colors.white38 : const Color(0xFFA09CB5)),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _input.text.trim().isEmpty ? Colors.grey.shade400 : _violet,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: (_sending || _input.text.trim().isEmpty) ? null : _send,
                          child: _sending
                              ? const Padding(
                                  padding: EdgeInsets.all(11),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});
  final int delay;
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();
  late final Animation<double> _anim = Tween<double>(begin: 0.3, end: 1.0)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _violet,
        ),
      ),
    );
  }
}