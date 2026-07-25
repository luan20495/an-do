import 'dart:async';
import 'dart:io';

import 'package:an_do/core/device/device_identity.dart';
import 'package:an_do/core/firebase/an_do_firebase.dart';
import 'package:an_do/core/i18n/app_language_controller.dart';
import 'package:an_do/core/i18n/strings.dart';
import 'package:an_do/core/location/sos_foreground_service.dart';
import 'package:an_do/core/routing/osrm_client.dart';
import 'package:an_do/core/routing/route_models.dart';
import 'package:an_do/core/theme/app_theme.dart';
import 'package:an_do/features/compass/presentation/compass_page.dart';
import 'package:an_do/features/map/presentation/menu_drawer.dart';
import 'package:an_do/features/map/presentation/widgets/map_overlay_controls.dart';
import 'package:an_do/features/map/presentation/widgets/map_search_sheet.dart';
import 'package:an_do/features/report/data/road_hazard_repository.dart';
import 'package:an_do/features/report/data/road_report_repository.dart';
import 'package:an_do/features/report/domain/road_report.dart';
import 'package:an_do/features/report/presentation/report_form.dart';
import 'package:an_do/features/sos/data/profile_store.dart';
import 'package:an_do/features/sos/data/sos_repository.dart';
import 'package:an_do/features/sos/domain/sos_models.dart';
import 'package:an_do/features/sos/presentation/profile_form.dart';
import 'package:an_do/features/sos/presentation/sos_form.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.language,
    required this.firebaseReady,
    super.key,
  });

  final AppLanguageController language;
  final bool firebaseReady;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  /// Used when GPS is unavailable so demo rescue routes still work.
  static const _demoOrigin = LatLng(21.0285, 105.8542);

  late final SosRepository _sosRepository;
  late final RoadHazardRepository? _hazardRepository;
  final ProfileStore _profileStore = ProfileStore();
  final RoadReportRepository _reportRepository = RoadReportRepository();
  final OsrmClient _routing = OsrmClient();
  final Map<String, SosSession> _symbolSessions = {};
  final Map<String, SosSession> _circleSessions = {};
  final Map<String, RoadHazard> _circleHazards = {};
  final Map<String, RoadHazard> _symbolHazards = {};

  StreamSubscription<List<SosSession>>? _sosSubscription;
  StreamSubscription<List<RoadHazard>>? _hazardSubscription;
  MapLibreMapController? _mapController;
  Position? _position;
  List<SosSession> _sessions = const [];
  List<RoadHazard> _hazards = const [];
  List<RescueRoute> _routes = const [];
  SosSession? _selectedSession;
  RoadHazard? _selectedHazard;
  SosSession? _mySession;
  bool _loadingRoutes = false;
  bool _styleReady = false;
  bool _didFitOverview = false;

  @override
  void initState() {
    super.initState();
    _sosRepository = createSosRepository(firebaseReady: widget.firebaseReady);
    // Road hazards stay local until Firestore sync ships; still useful on Firebase builds.
    _hazardRepository = DemoRoadHazardRepository();
    _sosSubscription = _sosRepository.watchActive().listen((sessions) {
      if (!mounted) return;
      setState(() => _sessions = sessions);
      unawaited(_renderMapOverlays());
    });
    _hazardSubscription = _hazardRepository?.watch().listen((hazards) {
      if (!mounted) return;
      setState(() => _hazards = hazards);
      unawaited(_renderMapOverlays());
    });
    unawaited(_prepareLocation(moveCamera: false));
  }

  @override
  void dispose() {
    _sosSubscription?.cancel();
    _hazardSubscription?.cancel();
    super.dispose();
  }

  LatLng get _origin => _position == null
      ? _demoOrigin
      : LatLng(_position!.latitude, _position!.longitude);

  Future<bool> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showMessage(
          widget.firebaseReady
              ? 'An Đồ cần quyền vị trí để phát SOS.'
              : 'Đang dùng vị trí demo quanh Hồ Gươm (chưa có GPS).',
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _jumpTo(LatLng target, {double zoom = 15}) async {
    final controller = _mapController;
    if (controller == null) return;
    // Instant jump — locate should feel immediate.
    await controller.moveCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  /// Fast locate for the top-bar button: jump now, refine GPS in background.
  Future<void> _goToMyLocation() async {
    if (!await _ensureLocationPermission()) return;

    // 1) Jump immediately to anything we already know.
    final cached = _position;
    final lastKnown = cached == null
        ? await Geolocator.getLastKnownPosition()
        : null;
    final quick = cached ?? lastKnown;
    if (quick != null) {
      if (!mounted) return;
      setState(() => _position = quick);
      await _jumpTo(LatLng(quick.latitude, quick.longitude));
    }

    // 2) Refresh a fresher fix without blocking the first jump.
    try {
      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );
      if (!mounted) return;
      setState(() => _position = fresh);
      await _jumpTo(LatLng(fresh.latitude, fresh.longitude));
    } catch (_) {
      if (quick == null && mounted) {
        _showMessage('Chưa lấy được vị trí GPS.');
      }
    }
  }

  /// Refresh GPS for SOS / report flows (no camera jump required).
  Future<void> _prepareLocation({bool moveCamera = false}) async {
    if (!await _ensureLocationPermission()) return;

    Position? position = _position ?? await Geolocator.getLastKnownPosition();
    if (position != null && mounted) {
      setState(() => _position = position);
      if (moveCamera) {
        await _jumpTo(LatLng(position.latitude, position.longitude));
      }
    }

    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (!mounted) return;
      setState(() => _position = position);
      if (moveCamera) {
        await _jumpTo(LatLng(position.latitude, position.longitude));
      }
    } catch (_) {
      // Keep last-known / demo origin if a fresh fix times out.
    }
  }

  Future<void> _renderMapOverlays() async {
    final controller = _mapController;
    if (controller == null || !_styleReady) return;

    try {
      await controller.clearSymbols();
      await controller.clearCircles();
      _symbolSessions.clear();
      _circleSessions.clear();
      _circleHazards.clear();
      _symbolHazards.clear();

      final points = <LatLng>[];

      for (final session in _sessions) {
        final point = LatLng(session.latitude, session.longitude);
        points.add(point);
        final selected = _selectedSession?.id == session.id;
        final circle = await controller.addCircle(
          CircleOptions(
            geometry: point,
            circleRadius: selected ? 16 : 11,
            circleColor: selected ? '#9F1239' : '#E11D48',
            circleOpacity: 0.92,
            circleStrokeWidth: selected ? 4 : 3,
            circleStrokeColor: '#FFFFFF',
          ),
        );
        _circleSessions[circle.id] = session;
        final symbol = await controller.addSymbol(
          SymbolOptions(
            geometry: point,
            textField: 'SOS ${session.id}',
            textSize: selected ? 14 : 12,
            textColor: '#9F1239',
            textHaloColor: '#FFFFFF',
            textHaloWidth: 1.6,
            textOffset: const Offset(0, 1.9),
            textAnchor: 'top',
          ),
        );
        _symbolSessions[symbol.id] = session;
      }

      for (final hazard in _hazards) {
        final point = LatLng(hazard.latitude, hazard.longitude);
        points.add(point);
        final selected = _selectedHazard?.id == hazard.id;
        final circle = await controller.addCircle(
          CircleOptions(
            geometry: point,
            circleRadius: selected ? 14 : 12,
            circleColor: selected ? '#B45309' : '#D97706',
            circleOpacity: 0.95,
            circleStrokeWidth: selected ? 4 : 3,
            circleStrokeColor: '#FFFFFF',
          ),
        );
        _circleHazards[circle.id] = hazard;
        final symbol = await controller.addSymbol(
          SymbolOptions(
            geometry: point,
            textField: hazard.label,
            textSize: selected ? 13 : 11,
            textColor: '#92400E',
            textHaloColor: '#FFFFFF',
            textHaloWidth: 1.4,
            textOffset: const Offset(0, 1.7),
            textAnchor: 'top',
          ),
        );
        _symbolHazards[symbol.id] = hazard;
      }

      if (!_didFitOverview &&
          _selectedSession == null &&
          _selectedHazard == null &&
          points.length >= 2) {
        _didFitOverview = true;
        await _fitToPoints(points);
      }
    } catch (error) {
      debugPrint('Map overlays skipped: $error');
    }
  }

  Future<void> _fitToPoints(List<LatLng> points) async {
    final controller = _mapController;
    if (controller == null || points.isEmpty) return;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    final latPad = ((maxLat - minLat).abs() * 0.25).clamp(0.01, 0.05);
    final lngPad = ((maxLng - minLng).abs() * 0.25).clamp(0.01, 0.05);
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - latPad, minLng - lngPad),
          northeast: LatLng(maxLat + latPad, maxLng + lngPad),
        ),
        left: 48,
        top: 120,
        right: 48,
        bottom: 120,
      ),
    );
  }

  Future<void> _clearSelection() async {
    setState(() {
      _selectedSession = null;
      _selectedHazard = null;
      _routes = const [];
      _loadingRoutes = false;
    });
    await _mapController?.clearLines();
    await _renderMapOverlays();
  }

  Future<void> _selectHazard(RoadHazard hazard) async {
    setState(() {
      _selectedHazard = hazard;
      _selectedSession = null;
      _routes = const [];
      _loadingRoutes = false;
    });
    await _mapController?.clearLines();
    await _renderMapOverlays();
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(hazard.latitude, hazard.longitude),
        15,
      ),
    );
  }

  Future<void> _selectSession(SosSession session) async {
    setState(() {
      _selectedSession = session;
      _selectedHazard = null;
      _routes = const [];
      _loadingRoutes = true;
    });
    await _renderMapOverlays();
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(session.latitude, session.longitude),
        14.5,
      ),
    );

    final from = _origin;
    try {
      final routes = await _routing.routes(
        from: from,
        to: LatLng(session.latitude, session.longitude),
      );
      if (!mounted) return;
      if (_selectedSession?.id != session.id) return;
      setState(() {
        _routes = routes;
        _loadingRoutes = false;
      });
      if (routes.isNotEmpty) await _drawRoute(routes.first);
    } catch (_) {
      if (!mounted || _selectedSession?.id != session.id) return;
      setState(() => _loadingRoutes = false);
      _showMessage('Không thể tải tuyến đường lúc này.');
    }
  }

  Future<void> _drawRoute(RescueRoute route) async {
    final controller = _mapController;
    if (controller == null || route.points.isEmpty) return;

    await controller.clearLines();
    await controller.addLine(
      LineOptions(
        geometry: route.points,
        lineColor: '#087F65',
        lineWidth: 6,
        lineOpacity: .92,
      ),
    );

    final midpoint = route.points[route.points.length ~/ 2];
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(midpoint, 13.5),
    );
  }

  Future<void> _startSos() async {
    final profile = await _profileStore.read();
    if (!mounted) return;

    final draft = await showModalBottomSheet<SosDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => SosForm(initialProfile: profile),
    );
    if (draft == null) return;

    await _prepareLocation();
    final position = _position;
    final latLng = position == null && !widget.firebaseReady
        ? _demoOrigin
        : position == null
            ? null
            : LatLng(position.latitude, position.longitude);
    if (latLng == null) return;

    final ownerId = widget.firebaseReady
        ? FirebaseAuth.instance.currentUser!.uid
        : await DeviceIdentity.getOrCreate();
    final session = SosSession(
      id: const Uuid().v4().substring(0, 8).toUpperCase(),
      ownerId: ownerId,
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      accuracyMeters: position?.accuracy ?? 15,
      updatedAt: DateTime.now(),
      type: draft.type,
      peopleCount: draft.peopleCount,
      description: draft.description,
      profile: draft.profile,
    );

    await _profileStore.save(draft.profile);
    await _sosRepository.upsert(session);
    await SosForegroundService.start(
      sosId: session.id,
      firebaseEnabled: widget.firebaseReady,
    );

    if (!mounted) return;
    setState(() {
      _mySession = session;
      _selectedSession = session;
    });
  }

  Future<void> _finishSos() async {
    final session = _mySession;
    if (session == null) return;

    await _sosRepository.finish(session.id);
    await SosForegroundService.stop();
    if (!mounted) return;
    setState(() {
      _mySession = null;
      _selectedSession = null;
      _routes = const [];
    });
    await _mapController?.clearLines();
  }

  Future<void> _reportRoad() async {
    await _prepareLocation();
    final latLng = _position == null && !widget.firebaseReady
        ? _demoOrigin
        : _position == null
            ? null
            : LatLng(_position!.latitude, _position!.longitude);
    if (latLng == null || !mounted) return;

    final draft = await showModalBottomSheet<ReportDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => const ReportForm(),
    );
    if (draft == null) return;

    final ownerId = widget.firebaseReady
        ? FirebaseAuth.instance.currentUser!.uid
        : await DeviceIdentity.getOrCreate();
    final report = RoadReport(
      id: const Uuid().v4(),
      ownerId: ownerId,
      type: draft.type,
      severity: draft.severity,
      note: draft.note,
      latitude: latLng.latitude + 0.0035,
      longitude: latLng.longitude - 0.0025,
      createdAt: DateTime.now(),
    );

    try {
      await _reportRepository.submit(
        report,
        draft.photo == null ? null : File(draft.photo!.path),
      );
    } catch (_) {
      // Still show on map even if cloud upload failed / queued.
    }
    await _hazardRepository?.add(
      RoadHazard(
        id: report.id,
        latitude: report.latitude,
        longitude: report.longitude,
        type: report.type,
        label: draft.note.isEmpty ? report.type : draft.note,
        severity: report.severity,
      ),
    );
    if (!mounted) return;
    _showMessage(
      widget.firebaseReady
          ? 'Đã gửi cảnh báo đoạn đường.'
          : 'Đã lưu báo cáo demo trên thiết bị.',
    );
  }

  Future<void> _acceptCase() async {
    final selected = _selectedSession;
    if (selected == null) return;
    final helperId = widget.firebaseReady
        ? FirebaseAuth.instance.currentUser!.uid
        : await DeviceIdentity.getOrCreate();
    if (widget.firebaseReady) {
      await AnDoFirebase.database
          .ref('sos_assignments/${selected.id}/$helperId')
          .set({
        'acceptedAt': ServerValue.timestamp,
        'status': 'heading_to_scene',
      });
    }
    if (mounted) _showMessage('Đã nhận hỗ trợ ca SOS ${selected.id}.');
  }

  Future<void> _call112() async {
    final uri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      _showMessage('Không thể mở ứng dụng gọi điện.');
    }
  }

  void _openCompass() {
    final selected = _selectedSession;
    if (selected == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CompassPage(target: selected),
      ),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _openSearch() async {
    final result = await showMapSearchSheet(
      context: context,
      sessions: _sessions,
      hazards: _hazards,
      origin: _origin,
    );
    if (result == null || !mounted) return;
    switch (result) {
      case SosSearchHit(:final session):
        await _selectSession(session);
      case HazardSearchHit(:final hazard):
        await _selectHazard(hazard);
      case MapFocusResult(:final kind):
        await _applyMapFocus(kind);
    }
  }

  Future<void> _applyMapFocus(MapFocusKind kind) async {
    await _clearSelection();
    switch (kind) {
      case MapFocusKind.nearestSos:
        if (_sessions.isEmpty) return;
        SosSession nearest = _sessions.first;
        var best = double.infinity;
        for (final session in _sessions) {
          final d = Geolocator.distanceBetween(
            _origin.latitude,
            _origin.longitude,
            session.latitude,
            session.longitude,
          );
          if (d < best) {
            best = d;
            nearest = session;
          }
        }
        await _selectSession(nearest);
      case MapFocusKind.allSos:
        if (_sessions.isEmpty) return;
        await _fitToPoints([
          for (final s in _sessions) LatLng(s.latitude, s.longitude),
        ]);
      case MapFocusKind.hazards:
        if (_hazards.isEmpty) return;
        await _fitToPoints([
          for (final h in _hazards) LatLng(h.latitude, h.longitude),
        ]);
      case MapFocusKind.overview:
        final points = <LatLng>[
          for (final s in _sessions) LatLng(s.latitude, s.longitude),
          for (final h in _hazards) LatLng(h.latitude, h.longitude),
        ];
        if (points.isEmpty) return;
        await _fitToPoints(points);
    }
  }

  Future<void> _openProfile() async {
    final profile = await _profileStore.read();
    if (!mounted) return;
    final updated = await showModalBottomSheet<SosProfile>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => ProfileForm(initialProfile: profile),
    );
    if (updated == null) return;
    await _profileStore.save(updated);
    if (mounted) _showMessage(S(context).profileSaved);
  }

  Future<void> _openPrivacy() async {
    final strings = S(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.privacyTitle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(strings.privacyBody, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(strings.gotIt),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOfflineInfo() async {
    final strings = S(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.offlineMap),
        content: Text(strings.offlineComingSoon),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.gotIt),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = S(context);

    return WithForegroundTask(
      child: Scaffold(
        drawer: MenuDrawer(
          language: widget.language,
          onReportRoad: () => unawaited(_reportRoad()),
          onProfile: () => unawaited(_openProfile()),
          onOffline: () => unawaited(_openOfflineInfo()),
          onPrivacy: () => unawaited(_openPrivacy()),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: MapLibreMap(
                // demotiles is world-outline only — blank at city zoom.
                styleString: MapLibreStyles.openfreemapLiberty,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(21.0285, 105.8042),
                  zoom: 12.2,
                ),
                myLocationEnabled: true,
                myLocationTrackingMode: MyLocationTrackingMode.none,
                compassEnabled: false,
                onMapCreated: (controller) {
                  _mapController = controller;
                  controller.onSymbolTapped.add((symbol) {
                    final session = _symbolSessions[symbol.id];
                    if (session != null) {
                      unawaited(_selectSession(session));
                      return;
                    }
                    final hazard = _symbolHazards[symbol.id];
                    if (hazard != null) unawaited(_selectHazard(hazard));
                  });
                  controller.onCircleTapped.add((circle) {
                    final session = _circleSessions[circle.id];
                    if (session != null) {
                      unawaited(_selectSession(session));
                      return;
                    }
                    final hazard = _circleHazards[circle.id];
                    if (hazard != null) unawaited(_selectHazard(hazard));
                  });
                },
                onStyleLoadedCallback: () {
                  _styleReady = true;
                  unawaited(_renderMapOverlays());
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Builder(
                      builder: (context) => GlassButton(
                        icon: Icons.menu_rounded,
                        onTap: Scaffold.of(context).openDrawer,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => unawaited(_openSearch()),
                          child: Ink(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: glassDecoration(),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.travel_explore_rounded,
                                  color: Colors.black54,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    strings.search,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GlassButton(
                      icon: Icons.my_location_rounded,
                      onTap: () => unawaited(_goToMyLocation()),
                    ),
                  ],
                ),
              ),
            ),
            if (_mySession != null)
              SafeArea(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 74, 12, 0),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 20),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sos, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${strings.sosActive} · ${_mySession!.id}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Gọi 112',
                        onPressed: _call112,
                        icon: const Icon(Icons.call, color: Colors.white),
                      ),
                      TextButton(
                        onPressed: _finishSos,
                        child: Text(
                          strings.stopSos,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_selectedSession == null && _selectedHazard == null)
              MapActionDock(onSos: _startSos)
            else if (_selectedSession != null)
              SosDetailPanel(
                session: _selectedSession!,
                routes: _routes,
                loadingRoutes: _loadingRoutes,
                onClose: () => unawaited(_clearSelection()),
                onAccept: () => unawaited(_acceptCase()),
                onCompass: _openCompass,
                onRouteSelected: (route) => unawaited(_drawRoute(route)),
              )
            else if (_selectedHazard != null)
              HazardDetailPanel(
                hazard: _selectedHazard!,
                onClose: () => unawaited(_clearSelection()),
              ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration glassDecoration() => BoxDecoration(
      color: Colors.white.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 18)],
    );

class GlassButton extends StatelessWidget {
  const GlassButton({required this.icon, required this.onTap, super.key});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 50,
          height: 50,
          decoration: glassDecoration(),
          child: Icon(icon),
        ),
      ),
    );
  }
}
