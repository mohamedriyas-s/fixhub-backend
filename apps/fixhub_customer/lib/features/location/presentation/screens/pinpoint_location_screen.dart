import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/widgets/fixhub_button.dart';
import '../../../booking/data/models/address_model.dart';
import '../../../booking/presentation/providers/booking_provider.dart';
import '../../../profile/presentation/providers/address_provider.dart';

class PinpointLocationScreen extends ConsumerStatefulWidget {
  const PinpointLocationScreen({
    super.key,
    this.initialAddress,
    this.bookingId,
  });

  final AddressModel? initialAddress;
  final String? bookingId;

  /// Utility to prompt and ensure device GPS is turned on
  static Future<bool> ensureGpsEnabled(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!context.mounted) return false;
      final shouldEnable = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Text(
                'Location is OFF',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: const Text(
            'Your device location (GPS) is currently off. Please turn it on to pinpoint your exact doorstep for the technician.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Turn ON', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (shouldEnable == true) {
        await Geolocator.openLocationSettings();
        await Future.delayed(const Duration(milliseconds: 600));
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      }
      return serviceEnabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  @override
  ConsumerState<PinpointLocationScreen> createState() =>
      _PinpointLocationScreenState();
}

class _PinpointLocationScreenState
    extends ConsumerState<PinpointLocationScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // Default coordinate: Kolathur, Chennai pilot (13.1185, 80.2085)
  LatLng _currentCenter = const LatLng(13.1185, 80.2085);
  bool _isMapReady = false;
  bool _isSaving = false;
  bool _isSearching = false;
  Timer? _debounceTimer;

  String _resolvedTitle = 'Locating...';
  String _resolvedSubtitle = 'Drag the map to pinpoint your exact building';
  String? _detectedLine1;
  String? _detectedLine2;
  String? _detectedPincode;
  String? _detectedCity;
  String? _detectedState;

  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _initInitialPosition();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initInitialPosition() async {
    final addr = widget.initialAddress;

    // 1. If existing address has valid coordinates (not 0,0), start there
    if (addr?.latitude != null &&
        addr?.longitude != null &&
        (addr!.latitude! != 0 || addr.longitude! != 0)) {
      _currentCenter = LatLng(addr.latitude!, addr.longitude!);
      _resolvedTitle = addr.line1.isNotEmpty ? addr.line1 : addr.formattedAddress;
      _resolvedSubtitle = '${addr.city}, ${addr.state} - ${addr.pincode}';
      setState(() => _isMapReady = true);
      return;
    }

    // 2. Try device GPS
    try {
      final isGpsOn = await Geolocator.isLocationServiceEnabled();
      if (isGpsOn) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        _currentCenter = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {
      // Fallback: Try address text geocoding if pincode/city is available
      if (addr != null && addr.pincode.isNotEmpty) {
        try {
          final locs = await geo.Geocoding().locationFromAddress(
            '${addr.city}, ${addr.pincode}, India',
          );
          if (locs.isNotEmpty) {
            _currentCenter = LatLng(locs.first.latitude, locs.first.longitude);
          }
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() => _isMapReady = true);
      _reverseGeocode(_currentCenter);
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      _currentCenter = camera.center;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        _reverseGeocode(_currentCenter);
      });
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    try {
      final placemarks = await geo.Geocoding()
          .placemarkFromCoordinates(point.latitude, point.longitude)
          .timeout(const Duration(seconds: 4));

      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final subThoroughfare = p.subThoroughfare?.trim();
        final thoroughfare = p.thoroughfare?.trim();
        final street = p.street?.trim();
        final subLocality = p.subLocality?.trim();
        final name = p.name?.trim();
        final locality = p.locality?.trim();

        // Solution 2: Only extract house/building number for line1 if distinct & specific.
        final isGenericName = name == null ||
            name.isEmpty ||
            name == street ||
            name == thoroughfare ||
            name == subLocality ||
            name == locality ||
            name.toLowerCase() == 'unnamed road';

        final line1 = (subThoroughfare != null && subThoroughfare.isNotEmpty)
            ? subThoroughfare
            : (!isGenericName ? name : null);

        // Build Street / Area / Locality (line2) cleanly without duplicating line1.
        final roadPart = (thoroughfare != null &&
                thoroughfare.isNotEmpty &&
                thoroughfare.toLowerCase() != 'unnamed road')
            ? thoroughfare
            : (street != null &&
                    street.isNotEmpty &&
                    street.toLowerCase() != 'unnamed road' &&
                    street != line1)
                ? street
                : null;

        final line2Parts = <String>[
          if (roadPart != null && roadPart != line1) roadPart,
          if (subLocality != null &&
              subLocality.isNotEmpty &&
              subLocality != line1 &&
              subLocality != roadPart)
            subLocality,
        ];
        final line2 = line2Parts.isNotEmpty ? line2Parts.join(', ') : null;

        final titleParts = [
          if (line1 != null && line1.isNotEmpty) line1,
          if (line2 != null && line2.isNotEmpty) line2,
        ];
        final areaParts = [
          if (locality != null && locality.isNotEmpty) locality,
          if (p.subAdministrativeArea != null &&
              p.subAdministrativeArea!.isNotEmpty &&
              p.subAdministrativeArea != locality)
            p.subAdministrativeArea!,
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty)
            p.administrativeArea!,
          if (p.postalCode != null && p.postalCode!.isNotEmpty) p.postalCode!,
        ];

        setState(() {
          _detectedLine1 = line1;
          _detectedLine2 = line2;
          _resolvedTitle = titleParts.isNotEmpty
              ? titleParts.join(', ')
              : (name ?? 'Selected Location');
          _resolvedSubtitle = areaParts.join(', ');
          _detectedPincode = p.postalCode;
          _detectedCity = locality?.isNotEmpty == true ? locality : p.subAdministrativeArea;
          _detectedState = p.administrativeArea;
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _resolvedTitle = 'Pinned Location';
        _resolvedSubtitle =
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      });
    }
  }

  Future<void> _moveToCurrentGps() async {
    try {
      final isEnabled = await PinpointLocationScreen.ensureGpsEnabled(context);
      if (!isEnabled) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      final target = LatLng(pos.latitude, pos.longitude);
      _mapController.move(target, 17.0);
      _currentCenter = target;
      _reverseGeocode(target);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current GPS location')),
        );
      }
    }
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();

    // 1. If 6-digit Indian pincode, try geocoding first
    if (RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      try {
        final locs = await geo.Geocoding().locationFromAddress('$trimmed, India');
        if (locs.isNotEmpty && mounted) {
          final target = LatLng(locs.first.latitude, locs.first.longitude);
          _mapController.move(target, 16.5);
          _currentCenter = target;
          _reverseGeocode(target);
          setState(() {
            _isSearching = false;
            _searchResults = [];
          });
          return;
        }
      } catch (_) {}
    }

    // 2. Query free OpenStreetMap Nominatim API
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {'User-Agent': 'FixHubCustomerApp/1.0'},
        ),
      );

      final response = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': trimmed,
          'format': 'json',
          'addressdetails': '1',
          'limit': '5',
          'countrycodes': 'in',
        },
      );

      if (response.statusCode == 200 && response.data is List && mounted) {
        final list = (response.data as List)
            .whereType<Map<String, dynamic>>()
            .toList();

        setState(() {
          _searchResults = list;
          _isSearching = false;
        });

        if (list.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No matching locations found')),
          );
        }
        return;
      }
    } catch (_) {
      // Fallback to native geocoding
      try {
        final locs = await geo.Geocoding().locationFromAddress(trimmed);
        if (locs.isNotEmpty && mounted) {
          final target = LatLng(locs.first.latitude, locs.first.longitude);
          _mapController.move(target, 16.5);
          _currentCenter = target;
          _reverseGeocode(target);
          setState(() {
            _isSearching = false;
            _searchResults = [];
          });
          return;
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _isSearching = false);
  }

  void _selectSearchResult(Map<String, dynamic> item) {
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    if (lat != null && lon != null) {
      final target = LatLng(lat, lon);
      _mapController.move(target, 16.5);
      _currentCenter = target;

      final addr = item['address'];
      if (addr is Map) {
        final house = (addr['house_number'] ?? addr['building'])?.toString().trim();
        final road = addr['road']?.toString().trim();
        final area = (addr['neighbourhood'] ?? addr['suburb'] ?? addr['residential'])
            ?.toString()
            .trim();
        final city = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'])
            ?.toString()
            .trim();
        final state = addr['state']?.toString().trim();
        final postcode = addr['postcode']?.toString().trim();

        final line2Parts = <String>[
          if (road != null && road.isNotEmpty) road,
          if (area != null && area.isNotEmpty && area != road) area,
        ];
        final line2 = line2Parts.isNotEmpty ? line2Parts.join(', ') : null;
        final titleParts = [
          if (house != null && house.isNotEmpty) house,
          if (line2 != null && line2.isNotEmpty) line2,
        ];

        setState(() {
          _searchResults = [];
          _searchController.text = item['display_name'] ?? '';
          _detectedLine1 = (house != null && house.isNotEmpty) ? house : null;
          _detectedLine2 = line2;
          _detectedCity = city;
          _detectedState = state;
          _detectedPincode = postcode;
          if (titleParts.isNotEmpty) {
            _resolvedTitle = titleParts.join(', ');
          }
          _resolvedSubtitle = [
            if (city != null && city.isNotEmpty) city,
            if (state != null && state.isNotEmpty) state,
            if (postcode != null && postcode.isNotEmpty) postcode,
          ].join(', ');
        });
        if (line2 != null && city != null && postcode != null) {
          return;
        }
      } else {
        setState(() {
          _searchResults = [];
          _searchController.text = item['display_name'] ?? '';
        });
      }
      _reverseGeocode(target);
    }
  }

  Future<void> _confirmLocation() async {
    setState(() => _isSaving = true);

    try {
      final initial = widget.initialAddress;
      final lat = _currentCenter.latitude;
      final lng = _currentCenter.longitude;

      if (initial != null && initial.id.isNotEmpty) {
        // Update existing saved address
        final updatedAddress = initial.copyWith(
          latitude: lat,
          longitude: lng,
          line1: _detectedLine1 ?? (initial.line1.isNotEmpty ? initial.line1 : _resolvedTitle),
          line2: _detectedLine2 ?? initial.line2,
          city: _detectedCity ?? (initial.city.isNotEmpty ? initial.city : 'Chennai'),
          state: _detectedState ?? (initial.state.isNotEmpty ? initial.state : 'Tamil Nadu'),
          pincode: _detectedPincode ?? (initial.pincode.isNotEmpty ? initial.pincode : '600099'),
        );

        final result = await ref
            .read(addressesProvider.notifier)
            .updateAddress(initial.id, updatedAddress);

        if (widget.bookingId != null) {
          ref.invalidate(bookingDetailProvider(widget.bookingId!));
        }

        if (mounted) {
          Navigator.pop(context, result);
        }
      } else {
        // Return freshly selected coordinates model to the caller form
        final newAddress = AddressModel(
          id: '',
          label: 'Service Location',
          line1: _detectedLine1 ?? (_resolvedTitle == 'Locating...' ? '' : _resolvedTitle),
          line2: _detectedLine2,
          city: _detectedCity ?? (initial?.city.isNotEmpty == true ? initial!.city : 'Chennai'),
          state: _detectedState ?? (initial?.state.isNotEmpty == true ? initial!.state : 'Tamil Nadu'),
          pincode: _detectedPincode ?? (initial?.pincode.isNotEmpty == true ? initial!.pincode : '600099'),
          latitude: lat,
          longitude: lng,
        );
        if (mounted) {
          Navigator.pop(context, newAddress);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update address: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Map View ───────────────────────────────────────────
          if (_isMapReady)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentCenter,
                initialZoom: 16.5,
                maxZoom: 19.0,
                minZoom: 4.0,
                onPositionChanged: _onPositionChanged,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.fixhub.fixhub_customer',
                ),
              ],
            )
          else
            const Center(child: CircularProgressIndicator()),

          // ── Center Pinpoint Indicator ──────────────────────────
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 38.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.buttonPrimary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Exact Doorstep',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Icon(
                      Icons.location_on_rounded,
                      size: 44,
                      color: AppColors.buttonPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Top Bar & Search ───────────────────────────────────
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.elevatedSurface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.elevatedSurface,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search street, area, or pincode...',
                              hintStyle: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              suffixIcon: _isSearching
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : (_searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchResults = []);
                                          },
                                        )
                                      : null),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: _performSearch,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Results Dropdown List
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedSurface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (ctx, i) {
                        final item = _searchResults[i];
                        final name = item['display_name'] ?? '';
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          title: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          onTap: () => _selectSearchResult(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ── GPS Snap Button ────────────────────────────────────
          Positioned(
            right: AppSpacing.screenPadding,
            bottom: 185,
            child: FloatingActionButton.small(
              backgroundColor: AppColors.elevatedSurface,
              foregroundColor: AppColors.textPrimary,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: _moveToCurrentGps,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),

          // ── Bottom Location Confirmation Card ──────────────────
          Positioned(
            left: AppSpacing.screenPadding,
            right: AppSpacing.screenPadding,
            bottom: AppSpacing.bottomSafePadding,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.home_work_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _resolvedTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _resolvedSubtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FixHubButton(
                    label: 'Confirm Doorstep Location',
                    isLoading: _isSaving,
                    onPressed: _confirmLocation,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

