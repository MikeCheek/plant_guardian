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

  // UI state that can be modified by tools
  String _appTitle = '🌿 Plant Guardian';
  Color _bgColor = Colors.white;

  @override
  void initState() {
    super.initState();

    // Initialize the model (fire-and-forget). ask(...) will ensure init if needed.
    _agent.init();

    // After first frame, give the agent a BuildContext so its built-in show_alert can work.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _agent.uiContext = context;
    });

    // Register handlers so tools can actually change app UI.
    _agent.registerToolHandler('change_app_title', (args) async {
      final title = args['title']?.toString() ?? '';
      if (mounted) {
        setState(() {
          _appTitle = title.isNotEmpty ? title : _appTitle;
        });
      }
      return {'message': 'App title changed to "$_appTitle".'};
    });

    _agent.registerToolHandler('change_background_color', (args) async {
      final colorName = args['color']?.toString() ?? '';
      final color = _colorFromName(colorName);
      if (mounted) {
        setState(() {
          _bgColor = color;
        });
      }
      return {'message': 'Background color changed to "$colorName".'};
    });

    // Note: show_alert is implemented inside AIAgent and will use uiContext if provided.
  }

  @override
  void dispose() {
    // AIAgent no longer exposes close(); just dispose the controller.
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
      _controller.clear();
    });

    final reply = await _agent.ask(text);
    setState(() {
      _messages.add({'role': 'bot', 'content': reply});
      _isLoading = false;
    });
  }

  Color _colorFromName(String name) {
    switch (name.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow;
      case 'purple':
        return Colors.purple;
      case 'orange':
        return Colors.orange;
      case 'black':
        return Colors.black;
      case 'grey':
      case 'gray':
        return Colors.grey;
      case 'white':
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_appTitle)),
      backgroundColor: _bgColor,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                return MessageBubble(
                  text: msg['content']!,
                  isUser: msg['role'] == 'user',
                );
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
                      hintText: 'Ask about your plants...',
                    ),
                    onSubmitted: (_) => _sendMessage(),
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
