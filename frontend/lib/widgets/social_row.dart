import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SocialRow extends StatelessWidget {
  final Color fill;
  const SocialRow({super.key, this.fill = AppColors.card});

  void _soon(BuildContext c) => ScaffoldMessenger.of(c).showSnackBar(
        const SnackBar(content: Text('Social login coming soon')),
      );

  @override
  Widget build(BuildContext context) {
    Widget btn(Widget child) => Expanded(
          child: Material(
            color: fill,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _soon(context),
              child: SizedBox(height: 56, child: Center(child: child)),
            ),
          ),
        );
    return Row(
      children: [
        btn(const Text('G',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4285F4)))),
        const SizedBox(width: 12),
        btn(const Icon(Icons.apple, size: 28, color: Colors.black)),
        const SizedBox(width: 12),
        btn(const Icon(Icons.facebook, size: 28, color: Color(0xFF1877F2))),
      ],
    );
  }
}
