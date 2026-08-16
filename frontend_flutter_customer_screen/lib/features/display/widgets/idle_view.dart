import 'package:flutter/material.dart';

/// Shown while there is no active order — a calm branded empty state that
/// fades/slides in (staggered: icon, then title, then subtitle, then the
/// marquee) so the transition away from a cart doesn't feel abrupt, plus a
/// slow, low-amplitude float on the icon and a continuously scrolling
/// advertisement-style ticker while it waits.
class IdleView extends StatefulWidget {
  const IdleView({super.key});

  @override
  State<IdleView> createState() => _IdleViewState();
}

class _IdleViewState extends State<IdleView> with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  Animation<double> _stagger(double start, double end) {
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _entrance.dispose();
    _float.dispose();
    super.dispose();
  }

  Widget _fadeSlideIn(Animation<double> animation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  double _iconSizeFor(double shortestSide) {
    final double raw = shortestSide * 0.22;
    if (raw < 64) return 64;
    if (raw > 160) return 160;
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> iconAnim = _stagger(0.0, 0.55);
    final Animation<double> titleAnim = _stagger(0.2, 0.7);
    final Animation<double> subtitleAnim = _stagger(0.35, 0.85);
    final Animation<double> waitingAnim = _stagger(0.5, 1.0);
    final double iconSize = _iconSizeFor(MediaQuery.sizeOf(context).shortestSide);

    return Container(
      color: const Color(0xFF1B1F23),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _fadeSlideIn(
                          iconAnim,
                          AnimatedBuilder(
                            animation: _float,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, -6 * _float.value),
                                child: child,
                              );
                            },
                            child: Container(
                              width: iconSize + 32,
                              height: iconSize + 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.shopping_cart_outlined,
                                size: iconSize,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        _fadeSlideIn(
                          titleAnim,
                          const Text(
                            'No Order Yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _fadeSlideIn(
                          subtitleAnim,
                          Text(
                            'Your order will appear here\nwhen items are added.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _fadeSlideIn(
                          waitingAnim,
                          const _Marquee(
                            text: 'Welcome to our store!   •   '
                                'Your order will appear here once items are added.   •   ',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A continuously scrolling, advertisement-style ticker: [text] enters from
/// the right edge, drifts left at a constant speed, and re-enters from the
/// right the instant it fully exits on the left — looping forever with no
/// pause and no bounce. Positioned absolutely inside a clipped box (rather
/// than laid out in a [Row]/[Text]), so it can never trigger a
/// `RenderFlex overflowed` regardless of how long [text] is or how narrow
/// the screen is.
class _Marquee extends StatefulWidget {
  const _Marquee({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee> with SingleTickerProviderStateMixin {
  static const double _pixelsPerSecond = 45;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  double? _lastCycleDistance;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncSpeed(double cycleDistance) {
    if (_lastCycleDistance == cycleDistance) {
      return;
    }
    _lastCycleDistance = cycleDistance;
    final int seconds = (cycleDistance / _pixelsPerSecond).clamp(6, 60).round();
    _controller
      ..duration = Duration(seconds: seconds)
      ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double containerWidth = constraints.maxWidth;
        final double cycleDistance = painter.width + containerWidth;
        _syncSpeed(cycleDistance);

        return ClipRect(
          child: SizedBox(
            width: containerWidth,
            height: painter.height,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final double dx = containerWidth - _controller.value * cycleDistance;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: dx,
                      top: 0,
                      child: Text(
                        widget.text,
                        style: widget.style,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
