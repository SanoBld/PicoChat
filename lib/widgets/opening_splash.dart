// lib/widgets/opening_splash.dart
// Short launch animation: the smiley pops in, the name appears, then everything fades out.
import 'package:flutter/material.dart';
import '../app_state.dart';
import 'pico_avatar.dart';

class OpeningGate extends StatefulWidget {
  final Widget child;
  const OpeningGate({super.key, required this.child});

  static bool _played = false; // once per app start

  @override
  State<OpeningGate> createState() => _OpeningGateState();
}

class _OpeningGateState extends State<OpeningGate> {
  late bool _show;

  @override
  void initState() {
    super.initState();
    // Off when the option is off or energy saving is on.
    _show = !OpeningGate._played && openingAnimNotifier.value && !ecoModeNotifier.value;
    OpeningGate._played = true;
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        widget.child,
        if (_show) Positioned.fill(child: _Splash(onDone: () => setState(() => _show = false))),
      ]);
}

class _Splash extends StatefulWidget {
  final VoidCallback onDone;
  const _Splash({required this.onDone});
  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double t, double a, double b, Curve k) => k.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final v = _c.value;
        final pop = _seg(v, 0.0, 0.4, Curves.easeOutBack);
        final title = _seg(v, 0.3, 0.55, Curves.easeOut);
        final out = _seg(v, 0.75, 1.0, Curves.easeInCubic);
        return IgnorePointer(
          ignoring: out > 0.3,
          child: Opacity(
            opacity: 1 - out,
            child: ColoredBox(
              color: s.surface,
              child: Center(
                child: Transform.scale(
                  scale: 1 + 0.25 * out,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Transform.scale(
                      scale: 0.3 + 0.7 * pop,
                      child: Transform.rotate(angle: (1 - pop) * -0.5, child: const PicoAvatar(size: 96)),
                    ),
                    const SizedBox(height: 18),
                    Opacity(
                      opacity: title,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - title)),
                        child: Text('PicoChat', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: s.onSurface)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
