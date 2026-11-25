import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/widgets/fixhub_app_bar.dart';
import '../../../../core/widgets/fixhub_button.dart';
import '../../../../core/widgets/fixhub_text_field.dart';
import '../../../../core/widgets/fixhub_snackbar.dart';
import '../../../booking/data/models/address_model.dart';
import '../providers/address_provider.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../location/presentation/screens/pinpoint_location_screen.dart';

class AddAddressScreen extends ConsumerStatefulWidget {
  const AddAddressScreen({super.key});

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _labelController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  
  bool _isDefault = false;
  bool _isValidating = false;
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _labelController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _chooseOnMap() async {
    await PinpointLocationScreen.ensureGpsEnabled(context);
    if (!mounted) return;

    final selected = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(
        builder: (ctx) => const PinpointLocationScreen(),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _latitude = selected.latitude;
        _longitude = selected.longitude;
        if (selected.line1.isNotEmpty && _addressLine1Controller.text.isEmpty) {
          _addressLine1Controller.text = selected.line1;
        }
        if (selected.city.isNotEmpty) {
          _cityController.text = selected.city;
        }
        if (selected.state.isNotEmpty) {
          _stateController.text = selected.state;
        }
        if (selected.pincode.isNotEmpty) {
          _pincodeController.text = selected.pincode;
        }
      });
      FixHubSnackbar.success(context, 'Doorstep location pinned');
    }
  }

  void _saveAddress() async {
    if (_formKey.currentState?.validate() ?? false) {
      final pincode = _pincodeController.text.trim();
      setState(() => _isValidating = true);

      try {
        final areaResult = await ref
            .read(locationRepositoryProvider)
            .validateServiceArea(pincode, lat: _latitude, lng: _longitude);

        if (!areaResult.isServiceable) {
          if (mounted) {
            FixHubSnackbar.error(
              context,
              'FixHub does not serve pincode $pincode yet. Please enter an address within our active service areas.',
            );
          }
          return;
        }

        final addressModel = AddressModel(
          id: '',
          customerId: '',
          label: _labelController.text.trim(),
          line1: _addressLine1Controller.text.trim(),
          line2: _addressLine2Controller.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim(),
          pincode: pincode,
          latitude: _latitude,
          longitude: _longitude,
          isDefault: _isDefault,
        );

        await ref.read(addressesProvider.notifier).addAddress(addressModel);

        if (mounted) {
          FixHubSnackbar.success(context, 'Address added successfully');
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          final cleanErr = e
              .toString()
              .replaceAll(RegExp(r'^(Exception:\s*|DioException:\s*)'), '');
          FixHubSnackbar.error(context, cleanErr);
        }
      } finally {
        if (mounted) {
          setState(() => _isValidating = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(addressesProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const FixHubAppBar(title: 'Add New Address'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            InkWell(
              onTap: _chooseOnMap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _latitude != null ? AppColors.success : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _latitude != null
                            ? AppColors.success.withValues(alpha: 0.12)
                            : AppColors.elevatedSurface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _latitude != null
                            ? Icons.check_circle_rounded
                            : Icons.map_rounded,
                        color: _latitude != null
                            ? AppColors.success
                            : AppColors.textPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _latitude != null
                                ? 'Doorstep Location Pinned'
                                : 'Pinpoint on Map',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _latitude != null
                                ? 'Coordinates: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                                : 'Tap to select exact location with pin',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FixHubTextField(
              controller: _labelController,
              label: 'Label (e.g., Home, Work)',
              hint: 'Home',
              validator: (value) => value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            FixHubTextField(
              controller: _addressLine1Controller,
              label: 'Flat / House No. / Building',
              hint: 'e.g. 101, Signature Towers',
              validator: (value) => value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            FixHubTextField(
              controller: _addressLine2Controller,
              label: 'Street / Area / Locality',
              hint: 'e.g. MG Road',
              validator: (value) => value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: FixHubTextField(
                    controller: _cityController,
                    label: 'City',
                    hint: 'e.g. Bangalore',
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FixHubTextField(
                    controller: _stateController,
                    label: 'State',
                    hint: 'e.g. Karnataka',
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FixHubTextField(
              controller: _pincodeController,
              label: 'Pincode',
              hint: 'e.g. 560001',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                if (value.length != 6) return 'Must be 6 digits';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              title: Text(
                'Set as Default Address',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              value: _isDefault,
              onChanged: (val) {
                setState(() {
                  _isDefault = val;
                });
              },
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.buttonPrimary,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: FixHubButton(
            label: _isValidating ? 'Validating Area...' : 'Save Address',
            isLoading: isLoading || _isValidating,
            onPressed: _saveAddress,
          ),
        ),
      ),
    );
  }
}
