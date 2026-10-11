import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_colors.dart';

/* ---------------- formatting ---------------- */

String lkr(num? v) {
  final n = (v ?? 0).round();
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return 'LKR ${n < 0 ? '-' : ''}$buf';
}

String two(int n) => n.toString().padLeft(2, '0');
String ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
DateTime parseYmd(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String prettyDate(DateTime d) => '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

String hm(TimeOfDay t) => '${two(t.hour)}:${two(t.minute)}';
TimeOfDay parseHm(String s) {
  final p = s.split(':');
  final h = int.tryParse(p[0]) ?? 0;
  return TimeOfDay(hour: h >= 24 ? 23 : h, minute: int.tryParse(p[1]) ?? 0);
}

/// Midnight as an end time means "end of the day" for the backend.
String endOf(String t) => t == '00:00' ? '24:00' : t;

List<String> splitLines(String s) =>
    s.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
List<String> splitCsv(String s) =>
    s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

/* ---------------- feedback ---------------- */

void toast(BuildContext context, String msg, {bool error = false}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? AppColors.danger : null,
  ));
}

/// Runs [fn]; shows the error (or [ok] message) and returns true on success.
Future<bool> runAction(BuildContext context, Future<void> Function() fn,
    {String? ok}) async {
  try {
    await fn();
    if (context.mounted && ok != null) toast(context, ok);
    return true;
  } on AdminApiException catch (e) {
    if (context.mounted) toast(context, e.message, error: true);
    return false;
  } catch (e) {
    if (context.mounted) toast(context, 'Something went wrong: $e', error: true);
    return false;
  }
}

Future<bool> confirmDialog(BuildContext context,
    {required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r == true;
}

/* ---------------- layout pieces ---------------- */

PreferredSizeWidget adminAppBar(String title, {List<Widget>? actions}) => AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      actions: actions,
    );

class AdminCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const AdminCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}

class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  const StatusChip(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

Color statusColor(String s) {
  switch (s) {
    case 'open':
    case 'confirmed':
    case 'paid':
      return AppColors.success;
    case 'booked':
      return AppColors.primary;
    case 'pending':
      return AppColors.warning;
    case 'cancelled':
    case 'refunded':
      return AppColors.danger;
    default:
      return AppColors.disabled; // disabled / expired / completed
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 46, color: AppColors.dotInactive),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
      );
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 44, color: AppColors.danger),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ]),
        ),
      );
}

/// Loads data, shows a spinner / error / the [builder] result. Pull-to-refresh is
/// up to the builder; call the `reload` it receives after a change.
class LoadView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  /// When set, the spinner / error state is wrapped in a Scaffold with this
  /// app bar (for full screens, so the back button is always there).
  final PreferredSizeWidget? stateAppBar;
  const LoadView({super.key, required this.load, required this.builder, this.stateAppBar});

  @override
  State<LoadView<T>> createState() => _LoadViewState<T>();
}

class _LoadViewState<T> extends State<LoadView<T>> {
  T? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (_data == null) setState(() => _loading = true);
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _loading = false;
      });
    } on AdminApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget wrap(Widget w) =>
        widget.stateAppBar == null ? w : Scaffold(appBar: widget.stateAppBar, body: w);
    if (_loading) return wrap(const Center(child: CircularProgressIndicator()));
    if (_data == null) {
      return wrap(ErrorState(message: _error ?? 'Failed to load', onRetry: _reload));
    }
    return widget.builder(context, _data as T, _reload);
  }
}

/* ---------------- form helpers ---------------- */

class FormBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboard;
  final int maxLines;
  final bool enabled;
  final String? Function(String?)? validator;
  const FormBox({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboard,
    this.maxLines = 1,
    this.enabled = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: 1.3),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        enabled: enabled,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintMaxLines: 3,
          filled: true,
          fillColor: Colors.white,
          border: b(AppColors.dotInactive),
          enabledBorder: b(AppColors.dotInactive),
          focusedBorder: b(AppColors.primary),
          errorBorder: b(AppColors.danger),
          focusedErrorBorder: b(AppColors.danger),
        ),
      ),
    );
  }
}

String? requiredField(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
String? numberField(String? v) =>
    (v == null || v.trim().isEmpty || num.tryParse(v.trim()) == null) ? 'Enter a number' : null;
String? optionalNumber(String? v) =>
    (v == null || v.trim().isEmpty || num.tryParse(v.trim()) != null) ? null : 'Enter a number';

/// Full-width save button used at the bottom of the forms.
class SaveButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  const SaveButton({super.key, required this.label, required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27))),
          onPressed: busy ? null : onPressed,
          child: busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      );
}
