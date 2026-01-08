import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import 'package:url_launcher/url_launcher.dart';
import 'fadeslide_bubble.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isTyping;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.isTyping = false,
  });

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = text.replaceAll('\\n', '\n');

    final baseStyle =
        theme.textTheme.bodyMedium?.copyWith(
          color: isUser
              ? Colors.black87
              : (theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87),
          height: 1.4,
          fontSize: 15,
        ) ??
        const TextStyle(height: 1.4, fontSize: 15);

    final linkStyle = baseStyle.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    final inlinePattern = RegExp(
      r'\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)|\*\*([^*]+)\*\*',
    );
    final listItemPattern = RegExp(r'^\s*([*\-\+])\s*(.*)$');

    List<InlineSpan> spans = [];

    final lines = content.split('\n');
    for (var li = 0; li < lines.length; li++) {
      final line = lines[li];
      String segment = line;

      final listMatch = listItemPattern.firstMatch(line);
      if (listMatch != null) {
        segment = listMatch.group(2) ?? '';
        spans.add(
          TextSpan(
            text: ' • ',
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      }

      int lastEnd = 0;
      for (final match in inlinePattern.allMatches(segment)) {
        if (match.start > lastEnd) {
          spans.add(
            TextSpan(
              text: segment.substring(lastEnd, match.start),
              style: baseStyle,
            ),
          );
        }

        if (match.group(1) != null && match.group(2) != null) {
          final label = match.group(1)!;
          final url = match.group(2)!;
          spans.add(
            TextSpan(
              text: label,
              style: linkStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
            ),
          );
        } else if (match.group(3) != null) {
          final boldText = match.group(3)!;
          spans.add(
            TextSpan(
              text: boldText,
              style: baseStyle.copyWith(fontWeight: FontWeight.bold),
            ),
          );
        }
        lastEnd = match.end;
      }

      if (lastEnd < segment.length) {
        spans.add(TextSpan(text: segment.substring(lastEnd), style: baseStyle));
      }

      if (li != lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
    }

    // 1. ADD CURSOR AS A SPAN (Moves with text)
    if (isTyping) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: BlinkingCursor(
            color: isUser ? Colors.black54 : theme.colorScheme.primary,
          ),
        ),
      );
    }

    return FadeSlideBubble(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: () => _copyToClipboard(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 2),
                    bottomRight: Radius.circular(isUser ? 2 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: RichText(text: TextSpan(children: spans)),
              ),
            ),
            // 2. OPTIONAL: SMALL COPY BUTTON FOR BOT RESPONSES
            if (!isUser && !isTyping && text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: InkWell(
                  onTap: () => _copyToClipboard(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: theme.hintColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BlinkingCursor extends StatefulWidget {
  final Color color;
  const BlinkingCursor({super.key, required this.color});

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 16,
        margin: const EdgeInsets.only(left: 2),
        color: widget.color,
      ),
    );
  }
}
