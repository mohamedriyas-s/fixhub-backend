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
  const AddAddressScreen({super.key, this.initialAddress});

  final AddressModel? initialAddress;

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _labelController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  
  String _selectedLabelType = 'Home';
  bool _isDefault = false;
  bool _isValidating = false;
  double? _latitude;
  double? _longitude;

  bool get _isEditing => widget.initialAddress != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initialAddress;
    if (init != null) {
      final knownLabels = ['Home', 'Work'];
      if (knownLabels.contains(init.label)) {
        _selectedLabelType = init.label;
      } else {
        _selectedLabelType = 'Other';
        _labelController.text = init.label;
      }
      _addressLine1Controller.text = init.line1;
      _addressLine2Controller.text = init.line2 ?? '';
      _landmarkController.text = init.landmark ?? '';
      _cityController.text = init.city;
      _stateController.text = init.state;
      _pincodeController.text = init.pincode;
      _isDefault = init.isDefault;
      _latitude = init.latitude;
      _longitude = init.longitude;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _landmarkController.dispose();
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
        builder: (ctx) => PinpointLocationScreen(
          initialAddress: _latitude != null && _longitude != null
              ? AddressModel(
                  id: '',
                  line1: _addressLine1Controller.text,
                  line2: _addressLine2Controller.text.isEmpty
                      ? null
                      : _addressLine2Controller.text,
                  city: _cityController.text,
                  state: _stateController.text,
                  pincode: _pincodeController.text,
                  latitude: _latitude,
                  longitude: _longitude,
                )
              : null,
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _latitude = selected.latitude;
        _longitude = selected.longitude;
        if (selected.line1.isNotEmpty) {
          _addressLine1Controller.text = selected.line1;
        }
        if (selected.line2 != null && selected.line2!.isNotEmpty) {
          _addressLine2Controller.text = selected.line2!;
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

        final finalLabel = _selectedLabelType == 'Other'
            ? (_labelController.text.trim().isEmpty ? 'Other' : _labelController.text.trim())
            : _selectedLabelType;

        final addressModel = AddressModel(
          id: widget.initialAddress?.id ?? '',
          customerId: widget.initialAddress?.customerId ?? '',
          label: finalLabel,
          line1: _addressLine1Controller.text.trim(),
          line2: _addressLine2Controller.text.trim().isEmpty ? null : _addressLine2Controller.text.trim(),
          landmark: _landmarkController.text.trim().isEmpty ? null : _landmarkController.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim(),
          pincode: pincode,
          latitude: _latitude,
          longitude: _longitude,
          isDefault: _isDefault,
        );

        if (_isEditing) {
          await ref.read(addressesProvider.notifier).updateAddress(widget.initialAddress!.id, addressModel);
        } else {
          await ref.read(addressesProvider.notifier).addAddress(addressModel);
        }

        if (mounted) {
          FixHubSnackbar.success(
            context,
            _isEditing ? 'Address updated successfully' : 'Address added successfully',
          );
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
      appBar: FixHubAppBar(title: _isEditing ? 'Edit Address' : 'Add New Address'),
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

            // Quick Address Label Type Chips
            Text(
              'Save Address As',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                _buildLabelChip('Home', Icons.home_rounded),
                const SizedBox(width: AppSpacing.sm),
                _buildLabelChip('Work', Icons.work_rounded),
                const SizedBox(width: AppSpacing.sm),
                _buildLabelChip('Other', Icons.location_on_rounded),
              ],
            ),
            if (_selectedLabelType == 'Other') ...[
              const SizedBox(height: AppSpacing.sm),
              FixHubTextField(
                controller: _labelController,
                label: 'Custom Label Name',
                hint: 'e.g., Mom\'s House, Warehouse',
                validator: (value) => _selectedLabelType == 'Other' && (value == null || value.trim().isEmpty)
                    ? 'Please provide a label name'
                    : null,
              ),
            ],
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
              hint: 'e.g. MG Road, Indiranagar',
              validator: (value) => value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            FixHubTextField(
              controller: _landmarkController,
              label: 'Landmark (Optional)',
              hint: 'e.g. Near Apollo Pharmacy, Opposite Park',
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
                if (value.length != 6 || int.tryParse(value) == null) return 'Must be 6 digits';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              title: Text(
                'Set as Default Address',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                'Use this as primary address for future bookings',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
            label: _isValidating
                ? 'Validating Area...'
                : (_isEditing ? 'Update Address' : 'Save Address'),
            isLoading: isLoading || _isValidating,
            onPressed: _saveAddress,
          ),
        ),
      ),
    );
  }

  Widget _buildLabelChip(String label, IconData icon) {
    final isSelected = _selectedLabelType == label;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selected: isSelected,
      selectedColor: AppColors.buttonPrimary,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.buttonPrimary : AppColors.border,
        ),
      ),
      onSelected: (_) {
        setState(() {
          _selectedLabelType = label;
        });
      },
    );
  }
}
