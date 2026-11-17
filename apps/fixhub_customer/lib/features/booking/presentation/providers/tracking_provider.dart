import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/storage/local_storage.dart';
import '../../data/datasources/tracking_remote_datasource.dart';
import 'booking_provider.dart';

part 'tracking_provider.g.dart';

// State class to hold the real-time tech location
class TrackingState {
  final LatLng? technicianLocation;
  final bool isConnected;

  const TrackingState({
    this.technicianLocation,
    this.isConnected = false,
  });

  TrackingState copyWith({
    LatLng? technicianLocation,
    bool? isConnected,
  }) {
    return TrackingState(
      technicianLocation: technicianLocation ?? this.technicianLocation,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

// Data source provider
@riverpod
TrackingRemoteDataSource trackingRemoteDataSource(Ref ref) {
  final baseUrl = AppConfig.apiBaseUrl;
  final dataSource = TrackingRemoteDataSource(baseUrl);
  
  ref.onDispose(() {
    dataSource.dispose();
  });
  
  return dataSource;
}

// The Tracking Notifier manages the socket lifecycle for a specific booking
@riverpod
class BookingTracking extends _$BookingTracking {
  StreamSubscription? _locationSub;
  StreamSubscription? _statusSub;

  @override
  TrackingState build(String bookingId) {
    _initSocket();
    return const TrackingState();
  }

  void _initSocket() async {
    final localStorage = ref.read(localStorageProvider);
    final token = await localStorage.getAccessToken();
    
    if (token == null) return;

    final dataSource = ref.read(trackingRemoteDataSourceProvider);
    
    // Connect and join room once connected
    dataSource.connect(token, onConnected: () {
      dataSource.joinBooking(bookingId);
      state = state.copyWith(isConnected: true);
    });

    // Listen to location updates
    _locationSub = dataSource.locationUpdates.listen((data) {
      if (data['bookingId'] == bookingId) {
        final lat = double.tryParse(data['latitude'].toString());
        final lng = double.tryParse(data['longitude'].toString());
        
        if (lat != null && lng != null) {
          state = state.copyWith(technicianLocation: LatLng(lat, lng));
        }
      }
    });

    // Listen to status updates
    _statusSub = dataSource.statusUpdates.listen((data) {
      if (data['bookingId'] == bookingId) {
        // Status changed on backend, invalidate the booking detail provider
        ref.invalidate(bookingDetailProvider(bookingId));
      }
    });

    ref.onDispose(() {
      _locationSub?.cancel();
      _statusSub?.cancel();
      dataSource.leaveBooking(bookingId);
    });
  }
}
