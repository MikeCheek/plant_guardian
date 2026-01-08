import 'package:flutter/material.dart';
// import '../services/ai_agent.dart';
import '../services/llm.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final OnnxInferenceLLM _agent = OnnxInferenceLLM();

  bool _isLoading = false; // Tracks if AI is currently generating
  bool _isIsolateReady = false; // Tracks if the Isolate & Model are loaded

  final ValueNotifier<String> _liveResponse = ValueNotifier<String>('');
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeLLM(); // Start the heavy lifting immediately
  }

  Future<void> _initializeLLM() async {
    try {
      await _agent.init();
      setState(() {
        _isIsolateReady = true;
      });
    } catch (e) {
      debugPrint("Init Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error initializing AI model: $e")),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      // Use jumpTo during active streaming for maximum performance
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

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
        _liveResponse.value = status; // Update notifier
        _scrollToBottom();
      },
      onPartialResponse: (partial) {
        _liveResponse.value = partial; // Update notifier (No setState here!)
        _scrollToBottom();
      },
      onCompleted: (finalText) {
        setState(() {
          _messages.add({'role': 'bot', 'content': finalText});
          _liveResponse.value = 'Sorry, I did not get that.';
          _isLoading = false;
        });
        _scrollToBottom();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // If the background thread isn't ready, show the spinner
    if (!_isIsolateReady) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Starting AI Engine..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length + 1,
              itemBuilder: (ctx, i) {
                if (i < _messages.length) {
                  final msg = _messages[i];
                  return MessageBubble(
                    text: msg['content']!,
                    isUser: msg['role'] == 'user',
                  );
                } else {
                  return ValueListenableBuilder<String>(
                    valueListenable: _liveResponse,
                    builder: (context, text, _) {
                      if (text.isEmpty && !_isLoading)
                        return const SizedBox.shrink();
                      return MessageBubble(
                        text: text,
                        isUser: false,
                        isTyping: true,
                      );
                    },
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
