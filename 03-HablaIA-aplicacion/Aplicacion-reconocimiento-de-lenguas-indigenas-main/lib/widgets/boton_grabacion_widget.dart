import 'package:flutter/material.dart';

// Widget de controles de grabación, que muestra un botón para iniciar o detener la grabación de audio,
// con un anillo de progreso animado alrededor que se llena durante el minuto de grabación,
// y un cambio de color al presionar el botón.
class ControlesGrabacion extends StatefulWidget {
  final bool grabando;
  final VoidCallback onToggle;

  const ControlesGrabacion({
    super.key,
    required this.grabando,
    required this.onToggle,
  });

  @override
  State<ControlesGrabacion> createState() => _ControlesGrabacionState();
}

class _ControlesGrabacionState extends State<ControlesGrabacion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );
    _controller.addStatusListener(_onAnimationStatusChanged);

    if (widget.grabando) {
      _controller.forward();
    }
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.grabando) {
      widget.onToggle();
    }
  }

  @override
  void didUpdateWidget(ControlesGrabacion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.grabando && !oldWidget.grabando) {
      _controller.forward(from: 0);
    } else if (!widget.grabando && oldWidget.grabando) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),

        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: widget.grabando ? _controller.value : 0,
                      strokeWidth: 6,
                      backgroundColor: widget.grabando
                          ? colorScheme.secondary
                          : colorScheme.primary,
                      valueColor: AlwaysStoppedAnimation(colorScheme.tertiary),
                    ),
                  );
                },
              ),

              SizedBox(
                width: 120,
                height: 120,
                child: ElevatedButton(
                  onPressed: widget.onToggle,
                  style: ButtonStyle(
                    shape: WidgetStateProperty.all(const CircleBorder()),
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                    backgroundColor: WidgetStateProperty.all(
                      widget.grabando
                          ? colorScheme.tertiary
                          : colorScheme.secondary,
                    ),
                    foregroundColor: WidgetStateProperty.all(
                      widget.grabando
                          ? colorScheme.onTertiary
                          : colorScheme.onSecondary,
                    ),
                  ),
                  child: Icon(
                    widget.grabando ? Icons.stop : Icons.mic,
                    color: widget.grabando
                        ? colorScheme.secondary
                        : colorScheme.tertiary,
                    size: 60,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
