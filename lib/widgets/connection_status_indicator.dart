import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:railway_secretariat/core/providers/connection_status_provider.dart';

/// Compact widget that shows the current server connection status.
///
/// Place this in the AppBar or NavigationRail to give users a quick
/// visual indication of whether the app is connected to a remote
/// server or running in local-only mode.
///
/// Reads from [ConnectionStatusProvider] so that all instances share
/// a single source of truth (and a single health-check timer).
class ConnectionStatusIndicator extends StatefulWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  State<ConnectionStatusIndicator> createState() =>
      _ConnectionStatusIndicatorState();
}

class _ConnectionStatusIndicatorState extends State<ConnectionStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionStatusProvider>();
    final connState = provider.state;
    final scheme = Theme.of(context).colorScheme;

    final Color dotColor;
    final IconData icon;
    final String tooltip;

    switch (connState) {
      case ServerConnectionState.connected:
        dotColor = const Color(0xFF00C58A);
        icon = Icons.cloud_done_outlined;
        tooltip = '\u0645\u062a\u0635\u0644 \u0628\u0627\u0644\u0633\u064a\u0631\u0641\u0631';
        _glowController.stop();
      case ServerConnectionState.disconnected:
        dotColor = const Color(0xFFD6456A);
        icon = Icons.cloud_off_outlined;
        tooltip = '\u063a\u064a\u0631 \u0645\u062a\u0635\u0644 \u0628\u0627\u0644\u0633\u064a\u0631\u0641\u0631';
        if (!_glowController.isAnimating) {
          _glowController.repeat(reverse: true);
        }
      case ServerConnectionState.checking:
        dotColor = const Color(0xFFFFB74D);
        icon = Icons.sync;
        tooltip = '\u062c\u0627\u0631\u064a \u0641\u062d\u0635 \u0627\u0644\u0627\u062a\u0635\u0627\u0644...';
        _glowController.stop();
      case ServerConnectionState.local:
        dotColor = Colors.grey;
        icon = Icons.smartphone;
        tooltip = '\u0648\u0636\u0639 \u0645\u062d\u0644\u064a (\u0628\u062f\u0648\u0646 \u0633\u064a\u0631\u0641\u0631)';
        _glowController.stop();
      case ServerConnectionState.unknown:
        dotColor = Colors.grey.shade400;
        icon = Icons.help_outline;
        tooltip = '\u062c\u0627\u0631\u064a \u0627\u0644\u062a\u062d\u0645\u064a\u0644...';
        _glowController.stop();
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => provider.checkNow(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  final glowOpacity =
                      connState == ServerConnectionState.disconnected
                          ? 0.3 + (_glowController.value * 0.5)
                          : 1.0;
                  return Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor.withValues(alpha: glowOpacity),
                      boxShadow: [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 18, color: scheme.onSurface.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
