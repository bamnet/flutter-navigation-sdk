// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../google_maps_navigation.dart';
import '../google_maps_navigation_platform_interface.dart';
import '../types/util/circle_conversion.dart';
import '../types/util/marker_conversion.dart';
import '../types/util/polygon_conversion.dart';
import '../types/util/polyline_conversion.dart';

/// @nodoc
/// Class that handles navigation view communications.
mixin CommonNavigationViewAPI on NavigationViewAPIInterface {
  final NavigationViewApi _viewApi = NavigationViewApi();
  bool _viewApiHasBeenSetUp = false;
  final StreamController<_ViewIdEventWrapper> _viewEventStreamController =
      StreamController<_ViewIdEventWrapper>.broadcast();

  /// Keep track of marker count, used to generate marker id's
  int _markerCounter = 0;
  String _createMarkerId() {
    final String markerId = 'Marker_$_markerCounter';
    _markerCounter += 1;
    return markerId;
  }

  /// Keep track of polygon count, used to generate polygon id's
  int _polygonCounter = 0;
  String _createPolygonId() {
    final String polygonId = 'Polygon_$_polygonCounter';
    _polygonCounter += 1;
    return polygonId;
  }

  /// Keep track of polyline count, used to generate polyline id's
  int _polylineCounter = 0;
  String _createPolylineId() {
    final String polylineId = 'Polyline_$_polylineCounter';
    _polylineCounter += 1;
    return polylineId;
  }

  /// Keep track of circle count, used to generate circle id's
  int _circleCounter = 0;
  String _createCircleId() {
    final String circleId = 'Circle_$_circleCounter';
    _circleCounter += 1;
    return circleId;
  }

  /// This function ensures that the event API has been setup. This should be
  /// called when initializing navigation view.
  void ensureViewAPISetUp() {
    if (!_viewApiHasBeenSetUp) {
      NavigationViewEventApi.setup(
        NavigationViewEventApiImpl(
            viewEventStreamController: _viewEventStreamController),
      );
      _viewApiHasBeenSetUp = true;
    }
  }

  /// Builds creation params used to initialize navigation view with initial parameters.
  NavigationViewCreationOptionsDto buildNavigationViewCreationOptions(
      NavigationViewInitializationOptions initializationSettings) {
    /// Map options
    final MapOptions mapOptions = initializationSettings.mapOptions;
    final CameraPosition cameraPosition = mapOptions.cameraPosition;
    final CameraPositionDto initialCameraPosition = CameraPositionDto(
      bearing: cameraPosition.bearing,
      target: LatLngDto(
          latitude: cameraPosition.target.latitude,
          longitude: cameraPosition.target.longitude),
      tilt: cameraPosition.tilt,
      zoom: cameraPosition.zoom,
    );
    final MapOptionsDto mapOptionsMessage = MapOptionsDto(
        cameraPosition: initialCameraPosition,
        mapType: mapTypeToDto(mapOptions.mapType),
        compassEnabled: mapOptions.compassEnabled,
        rotateGesturesEnabled: mapOptions.rotateGesturesEnabled,
        scrollGesturesEnabled: mapOptions.scrollGesturesEnabled,
        tiltGesturesEnabled: mapOptions.tiltGesturesEnabled,
        zoomGesturesEnabled: mapOptions.zoomGesturesEnabled,
        scrollGesturesEnabledDuringRotateOrZoom:
            mapOptions.scrollGesturesEnabledDuringRotateOrZoom,
        mapToolbarEnabled: mapOptions.mapToolbarEnabled,
        minZoomPreference: mapOptions.minZoomPreference,
        maxZoomPreference: mapOptions.maxZoomPreference,
        zoomControlsEnabled: mapOptions.zoomControlsEnabled,
        cameraTargetBounds: mapOptions.cameraTargetBounds != null
            ? latLngBoundsToDto(mapOptions.cameraTargetBounds!)
            : null);

    // Navigation options
    final NavigationViewOptions navigationViewOptions =
        initializationSettings.navigationViewOptions;
    final NavigationViewOptionsDto navigationOptionsMessage =
        NavigationViewOptionsDto(
            navigationUIEnabled: navigationViewOptions.navigationUIEnabled);

    // Build NavigationViewCreationMessage
    return NavigationViewCreationOptionsDto(
        mapOptions: mapOptionsMessage,
        navigationViewOptions: navigationOptionsMessage);
  }

  @override
  Future<void> awaitMapReady({required int viewId}) {
    return _viewApi.awaitMapReady(viewId);
  }

  @override
  Future<bool> isMyLocationEnabled({required int viewId}) {
    return _viewApi.isMyLocationEnabled(viewId);
  }

  @override
  Future<void> enableMyLocation({required int viewId, required bool enabled}) {
    return _viewApi.enableMyLocation(viewId, enabled);
  }

  @override
  Future<MapType> getMapType({required int viewId}) async {
    final MapTypeDto mapType = await _viewApi.getMapType(viewId);
    return mapTypeFromDto(mapType);
  }

  @override
  Future<void> setMapType(
      {required int viewId, required MapType mapType}) async {
    return _viewApi.setMapType(viewId, mapTypeToDto(mapType));
  }

  @override
  Future<void> setMapStyle(int viewId, String? styleJson) async {
    try {
      // Set the given json to the viewApi or reset the map style if
      // the styleJson is null.
      return await _viewApi.setMapStyle(viewId, styleJson ?? '[]');
    } on PlatformException catch (error) {
      if (error.code == 'mapStyleError') {
        throw const MapStyleException();
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> enableMyLocationButton(
      {required int viewId, required bool enabled}) {
    return _viewApi.enableMyLocationButton(viewId, enabled);
  }

  @override
  Future<void> enableZoomGestures(
      {required int viewId, required bool enabled}) {
    return _viewApi.enableZoomGestures(viewId, enabled);
  }

  @override
  Future<void> enableZoomControls(
      {required int viewId, required bool enabled}) async {
    try {
      return await _viewApi.enableZoomControls(viewId, enabled);
    } on PlatformException catch (error) {
      if (error.code == 'notSupported') {
        throw UnsupportedError('Zoom controls are not supported on iOS.');
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> enableCompass({required int viewId, required bool enabled}) {
    return _viewApi.enableCompass(viewId, enabled);
  }

  @override
  Future<void> enableRotateGestures(
      {required int viewId, required bool enabled}) {
    return _viewApi.enableRotateGestures(viewId, enabled);
  }

  @override
  Future<void> enableScrollGestures(
      {required int viewId, required bool enabled}) {
    return _viewApi.enableScrollGestures(viewId, enabled);
  }

  @override
  Future<void> enableScrollGesturesDuringRotateOrZoom(
      {required int viewId, required bool enabled}) {
    return _viewApi.enableScrollGesturesDuringRotateOrZoom(viewId, enabled);
  }

  @override
  Future<void> enableTiltGestures(
      {required int viewId, required bool enabled}) {
    return _viewApi.enableTiltGestures(viewId, enabled);
  }

  @override
  Future<void> enableMapToolbar(
      {required int viewId, required bool enabled}) async {
    try {
      return await _viewApi.enableMapToolbar(viewId, enabled);
    } on PlatformException catch (error) {
      if (error.code == 'notSupported') {
        throw UnsupportedError('Map toolbar is not supported on iOS.');
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> enableTraffic({required int viewId, required bool enabled}) {
    return _viewApi.enableTraffic(viewId, enabled);
  }

  @override
  Future<bool> isMyLocationButtonEnabled({required int viewId}) {
    return _viewApi.isMyLocationButtonEnabled(viewId);
  }

  @override
  Future<bool> isNavigationTripProgressBarEnabled({required int viewId}) {
    return _viewApi.isNavigationTripProgressBarEnabled(viewId);
  }

  @override
  Future<bool> isZoomGesturesEnabled({required int viewId}) {
    return _viewApi.isZoomGesturesEnabled(viewId);
  }

  @override
  Future<bool> isZoomControlsEnabled({required int viewId}) async {
    try {
      return await _viewApi.isZoomControlsEnabled(viewId);
    } on PlatformException catch (error) {
      if (error.code == 'notSupported') {
        throw UnsupportedError('Zoom controls are not supported on iOS.');
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<bool> isCompassEnabled({required int viewId}) {
    return _viewApi.isCompassEnabled(viewId);
  }

  @override
  Future<bool> isRotateGesturesEnabled({required int viewId}) {
    return _viewApi.isRotateGesturesEnabled(viewId);
  }

  @override
  Future<bool> isScrollGesturesEnabled({required int viewId}) {
    return _viewApi.isScrollGesturesEnabled(viewId);
  }

  @override
  Future<bool> isScrollGesturesEnabledDuringRotateOrZoom(
      {required int viewId}) {
    return _viewApi.isScrollGesturesEnabledDuringRotateOrZoom(viewId);
  }

  @override
  Future<bool> isTiltGesturesEnabled({required int viewId}) {
    return _viewApi.isTiltGesturesEnabled(viewId);
  }

  @override
  Future<bool> isMapToolbarEnabled({required int viewId}) async {
    try {
      return await _viewApi.isMapToolbarEnabled(viewId);
    } on PlatformException catch (error) {
      if (error.code == 'notSupported') {
        throw UnsupportedError('Map toolbar is not supported on iOS.');
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<bool> isTrafficEnabled({required int viewId}) {
    return _viewApi.isTrafficEnabled(viewId);
  }

  @override
  Future<LatLng?> getMyLocation({required int viewId}) async {
    final LatLngDto? myLocation = await _viewApi.getMyLocation(viewId);
    if (myLocation == null) {
      return null;
    }
    return latLngFromDto(myLocation);
  }

  @override
  Future<CameraPosition> getCameraPosition({required int viewId}) async {
    final CameraPositionDto position = await _viewApi.getCameraPosition(
      viewId,
    );
    return cameraPositionfromDto(position);
  }

  @override
  Future<LatLngBounds> getVisibleRegion({required int viewId}) async {
    final LatLngBoundsDto bounds = await _viewApi.getVisibleRegion(
      viewId,
    );
    return LatLngBounds(
        southwest: latLngFromDto(bounds.southwest),
        northeast: latLngFromDto(bounds.northeast));
  }

  @override
  Future<void> animateCamera(
      {required int viewId,
      required CameraUpdate cameraUpdate,
      required int? duration,
      AnimationFinishedCallback? onFinished}) async {
    switch (cameraUpdate.type) {
      case CameraUpdateType.cameraPosition:
        unawaited(_viewApi
            .animateCameraToCameraPosition(viewId,
                cameraPositionToDto(cameraUpdate.cameraPosition!), duration)
            .then((bool success) => onFinished != null && Platform.isAndroid
                ? onFinished(success)
                : null));
      case CameraUpdateType.latLng:
        unawaited(_viewApi
            .animateCameraToLatLng(
                viewId, cameraUpdate.latLng!.toDto(), duration)
            .then((bool success) => onFinished != null && Platform.isAndroid
                ? onFinished(success)
                : null));
      case CameraUpdateType.latLngBounds:
        unawaited(_viewApi
            .animateCameraToLatLngBounds(
                viewId,
                latLngBoundsToDto(cameraUpdate.bounds!),
                cameraUpdate.padding!,
                duration)
            .then((bool success) => onFinished != null && Platform.isAndroid
                ? onFinished(success)
                : null));
      case CameraUpdateType.latLngZoom:
        unawaited(_viewApi
            .animateCameraToLatLngZoom(viewId, cameraUpdate.latLng!.toDto(),
                cameraUpdate.zoom!, duration)
            .then((bool success) => onFinished != null && Platform.isAndroid
                ? onFinished(success)
                : null));
      case CameraUpdateType.scrollBy:
        unawaited(_viewApi
            .animateCameraByScroll(viewId, cameraUpdate.scrollByDx!,
                cameraUpdate.scrollByDy!, duration)
            .then((bool success) => onFinished != null && Platform.isAndroid
                ? onFinished(success)
                : null));
      case CameraUpdateType.zoomBy:
        unawaited(_viewApi
            .animateCameraByZoom(viewId, cameraUpdate.zoomByAmount!,
                cameraUpdate.focus?.dx, cameraUpdate.focus?.dy, duration)
            .then((bool success) => onFinished != null && Platform.isAndroid
                ? onFinished(success)
                : null));
      case CameraUpdateType.zoomTo:
        unawaited(_viewApi
            .animateCameraToZoom(viewId, cameraUpdate.zoom!, duration)
            .then((bool success) => onFinished != null && Platform.isAndroid
                ? onFinished(success)
                : null));
    }
  }

  @override
  Future<void> moveCamera(
      {required int viewId, required CameraUpdate cameraUpdate}) async {
    switch (cameraUpdate.type) {
      case CameraUpdateType.cameraPosition:
        assert(cameraUpdate.cameraPosition != null, 'Camera position is null');
        return _viewApi.moveCameraToCameraPosition(
            viewId, cameraPositionToDto(cameraUpdate.cameraPosition!));
      case CameraUpdateType.latLng:
        return _viewApi.moveCameraToLatLng(
            viewId, cameraUpdate.latLng!.toDto());
      case CameraUpdateType.latLngBounds:
        assert(cameraUpdate.padding != null, 'Camera position is null');
        return _viewApi.moveCameraToLatLngBounds(viewId,
            latLngBoundsToDto(cameraUpdate.bounds!), cameraUpdate.padding!);
      case CameraUpdateType.latLngZoom:
        return _viewApi.moveCameraToLatLngZoom(
            viewId, cameraUpdate.latLng!.toDto(), cameraUpdate.zoom!);
      case CameraUpdateType.scrollBy:
        return _viewApi.moveCameraByScroll(
            viewId, cameraUpdate.scrollByDx!, cameraUpdate.scrollByDy!);
      case CameraUpdateType.zoomBy:
        return _viewApi.moveCameraByZoom(viewId, cameraUpdate.zoomByAmount!,
            cameraUpdate.focus?.dx, cameraUpdate.focus?.dy);
      case CameraUpdateType.zoomTo:
        return _viewApi.moveCameraToZoom(viewId, cameraUpdate.zoom!);
    }
  }

  @override
  Future<void> followMyLocation(
      {required int viewId,
      required CameraPerspective perspective,
      required double? zoomLevel}) {
    return _viewApi.followMyLocation(
        viewId, cameraPerspectiveTypeToDto(perspective), zoomLevel);
  }

  @override
  Future<void> enableNavigationTripProgressBar(
      {required int viewId, required bool enabled}) {
    return _viewApi.enableNavigationTripProgressBar(viewId, enabled);
  }

  @override
  Future<bool> isNavigationHeaderEnabled({required int viewId}) {
    return _viewApi.isNavigationHeaderEnabled(viewId);
  }

  @override
  Future<void> enableNavigationHeader(
      {required int viewId, required bool enabled}) {
    return _viewApi.enableNavigationHeader(viewId, enabled);
  }

  @override
  Future<bool> isNavigationFooterEnabled({required int viewId}) {
    return _viewApi.isNavigationFooterEnabled(viewId);
  }

  @override
  Future<void> enableNavigationFooter(
      {required int viewId, required bool enabled}) {
    return _viewApi.enableNavigationFooter(viewId, enabled);
  }

  @override
  Future<bool> isRecenterButtonEnabled({required int viewId}) {
    return _viewApi.isRecenterButtonEnabled(viewId);
  }

  @override
  Future<void> enableRecenterButton(
      {required int viewId, required bool enabled}) {
    return _viewApi.enableRecenterButton(viewId, enabled);
  }

  @override
  Future<bool> isSpeedLimitIconEnabled({required int viewId}) {
    return _viewApi.isSpeedLimitIconEnabled(viewId);
  }

  @override
  Future<void> enableSpeedLimitIcon(
      {required int viewId, required bool enable}) {
    return _viewApi.enableSpeedLimitIcon(viewId, enable);
  }

  @override
  Future<bool> isSpeedometerEnabled({required int viewId}) {
    return _viewApi.isSpeedometerEnabled(viewId);
  }

  @override
  Future<void> enableSpeedometer({required int viewId, required bool enable}) {
    return _viewApi.enableSpeedometer(viewId, enable);
  }

  @override
  Future<bool> isIncidentCardsEnabled({required int viewId}) {
    return _viewApi.isIncidentCardsEnabled(viewId);
  }

  @override
  Future<void> enableIncidentCards(
      {required int viewId, required bool enable}) {
    return _viewApi.enableIncidentCards(viewId, enable);
  }

  @override
  Future<bool> isNavigationUIEnabled({required int viewId}) {
    return _viewApi.isNavigationUIEnabled(viewId);
  }

  @override
  Future<void> enableNavigationUI(
      {required int viewId, required bool enabled}) {
    return _viewApi.enableNavigationUI(viewId, enabled);
  }

  @override
  Future<void> showRouteOverview({required int viewId}) {
    return _viewApi.showRouteOverview(viewId);
  }

  Stream<T> _unwrapEventStream<T>({required int viewId}) {
    // If event that does not
    return _viewEventStreamController.stream
        .where((_ViewIdEventWrapper wrapper) =>
            (wrapper.event is T) && wrapper.viewId == viewId)
        .map<T>((_ViewIdEventWrapper wrapper) => wrapper.event as T);
  }

  @override
  Stream<NavigationViewRecenterButtonClickedEvent>
      getNavigationRecenterButtonClickedEventStream({required int viewId}) {
    return _unwrapEventStream<NavigationViewRecenterButtonClickedEvent>(
        viewId: viewId);
  }

  @override
  Future<List<Marker?>> getMarkers({required int viewId}) async {
    final List<MarkerDto?> markers = await _viewApi.getMarkers(viewId);
    return markers
        .whereType<MarkerDto>()
        .map((MarkerDto e) => e.toMarker())
        .toList();
  }

  @override
  Future<List<Marker>> addMarkers(
      {required int viewId, required List<MarkerOptions> markerOptions}) async {
    // Convert options to pigeon format
    final List<MarkerOptionsDto> options =
        markerOptions.map((MarkerOptions opt) => opt.toDto()).toList();

    // Create marker objects with new id's
    final List<MarkerDto> markersToAdd = options
        .map((MarkerOptionsDto options) =>
            MarkerDto(markerId: _createMarkerId(), options: options))
        .toList();

    // Add markers to map
    final List<MarkerDto?> markersAdded =
        await _viewApi.addMarkers(viewId, markersToAdd);

    if (markersToAdd.length != markersAdded.length) {
      throw Exception('Could not add all markers to map view');
    }

    return markersAdded
        .whereType<MarkerDto>()
        .map((MarkerDto markerDto) => markerDto.toMarker())
        .toList();
  }

  @override
  Future<List<Marker>> updateMarkers(
      {required int viewId, required List<Marker> markers}) async {
    try {
      final List<MarkerDto> markerDtos =
          markers.map((Marker marker) => marker.toDto()).toList();
      final List<MarkerDto?> updatedMarkers =
          await _viewApi.updateMarkers(viewId, markerDtos);
      return updatedMarkers
          .whereType<MarkerDto>()
          .map((MarkerDto markerDto) => markerDto.toMarker())
          .toList();
    } on PlatformException catch (error) {
      if (error.code == 'markerNotFound') {
        throw const MarkerNotFoundException();
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> removeMarkers(
      {required int viewId, required List<Marker> markers}) async {
    try {
      final List<MarkerDto> markerDtos =
          markers.map((Marker marker) => marker.toDto()).toList();
      return await _viewApi.removeMarkers(viewId, markerDtos);
    } on PlatformException catch (error) {
      if (error.code == 'markerNotFound') {
        throw const MarkerNotFoundException();
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> clearMarkers({required int viewId}) {
    return _viewApi.clearMarkers(viewId);
  }

  @override
  Future<void> clear({required int viewId}) {
    return _viewApi.clear(viewId);
  }

  @override
  Future<List<Polygon?>> getPolygons({required int viewId}) async {
    final List<PolygonDto?> polygons = await _viewApi.getPolygons(viewId);

    return polygons
        .whereType<PolygonDto>()
        .map((PolygonDto polygon) => polygon.toPolygon())
        .toList();
  }

  @override
  Future<List<Polygon?>> addPolygons(
      {required int viewId,
      required List<PolygonOptions> polygonOptions}) async {
    // Convert options to pigeon format
    final List<PolygonOptionsDto> options =
        polygonOptions.map((PolygonOptions opt) => opt.toDto()).toList();

    // Create polygon objects with new id's
    final List<PolygonDto> polygonsToAdd = options
        .map((PolygonOptionsDto options) =>
            PolygonDto(polygonId: _createPolygonId(), options: options))
        .toList();

    // Add polygons to map
    final List<PolygonDto?> polygonsAdded =
        await _viewApi.addPolygons(viewId, polygonsToAdd);

    if (polygonsToAdd.length != polygonsAdded.length) {
      throw Exception('Could not add all polygons to map view');
    }

    return polygonsAdded
        .whereType<PolygonDto>()
        .map((PolygonDto polygon) => polygon.toPolygon())
        .toList();
  }

  @override
  Future<List<Polygon?>> updatePolygons(
      {required int viewId, required List<Polygon> polygons}) async {
    try {
      final List<PolygonDto> navigationViewPolygons =
          polygons.map((Polygon polygon) => polygon.toDto()).toList();
      final List<PolygonDto?> updatedPolygons =
          await _viewApi.updatePolygons(viewId, navigationViewPolygons);
      return updatedPolygons
          .whereType<PolygonDto>()
          .map((PolygonDto polygon) => polygon.toPolygon())
          .toList();
    } on PlatformException catch (error) {
      if (error.code == 'polygonNotFound') {
        throw const PolygonNotFoundException();
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> removePolygons(
      {required int viewId, required List<Polygon> polygons}) async {
    try {
      final List<PolygonDto> navigationViewPolygons =
          polygons.map((Polygon polygon) => polygon.toDto()).toList();
      return await _viewApi.removePolygons(viewId, navigationViewPolygons);
    } on PlatformException catch (error) {
      if (error.code == 'polygonNotFound') {
        throw const PolygonNotFoundException();
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> clearPolygons({required int viewId}) {
    return _viewApi.clearPolygons(viewId);
  }

  @override
  Future<List<Polyline?>> getPolylines({required int viewId}) async {
    final List<PolylineDto?> polylines = await _viewApi.getPolylines(viewId);

    return polylines
        .whereType<PolylineDto>()
        .map((PolylineDto polyline) => polyline.toPolyline())
        .toList();
  }

  @override
  Future<List<Polyline?>> addPolylines(
      {required int viewId,
      required List<PolylineOptions> polylineOptions}) async {
    // Convert options to pigeon format
    final List<PolylineOptionsDto> options = polylineOptions
        .map((PolylineOptions opt) => opt.toPolylineOptionsDto())
        .toList();

    // Create polyline objects with new id's
    final List<PolylineDto> polylinesToAdd = options
        .map((PolylineOptionsDto options) =>
            PolylineDto(polylineId: _createPolylineId(), options: options))
        .toList();

    // Add polylines to map
    final List<PolylineDto?> polylinesAdded =
        await _viewApi.addPolylines(viewId, polylinesToAdd);

    if (polylinesToAdd.length != polylinesAdded.length) {
      throw Exception('Could not add all polylines to map view');
    }

    return polylinesAdded
        .whereType<PolylineDto>()
        .map((PolylineDto polyline) => polyline.toPolyline())
        .toList();
  }

  @override
  Future<List<Polyline?>> updatePolylines(
      {required int viewId, required List<Polyline> polylines}) async {
    try {
      final List<PolylineDto> navigationViewPolylines = polylines
          .map((Polyline polyline) => polyline.toNavigationViewPolyline())
          .toList();
      final List<PolylineDto?> updatedPolylines =
          await _viewApi.updatePolylines(viewId, navigationViewPolylines);
      return updatedPolylines
          .whereType<PolylineDto>()
          .map((PolylineDto polyline) => polyline.toPolyline())
          .toList();
    } on PlatformException catch (error) {
      if (error.code == 'polylineNotFound') {
        throw const PolylineNotFoundException();
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> removePolylines(
      {required int viewId, required List<Polyline> polylines}) async {
    try {
      final List<PolylineDto> navigationViewPolylines = polylines
          .map((Polyline polyline) => polyline.toNavigationViewPolyline())
          .toList();
      return await _viewApi.removePolylines(viewId, navigationViewPolylines);
    } on PlatformException catch (error) {
      if (error.code == 'polylineNotFound') {
        throw const PolylineNotFoundException();
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> clearPolylines({required int viewId}) {
    return _viewApi.clearPolylines(viewId);
  }

  @override
  Future<List<Circle?>> getCircles({required int viewId}) async {
    final List<CircleDto?> circles = await _viewApi.getCircles(viewId);

    return circles
        .whereType<CircleDto>()
        .map((CircleDto circle) => circle.toCircle())
        .toList();
  }

  @override
  Future<List<Circle?>> addCircles(
      {required int viewId, required List<CircleOptions> options}) async {
    // Convert options to pigeon format
    final List<CircleOptionsDto> optionsDto =
        options.map((CircleOptions opt) => opt.toDto()).toList();

    // Create circle objects with new id's
    final List<CircleDto> circlesToAdd = optionsDto
        .map((CircleOptionsDto options) =>
            CircleDto(circleId: _createCircleId(), options: options))
        .toList();

    // Add circles to map
    final List<CircleDto?> circlesAdded =
        await _viewApi.addCircles(viewId, circlesToAdd);

    if (circlesToAdd.length != circlesAdded.length) {
      throw Exception('Could not add all circles to map view');
    }

    return circlesAdded
        .whereType<CircleDto>()
        .map((CircleDto circle) => circle.toCircle())
        .toList();
  }

  @override
  Future<List<Circle?>> updateCircles(
      {required int viewId, required List<Circle> circles}) async {
    try {
      final List<CircleDto> navigationViewCircles =
          circles.map((Circle circle) => circle.toDto()).toList();
      final List<CircleDto?> updatedCircles =
          await _viewApi.updateCircles(viewId, navigationViewCircles);

      return updatedCircles
          .whereType<CircleDto>()
          .map((CircleDto circle) => circle.toCircle())
          .toList();
    } on PlatformException catch (error) {
      if (error.code == 'circleNotFound') {
        throw const CircleNotFoundException();
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> removeCircles(
      {required int viewId, required List<Circle> circles}) async {
    try {
      final List<CircleDto> navigationViewCircles =
          circles.map((Circle circle) => circle.toDto()).toList();
      return await _viewApi.removeCircles(viewId, navigationViewCircles);
    } on PlatformException catch (error) {
      if (error.code == 'circleNotFound') {
        throw const CircleNotFoundException();
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> clearCircles({required int viewId}) {
    return _viewApi.clearCircles(viewId);
  }

  @override
  Stream<MapClickEvent> getMapClickEventStream({required int viewId}) {
    return _unwrapEventStream<MapClickEvent>(viewId: viewId);
  }

  @override
  Stream<MapLongClickEvent> getMapLongClickEventStream({required int viewId}) {
    return _unwrapEventStream<MapLongClickEvent>(viewId: viewId);
  }

  @override
  Stream<MarkerEventDto> getMarkerEventStream({required int viewId}) {
    return _unwrapEventStream<MarkerEventDto>(viewId: viewId);
  }

  @override
  Stream<MarkerDragEventDto> getMarkerDragEventStream({required int viewId}) {
    return _unwrapEventStream<MarkerDragEventDto>(viewId: viewId);
  }

  @override
  Stream<PolygonClickedEventDto> getPolygonClickedEventStream(
      {required int viewId}) {
    return _unwrapEventStream<PolygonClickedEventDto>(viewId: viewId);
  }

  @override
  Stream<PolylineClickedEventDto> getPolylineDtoClickedEventStream(
      {required int viewId}) {
    return _unwrapEventStream<PolylineClickedEventDto>(viewId: viewId);
  }

  @override
  Stream<CircleClickedEventDto> getCircleDtoClickedEventStream(
      {required int viewId}) {
    return _unwrapEventStream<CircleClickedEventDto>(viewId: viewId);
  }
}

/// Implementation for navigation view event API event handling.
class NavigationViewEventApiImpl implements NavigationViewEventApi {
  /// Initialize implementation for NavigationViewEventApi.
  const NavigationViewEventApiImpl({
    required StreamController<Object> viewEventStreamController,
  }) : _viewEventStreamController = viewEventStreamController;

  final StreamController<Object> _viewEventStreamController;

  @override
  void onRecenterButtonClicked(int viewId) {
    _viewEventStreamController.add(_ViewIdEventWrapper(
        viewId, NavigationViewRecenterButtonClickedEvent()));
  }

  @override
  void onMarkerEvent(MarkerEventDto event) {
    _viewEventStreamController.add(_ViewIdEventWrapper(event.viewId, event));
  }

  @override
  void onMarkerDragEvent(MarkerDragEventDto event) {
    _viewEventStreamController.add(_ViewIdEventWrapper(event.viewId, event));
  }

  @override
  void onPolygonClicked(PolygonClickedEventDto event) {
    _viewEventStreamController.add(_ViewIdEventWrapper(event.viewId, event));
  }

  @override
  void onMapClickEvent(int viewId, LatLngDto latLng) {
    _viewEventStreamController
        .add(_ViewIdEventWrapper(viewId, MapClickEvent(latLngFromDto(latLng))));
  }

  @override
  void onMapLongClickEvent(int viewId, LatLngDto latLng) {
    _viewEventStreamController.add(
        _ViewIdEventWrapper(viewId, MapLongClickEvent(latLngFromDto(latLng))));
  }

  @override
  void onPolylineClicked(PolylineClickedEventDto msg) {
    _viewEventStreamController.add(_ViewIdEventWrapper(msg.viewId, msg));
  }

  @override
  void onCircleClicked(CircleClickedEventDto msg) {
    _viewEventStreamController.add(_ViewIdEventWrapper(msg.viewId, msg));
  }
}

class _ViewIdEventWrapper {
  _ViewIdEventWrapper(this.viewId, this.event);

  final int viewId;
  final Object event;
}
