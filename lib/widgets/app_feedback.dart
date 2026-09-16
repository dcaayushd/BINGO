import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppDialogAction<T> {
  const AppDialogAction({
    required this.label,
    required this.value,
    this.isDefault = false,
    this.isDestructive = false,
  });

  final String label;
  final T value;
  final bool isDefault;
  final bool isDestructive;
}

Future<T?> showAppChoiceDialog<T>(
  BuildContext context, {
  required Widget title,
  required Widget content,
  required List<AppDialogAction<T>> actions,
  bool barrierDismissible = false,
}) {
  final platform = Theme.of(context).platform;
  final isCupertino =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  if (isCupertino) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: title,
        content: content,
        actions: [
          for (final action in actions)
            CupertinoDialogAction(
              isDefaultAction: action.isDefault,
              isDestructiveAction: action.isDestructive,
              onPressed: () => Navigator.of(dialogContext).pop(action.value),
              child: Text(action.label),
            ),
        ],
      ),
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => AlertDialog(
      title: title,
      content: content,
      actions: [
        for (final action in actions)
          action.isDefault
              ? FilledButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(action.value),
                  child: Text(action.label),
                )
              : TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(action.value),
                  child: Text(action.label),
                ),
      ],
    ),
  );
}

/// A lightweight, Cupertino-inspired toast that does not depend on a Material
/// Scaffold. Only one message is shown at a time, so validation feedback never
/// stacks over a newer message.
void showAppToast(BuildContext context, String message) {
  _AppToastHost.dismissActive();
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (toastContext) => Positioned(
      left: 20,
      right: 20,
      bottom: math.max(
            MediaQuery.viewPaddingOf(toastContext).bottom,
            MediaQuery.viewInsetsOf(toastContext).bottom,
          ) +
          20,
      child: IgnorePointer(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _AppToastSurface(
              message: message,
              onDismissed: () {
                if (identical(_AppToastHost.activeEntry, entry)) {
                  _AppToastHost.activeEntry = null;
                }
                if (entry.mounted) entry.remove();
              },
            ),
          ),
        ),
      ),
    ),
  );
  _AppToastHost.activeEntry = entry;
  overlay.insert(entry);
}

class _AppToastHost {
  static OverlayEntry? activeEntry;

  static void dismissActive() {
    final entry = activeEntry;
    activeEntry = null;
    if (entry?.mounted ?? false) entry!.remove();
  }
}

class _AppToastSurface extends StatefulWidget {
  const _AppToastSurface({required this.message, required this.onDismissed});

  final String message;
  final VoidCallback onDismissed;

  @override
  State<_AppToastSurface> createState() => _AppToastSurfaceState();
}

class _AppToastSurfaceState extends State<_AppToastSurface> {
  static const _transitionDuration = Duration(milliseconds: 180);
  Timer? _dismissTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    _dismissTimer = Timer(const Duration(seconds: 2), _dismiss);
  }

  void _dismiss() {
    if (!mounted || !_visible) return;
    setState(() => _visible = false);
    _dismissTimer = Timer(_transitionDuration, widget.onDismissed);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? const Color(0xF0143247) : const Color(0xFAF8FBFC);
    final textColor =
        isDark ? const Color(0xFFF5FAFC) : const Color(0xFF102A43);
    final borderColor =
        isDark ? const Color(0x3376D6CF) : const Color(0x1F102A43);

    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, .12),
      duration: _transitionDuration,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: _transitionDuration,
        curve: Curves.easeOut,
        child: Semantics(
          container: true,
          liveRegion: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3D061C2C),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.info_circle_fill,
                    color: isDark
                        ? const Color(0xFF9CE3DE)
                        : const Color(0xFF087E8B),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        inherit: false,
                        color: textColor,
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
