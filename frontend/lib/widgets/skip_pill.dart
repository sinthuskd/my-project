import 'package:flutter/material.dart';

class SkipPill extends StatelessWidget {
  final VoidCallback onTap;
  const SkipPill({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(30)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Skip',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            SizedBox(width: 6),
            Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }
}
