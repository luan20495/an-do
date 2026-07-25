import 'dart:async';
import 'dart:io';

import 'package:an_do/core/device/device_identity.dart';
import 'package:an_do/core/i18n/app_language_controller.dart';
import 'package:an_do/core/i18n/strings.dart';
import 'package:an_do/core/location/sos_foreground_service.dart';
import 'package:an_do/core/routing/osrm_client.dart';
import 'package:an_do/core/routing/route_models.dart';
import 'package:an_do/features/compass/presentation/compass_page.dart';
import 'package:an_do/features/map/data/map_marker_layers.dart';
import 'package:an_do/features/map/presentation/menu_drawer.dart';
import 'package:an_do/features/map/presentation/widgets/active_sos_banner.dart';
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
import 'package:an_do/features/sos_chat/data/sos_chat_repository.dart';
import 'package:an_do/features/sos_chat/domain/chat_models.dart';
import 'package:an_do/features/sos_chat/presentation/helper_picker_sheet.dart';
import 'package:an_do/features/sos_chat/presentation/sos_chat_thread_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  

  late final SosRepository _sosRepository;
  late final SosChatRepository _chatRepository;
  late final RoadHazardRepository? _hazardRepository;
  final ProfileStore _profileStore = ProfileStore();
  final RoadReportRepository _reportRepository = RoadReportRepository();
  final OsrmClient _routing = OsrmClient();
  final Set<String> _acceptedSosIds = {};
  MapMarkerLayers? _markerLayers;

  StreamSubscription<List<SosSession>>? _sosSubscription;
  StreamSubscription<List<RoadHazard>>? _hazardSubscription;
  StreamSubscription<int>? _helperSubscription;
  StreamSubscription<List<String>>? _helperIdsSubscription;
  StreamSubscription<int>? _ownerUnreadSubscription;
  StreamSubscription<ChatThreadMeta>? _selectedThreadMetaSubscription;
  MapLibreMapController? _mapController;
  Position? _position;
  List<SosSession> _sessions = const [];
  List<RoadHazard> _hazards = const [];
  List<RescueRoute> _routes = const [];
  SosSession? _selectedSession;
  RoadHazard? _selectedHazard;
  SosSession? _mySession;
  List<String> _helperIds = const [];
  int _helperCount = 0;
  int _announcedHelperCount = 0;
  int _ownerUnreadTotal = 0;
  int _selectedThreadUnread = 0;
  bool _loadingRoutes = false;
  bool _styleReady = false;
  bool _didFitOverview = false;
  int _overlayGeneration = 0;
  bool _overlayBusy = false;
  bool _overlayDirty = false;
  bool _modalOpen = false;
  final GlobalKey _mapKey = GlobalKey();
  final ValueNotifier<int> _helperCountListenable = ValueNotifier(0);
  final ValueNotifier<int> _ownerUnreadListenable = ValueNotifier(0);
  final ValueNotifier<List<String>> _helperIdsListenable =
      ValueNotifier(const []);

  @override
  void initState() {
    super.initState();
    _sosRepository = createSosRepository(firebaseReady: widget.firebaseReady);
    _chatRepository = createSosChatRepository(firebaseReady: widget.firebaseReady);
    // Hazards: only user-reported (no seed). Cloud sync can replace later.
    _hazardRepository = LocalRoadHazardRepository();
    _sosSubscription = _sosRepository.watchActive().listen(
      (sessions) {
        if (!mounted) return;
        _sessions = sessions;
        // Refresh selected card data without rebuilding the whole map tree
        // unless the open sheet must update.
        final selected = _selectedSession;
        if (selected != null) {
          for (final s in sessions) {
            if (s.id == selected.id && !identical(s, selected)) {
              setState(() => _selectedSession = s);
              break;
            }
          }
        }
        _scheduleMapOverlays();
      },
      onError: (Object error) => debugPrint('SOS stream error: $error'),
    );
    _hazardSubscription = _hazardRepository?.watch().listen(
      (hazards) {
        if (!mounted) return;
        _hazards = hazards;
        _scheduleMapOverlays();
      },
      onError: (Object error) => debugPrint('Hazard stream error: $error'),
    );
    unawaited(_prepareLocation(moveCamera: false));
  }

  @override
  void dispose() {
    _sosSubscription?.cancel();
    _hazardSubscription?.cancel();
    _helperSubscription?.cancel();
    _helperIdsSubscription?.cancel();
    _ownerUnreadSubscription?.cancel();
    _selectedThreadMetaSubscription?.cancel();
    _helperCountListenable.dispose();
    _ownerUnreadListenable.dispose();
    _helperIdsListenable.dispose();
    super.dispose();
  }

  Future<String> _viewerId() async {
    if (widget.firebaseReady) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) return uid;
      // Soft fallback — never crash on null Auth during flaky network.
      return DeviceIdentity.getOrCreate();
    }
    return DeviceIdentity.getOrCreate();
  }

  LatLng? get _originOrNull => _position == null
      ? null
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

  /// Debounced GeoJSON marker sync — never N× addCircle on the UI isolate.
  void _scheduleMapOverlays() {
    if (_modalOpen) {
      _overlayDirty = true;
      return;
    }
    _overlayDirty = true;
    if (_overlayBusy) return;
    unawaited(_drainMapOverlays());
  }

  Future<void> _drainMapOverlays() async {
    if (_overlayBusy || _modalOpen) return;
    _overlayBusy = true;
    try {
      while (_overlayDirty && mounted && !_modalOpen) {
        _overlayDirty = false;
        final gen = ++_overlayGeneration;
        await Future<void>.delayed(const Duration(milliseconds: 220));
        if (!mounted || gen != _overlayGeneration || _modalOpen) continue;
        await _renderMapOverlays();
        // Give the input queue a chance to drain after MapLibre work.
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    } finally {
      _overlayBusy = false;
      if (_overlayDirty && mounted && !_modalOpen) {
        unawaited(_drainMapOverlays());
      }
    }
  }

  Future<void> _renderMapOverlays() async {
    final controller = _mapController;
    if (controller == null || !_styleReady || !mounted) return;
    final layers = _markerLayers ??= MapMarkerLayers(controller);
    try {
      await layers.sync(
        sessions: _sessions,
        hazards: _hazards,
        selectedSosId: _selectedSession?.id,
        selectedHazardId: _selectedHazard?.id,
      );
      if (!_didFitOverview &&
          _selectedSession == null &&
          _selectedHazard == null &&
          _mySession == null &&
          _sessions.length + _hazards.length >= 2) {
        _didFitOverview = true;
        final points = <LatLng>[
          ..._sessions.take(25).map((s) => LatLng(s.latitude, s.longitude)),
          ..._hazards.take(25).map((h) => LatLng(h.latitude, h.longitude)),
        ];
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
    await controller.moveCamera(
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
    _watchSelectedThreadMeta(null);
    setState(() {
      _selectedSession = null;
      _selectedHazard = null;
      _routes = const [];
      _loadingRoutes = false;
      _selectedThreadUnread = 0;
    });
    try {
      await _mapController?.clearLines();
    } catch (_) {}
    _scheduleMapOverlays();
  }

  Future<void> _selectHazard(RoadHazard hazard) async {
    setState(() {
      _selectedHazard = hazard;
      _selectedSession = null;
      _routes = const [];
      _loadingRoutes = false;
    });
    try {
      await _mapController?.clearLines();
    } catch (_) {}
    _scheduleMapOverlays();
    try {
      await _mapController?.moveCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(hazard.latitude, hazard.longitude),
          15,
        ),
      );
    } catch (_) {}
  }

  Future<void> _selectSession(SosSession session) async {
    final isOwn = _mySession?.id == session.id;
    setState(() {
      _selectedSession = session;
      _selectedHazard = null;
      _routes = const [];
      _loadingRoutes = !isOwn;
    });
    if (!isOwn) _watchSelectedThreadMeta(session);
    _scheduleMapOverlays();
    try {
      await _mapController?.moveCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(session.latitude, session.longitude),
          14.5,
        ),
      );
    } catch (_) {}

    // Own SOS: never hit OSRM / draw routes (ANR hotspot during active SOS).
    if (isOwn) return;

    final from = _originOrNull;
    if (from == null) {
      if (mounted) setState(() => _loadingRoutes = false);
      return;
    }
    try {
      final routes = await _routing
          .routes(
            from: from,
            to: LatLng(session.latitude, session.longitude),
          )
          .timeout(const Duration(seconds: 6));
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
    await controller.moveCamera(
      CameraUpdate.newLatLngZoom(midpoint, 13.5),
    );
  }

  Future<void> _startSos() async {
    try {
      final profile = await _profileStore.read();
      if (!mounted) return;

      _modalOpen = true;
      final SosDraft? draft;
      try {
        draft = await showModalBottomSheet<SosDraft>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (_) => SosForm(initialProfile: profile),
        );
      } finally {
        _modalOpen = false;
      }
      if (draft == null) return;

      await _prepareLocation();
      final position = _position;
      if (position == null) {
        if (mounted) {
          _showMessage('Chưa lấy được vị trí GPS thật. Bật GPS rồi thử lại.');
        }
        return;
      }
      final latLng = LatLng(position.latitude, position.longitude);

      final ownerId = widget.firebaseReady
          ? FirebaseAuth.instance.currentUser?.uid
          : await DeviceIdentity.getOrCreate();
      if (ownerId == null || ownerId.isEmpty) {
        if (mounted) {
          _showMessage('Chưa sẵn sàng đăng nhập. Thử lại sau vài giây.');
        }
        return;
      }
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
      try {
        await SosForegroundService.start(
          sosId: session.id,
          firebaseEnabled: widget.firebaseReady,
        ).timeout(const Duration(seconds: 8));
      } catch (error) {
        debugPrint('SOS FGS start soft-failed: $error');
      }

      if (!mounted) return;
      // Keep map quiet: banner only — no detail sheet / route fetch while SOS is live.
      setState(() {
        _mySession = session;
        _selectedSession = null;
        _selectedHazard = null;
        _routes = const [];
        _loadingRoutes = false;
        _helperCount = 0;
        _helperIds = const [];
        _announcedHelperCount = 0;
        _ownerUnreadTotal = 0;
      });
      _helperCountListenable.value = 0;
      _helperIdsListenable.value = const [];
      _ownerUnreadListenable.value = 0;
      _listenForHelpers(session.id);
      _listenOwnerUnread(session.id);
      // One light marker refresh after SOS appears in the stream.
      _markerLayers?.invalidate();
      _scheduleMapOverlays();
    } catch (error, stack) {
      debugPrint('SOS start failed: $error\n$stack');
      if (mounted) {
        _showMessage('Không thể tạo SOS lúc này. Thử lại.');
      }
    }
  }

  void _listenOwnerUnread(String sosId) {
    unawaited(_ownerUnreadSubscription?.cancel());
    _ownerUnreadSubscription =
        _chatRepository.watchOwnerUnreadTotal(sosId).listen((total) {
      if (!mounted || _mySession?.id != sosId) return;
      _ownerUnreadTotal = total;
      _ownerUnreadListenable.value = total;
    });
  }

  void _listenForHelpers(String sosId) {
    unawaited(_helperSubscription?.cancel());
    unawaited(_helperIdsSubscription?.cancel());
    _helperSubscription = _sosRepository.watchHelperCount(sosId).listen(
      (count) {
        if (!mounted || _mySession?.id != sosId) return;
        final previous = _helperCount;
        _helperCount = count;
        _helperCountListenable.value = count;
        unawaited(SosForegroundService.updateHelperCount(count));
        if (count > previous && count > _announcedHelperCount) {
          _announcedHelperCount = count;
          final strings = S(context);
          _showMessage(strings.helperJoined(count));
        }
      },
      onError: (Object error) => debugPrint('Helper count stream: $error'),
    );
    _helperIdsSubscription = _sosRepository.watchHelperIds(sosId).listen(
      (ids) {
        if (!mounted || _mySession?.id != sosId) return;
        _helperIds = ids;
        _helperIdsListenable.value = ids;
      },
      onError: (Object error) => debugPrint('Helper ids stream: $error'),
    );
  }

  Future<void> _finishSos() async {
    final session = _mySession;
    if (session == null) return;

    try {
      await _helperSubscription?.cancel();
      _helperSubscription = null;
      await _helperIdsSubscription?.cancel();
      _helperIdsSubscription = null;
      await _ownerUnreadSubscription?.cancel();
      _ownerUnreadSubscription = null;
      await _sosRepository.finish(session.id);
      try {
        await SosForegroundService.stop().timeout(const Duration(seconds: 5));
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _mySession = null;
        _selectedSession = null;
        _helperCount = 0;
        _helperIds = const [];
        _announcedHelperCount = 0;
        _ownerUnreadTotal = 0;
        _routes = const [];
      });
      _helperCountListenable.value = 0;
      _helperIdsListenable.value = const [];
      _ownerUnreadListenable.value = 0;
      try {
        await _mapController?.clearLines();
      } catch (_) {}
      _scheduleMapOverlays();
    } catch (error, stack) {
      debugPrint('SOS finish failed: $error\n$stack');
      if (mounted) _showMessage('Không thể kết thúc SOS. Thử lại.');
    }
  }

  Future<void> _openOwnerChatPicker() async {
    final session = _mySession;
    if (session == null) return;
    final helpers = List<String>.from(_helperIdsListenable.value);
    if (helpers.isEmpty) return;

    Future<void> open(String helperId) async {
      if (!mounted) return;
      final strings = S(context);
      final short = helperId.length > 8
          ? '${helperId.substring(0, 8)}…'
          : helperId;
      await _openChatThread(
        sosId: session.id,
        helperId: helperId,
        ownerId: session.ownerId,
        viewerId: session.ownerId,
        peerLabel: '${strings.helperLabel} $short',
      );
    }

    // Single helper: open chat immediately (common path + avoids sheet tap miss).
    if (helpers.length == 1) {
      await open(helpers.first);
      return;
    }

    _modalOpen = true;
    String? helperId;
    try {
      helperId = await showHelperPickerSheet(
        context: context,
        sosId: session.id,
        ownerId: session.ownerId,
        helperIds: helpers,
        chatRepository: _chatRepository,
      );
    } finally {
      _modalOpen = false;
      _scheduleMapOverlays();
    }
    if (helperId == null || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await open(helperId);
  }

  Future<void> _openVictimChat(SosSession session) async {
    final helperId = await _viewerId()
        .timeout(const Duration(seconds: 2), onTimeout: () => 'local-helper');
    if (!mounted) return;
    final strings = S(context);
    final name = session.profile.name.trim();
    await _openChatThread(
      sosId: session.id,
      helperId: helperId,
      ownerId: session.ownerId,
      viewerId: helperId,
      peerLabel: name.isEmpty ? strings.victimLabel : name,
    );
  }

  Future<void> _openChatThread({
    required String sosId,
    required String helperId,
    required String ownerId,
    required String viewerId,
    required String peerLabel,
  }) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SosChatThreadPage(
          sosId: sosId,
          helperId: helperId,
          ownerId: ownerId,
          viewerId: viewerId,
          peerLabel: peerLabel,
          chatRepository: _chatRepository,
        ),
      ),
    );
  }

  void _watchSelectedThreadMeta(SosSession? session) {
    unawaited(_selectedThreadMetaSubscription?.cancel());
    _selectedThreadMetaSubscription = null;
    if (session == null || _mySession?.id == session.id) {
      setState(() => _selectedThreadUnread = 0);
      return;
    }
    unawaited(() async {
      final helperId = await _viewerId();
      if (!mounted) return;
      _selectedThreadMetaSubscription = _chatRepository
          .watchThreadMeta(sosId: session.id, helperId: helperId)
          .listen((meta) {
        if (!mounted) return;
        setState(() {
          _selectedThreadUnread = meta.unreadFor(
            viewerId: helperId,
            ownerId: session.ownerId,
          );
        });
      });
    }());
  }

  Future<void> _reportRoad() async {
    await _prepareLocation();
    final position = _position;
    if (position == null || !mounted) {
      if (mounted) {
        _showMessage('Chưa lấy được vị trí GPS thật. Bật GPS rồi thử lại.');
      }
      return;
    }
    final latLng = LatLng(position.latitude, position.longitude);

    final draft = await showModalBottomSheet<ReportDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => const ReportForm(),
    );
    if (draft == null) return;

    final ownerId = widget.firebaseReady
        ? FirebaseAuth.instance.currentUser?.uid
        : await DeviceIdentity.getOrCreate();
    if (ownerId == null || ownerId.isEmpty) {
      if (mounted) _showMessage('Chưa sẵn sàng. Thử lại sau.');
      return;
    }
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
          : 'Đã lưu cảnh báo trên thiết bị (chưa đồng bộ cloud).',
    );
  }

  Future<void> _acceptCase() async {
    final selected = _selectedSession;
    if (selected == null) return;
    if (_mySession?.id == selected.id) {
      if (mounted) _showMessage(S(context).cannotHelpOwnSos);
      return;
    }
    try {
      final helperId = await _viewerId();
      await _sosRepository
          .acceptHelp(sosId: selected.id, helperId: helperId)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() => _acceptedSosIds.add(selected.id));
      _watchSelectedThreadMeta(selected);
      _showMessage('Đã nhận hỗ trợ ca SOS ${selected.id}.');
    } catch (error, stack) {
      debugPrint('Accept SOS failed: $error\n$stack');
      if (mounted) _showMessage('Không thể nhận hỗ trợ lúc này.');
    }
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
    final origin = _originOrNull;
    if (origin == null) {
      _showMessage('Chưa lấy được vị trí GPS thật. Bật GPS rồi thử lại.');
      return;
    }
    final result = await showMapSearchSheet(
      context: context,
      sessions: _sessions,
      hazards: _hazards,
      origin: origin,
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
    final origin = _originOrNull;
    if (origin == null) {
      _showMessage('Chưa lấy được vị trí GPS thật. Bật GPS rồi thử lại.');
      return;
    }
    await _clearSelection();
    switch (kind) {
      case MapFocusKind.nearestSos:
        if (_sessions.isEmpty) return;
        SosSession nearest = _sessions.first;
        var best = double.infinity;
        for (final session in _sessions) {
          final d = Geolocator.distanceBetween(
            origin.latitude,
            origin.longitude,
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
              child: _StableMapLibre(
                key: _mapKey,
                onCreated: (controller) {
                  _mapController = controller;
                  _markerLayers = MapMarkerLayers(controller);
                  controller.onFeatureTapped.add((point, latLng, id, layerId, annotation) {
                    if (_mySession != null) return; // ignore map taps while owning SOS
                    if (layerId == MapMarkerLayers.sosLayer) {
                      for (final s in _sessions) {
                        if (s.id == id) {
                          unawaited(_selectSession(s));
                          return;
                        }
                      }
                    } else if (layerId == MapMarkerLayers.hazardLayer) {
                      for (final h in _hazards) {
                        if (h.id == id) {
                          unawaited(_selectHazard(h));
                          return;
                        }
                      }
                    }
                  });
                },
                onStyleLoaded: () {
                  _styleReady = true;
                  unawaited(() async {
                    await _markerLayers?.ensureLayers();
                    _scheduleMapOverlays();
                  }());
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
                child: ValueListenableBuilder<List<String>>(
                  valueListenable: _helperIdsListenable,
                  builder: (context, helperIds, _) {
                    return ActiveSosBanner(
                      sosId: _mySession!.id,
                      title: strings.sosActive,
                      safeLabel: strings.stopSos,
                      callLabel: strings.call112,
                      chatLabel: strings.openChat,
                      helperCountListenable: _helperCountListenable,
                      unreadListenable: _ownerUnreadListenable,
                      helpersWatchingLabel: strings.helpersWatching,
                      chatEnabled: helperIds.isNotEmpty,
                      onCall: _call112,
                      onChat: () => unawaited(_openOwnerChatPicker()),
                      onSafe: () => unawaited(_finishSos()),
                    );
                  },
                ),
              ),
            if (_mySession == null &&
                _selectedSession == null &&
                _selectedHazard == null)
              MapActionDock(onSos: _startSos)
            else if (_mySession == null && _selectedSession != null)
              SosDetailPanel(
                session: _selectedSession!,
                routes: _routes,
                loadingRoutes: _loadingRoutes,
                isOwnSession: _mySession?.id == _selectedSession!.id,
                accepted: _acceptedSosIds.contains(_selectedSession!.id),
                unreadCount: _selectedThreadUnread,
                onClose: () => unawaited(_clearSelection()),
                onAccept: () => unawaited(_acceptCase()),
                onCompass: _openCompass,
                onRouteSelected: (route) => unawaited(_drawRoute(route)),
                onMessageVictim: () =>
                    unawaited(_openVictimChat(_selectedSession!)),
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


/// Keeps MapLibre platform view stable across parent setState rebuilds.
class _StableMapLibre extends StatefulWidget {
  const _StableMapLibre({
    required this.onCreated,
    required this.onStyleLoaded,
    super.key,
  });

  final void Function(MapLibreMapController controller) onCreated;
  final VoidCallback onStyleLoaded;

  @override
  State<_StableMapLibre> createState() => _StableMapLibreState();
}

class _StableMapLibreState extends State<_StableMapLibre>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MapLibreMap(
      styleString: MapLibreStyles.openfreemapLiberty,
      initialCameraPosition: const CameraPosition(
        target: LatLng(21.0285, 105.8042),
        zoom: 12.2,
      ),
      myLocationEnabled: false,
      myLocationTrackingMode: MyLocationTrackingMode.none,
      compassEnabled: false,
      onMapCreated: widget.onCreated,
      onStyleLoadedCallback: widget.onStyleLoaded,
    );
  }
}
