import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/location_map_picker_sheet.dart';
import '../../domain/entities/customer_address_entity.dart';
import '../bloc/customer_bloc.dart';

class CustomerAddressSheet extends StatefulWidget {
  const CustomerAddressSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<CustomerBloc>(),
        child: const CustomerAddressSheet(),
      ),
    );
  }

  @override
  State<CustomerAddressSheet> createState() => _CustomerAddressSheetState();
}

class _CustomerAddressSheetState extends State<CustomerAddressSheet> {
  bool _isAddingNew = false;
  final _formKey = GlobalKey<FormState>();

  String _selectedLabel = 'HOME';
  double _selectedLat = 12.9715987;
  double _selectedLng = 77.5945627;
  final _flatController = TextEditingController();
  final _areaController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _instructionsController = TextEditingController();
  bool _setAsDefault = true;

  @override
  void dispose() {
    _flatController.dispose();
    _areaController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _saveNewAddress() {
    if (!_formKey.currentState!.validate()) return;

    final line1 = _flatController.text.trim();
    final pincode = _pincodeController.text.trim();
    final saved = context.read<CustomerBloc>().state.savedAddresses;
    final existingIndex = saved.indexWhere(
      (a) =>
          a.label.toUpperCase() == _selectedLabel.toUpperCase() &&
          a.line1.toLowerCase().trim() == line1.toLowerCase().trim() &&
          a.pincode == pincode,
    );

    if (existingIndex != -1) {
      final existing = saved[existingIndex];
      context.read<CustomerBloc>().add(
        SelectAddressEvent(existing.formattedFullAddress),
      );
      setState(() => _isAddingNew = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Address already saved. Selected: ${existing.formattedFullAddress}',
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final newAddress = CustomerAddressEntity(
      id: '',
      label: _selectedLabel,
      line1: line1,
      line2: _areaController.text.trim(),
      landmark: _landmarkController.text.trim().isNotEmpty
          ? _landmarkController.text.trim()
          : null,
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pincode: pincode,
      lat: _selectedLat,
      lng: _selectedLng,
      isDefault: _setAsDefault,
      deliveryInstructions: _instructionsController.text.trim().isNotEmpty
          ? _instructionsController.text.trim()
          : null,
    );

    context.read<CustomerBloc>().add(AddAddressEvent(newAddress));
    setState(() => _isAddingNew = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
        maxWidth: 640,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isAddingNew
                              ? 'Add Delivery Address'
                              : 'Select Delivery Address',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _isAddingNew
                              ? 'Enter complete delivery details'
                              : 'Choose where you want items delivered',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isAddingNew)
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF334155),
                      ),
                      onPressed: () => setState(() => _isAddingNew = false),
                    )
                  else
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF334155),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Content Body
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _isAddingNew
                    ? _buildAddAddressForm()
                    : _buildAddressList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onDetectGpsLocation() async {
    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Detecting GPS location...'),
            ],
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final pos = await LocationService.getCurrentPosition(
        requestIfNeeded: true,
      );
      if (!mounted) return;

      if (pos != null) {
        final details = await LocationService.reverseGeocodeDetails(
          pos.latitude,
          pos.longitude,
        );
        if (!mounted) return;
        final line1 = details['line1'] ?? 'Current Location';
        final line2 = details['line2'] ?? '';
        final city = details['city'] ?? '';
        final state = details['state'] ?? '';
        final pincode = details['pincode'] ?? '';
        final formatted = details['formatted'] ?? 'Current Location';

        final saved = context.read<CustomerBloc>().state.savedAddresses;
        final existingMatches = saved
            .where(
              (a) =>
                  a.label.toUpperCase() == 'CURRENT' ||
                  ((a.lat - pos.latitude).abs() < 0.0015 &&
                      (a.lng - pos.longitude).abs() < 0.0015) ||
                  (a.line1.toLowerCase().trim() == line1.toLowerCase().trim() &&
                      a.pincode == pincode),
            )
            .toList();

        // Safe iterable check - prevent "Bad state: No element"
        final existing = existingMatches.isNotEmpty
            ? existingMatches.first
            : null;
        if (existing != null) {
          if (!mounted) return;
          context.read<CustomerBloc>().add(
            SelectAddressEvent(existing.formattedFullAddress),
          );
          context.read<CustomerBloc>().add(
            LoadCustomerDataEvent(lat: pos.latitude, lng: pos.longitude),
          );

          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }

          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                '📍 Delivery updated: ${existing.formattedFullAddress}',
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        final newAddr = CustomerAddressEntity(
          id: '',
          label: 'CURRENT',
          line1: line1,
          line2: line2.isNotEmpty ? line2 : null,
          city: city,
          state: state,
          pincode: pincode,
          lat: pos.latitude,
          lng: pos.longitude,
          isDefault: true,
        );

        if (!mounted) return;
        context.read<CustomerBloc>().add(AddAddressEvent(newAddr));
        context.read<CustomerBloc>().add(
          LoadCustomerDataEvent(lat: pos.latitude, lng: pos.longitude),
        );

        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('📍 Delivery updated: $formatted'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Could not access GPS. Please check location permissions or enable GPS.',
            ),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Unable to detect location. Please select or enter your address manually.',
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildAddressList() {
    return BlocBuilder<CustomerBloc, CustomerState>(
      builder: (ctx, state) {
        final addresses = CustomerAddressEntity.deduplicate(
          state.savedAddresses,
        );

        return ListView(
          padding: const EdgeInsets.all(20),
          shrinkWrap: true,
          children: [
            // Detect Live GPS Location Button
            InkWell(
              onTap: _onDetectGpsLocation,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.primary,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.my_location_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Use Current GPS Location',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Add New Address Button
            InkWell(
              onTap: () => setState(() => _isAddingNew = true),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_location_alt_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Add New Delivery Address',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (addresses.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No saved addresses yet',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Add your home or work address for lightning fast delivery',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                'SAVED ADDRESSES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              ...addresses.map((addr) {
                final isSelected =
                    state.selectedAddress == addr.formattedFullAddress ||
                    state.selectedAddress.contains(addr.line1);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _getLabelBgColor(addr.label),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getLabelIcon(addr.label),
                                    size: 12,
                                    color: _getLabelTextColor(addr.label),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    addr.label.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      color: _getLabelTextColor(addr.label),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (addr.isDefault) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'DEFAULT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          addr.line1,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (addr.line2 != null && addr.line2!.isNotEmpty)
                          Text(
                            addr.line2!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                            ),
                          ),
                        Text(
                          '${addr.city}, ${addr.state} - ${addr.pincode}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        if (addr.landmark != null &&
                            addr.landmark!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.flag_outlined,
                                size: 12,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Near ${addr.landmark}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.primary
                                        : const Color(0xFFCBD5E1),
                                  ),
                                  backgroundColor: isSelected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () {
                                  context.read<CustomerBloc>().add(
                                    SelectAddressEvent(
                                      addr.formattedFullAddress,
                                    ),
                                  );
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  isSelected ? 'Selected' : 'Deliver Here',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ),
                            if (!addr.isDefault) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Set as Default',
                                icon: const Icon(
                                  Icons.star_outline_rounded,
                                  color: Color(0xFFF59E0B),
                                  size: 20,
                                ),
                                onPressed: () {
                                  context.read<CustomerBloc>().add(
                                    SetDefaultAddressEvent(addr.id),
                                  );
                                },
                              ),
                            ],
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFEF4444),
                                size: 20,
                              ),
                              onPressed: () {
                                context.read<CustomerBloc>().add(
                                  DeleteAddressEvent(addr.id),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAddAddressForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        shrinkWrap: true,
        children: [
          // Pick on Map Action Card
          InkWell(
            onTap: () async {
              final result = await LocationMapPickerSheet.show(
                context,
                initialLat: _selectedLat,
                initialLng: _selectedLng,
              );
              if (result != null) {
                setState(() {
                  _selectedLat = result.lat;
                  _selectedLng = result.lng;
                  if (result.street.isNotEmpty) {
                    _flatController.text = result.street;
                  }
                  if (result.area.isNotEmpty) {
                    _areaController.text = result.area;
                  }
                  if (result.city.isNotEmpty) {
                    _cityController.text = result.city;
                  }
                  if (result.state.isNotEmpty) {
                    _stateController.text = result.state;
                  }
                  if (result.pincode.isNotEmpty) {
                    _pincodeController.text = result.pincode;
                  }
                });
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pick Location on Map 🗺️',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pinpoint on Leaflet map to auto-fill address & pin code',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Label Selector Chips (Home, Work, Other)
          const Text(
            'ADDRESS TYPE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildTypeChip('HOME', Icons.home_rounded),
              const SizedBox(width: 8),
              _buildTypeChip('WORK', Icons.work_rounded),
              const SizedBox(width: 8),
              _buildTypeChip('OTHER', Icons.place_rounded),
            ],
          ),
          const SizedBox(height: 16),

          // Flat / House No
          TextFormField(
            controller: _flatController,
            decoration: _inputDecoration(
              'House / Flat / Building No. *',
              Icons.apartment_rounded,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter flat or house number'
                : null,
          ),
          const SizedBox(height: 12),

          // Area / Street
          TextFormField(
            controller: _areaController,
            decoration: _inputDecoration(
              'Street / Area / Locality *',
              Icons.streetview_rounded,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter street or area'
                : null,
          ),
          const SizedBox(height: 12),

          // Landmark
          TextFormField(
            controller: _landmarkController,
            decoration: _inputDecoration(
              'Landmark (Optional)',
              Icons.flag_rounded,
            ),
          ),
          const SizedBox(height: 12),

          // City & Pincode Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _cityController,
                  decoration: _inputDecoration(
                    'City *',
                    Icons.location_city_rounded,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _pincodeController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                    'Pin Code *',
                    Icons.pin_drop_rounded,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 6) ? 'Invalid' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Delivery Instructions
          TextFormField(
            controller: _instructionsController,
            decoration: _inputDecoration(
              'Delivery Notes (e.g. Ring bell, leave at door)',
              Icons.notes_rounded,
            ),
          ),
          const SizedBox(height: 12),

          // Set as Default Checkbox
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Set as default delivery address',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            activeTrackColor: AppColors.primary,
            value: _setAsDefault,
            onChanged: (val) => setState(() => _setAsDefault = val),
          ),
          const SizedBox(height: 16),

          // Save Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
            onPressed: _saveNewAddress,
            child: const Text(
              'Save Address & Continue',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, IconData icon) {
    final isSelected = _selectedLabel == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedLabel = label),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Color _getLabelBgColor(String label) {
    switch (label.toUpperCase()) {
      case 'HOME':
        return const Color(0xFFEFF6FF);
      case 'WORK':
        return const Color(0xFFF5F3FF);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getLabelTextColor(String label) {
    switch (label.toUpperCase()) {
      case 'HOME':
        return const Color(0xFF2563EB);
      case 'WORK':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF475569);
    }
  }

  IconData _getLabelIcon(String label) {
    switch (label.toUpperCase()) {
      case 'HOME':
        return Icons.home_rounded;
      case 'WORK':
        return Icons.work_rounded;
      default:
        return Icons.place_rounded;
    }
  }
}
