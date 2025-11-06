import 'package:flutter/material.dart';
import '../services/ai_agent.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final AIAgent _agent = AIAgent();
  bool _isLoading = false;
  String _currentBotText = ''; // for typing effect

  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom({
    Duration duration = const Duration(milliseconds: 250),
  }) {
    // ensure layout is complete before trying to scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final bottom = _scrollController.position.maxScrollExtent;
      try {
        _scrollController.animateTo(
          bottom,
          duration: duration,
          curve: Curves.easeOut,
        );
      } catch (_) {
        // fallback if animateTo fails for any reason
        _scrollController.jumpTo(bottom);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _agent.init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _agent.uiContext = context;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Sends the user message and streams the AI’s response with typing effect.
  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
      _controller.clear();
    });

    await _agent.ask(
      text,
      onThinking: (status) {
        setState(() {
          _currentBotText = status;
          _scrollToBottom();
        });
      },
      onPartialResponse: (partial) {
        setState(() {
          _currentBotText = partial;
        });
        _scrollToBottom();
      },
      onCompleted: (finalText) {
        setState(() {
          _messages.add({'role': 'bot', 'content': finalText});
          _isLoading = false;
          _currentBotText = '';
          _scrollToBottom();
        });
      },
      onError: (error) {
        setState(() {
          _messages.add({'role': 'bot', 'content': error});
          _isLoading = false;
          _currentBotText = '';
          _scrollToBottom();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount:
                  _messages.length + (_currentBotText.isNotEmpty ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i < _messages.length) {
                  final msg = _messages[i];
                  return MessageBubble(
                    text: msg['content']!,
                    isUser: msg['role'] == 'user',
                  );
                } else {
                  // The "thinking" or typing message being built live
                  return MessageBubble(
                    text: _currentBotText,
                    isUser: false,
                    isTyping: true, // optional param if you animate cursor
                  );
                }
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask the AI...',
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
