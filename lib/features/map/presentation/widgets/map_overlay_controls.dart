import 'package:an_do/core/i18n/strings.dart';
import 'package:an_do/core/routing/route_models.dart';
import 'package:an_do/core/theme/app_theme.dart';
import 'package:an_do/features/report/data/road_hazard_repository.dart';
import 'package:an_do/features/sos/domain/sos_models.dart';
import 'package:flutter/material.dart';

/// Single urgent action: red SOS on the bottom-left.
class MapActionDock extends StatelessWidget {
  const MapActionDock({
    required this.onSos,
    super.key,
  });

  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SosFab(onPressed: onSos),
        ),
      ),
    );
  }
}

class SosFab extends StatelessWidget {
  const SosFab({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.danger,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: AppTheme.danger.withValues(alpha: .4),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact detail panel shown only after tapping a SOS marker / list item.
class SosDetailPanel extends StatelessWidget {
  const SosDetailPanel({
    required this.session,
    required this.routes,
    required this.loadingRoutes,
    required this.onClose,
    required this.onAccept,
    required this.onCompass,
    required this.onRouteSelected,
    super.key,
  });

  final SosSession session;
  final List<RescueRoute> routes;
  final bool loadingRoutes;
  final VoidCallback onClose;
  final VoidCallback onAccept;
  final VoidCallback onCompass;
  final ValueChanged<RescueRoute> onRouteSelected;

  @override
  Widget build(BuildContext context) {
    final strings = S(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Material(
            color: Colors.white.withValues(alpha: .98),
            elevation: 16,
            shadowColor: Colors.black38,
            borderRadius: BorderRadius.circular(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.46,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE7E9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.sos,
                            color: AppTheme.danger,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SOS ${session.id}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '${strings.sosType(session.type)} · '
                                '${session.peopleCount} người · '
                                'GPS ±${session.accuracyMeters.toStringAsFixed(0)} m',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: strings.clearSelection,
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    if (session.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        session.description,
                        style: const TextStyle(height: 1.35),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onAccept,
                            icon: const Icon(Icons.volunteer_activism_outlined),
                            label: Text(strings.helpThis),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          onPressed: onCompass,
                          tooltip: strings.compass,
                          icon: const Icon(Icons.explore_outlined),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(52, 52),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      strings.routes,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    if (loadingRoutes)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (routes.isEmpty)
                      const Text(
                        'Chưa có tuyến đường phù hợp.',
                        style: TextStyle(color: Colors.black54),
                      )
                    else
                      ...routes.map(
                        (route) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => onRouteSelected(route),
                            borderRadius: BorderRadius.circular(14),
                            child: Ink(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F7F5),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 5,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppTheme.brand,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          route.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          '${(route.distanceMeters / 1000).toStringAsFixed(1)} km · '
                                          '${(route.durationSeconds / 60).round()} phút · '
                                          'rủi ro ${route.riskScore}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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

Future<SosSession?> showNearbySosPicker({
  required BuildContext context,
  required List<SosSession> sessions,
}) {
  final strings = S(context);
  return showModalBottomSheet<SosSession>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            strings.nearby,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Chạm một ca để xem trên bản đồ.',
            style: TextStyle(color: Colors.black.withValues(alpha: .55)),
          ),
          const SizedBox(height: 12),
          for (final session in sessions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFE7E9),
                child: Icon(Icons.sos, color: AppTheme.danger),
              ),
              title: Text(
                'SOS ${session.id}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${strings.sosType(session.type)} · ${session.peopleCount} người · ${session.description}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.pop(context, session),
            ),
        ],
      );
    },
  );
}

/// Detail panel for yellow road-hazard markers.
class HazardDetailPanel extends StatelessWidget {
  const HazardDetailPanel({
    required this.hazard,
    required this.onClose,
    super.key,
  });

  final RoadHazard hazard;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final strings = S(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Material(
            color: Colors.white.withValues(alpha: .98),
            elevation: 16,
            shadowColor: Colors.black38,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1D6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          strings.roadAlert,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${strings.hazardType(hazard.type)} · ${strings.severityLabel(hazard.severity)}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hazard.label,
                          style: const TextStyle(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: strings.clearSelection,
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
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
