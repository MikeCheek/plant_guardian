import 'package:flutter/material.dart';
import '../services/online_agent.dart'; // Import your new OnlineAgent class
import '../widgets/message_bubble.dart';

class ChatScreenOnline extends StatefulWidget {
  const ChatScreenOnline({super.key});

  @override
  State<ChatScreenOnline> createState() => _ChatScreenOnlineState();
}

class _ChatScreenOnlineState extends State<ChatScreenOnline> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];

  // Now using the OnlineAgent that connects to www.example.com
  final OnlineAgent _agent = OnlineAgent();

  bool _isLoading = false;
  bool _isServerReady = false;
  bool _isServerOffline = false;

  final ValueNotifier<String> _liveResponse = ValueNotifier<String>('');
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkServerStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _liveResponse.dispose();
    // If your OnlineAgent has a close/dispose method, call it here
    super.dispose();
  }

  /// Pings the /health endpoint on your Docker server
  Future<void> _checkServerStatus() async {
    try {
      await _agent.init(); // This calls the health check we defined
      if (!mounted) return;
      setState(() {
        _isServerReady = true;
        _isServerOffline = false;
      });
    } catch (e) {
      debugPrint("Server Error: $e");
      // Optional: Retry after 10 seconds if server is still booting the model
      if (!mounted) return;
      Future.delayed(const Duration(seconds: 20), () {
        if (mounted) _checkServerStatus();
      });
      setState(() {
        _isServerOffline = true;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
      _liveResponse.value = ''; // Reset for the new response
      _controller.clear();
    });
    _scrollToBottom();

    await _agent.ask(
      text,
      onThinking: (status) {
        _liveResponse.value = status;
        _scrollToBottom();
      },
      onPartialResponse: (partial) {
        _liveResponse.value = partial;
        _scrollToBottom();
      },
      onCompleted: (finalText) {
        setState(() {
          _messages.add({'role': 'bot', 'content': finalText});
          _liveResponse.value = ''; // Clear the live notifier
          _isLoading = false;
        });
        _scrollToBottom();
      },
      onError: (error) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isServerOffline) {
      return const Scaffold(
        body: Center(
          child: Text(
            "💤 The GreenThumb Engine is currently offline.\nTry again later.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // Show loading screen while the remote GPU is loading the model
    if (!_isServerReady) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Connecting to GreenThumb Engine..."),
              Text(
                "(The model is warming up on the GPU)",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
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
                      if (text.isEmpty) return const SizedBox.shrink();
                      return MessageBubble(
                        text: text,
                        isUser: false,
                        isTyping: _isLoading,
                      );
                    },
                  );
                }
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Ask about your plants...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
