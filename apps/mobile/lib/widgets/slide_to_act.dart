import 'package:flutter/material.dart';

class SlideToAct extends StatefulWidget {
  final VoidCallback onAct;
  final Color trackColor;
  final Color thumbColor;
  final String label;

  const SlideToAct({
    super.key,
    required this.onAct,
    this.trackColor = Colors.grey,
    this.thumbColor = Colors.indigo,
    this.label = 'Slide to confirm',
  });

  @override
  State<SlideToAct> createState() => _SlideToActState();
}

class _SlideToActState extends State<SlideToAct> {
  double _offset = 0.0;
  double _maxOffset = 250.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      width: 300,
      decoration: BoxDecoration(
        color: widget.trackColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              widget.label,
              style: TextStyle(color: widget.trackColor.withValues(alpha: 0.6)),
            ),
          ),
          Positioned(
            left: _offset,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _offset = (_offset + details.delta.dx).clamp(0.0, _maxOffset);
                });
              },
              onHorizontalDragEnd: (details) {
                if (_offset >= _maxOffset * 0.8) {
                  setState(() => _offset = _maxOffset);
                  widget.onAct();
                } else {
                  setState(() => _offset = 0.0);
                }
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: widget.thumbColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_forward, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
