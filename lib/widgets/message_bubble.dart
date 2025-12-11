import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = text.replaceAll('\\n', '\n');

    // Base text style used for normal text (respects theme & user)
    final baseStyle =
        theme.textTheme.bodyMedium?.copyWith(
          color: isUser
              ? Colors.black
              : (theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black),
          height: 1.4,
        ) ??
        TextStyle(
          color: isUser
              ? Colors.black
              : (theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black),
          height: 1.4,
        );

    // Style for links
    final linkStyle = baseStyle.copyWith(
      color: Colors.blue,
      decoration: TextDecoration.underline,
    );

    // Regex for inline elements: markdown link [label](url) or bold **text**
    final inlinePattern = RegExp(
      r'\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)|\*\*([^*]+)\*\*',
    );

    // Regex to detect list items like "*  something" or "- something" or "+ something"
    final listItemPattern = RegExp(r'^\s*([*\-\+])\s*(.*)$');

    List<TextSpan> spans = [];

    // Process content line by line so we can format lists nicely
    final lines = content.split('\n');
    for (var li = 0; li < lines.length; li++) {
      final line = lines[li];
      String segment = line;

      final listMatch = listItemPattern.firstMatch(line);
      if (listMatch != null) {
        segment = listMatch.group(2) ?? '';
        // Add bullet prefix
        spans.add(TextSpan(text: '• ', style: baseStyle));
      }

      // Parse inline elements within the segment
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
          // It's a link: [label](url)
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
          // Bold text: **text**
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

      // Add newline for all lines except the last one
      if (li != lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
    }

    return FadeSlideBubble(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: isUser
                ? Colors.green.shade300
                : theme.brightness == Brightness.dark
                ? Colors.grey.shade800
                : Colors.grey.shade300,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: isUser
                  ? const Radius.circular(14)
                  : const Radius.circular(0),
              bottomRight: isUser
                  ? const Radius.circular(0)
                  : const Radius.circular(14),
            ),
          ),
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: RichText(
                  text: TextSpan(style: baseStyle, children: spans),
                ),
              ),
              if (isTyping)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: BlinkingCursor(
                    color: isUser ? Colors.black : Colors.blue,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small blinking cursor widget to simulate “typing” animation.
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
    duration: const Duration(milliseconds: 600),
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
      child: Text(
        '|',
        style: TextStyle(color: widget.color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
