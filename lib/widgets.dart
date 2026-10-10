import 'package:flutter/material.dart';

const TextStyle kNoDeco = TextStyle(
  decoration: TextDecoration.none,
  decorationColor: Colors.transparent,
);

// ═══ Animated Background ═══
class AnimatedBackground extends StatelessWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _BlobsPainter(
                    c1: theme.colorScheme.primary.withOpacity(0.22),
                    c2: theme.colorScheme.secondary.withOpacity(0.16),
                    c3: theme.colorScheme.tertiary.withOpacity(0.12),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _BlobsPainter extends CustomPainter {
  final Color c1, c2, c3;
  _BlobsPainter({required this.c1, required this.c2, required this.c3});

  @override
  void paint(Canvas canvas, Size size) {
    _blob(canvas, Offset(size.width * 0.05, size.height * 0.08), 320, c1);
    _blob(canvas, Offset(size.width * 0.95, size.height * 0.42), 360, c2);
    _blob(canvas, Offset(size.width * 0.35, size.height * 0.95), 280, c3);
  }

  void _blob(Canvas canvas, Offset center, double radius, Color color) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(0)],
        stops: const [0.0, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_BlobsPainter old) =>
      old.c1 != c1 || old.c2 != c2 || old.c3 != c3;
}

// ═══ IconBtn ═══
class IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool spinning;
  final Color? color;

  const IconBtn({
    super.key,
    required this.icon,
    this.onTap,
    this.spinning = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withOpacity(0.6),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: spinning
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color ?? theme.colorScheme.primary,
                  ),
                )
              : Icon(
                  icon,
                  size: 20,
                  color: color ?? theme.colorScheme.onSurface,
                ),
        ),
      ),
    );
  }
}

// ═══ Primary Action Button ═══
class PrimaryBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final bool busy;
  final VoidCallback? onTap;

  const PrimaryBtn({
    super.key,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.busy,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: onTap == null
              ? [
                  gradient.first.withOpacity(0.4),
                  gradient.last.withOpacity(0.4),
                ]
              : gradient,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(onTap == null ? 0.1 : 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: kNoDeco.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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

// ═══ Log Panel ═══
class LogPanel extends StatelessWidget {
  final ValueNotifier<List<String>> logs;
  final double height;

  const LogPanel({
    super.key,
    required this.logs,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.terminal_rounded,
                  size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'السجل',
                style: kNoDeco.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: logs,
              builder: (context, list, _) {
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'لا يوجد سجل بعد',
                      style: kNoDeco.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      list[i],
                      style: kNoDeco.copyWith(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══ Warning Box ═══
class WarnBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  const WarnBox({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: kNoDeco.copyWith(color: color, fontSize: 12.5)),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel,
              style: kNoDeco.copyWith(
                  fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}