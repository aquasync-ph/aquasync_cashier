import 'package:flutter/material.dart';
import 'package:aquasync_cashier_app/theme.dart';

enum AlertType {
  success,
  error,
  warning,
  info,
}

class TopAlert {
  static void show(
    BuildContext context,
    String message, {
    AlertType type = AlertType.info,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    Color bg;
    Color borderClr;
    Color textClr;
    IconData icon;

    switch (type) {
      case AlertType.success:
        bg = AppColors.successLight;
        borderClr = AppColors.success;
        textClr = const Color(0xFF065F46);
        icon = Icons.check_circle_rounded;
        break;
      case AlertType.error:
        bg = AppColors.dangerLight;
        borderClr = AppColors.danger;
        textClr = const Color(0xFF991B1B);
        icon = Icons.error_rounded;
        break;
      case AlertType.warning:
        bg = AppColors.warningLight;
        borderClr = AppColors.warning;
        textClr = const Color(0xFF92400E);
        icon = Icons.warning_rounded;
        break;
      case AlertType.info:
        bg = AppColors.lightAqua;
        borderClr = AppColors.primary;
        textClr = AppColors.navy;
        icon = Icons.info_rounded;
        break;
    }

    OverlayState? overlayState;
    try {
      overlayState = Overlay.of(context);
    } catch (_) {
      overlayState = null;
    }

    if (overlayState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${title != null ? '$title: ' : ''}$message'),
          backgroundColor: borderClr,
        ),
      );
      return;
    }

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) {
        return _TopAlertWidget(
          title: title,
          message: message,
          backgroundColor: bg,
          borderColor: borderClr,
          textColor: textClr,
          icon: icon,
          duration: duration,
          onDismiss: () {
            if (overlayEntry.mounted) {
              overlayEntry.remove();
            }
          },
        );
      },
    );

    overlayState.insert(overlayEntry);
  }
}

class _TopAlertWidget extends StatefulWidget {
  final String? title;
  final String message;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final IconData icon;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopAlertWidget({
    required this.title,
    required this.message,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.icon,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_TopAlertWidget> createState() => _TopAlertWidgetState();
}

class _TopAlertWidgetState extends State<_TopAlertWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top + 12.0;

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(widget.icon, color: widget.borderColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.title != null && widget.title!.isNotEmpty) ...[
                        Text(
                          widget.title!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: widget.textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.textColor.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _controller.reverse().then((_) => widget.onDismiss());
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.close_rounded, color: widget.textColor.withValues(alpha: 0.6), size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
