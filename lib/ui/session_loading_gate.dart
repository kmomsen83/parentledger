import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';

/// Shown while [CaseContext.sessionReadyForRouter] is false.
/// Includes status copy and a timeout with retry.
class SessionLoadingGate extends StatefulWidget {
  const SessionLoadingGate({super.key});

  @override
  State<SessionLoadingGate> createState() => _SessionLoadingGateState();
}

class _SessionLoadingGateState extends State<SessionLoadingGate>
    with TickerProviderStateMixin {
  static const Duration _timeout = Duration(seconds: 9);
  Timer? _timer;
  bool _timedOut = false;

  late final AnimationController _introController;
  late final Animation<double> _introFade;
  late final Animation<double> _introSlide;

  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  late final AnimationController _rotateController;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    _introFade = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOutCubic,
    );
    _introSlide = Tween<double>(begin: 10, end: 0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: Curves.easeOutCubic,
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutCubic,
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _timer = Timer(_timeout, () {
      if (mounted) setState(() => _timedOut = true);
    });

    _introController.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _introController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  String _title(CaseContext session) {
    if (_timedOut) return 'Still working…';
    return session.userDocLoading
        ? 'Setting up your account'
        : 'Checking subscription';
  }

  String _subtitle(CaseContext session) {
    if (_timedOut) {
      return 'This is taking longer than usual. You can retry or wait a moment.';
    }
    return session.userDocLoading
        ? 'Hang tight — we’re connecting everything'
        : 'Hang tight — we’re syncing your subscription';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();

    return Scaffold(
      backgroundColor: PLDesign.bgBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xff141c2e),
              Color(0xff0c1018),
              Color(0xff080b12),
            ],
            stops: [0.0, 0.52, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_introFade, _introSlide]),
              builder: (context, child) {
                return Opacity(
                  opacity: _introFade.value,
                  child: Transform.translate(
                    offset: Offset(0, _introSlide.value),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SessionPremiumLoader(
                      pulse: _pulse,
                      rotate: _rotateController,
                    ),
                    const SizedBox(height: 26),
                    Text(
                      _title(session),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _subtitle(session),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                      ),
                    ),
                    if (_timedOut) ...[
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: () async {
                          setState(() => _timedOut = false);
                          _timer?.cancel();
                          _timer = Timer(_timeout, () {
                            if (mounted) setState(() => _timedOut = true);
                          });
                          await context.read<CaseContext>().retrySessionLoading();
                        },
                        icon: const Icon(Icons.refresh, size: 20),
                        label: Text(context.tTone('retry')),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: PLDesign.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsing orb with soft radial glow and a slow gradient ring rotation.
class _SessionPremiumLoader extends StatelessWidget {
  const _SessionPremiumLoader({
    required this.pulse,
    required this.rotate,
  });

  final Animation<double> pulse;
  final Animation<double> rotate;

  static const double _orbSize = 72;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: AnimatedBuilder(
        animation: Listenable.merge([pulse, rotate]),
        builder: (context, child) {
          final pulseT = pulse.value;
          final scale = 0.94 + 0.06 * pulseT;
          final glowAlpha = 0.38 + 0.22 * pulseT;
          final blur = 26.0 + 14.0 * pulseT;

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.scale(
                scale: scale * 1.08,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: PLDesign.primary.withValues(alpha: glowAlpha * 0.85),
                        blurRadius: blur,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: PLDesign.info.withValues(alpha: glowAlpha * 0.35),
                        blurRadius: blur * 0.65,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
              Transform.scale(
                scale: scale,
                child: CustomPaint(
                  size: const Size(_orbSize + 14, _orbSize + 14),
                  painter: _GradientRingPainter(
                    rotation: rotate.value * 2 * math.pi,
                  ),
                ),
              ),
              Transform.scale(
                scale: scale,
                child: Container(
                  width: _orbSize - 10,
                  height: _orbSize - 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        PLDesign.primary.withValues(alpha: 0.92),
                        const Color(0xff1a3a62),
                        PLDesign.bgBottom.withValues(alpha: 0.98),
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GradientRingPainter extends CustomPainter {
  _GradientRingPainter({required this.rotation});

  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: rotation,
        endAngle: rotation + math.pi * 2,
        colors: [
          PLDesign.primary.withValues(alpha: 0.05),
          PLDesign.primary,
          PLDesign.info,
          PLDesign.primary.withValues(alpha: 0.05),
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
        transform: GradientRotation(rotation),
      ).createShader(rect);

    const sweep = math.pi * 1.65;
    canvas.drawArc(rect, rotation + 0.35, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientRingPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}
