import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class LoginLink extends StatelessWidget {
  final VoidCallback onTap;
  const LoginLink({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Already have an account? ',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        GestureDetector(
          onTap: onTap,
          child: const Text('Log In',
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
