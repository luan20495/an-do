import 'package:an_do/core/i18n/strings.dart';
import 'package:an_do/core/theme/app_theme.dart';
import 'package:an_do/features/report/data/road_hazard_repository.dart';
import 'package:an_do/features/sos/domain/sos_models.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

sealed class MapSearchResult {}

class SosSearchHit extends MapSearchResult {
  SosSearchHit(this.session);
  final SosSession session;
}

class HazardSearchHit extends MapSearchResult {
  HazardSearchHit(this.hazard);
  final RoadHazard hazard;
}

enum MapFocusKind { nearestSos, allSos, hazards, overview }

class MapFocusResult extends MapSearchResult {
  MapFocusResult(this.kind);
  final MapFocusKind kind;
}

Future<MapSearchResult?> showMapSearchSheet({
  required BuildContext context,
  required List<SosSession> sessions,
  required List<RoadHazard> hazards,
  required LatLng origin,
}) {
  return showModalBottomSheet<MapSearchResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _MapSearchSheet(
      sessions: sessions,
      hazards: hazards,
      origin: origin,
    ),
  );
}

class _MapSearchSheet extends StatefulWidget {
  const _MapSearchSheet({
    required this.sessions,
    required this.hazards,
    required this.origin,
  });

  final List<SosSession> sessions;
  final List<RoadHazard> hazards;
  final LatLng origin;

  @override
  State<_MapSearchSheet> createState() => _MapSearchSheetState();
}

class _MapSearchSheetState extends State<_MapSearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _distanceMeters(double lat, double lng) => Geolocator.distanceBetween(
        widget.origin.latitude,
        widget.origin.longitude,
        lat,
        lng,
      );

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _normalize(String raw) {
    var q = raw.trim().toUpperCase();
    q = q.replaceAll('AĐ-', 'AD-').replaceAll('AĐ', 'AD');
    q = q.replaceAll(RegExp(r'[\s_]'), '');
    return q;
  }

  bool _matchesSession(SosSession session, String raw) {
    if (raw.isEmpty) return true;
    final lower = raw.toLowerCase();
    final id = _normalize(session.id);
    final q = _normalize(raw);
    return id.contains(q) ||
        session.description.toLowerCase().contains(lower) ||
        session.type.toLowerCase().contains(lower) ||
        session.profile.name.toLowerCase().contains(lower);
  }

  bool _matchesHazard(RoadHazard hazard, String raw) {
    if (raw.isEmpty) return true;
    final lower = raw.toLowerCase();
    return hazard.label.toLowerCase().contains(lower) ||
        hazard.type.toLowerCase().contains(lower) ||
        hazard.id.toLowerCase().contains(lower);
  }

  List<SosSession> get _sortedSessions {
    final list = widget.sessions
        .where((s) => _matchesSession(s, _query))
        .toList()
      ..sort(
        (a, b) => _distanceMeters(a.latitude, a.longitude).compareTo(
          _distanceMeters(b.latitude, b.longitude),
        ),
      );
    return list;
  }

  List<RoadHazard> get _filteredHazards {
    return widget.hazards.where((h) => _matchesHazard(h, _query)).toList()
      ..sort(
        (a, b) => _distanceMeters(a.latitude, a.longitude).compareTo(
          _distanceMeters(b.latitude, b.longitude),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final strings = S(context);
    final sessions = _sortedSessions;
    final hazards = _filteredHazards;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: SizedBox(
          height: maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.focusTitle,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                strings.focusSubtitle,
                style: const TextStyle(color: Colors.black54, height: 1.35),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FocusChip(
                    icon: Icons.near_me_rounded,
                    label: strings.focusNearest,
                    enabled: widget.sessions.isNotEmpty,
                    onTap: () => Navigator.pop(
                      context,
                      MapFocusResult(MapFocusKind.nearestSos),
                    ),
                  ),
                  _FocusChip(
                    icon: Icons.sos,
                    label: strings.focusAllSos,
                    enabled: widget.sessions.isNotEmpty,
                    onTap: () => Navigator.pop(
                      context,
                      MapFocusResult(MapFocusKind.allSos),
                    ),
                  ),
                  _FocusChip(
                    icon: Icons.warning_amber_rounded,
                    label: strings.focusHazards,
                    enabled: widget.hazards.isNotEmpty,
                    onTap: () => Navigator.pop(
                      context,
                      MapFocusResult(MapFocusKind.hazards),
                    ),
                  ),
                  _FocusChip(
                    icon: Icons.zoom_out_map_rounded,
                    label: strings.focusOverview,
                    enabled:
                        widget.sessions.isNotEmpty || widget.hazards.isNotEmpty,
                    onTap: () => Navigator.pop(
                      context,
                      MapFocusResult(MapFocusKind.overview),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.filter_list_rounded),
                  hintText: strings.focusFilterHint,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      strings.activeSosList(widget.sessions.length),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (sessions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          _query.isEmpty
                              ? strings.noActiveSos
                              : strings.searchNotFound,
                          style: const TextStyle(color: Colors.black45),
                        ),
                      )
                    else
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
                            '${strings.sosType(session.type)} · '
                            '${_formatDistance(_distanceMeters(session.latitude, session.longitude))}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              Navigator.pop(context, SosSearchHit(session)),
                        ),
                    if (hazards.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        strings.roadAlertsList(widget.hazards.length),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final hazard in hazards)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFFF1D6),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.warning,
                            ),
                          ),
                          title: Text(
                            hazard.label,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${strings.hazardType(hazard.type)} · '
                            '${_formatDistance(_distanceMeters(hazard.latitude, hazard.longitude))}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              Navigator.pop(context, HazardSearchHit(hazard)),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusChip extends StatelessWidget {
  const _FocusChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      selected: false,
      showCheckmark: false,
      onSelected: enabled ? (_) => onTap() : null,
    );
  }
}
