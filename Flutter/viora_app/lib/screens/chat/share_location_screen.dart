import '../../l10n/language.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:math' show Point;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../config/api_config.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../services/message_service.dart';
import '../../services/session_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/toast/app_toast.dart';

class ShareLocationScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? conversationId;
  final String? receiverId;
  final String? messageId;
  final bool initialIsSharing;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserAvatar;
  final double? otherUserLatitude;
  final double? otherUserLongitude;

  const ShareLocationScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.conversationId,
    this.receiverId,
    this.messageId,
    this.initialIsSharing = false,
    this.otherUserId,
    this.otherUserName,
    this.otherUserAvatar,
    this.otherUserLatitude,
    this.otherUserLongitude,
  });

  @override
  State<ShareLocationScreen> createState() => _ShareLocationScreenState();
}

class _ShareLocationScreenState extends State<ShareLocationScreen> {
  Language get l10n => context.l10n;

  static const String _lightStyleUrl = 'assets/styles/light_style.json';
  static const String _darkStyleUrl = 'assets/styles/dark_style.json';

  MapLibreMapController? _mapController;
  Symbol? _meSymbol;
  Symbol? _headingBeamSymbol;

  final Map<String, Map<String, dynamic>> _activeSharers = {};
  final Map<String, Symbol> _sharerSymbols = {};
  final Map<String, Uint8List> _cachedSharerPinBytes = {};
  String? _selectedSharerId;
  final ScrollController _sharerScrollController = ScrollController();
  final Map<String, GlobalKey> _chipKeys = {};
  bool _isRefreshing = false;
  bool _needsRefreshAgain = false;

  Line? _routeLine;
  bool _isRouteActive = false;
  bool _isLoadingRoute = false;
  String? _routeTargetId;
  String? _routeDistanceText;

  Uint8List? _cachedBeamBytes;
  bool? _cachedBeamIsLive;

  StreamSubscription<CompassEvent>? _compassSub;
  double _currentHeading = 0.0;
  double _currentBearing = 0.0;
  double _lastRenderedHeading = 0.0;
  DateTime _lastCompassTime = DateTime.now();

  Widget? _cachedMapWidget;
  bool? _cachedIsDark;

  Uint8List? _cachedMeBytes;
  bool? _cachedMeSharing;
  String? _cachedMeAvatar;
  Uint8List? _cachedGpsDotBytes;

  final Map<String, ui.Image> _avatarImageCache = {};

  late LatLng _currentCenter;
  bool _isLoadingGps = false;
  late bool _isSharing;
  bool _followUser = true;
  void Function(Map<String, dynamic>)? _socketNewMessageCb;
  void Function(Map<String, dynamic>)? _socketLocationStoppedCb;
  void Function(Map<String, dynamic>)? _socketLocationUpdatedCb;
  LatLng? _lastKnownGps;
  String? _activeMessageId;
  String? _myAvatar;
  String? _myName;

  StreamSubscription<Position>? _positionStreamSub;
  Timer? _pollTimer;
  String _placeName = '';
  String _address = '';

  @override
  void initState() {
    super.initState();
    MapLibreMap.useHybridComposition = true;
    _isSharing = widget.initialIsSharing;
    _activeMessageId = widget.messageId;

    if (widget.otherUserName != null && widget.otherUserLatitude != null && widget.otherUserLongitude != null) {
      final initialId = widget.otherUserId ?? widget.otherUserName!;
      _activeSharers[initialId] = {
        'userId': initialId,
        'name': widget.otherUserName!,
        'avatar': widget.otherUserAvatar ?? '',
        'latitude': widget.otherUserLatitude!,
        'longitude': widget.otherUserLongitude!,
        'isMe': false,
      };
      _selectedSharerId = initialId;
    }

    _loadMyProfile();

    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _currentCenter = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _followUser = (widget.otherUserName == null);
    } else if (widget.otherUserLatitude != null && widget.otherUserLongitude != null) {
      _currentCenter = LatLng(widget.otherUserLatitude!, widget.otherUserLongitude!);
      _followUser = false;
    } else {
      _currentCenter = const LatLng(10.776889, 106.700806);
      _followUser = true;
    }

    _initCurrentLocation();
    if (_isSharing) {
      _startLocationStream();
    }
    _fetchSharers();
    _startPollingUpdates();
    _startCompassStream();

    _socketNewMessageCb = (msg) {
      if (!mounted) return;
      final convId = msg['conversationId']?.toString();
      if (widget.conversationId != null && convId != null && convId != widget.conversationId) return;
      if (msg['type'] == 'location') {
        _fetchSharers();
      }
    };
    SocketService.onNewMessage(_socketNewMessageCb!);

    _socketLocationStoppedCb = (data) {
      if (!mounted) return;
      final convId = data['conversationId']?.toString();
      if (widget.conversationId != null && convId != null && convId != widget.conversationId) return;

      final msgId = data['messageId']?.toString();
      final stoppedUserId = data['userId']?.toString();

      if (msgId != null && msgId == _activeMessageId) {
        setState(() {
          _isSharing = false;
          _activeMessageId = null;
        });
        _positionStreamSub?.cancel();
        _refreshMarkers();
        return;
      }

      if (stoppedUserId != null && _activeSharers.containsKey(stoppedUserId)) {
        if (_routeTargetId == stoppedUserId) {
          _clearRouteLine();
        }
        setState(() {
          _activeSharers.remove(stoppedUserId);
          if (_selectedSharerId == stoppedUserId) {
            _selectedSharerId = null;
          }
        });
        _refreshMarkers();
      } else {
        _fetchSharers();
      }
    };
    SocketService.onLocationStopped(_socketLocationStoppedCb!);

    _socketLocationUpdatedCb = (data) {
      if (!mounted) return;
      final convId = data['conversationId']?.toString();
      if (widget.conversationId != null && convId != null && convId != widget.conversationId) return;

      final loc = data['location'];
      final uId = data['userId']?.toString();
      if (loc is Map && uId != null) {
        final lat = (loc['latitude'] as num?)?.toDouble();
        final lng = (loc['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          if (_activeSharers.containsKey(uId)) {
            setState(() {
              _activeSharers[uId]!['latitude'] = lat;
              _activeSharers[uId]!['longitude'] = lng;
              if (loc['address'] != null) {
                _activeSharers[uId]!['address'] = loc['address'];
              }
            });
            _refreshMarkers();
            if (_isRouteActive && _routeTargetId == uId) {
              _drawRouteToSelectedSharer();
            }
          } else {
            _fetchSharers();
          }
        }
      }
    };
    SocketService.onLocationUpdated(_socketLocationUpdatedCb!);
  }

  Future<void> _loadMyProfile() async {
    try {
      final av = await SessionService.getAvatar();
      final name = await SessionService.getUsername();
      if (mounted) {
        setState(() {
          _myAvatar = av;
          _myName = name;
        });
      }
      _refreshMarkers();
    } catch (_) {}
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _pollTimer?.cancel();
    _positionStreamSub?.cancel();
    _sharerScrollController.dispose();
    _clearRouteLine();
    if (_socketNewMessageCb != null) SocketService.offNewMessage(_socketNewMessageCb);
    if (_socketLocationStoppedCb != null) SocketService.offLocationStopped(_socketLocationStoppedCb);
    if (_socketLocationUpdatedCb != null) SocketService.offLocationUpdated(_socketLocationUpdatedCb);
    super.dispose();
  }

  void _startCompassStream() {
    _compassSub?.cancel();
    try {
      _compassSub = FlutterCompass.events?.listen((event) {
        final h = event.heading;
        if (h == null || !mounted) return;
        _currentHeading = h;

        final now = DateTime.now();
        if (now.difference(_lastCompassTime).inMilliseconds < 45) return;
        final diff = (h - _lastRenderedHeading).abs();
        if (diff < 1.2 && diff < 358.8) return;

        _lastCompassTime = now;
        _lastRenderedHeading = h;

        if (_mapController != null && _headingBeamSymbol != null) {
          unawaited(_mapController!.updateSymbol(
            _headingBeamSymbol!,
            SymbolOptions(iconRotate: (h - _currentBearing) % 360.0),
          ));
        }
      });
    } catch (e) {
      debugPrint('Compass stream error: $e');
    }
  }


  Future<void> _fetchSharers() async {
    if (widget.conversationId == null) return;
    try {
      final res = await MessageService.loadMessages(conversationId: widget.conversationId!);
      if (res != null && res['data'] is List && mounted) {
        final list = List<Map<String, dynamic>>.from(res['data']);

        final Map<String, Map<String, dynamic>> updatedSharers = {};
        bool meFoundActive = false;
        String? myActiveId;

        for (var m in list) {
          if (m['type'] != 'location') continue;
          final loc = m['location'];
          if (loc is! Map) continue;
          final bool isLive = loc['isLive'] != false && loc['status'] != 'stopped';
          if (!isLive) continue;

          final bool isMsgMe = m['isMe'] == true;
          final lat = (loc['latitude'] as num?)?.toDouble();
          final lng = (loc['longitude'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;

          if (isMsgMe) {
            meFoundActive = true;
            myActiveId = m['id']?.toString();
          } else {
            final sObj = m['sender'];
            final sId = m['senderId']?.toString() ??
                (sObj is Map ? (sObj['_id']?.toString() ?? sObj['id']?.toString()) : sObj?.toString()) ??
                m['senderName']?.toString() ??
                '';
            final sName = (sObj is Map ? (sObj['fullName']?.toString() ?? sObj['username']?.toString()) : null) ??
                m['senderName']?.toString() ??
                l10n.user;
            final sAvatar = (sObj is Map ? sObj['avatar']?.toString() : null) ??
                m['senderAvatar']?.toString() ??
                '';

            if (sId.isNotEmpty) {
              updatedSharers[sId] = {
                'userId': sId,
                'name': sName,
                'avatar': sAvatar,
                'latitude': lat,
                'longitude': lng,
                'address': loc['address']?.toString() ?? '',
                'isMe': false,
              };
            }
          }
        }

        if (meFoundActive) {
          if (!_isSharing) {
            setState(() {
              _isSharing = true;
              _activeMessageId = myActiveId;
            });
            _startLocationStream();
          } else if (_activeMessageId != myActiveId) {
            _activeMessageId = myActiveId;
          }
        }

        if (mounted) {
          setState(() {
            _activeSharers.clear();
            _activeSharers.addAll(updatedSharers);
          });
          _refreshMarkers();
        }
      }
    } catch (_) {}
  }

  void _startPollingUpdates() {
    if (widget.conversationId == null) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      _fetchSharers();
    });
  }

  Future<void> _initCurrentLocation({bool forceMoveCamera = false}) async {
    final bool shouldFollow = forceMoveCamera || (_activeSharers.isEmpty && _followUser);
    _followUser = shouldFollow;

    if (_lastKnownGps != null) {
      if (shouldFollow) {
        _currentCenter = _lastKnownGps!;
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _lastKnownGps!, zoom: 16.0),
          ),
          duration: const Duration(milliseconds: 350),
        );
      }
      _updateMeMarker(_lastKnownGps!);
    }

    setState(() => _isLoadingGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 7));

        final newCenter = LatLng(position.latitude, position.longitude);
        _lastKnownGps = newCenter;
        if (shouldFollow) {
          _currentCenter = newCenter;
          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: newCenter, zoom: 16.0),
            ),
            duration: const Duration(milliseconds: 350),
          );
        }
        _updateMeMarker(newCenter);
        _fetchAddressForCoordinate(newCenter);
        _startLocationStream();
      }
    } catch (e) {
      debugPrint('ShareLocationScreen: GPS error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingGps = false);
      }
    }
  }

  Future<void> _fetchAddressForCoordinate(LatLng point) async {
    final currentLocationLabel = l10n.currentLocation;
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'VioraApp/1.0 (contact@viora.app)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final displayName = data['display_name']?.toString() ?? '';
          final parts = displayName.split(',');
          final name = parts.isNotEmpty ? parts.first.trim() : currentLocationLabel;
          _placeName = name;
          _address = displayName;
          return;
        }
      }
    } catch (_) {}

    _placeName = currentLocationLabel;
    _address = '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  void _startLocationStream() {
    _positionStreamSub?.cancel();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );

    _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen((pos) {
      final newPoint = LatLng(pos.latitude, pos.longitude);
      _lastKnownGps = newPoint;

      if (pos.heading > 0 && _lastRenderedHeading == 0.0) {
        _currentHeading = pos.heading;
        if (_headingBeamSymbol != null) {
          unawaited(_mapController!.updateSymbol(
            _headingBeamSymbol!,
            SymbolOptions(iconRotate: (pos.heading - _currentBearing) % 360.0),
          ));
        }
      }

      if (_isSharing) {
        _currentCenter = newPoint;
        _updateMeMarker(newPoint);

        MessageService.updateLiveLocation(
          messageId: _activeMessageId,
          conversationId: widget.conversationId,
          latitude: pos.latitude,
          longitude: pos.longitude,
          address: _address,
          name: _placeName,
        );
      } else if (_followUser) {
        _currentCenter = newPoint;
        _updateMeMarker(newPoint);
      }

      if (_isRouteActive && _routeTargetId != null) {
        _drawRouteToSelectedSharer();
      }

      if (_followUser) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(newPoint),
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  Future<void> _handleToggleSharing() async {
    if (!_isSharing) {
      setState(() {
        _isSharing = true;
      });
      _startLocationStream();
      _refreshMarkers();

      final locationPayload = {
        'latitude': _currentCenter.latitude,
        'longitude': _currentCenter.longitude,
        'name': _placeName,
        'address': _address,
        'isLive': true,
        'status': 'active',
      };

      if (widget.conversationId != null || widget.receiverId != null) {
        final res = await MessageService.sendMessage(
          content: l10n.sharingLiveLocation,
          type: 'location',
          location: locationPayload,
          conversationId: widget.conversationId,
          receiverId: widget.receiverId,
        );
        if (res != null && res['id'] != null) {
          _activeMessageId = res['id'].toString();
        }
      }

      if (mounted) {
        AppToast.success(context, l10n.sharingLiveLocation);
      }
    } else {
      final stoppedId = _activeMessageId;
      setState(() {
        _isSharing = false;
        _activeMessageId = null;
      });
      _positionStreamSub?.cancel();
      _refreshMarkers();

      final convId = widget.conversationId;
      if (convId != null && convId.isNotEmpty) {
        SocketService.emitStopShareLocation(
          conversationId: convId,
          messageId: stoppedId,
        );
      }

      await MessageService.stopShareLocation(
        messageId: stoppedId,
        conversationId: widget.conversationId,
      );

      if (mounted) {
        AppToast.info(context, l10n.stoppedSharingLocation);
      }
    }
  }

  void _onBack() {
    Navigator.pop(context, {
      'isSharing': _isSharing,
      'messageId': _activeMessageId,
      'latitude': _currentCenter.latitude,
      'longitude': _currentCenter.longitude,
      'name': _placeName,
      'address': _address,
    });
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  Future<void> _configureSymbolLayers() async {
    final sm = _mapController?.symbolManager;
    if (sm == null) return;
    try {
      await _mapController!.setSymbolIconAllowOverlap(true);
      await _mapController!.setSymbolIconIgnorePlacement(true);
      await _mapController!.setSymbolTextAllowOverlap(true);
      await _mapController!.setSymbolTextIgnorePlacement(true);

      final layerIds = sm.layerIds;
      final layerProps = sm.allLayerProperties;
      for (int i = 0; i < layerIds.length && i < layerProps.length; i++) {
        final prop = layerProps[i];
        if (prop is SymbolLayerProperties) {
          final updated = prop.copyWith(
            const SymbolLayerProperties(
              iconRotationAlignment: 'viewport',
              iconPitchAlignment: 'viewport',
              iconKeepUpright: true,
              iconAllowOverlap: true,
              iconIgnorePlacement: true,
            ),
          );
          await _mapController!.setLayerProperties(layerIds[i], updated);
        }
      }
    } catch (e) {
      debugPrint('Configure symbol layer error: $e');
    }
  }

  void _onStyleLoaded() async {
    await _configureSymbolLayers();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(widget.initialLatitude!, widget.initialLongitude!),
            zoom: 16.5,
          ),
        ),
        duration: const Duration(milliseconds: 350),
      );
    }
    _refreshMarkers();
  }

  Future<void> _updateMeMarker(LatLng pos) async {
    _refreshMarkers();
  }

  void _fitAllSharers() {
    final List<LatLng> points = [];
    if (_isSharing) {
      points.add(_lastKnownGps ?? _currentCenter);
    }
    for (var sharer in _activeSharers.values) {
      final lat = (sharer['latitude'] as num?)?.toDouble();
      final lng = (sharer['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
    }
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: points.first, zoom: 16.5),
        ),
        duration: const Duration(milliseconds: 350),
      );
      return;
    }
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    if ((maxLat - minLat).abs() < 0.00005 && (maxLng - minLng).abs() < 0.00005) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(minLat, minLng), zoom: 16.5),
        ),
        duration: const Duration(milliseconds: 350),
      );
      return;
    }

    _followUser = false;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        left: 60,
        right: 60,
        top: 130,
        bottom: 130,
      ),
      duration: const Duration(milliseconds: 400),
    );
  }

  void _scrollToChip(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyContext = key.currentContext;
      if (keyContext != null && mounted) {
        Scrollable.ensureVisible(
          keyContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _clearRouteLine() async {
    if (_routeLine != null && _mapController != null) {
      try {
        await _mapController!.removeLine(_routeLine!);
      } catch (_) {}
      _routeLine = null;
    }
    if (mounted) {
      setState(() {
        _isRouteActive = false;
        _routeTargetId = null;
        _routeDistanceText = null;
      });
    }
  }

  Future<List<LatLng>> _getRouteCoordinates(LatLng from, LatLng to, double distanceInMeters) async {

    if (distanceInMeters < 40) {
      return [from, to];
    }

    try {

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/foot/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['code'] == 'Ok' && data['routes'] is List && (data['routes'] as List).isNotEmpty) {
          final route = (data['routes'] as List).first;
          if (route is Map && route['geometry'] is Map) {
            final coordinates = route['geometry']['coordinates'];
            if (coordinates is List && coordinates.isNotEmpty) {
              final List<LatLng> pts = [from];
              for (var c in coordinates) {
                if (c is List && c.length >= 2) {
                  final lng = (c[0] as num).toDouble();
                  final lat = (c[1] as num).toDouble();
                  pts.add(LatLng(lat, lng));
                }
              }
              pts.add(to);
              return pts;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM route fetch error: $e');
    }
    return [from, to];
  }

  Future<void> _drawRouteToSelectedSharer() async {
    if (_mapController == null || _selectedSharerId == null) return;
    final sharer = _activeSharers[_selectedSharerId];
    if (sharer == null) return;

    final myPos = _lastKnownGps ?? _currentCenter;
    final targetPos = LatLng(
      (sharer['latitude'] as num).toDouble(),
      (sharer['longitude'] as num).toDouble(),
    );

    final double distanceInMeters = Geolocator.distanceBetween(
      myPos.latitude,
      myPos.longitude,
      targetPos.latitude,
      targetPos.longitude,
    );

    if (_routeLine != null) {
      try {
        await _mapController!.removeLine(_routeLine!);
      } catch (_) {}
      _routeLine = null;
    }

    if (distanceInMeters < 10) {
      if (mounted) {
        setState(() {
          _isRouteActive = true;
          _routeTargetId = _selectedSharerId;
          _routeDistanceText = l10n.nearYou;
          _isLoadingRoute = false;
        });
        AppToast.info(context, '${l10n.you} & ${sharer['name'] ?? l10n.user} ${l10n.sameLocationDesc} (~${distanceInMeters.round()} m)');
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingRoute = true;
      });
    }

    try {
      final pts = await _getRouteCoordinates(myPos, targetPos, distanceInMeters);

      final String distStr = distanceInMeters < 1000
          ? '${distanceInMeters.round()} m'
          : '${(distanceInMeters / 1000).toStringAsFixed(1)} km';

      _routeLine = await _mapController!.addLine(
        LineOptions(
          geometry: pts,
          lineColor: '#0084FF',
          lineWidth: 5.5,
          lineOpacity: 0.92,
          lineJoin: 'round',
        ),
      );

      if (mounted) {
        setState(() {
          _isRouteActive = true;
          _routeTargetId = _selectedSharerId;
          _routeDistanceText = distStr;
          _isLoadingRoute = false;
        });
      }

      final double minLat = math.min(myPos.latitude, targetPos.latitude);
      final double maxLat = math.max(myPos.latitude, targetPos.latitude);
      final double minLng = math.min(myPos.longitude, targetPos.longitude);
      final double maxLng = math.max(myPos.longitude, targetPos.longitude);

      if ((maxLat - minLat).abs() > 0.0001 || (maxLng - minLng).abs() > 0.0001) {
        _followUser = false;
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat, minLng),
              northeast: LatLng(maxLat, maxLng),
            ),
            left: 70,
            right: 70,
            top: 140,
            bottom: 140,
          ),
          duration: const Duration(milliseconds: 400),
        );
      }
    } catch (e) {
      debugPrint('Draw route error: $e');
      if (mounted) {
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  Widget _buildDirectionsButton(bool isDark) {
    final bool isOtherSelected = _selectedSharerId != null &&
        _selectedSharerId != '__all__' &&
        _selectedSharerId != '__me__' &&
        _activeSharers.containsKey(_selectedSharerId);

    if (!isOtherSelected) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 44.h,
      decoration: BoxDecoration(
        color: _isRouteActive
            ? AppColors.blue
            : (isDark ? const Color(0xFF2C2C3E) : Colors.white),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: _isRouteActive
              ? AppColors.blue
              : (isDark ? Colors.white12 : Colors.black12),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _isRouteActive
                ? AppColors.blue.withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22.r),
          onTap: _isLoadingRoute
              ? null
              : () {
                  if (_isRouteActive) {
                    _clearRouteLine();
                  } else {
                    _drawRouteToSelectedSharer();
                  }
                },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoadingRoute)
                  SizedBox(
                    width: 16.r,
                    height: 16.r,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: _isRouteActive ? Colors.white : AppColors.blue,
                    ),
                  )
                else
                  Icon(
                    _isRouteActive ? Icons.route_rounded : Icons.directions_rounded,
                    size: 20.r,
                    color: _isRouteActive ? Colors.white : AppColors.blue,
                  ),
                SizedBox(width: 8.w),
                Text(
                  _isRouteActive
                      ? (_routeDistanceText == l10n.nearYou
                          ? l10n.nearYou
                          : (_routeDistanceText != null ? '${l10n.routePrefix} • $_routeDistanceText' : l10n.navigating))
                      : l10n.navigation,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: _isRouteActive
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                if (_isRouteActive) ...[
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.close_rounded,
                    size: 16.r,
                    color: Colors.white70,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _createGpsDotBitmap() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double size = 96;
    const double c = size / 2;

    canvas.drawCircle(
      const Offset(c, c),
      32,
      Paint()
        ..color = const Color(0xFF007AFF).withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawCircle(
      const Offset(c, c),
      18,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      const Offset(c, c),
      18,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    canvas.drawCircle(
      const Offset(c, c),
      13,
      Paint()..color = const Color(0xFF007AFF),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _refreshMarkers() async {
    if (_mapController == null) return;
    if (_isRefreshing) {
      _needsRefreshAgain = true;
      return;
    }
    final youLabel = l10n.you;
    final userLabel = l10n.user;
    _isRefreshing = true;

    try {
      await _mapController!.setSymbolIconAllowOverlap(true);
      await _mapController!.setSymbolIconIgnorePlacement(true);
      await _mapController!.setSymbolTextAllowOverlap(true);
      await _mapController!.setSymbolTextIgnorePlacement(true);

      final mePosition = _lastKnownGps ?? _currentCenter;
      final bool isMeSelected = _selectedSharerId == '__me__' || (_selectedSharerId == null && _isSharing);
      final int meZIndex = isMeSelected ? 12 : 10;

      final beamName = 'me_beam_${_isSharing ? "live" : "idle"}';
      if (_cachedBeamBytes == null || _cachedBeamIsLive != _isSharing) {
        _cachedBeamBytes = await _createDirectionBeamBitmap(isLive: _isSharing);
        _cachedBeamIsLive = _isSharing;
      }
      await _mapController!.addImage(beamName, _cachedBeamBytes!);

      if (_headingBeamSymbol == null) {
        _headingBeamSymbol = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: mePosition,
            iconImage: beamName,
            iconSize: 0.50,
            iconAnchor: 'center',
            iconRotate: (_currentHeading - _currentBearing) % 360.0,
            zIndex: 1,
          ),
        );
      } else {
        await _mapController!.updateSymbol(
          _headingBeamSymbol!,
          SymbolOptions(
            geometry: mePosition,
            iconImage: beamName,
            iconSize: 0.50,
            iconAnchor: 'center',
            iconRotate: (_currentHeading - _currentBearing) % 360.0,
            zIndex: 1,
          ),
        );
      }

      final bool showMyAvatarPin = _isSharing || _activeSharers.isEmpty;

      if (showMyAvatarPin) {
        final mePinName = 'me_pin_${_isSharing ? "live" : "idle"}_${(_myAvatar ?? "").hashCode}';
        if (_cachedMeBytes == null || _cachedMeSharing != _isSharing || _cachedMeAvatar != _myAvatar) {
          _cachedMeBytes = await _createPinBitmap(
            avatarUrl: _myAvatar,
            name: _myName ?? youLabel,
            isMe: true,
            isLive: _isSharing,
          );
          _cachedMeSharing = _isSharing;
          _cachedMeAvatar = _myAvatar;
        }
        await _mapController!.addImage(mePinName, _cachedMeBytes!);

        if (_meSymbol == null) {
          _meSymbol = await _mapController!.addSymbol(
            SymbolOptions(
              geometry: mePosition,
              iconImage: mePinName,
              iconSize: 0.48,
              iconAnchor: 'center',
              iconRotate: 0.0,
              zIndex: meZIndex,
            ),
          );
        } else {
          await _mapController!.updateSymbol(
            _meSymbol!,
            SymbolOptions(
              geometry: mePosition,
              iconImage: mePinName,
              iconSize: 0.48,
              iconAnchor: 'center',
              iconRotate: 0.0,
              zIndex: meZIndex,
            ),
          );
        }
      } else {
        const gpsDotName = 'me_gps_dot';
        _cachedGpsDotBytes ??= await _createGpsDotBitmap();
        await _mapController!.addImage(gpsDotName, _cachedGpsDotBytes!);

        if (_meSymbol == null) {
          _meSymbol = await _mapController!.addSymbol(
            SymbolOptions(
              geometry: mePosition,
              iconImage: gpsDotName,
              iconSize: 0.55,
              iconAnchor: 'center',
              iconRotate: 0.0,
              zIndex: meZIndex,
            ),
          );
        } else {
          await _mapController!.updateSymbol(
            _meSymbol!,
            SymbolOptions(
              geometry: mePosition,
              iconImage: gpsDotName,
              iconSize: 0.55,
              iconAnchor: 'center',
              iconRotate: 0.0,
              zIndex: meZIndex,
            ),
          );
        }
      }

      final currentActiveIds = _activeSharers.keys.toSet();

      final toRemove = _sharerSymbols.keys.where((id) => !currentActiveIds.contains(id)).toList();
      for (var id in toRemove) {
        final sym = _sharerSymbols.remove(id);
        if (sym != null) {
          await _mapController!.removeSymbol(sym);
        }
      }

      for (var entry in _activeSharers.entries) {
        final sId = entry.key;
        final sharer = entry.value;
        final sAvatar = sharer['avatar']?.toString();
        final sName = sharer['name']?.toString() ?? userLabel;
        final sPos = LatLng(
          (sharer['latitude'] as num).toDouble(),
          (sharer['longitude'] as num).toDouble(),
        );
        final bool isSharerSelected = _selectedSharerId == sId;
        final int sharerZIndex = isSharerSelected ? 12 : 9;

        final pinKey = 'sharer_pin_${sId}_${(sAvatar ?? "").hashCode}';
        if (!_cachedSharerPinBytes.containsKey(pinKey)) {
          final bytes = await _createPinBitmap(
            avatarUrl: sAvatar,
            name: sName,
            isMe: false,
            isLive: true,
          );
          _cachedSharerPinBytes[pinKey] = bytes;
        }
        await _mapController!.addImage(pinKey, _cachedSharerPinBytes[pinKey]!);

        if (_sharerSymbols.containsKey(sId)) {
          await _mapController!.updateSymbol(
            _sharerSymbols[sId]!,
            SymbolOptions(
              geometry: sPos,
              iconImage: pinKey,
              iconSize: 0.48,
              iconAnchor: 'center',
              iconRotate: 0.0,
              zIndex: sharerZIndex,
            ),
          );
        } else {
          final sym = await _mapController!.addSymbol(
            SymbolOptions(
              geometry: sPos,
              iconImage: pinKey,
              iconSize: 0.48,
              iconAnchor: 'center',
              iconRotate: 0.0,
              zIndex: sharerZIndex,
            ),
          );
          _sharerSymbols[sId] = sym;
        }
      }

      await _configureSymbolLayers();
    } catch (e) {
      debugPrint('ShareLocationScreen: _refreshMarkers error: $e');
    } finally {
      _isRefreshing = false;
      if (_needsRefreshAgain) {
        _needsRefreshAgain = false;
        Future.microtask(() => _refreshMarkers());
      }
    }
  }

  Future<Uint8List> _createDirectionBeamBitmap({required bool isLive}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double w = 320;
    const double h = 320;
    const double cx = w / 2;
    const double cy = h / 2; 
    const double beamRadius = 145;

    final Color beamColorPrimary = isLive ? const Color(0xFFFF3366) : const Color(0xFF00E5FF);
    final Color beamColorSecondary = isLive ? const Color(0xFFFF5E3A) : const Color(0xFF2979FF);

    const double halfAngle = math.pi / 6;
    final beamPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(
        Rect.fromCircle(center: const Offset(cx, cy), radius: beamRadius),
        -math.pi / 2 - halfAngle,
        halfAngle * 2,
        false,
      )
      ..close();

    final beamPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(cx, cy),
        beamRadius,
        [
          beamColorPrimary.withValues(alpha: 0.55),
          beamColorSecondary.withValues(alpha: 0.35),
          beamColorSecondary.withValues(alpha: 0.12),
          beamColorSecondary.withValues(alpha: 0.0),
        ],
        [0.0, 0.40, 0.75, 1.0],
      );
    canvas.drawPath(beamPath, beamPaint);

    final double leftX = cx + beamRadius * math.cos(-math.pi / 2 - halfAngle);
    final double leftY = cy + beamRadius * math.sin(-math.pi / 2 - halfAngle);
    final double rightX = cx + beamRadius * math.cos(-math.pi / 2 + halfAngle);
    final double rightY = cy + beamRadius * math.sin(-math.pi / 2 + halfAngle);

    final leftRayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..shader = ui.Gradient.linear(
        const Offset(cx, cy),
        Offset(leftX, leftY),
        [beamColorPrimary.withValues(alpha: 0.80), Colors.transparent],
      );
    canvas.drawLine(const Offset(cx, cy), Offset(leftX, leftY), leftRayPaint);

    final rightRayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..shader = ui.Gradient.linear(
        const Offset(cx, cy),
        Offset(rightX, rightY),
        [beamColorPrimary.withValues(alpha: 0.80), Colors.transparent],
      );
    canvas.drawLine(const Offset(cx, cy), Offset(rightX, rightY), rightRayPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<ui.Image?> _loadAvatarImage(String? rawUrl) async {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return _loadFallbackAssetImage();
    }

    String url = rawUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://') && !url.startsWith('assets/')) {
      if (url.startsWith('/')) {
        url = '${ApiConfig.socketUrl}$url';
      } else if (url.contains('uploads/')) {
        url = '${ApiConfig.socketUrl}/$url';
      }
    }

    if (_avatarImageCache.containsKey(url)) {
      return _avatarImageCache[url];
    }

    try {
      Uint8List? bytes;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          bytes = res.bodyBytes;
        }
      } else if (url.startsWith('assets/')) {
        final data = await rootBundle.load(url);
        bytes = data.buffer.asUint8List();
      } else {
        final f = File(url);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: 200,
          targetHeight: 200,
        );
        final frame = await codec.getNextFrame();
        _avatarImageCache[url] = frame.image;
        return frame.image;
      }
    } catch (e) {
      debugPrint('Avatar image load failed for $url: $e');
    }

    return _loadFallbackAssetImage();
  }

  Future<ui.Image?> _loadFallbackAssetImage() async {
    const assetPath = 'assets/images/avatar.jpg';
    if (_avatarImageCache.containsKey(assetPath)) {
      return _avatarImageCache[assetPath];
    }
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 200,
        targetHeight: 200,
      );
      final frame = await codec.getNextFrame();
      _avatarImageCache[assetPath] = frame.image;
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _createPinBitmap({
    required String? avatarUrl,
    required String name,
    required bool isMe,
    required bool isLive,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double w = 220;
    const double h = 220;
    const double cx = w / 2;
    const double cy = h / 2;
    const double avatarRadius = 68;
    const double innerWhiteRadius = 74;
    const double outerRimRadius = 84;
    const double glowRadius = 98; 

    final Color gradStart;
    final Color gradEnd;
    final Color glowColor;

    if (isMe) {
      if (isLive) {
        gradStart = const Color(0xFFFF3366);
        gradEnd = const Color(0xFFFF5E3A);
        glowColor = const Color(0xFFFF3366);
      } else {
        gradStart = const Color(0xFF00C6FF);
        gradEnd = const Color(0xFF0072FF);
        glowColor = const Color(0xFF00C6FF);
      }
    } else {
      gradStart = const Color(0xFFFF9100);
      gradEnd = const Color(0xFFFF3D00);
      glowColor = const Color(0xFFFF9100);
    }

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(const Offset(cx, cy + 4), outerRimRadius + 2, shadowPaint);

    final haloPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(cx, cy),
        glowRadius,
        [
          glowColor.withValues(alpha: isLive ? 0.45 : 0.25),
          glowColor.withValues(alpha: isLive ? 0.15 : 0.08),
          glowColor.withValues(alpha: 0.0),
        ],
        [0.0, 0.70, 1.0],
      );
    canvas.drawCircle(const Offset(cx, cy), glowRadius, haloPaint);

    final rimPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(cx, cy - outerRimRadius),
        const Offset(cx, cy + outerRimRadius),
        [gradStart, gradEnd],
      );
    canvas.drawCircle(const Offset(cx, cy), outerRimRadius, rimPaint);

    canvas.drawCircle(
      const Offset(cx, cy),
      innerWhiteRadius,
      Paint()..color = Colors.white,
    );

    final ui.Image? avatarImage = await _loadAvatarImage(avatarUrl);

    if (avatarImage != null) {
      canvas.save();
      final clipPath = Path()..addOval(Rect.fromCircle(center: const Offset(cx, cy), radius: avatarRadius));
      canvas.clipPath(clipPath);

      final double imgW = avatarImage.width.toDouble();
      final double imgH = avatarImage.height.toDouble();
      final double cropSize = math.min(imgW, imgH);
      final Rect srcRect = Rect.fromLTWH(
        (imgW - cropSize) / 2,
        (imgH - cropSize) / 2,
        cropSize,
        cropSize,
      );
      final Rect dstRect = Rect.fromCircle(center: const Offset(cx, cy), radius: avatarRadius);
      canvas.drawImageRect(
        avatarImage,
        srcRect,
        dstRect,
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high,
      );
      canvas.restore();
    } else {
      canvas.save();
      final clipPath = Path()..addOval(Rect.fromCircle(center: const Offset(cx, cy), radius: avatarRadius));
      canvas.clipPath(clipPath);

      final bgShader = ui.Gradient.linear(
        const Offset(cx, cy - avatarRadius),
        const Offset(cx, cy + avatarRadius),
        [gradStart.withValues(alpha: 0.9), gradEnd],
      );
      canvas.drawCircle(const Offset(cx, cy), avatarRadius, Paint()..shader = bgShader);

      final initial = name.trim().isNotEmpty
          ? name.trim().characters.first.toUpperCase()
          : (isMe ? 'B' : 'N');
      final textPainter = TextPainter(
        text: TextSpan(
          text: initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
      );
      canvas.restore();
    }

    final glossShader = ui.Gradient.linear(
      const Offset(cx, cy - avatarRadius),
      const Offset(cx, cy),
      [
        Colors.white.withValues(alpha: 0.40),
        Colors.white.withValues(alpha: 0.0),
      ],
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(cx, cy), radius: avatarRadius),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..shader = glossShader,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Widget _buildActiveSharersBar() {
    final List<Map<String, dynamic>> allSharers = [];
    if (_isSharing) {
      final mePos = _lastKnownGps ?? _currentCenter;
      allSharers.add({
        'userId': '__me__',
        'name': l10n.you,
        'avatar': _myAvatar ?? '',
        'latitude': mePos.latitude,
        'longitude': mePos.longitude,
        'isMe': true,
      });
    }
    for (var sharer in _activeSharers.values) {
      allSharers.add(sharer);
    }

    if (allSharers.isEmpty) return const SizedBox.shrink();

    final isDark = context.isDark;
    final bool showAllOption = allSharers.length > 1;
    final int totalCount = (showAllOption ? 1 : 0) + allSharers.length;

    return SizedBox(
      height: 38.h,
      child: ListView.separated(
        controller: _sharerScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        itemCount: totalCount,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          if (showAllOption && index == 0) {
            final isSelected = _selectedSharerId == '__all__';
            final key = _chipKeys.putIfAbsent('__all__', () => GlobalKey());
            return Container(
              key: key,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20.r),
                  onTap: () {
                    setState(() {
                      _selectedSharerId = '__all__';
                    });
                    _scrollToChip(key);
                    _clearRouteLine();
                    _fitAllSharers();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? const Color(0xFF2C2C3E) : Colors.white)
                          : (isDark ? Colors.black.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.88)),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF0084FF)
                            : (isDark ? Colors.white12 : Colors.black12),
                        width: isSelected ? 1.6 : 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? const Color(0xFF0084FF).withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_rounded,
                          size: 18.r,
                          color: isSelected ? const Color(0xFF0084FF) : (isDark ? Colors.white70 : Colors.black54),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          l10n.all,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final sharerIndex = showAllOption ? index - 1 : index;
          final sharer = allSharers[sharerIndex];
          final sId = sharer['userId']?.toString() ?? '';
          final isMe = sharer['isMe'] == true;
          final isSelected = _selectedSharerId == sId || (_selectedSharerId == null && isMe && _isSharing);
          final name = sharer['name']?.toString() ?? (isMe ? l10n.you : l10n.user);
          final avatar = sharer['avatar']?.toString() ?? '';
          final key = _chipKeys.putIfAbsent(sId, () => GlobalKey());

          return Container(
            key: key,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20.r),
                onTap: () {
                  final bool wasOther = _selectedSharerId != sId;
                  setState(() {
                    _selectedSharerId = sId;
                  });
                  _scrollToChip(key);
                  final targetPos = isMe
                      ? (_lastKnownGps ?? _currentCenter)
                      : LatLng(
                          (sharer['latitude'] as num).toDouble(),
                          (sharer['longitude'] as num).toDouble(),
                        );
                  if (isMe) {
                    _followUser = true;
                    _clearRouteLine();
                  } else {
                    _followUser = false;
                    if (_isRouteActive && wasOther) {
                      _drawRouteToSelectedSharer();
                    }
                  }
                  _mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(target: targetPos, zoom: 16.5),
                    ),
                    duration: const Duration(milliseconds: 350),
                  );
                  _refreshMarkers();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF2C2C3E) : Colors.white)
                        : (isDark ? Colors.black.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.88)),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isSelected
                          ? (isMe ? const Color(0xFF00C6FF) : const Color(0xFFFF9100))
                          : (isDark ? Colors.white12 : Colors.black12),
                      width: isSelected ? 1.6 : 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? (isMe ? const Color(0xFF00C6FF) : const Color(0xFFFF9100)).withValues(alpha: 0.35)
                            : Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24.r,
                        height: 24.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isMe ? const Color(0xFF00C6FF) : const Color(0xFFFF9100),
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: avatar.isNotEmpty
                              ? Image.network(
                                  avatar,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => _buildAvatarFallback(name),
                                )
                              : _buildAvatarFallback(name),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 85.w),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      SizedBox(width: 5.w),
                      Container(
                        width: 6.r,
                        height: 6.r,
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF00E676) : const Color(0xFFFF3366),
                          shape: BoxShape.circle,
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
    );
  }

  Widget _buildAvatarFallback(String name) {
    final initial = name.trim().isNotEmpty ? name.trim().characters.first.toUpperCase() : 'U';
    return Container(
      color: AppColors.blue,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = context.isDark;
    final styleUrl = isDark ? _darkStyleUrl : _lightStyleUrl;

    if (_cachedIsDark != isDark) {
      _cachedIsDark = isDark;
      _cachedMapWidget = null;
    }

    _cachedMapWidget ??= RepaintBoundary(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          _followUser = false;
        },
        onPointerMove: (_) {
          _followUser = false;
        },
        onPointerPanZoomStart: (_) {
          _followUser = false;
        },
        child: MapLibreMap(
          initialCameraPosition: CameraPosition(
            target: _currentCenter,
            zoom: 16.0,
            bearing: 0.0,
            tilt: 0.0,
          ),
          minMaxZoomPreference: const MinMaxZoomPreference(4.0, 18.0),
          styleString: styleUrl,
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
          },
          onMapClick: (point, latLng) {
            if (!_isSharing) {
              _followUser = false;
              _currentCenter = latLng;
              _mapController?.animateCamera(
                CameraUpdate.newLatLng(latLng),
                duration: const Duration(milliseconds: 250),
              );
              _updateMeMarker(latLng);
              _fetchAddressForCoordinate(latLng);
            }
          },
          trackCameraPosition: true,
          dragEnabled: true,
          zoomGesturesEnabled: true,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: false,
          compassEnabled: false,
          compassViewPosition: CompassViewPosition.topRight,
          compassViewMargins: const Point(-2000, -2000),
          onCameraMove: (CameraPosition pos) {
            _currentBearing = pos.bearing;
            if (_headingBeamSymbol != null) {
              unawaited(_mapController?.updateSymbol(
                _headingBeamSymbol!,
                SymbolOptions(iconRotate: (_currentHeading - _currentBearing) % 360.0),
              ));
            }
          },
          myLocationEnabled: false,
          logoEnabled: false,
          attributionButtonPosition: AttributionButtonPosition.bottomRight,
          attributionButtonMargins: const Point(-2000, -2000),
          attributionButtonColor: Colors.transparent,
        ),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [

              Positioned.fill(
                child: _cachedMapWidget!,
              ),

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 14.w, top: 8.h, bottom: 6.h),
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24.r),
                              onTap: _onBack,
                              child: Padding(
                                padding: EdgeInsets.all(10.r),
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 20.r,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildActiveSharersBar(),
                    ],
                  ),
                ),
              ),

              Positioned(
                left: 18.w,
                bottom: 95.h,
                child: _buildDirectionsButton(isDark),
              ),

              Positioned(
                right: 18.w,
                bottom: 95.h,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24.r),
                      onTap: _isLoadingGps ? null : () => _initCurrentLocation(forceMoveCamera: true),
                      child: Padding(
                        padding: EdgeInsets.all(12.r),
                        child: _isLoadingGps
                            ? SizedBox(
                                width: 22.r,
                                height: 22.r,
                                child: CircularProgressIndicator(
                                  color: AppColors.blue,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : Icon(
                                Icons.my_location_rounded,
                                size: 22.r,
                                color: AppColors.blue,
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 18.w,
                right: 18.w,
                bottom: 24.h,
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton.icon(
                      onPressed: _handleToggleSharing,
                      icon: Icon(
                        _isSharing ? Icons.stop_circle_rounded : Icons.near_me_rounded,
                        size: 22.r,
                        color: Colors.white,
                      ),
                      label: Text(
                        _isSharing ? l10n.stopSharingLocation : l10n.shareThisLocation,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSharing ? const Color(0xFFE53935) : AppColors.blue,
                        elevation: 6,
                        shadowColor: (_isSharing ? const Color(0xFFE53935) : AppColors.blue)
                            .withValues(alpha: 0.45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
