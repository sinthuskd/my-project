import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String? trailingLabel;
  final String hint;
  final IconData? icon;
  final Widget? prefix;
  final TextEditingController controller;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.trailingLabel,
    this.icon,
    this.prefix,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: c, width: 1.4),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (trailingLabel != null)
              Text(trailingLabel!,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            prefixIcon: prefix ??
                (icon != null
                    ? Icon(icon, color: AppColors.textSecondary, size: 22)
                    : null),
            suffixIcon: suffix,
            border: border(Colors.transparent),
            enabledBorder: border(Colors.transparent),
            focusedBorder: border(AppColors.primary),
            errorBorder: border(AppColors.danger),
            focusedErrorBorder: border(AppColors.danger),
          ),
        ),
      ],
    );
  }
}
