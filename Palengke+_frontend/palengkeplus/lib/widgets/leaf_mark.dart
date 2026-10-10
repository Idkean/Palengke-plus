import 'package:flutter/material.dart';

class LeafMark extends StatelessWidget {
  final double size;
  final Color color;
  final double rotation;

  const LeafMark({
    super.key,
    required this.size,
    required this.color,
    this.rotation = 0,
  });

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Transform.rotate(
        angle: rotation,
        child: Icon(Icons.eco_outlined, size: size, color: color),
      ),
    ),
  );
}

