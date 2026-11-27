import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/widgets/fixhub_app_bar.dart';
import '../../../../core/widgets/fixhub_error_state.dart';
import '../../../../core/widgets/fixhub_status_chip.dart';
import '../providers/booking_provider.dart';
import '../providers/tracking_provider.dart';
import '../widgets/start_service_otp_card.dart';
import '../widgets/technician_contact_card.dart';

class BookingTrackingScreen extends ConsumerStatefulWidget {
  const BookingTrackingScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<BookingTrackingScreen> createState() => _BookingTrackingScreenState();
}

class _BookingTrackingScreenState extends ConsumerState<BookingTrackingScreen> {
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));
    final trackingState = ref.watch(bookingTrackingProvider(widget.bookingId));

    // Animate map when live location changes
    ref.listen<TrackingState>(bookingTrackingProvider(widget.bookingId), (previous, next) {
      if (next.technicianLocation != null && 
          previous?.technicianLocation != next.technicianLocation &&
          _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(next.technicianLocation!),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const FixHubAppBar(title: 'Live Tracking'),
      body: bookingAsync.when(
        data: (booking) {
          final isArrived = booking.statusType == BookingStatusType.arrived;
          final isEnRoute = booking.statusType == BookingStatusType.enRoute;
          final canShowTechMarker = isEnRoute && !isArrived;
          
          // Get locations
          final customerLat = booking.address?.latitude;
          final customerLng = booking.address?.longitude;
          
          final initialTechLat = booking.technician != null && booking.technician!['latitude'] != null
              ? double.tryParse(booking.technician!['latitude'].toString())
              : null;
          final initialTechLng = booking.technician != null && booking.technician!['longitude'] != null
              ? double.tryParse(booking.technician!['longitude'].toString())
              : null;

          final customerPos = (customerLat != null && customerLng != null)
              ? LatLng(customerLat, customerLng)
              : const LatLng(28.6139, 77.2090); // Default to Delhi if missing

          // Priority: Live Socket Location -> HTTP Initial Location
          final techPos = trackingState.technicianLocation ?? 
              ((initialTechLat != null && initialTechLng != null)
                  ? LatLng(initialTechLat, initialTechLng)
                  : null);

          final initialCameraPos = canShowTechMarker ? (techPos ?? customerPos) : customerPos;

          Set<Marker> markers = {
            Marker(
              markerId: const MarkerId('customer'),
              position: customerPos,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: const InfoWindow(title: 'Service Location'),
            ),
          };

          if (techPos != null && canShowTechMarker) {
            markers.add(
              Marker(
                markerId: const MarkerId('technician'),
                position: techPos,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                infoWindow: const InfoWindow(title: 'Technician'),
              ),
            );
          }

          return Column(
            children: [
              // Map View
              Expanded(
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: initialCameraPos,
                        zoom: 14,
                      ),
                      markers: markers,
                      onMapCreated: (controller) => _mapController = controller,
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    ),
                    // Floating Status Card
                    Positioned(
                      top: AppSpacing.md,
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Booking ID',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                    Text(
                                      '#${booking.id.substring(0, 8).toUpperCase()}',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                FixHubStatusChip(status: booking.statusType, label: booking.displayStatus),
                              ],
                            ),
                          ),
                          if (!isEnRoute && !isArrived) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                'Technician has not started travelling yet. Live location will appear once they are en route.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bottom Section
              Container(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isArrived ? 'Your expert has arrived' : 'Your expert is on the way',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      isArrived 
                          ? '${booking.technician?['user']?['name'] ?? 'Technician'} is at your location.'
                          : 'Expected arrival by ${TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1).format(context)}', // Mock ETA for now
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TechnicianContactCard(technicianData: booking.technician),
                    if (booking.startOtp != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      StartServiceOtpCard(
                        otp: booking.startOtp!,
                        isTechnicianArrived: isArrived,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => FixHubErrorState(
          onRetry: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
        ),
      ),
    );
  }
}
