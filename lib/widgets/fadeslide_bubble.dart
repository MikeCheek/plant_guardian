import 'package:flutter/material.dart';

class FadeSlideBubble extends StatefulWidget {
  final Widget child;
  const FadeSlideBubble({super.key, required this.child});

  @override
  State<FadeSlideBubble> createState() => _FadeSlideBubbleState();
}

class _FadeSlideBubbleState extends State<FadeSlideBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 500), // slower
    vsync: this,
  );

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<double> _scale =
      Tween<double>(
        begin: 0.8, // start slightly smaller like a bubble
        end: 1.0,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      ); // slight pop

  @override
  void initState() {
    super.initState();
    _controller.forward(); // start animation immediately
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}
