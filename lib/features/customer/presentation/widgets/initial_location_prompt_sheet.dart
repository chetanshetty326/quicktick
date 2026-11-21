import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/location_map_picker_sheet.dart';
import '../../domain/entities/customer_address_entity.dart';
import '../bloc/customer_bloc.dart';
import 'customer_address_sheet.dart';

class InitialLocationPromptSheet extends StatefulWidget {
  final bool animate;
  const InitialLocationPromptSheet({super.key, this.animate = true});

  /// Presents the location permission & address selection modal
  static Future<void> show(BuildContext context, {bool animate = true}) {
    final customerBloc = context.read<CustomerBloc>();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => BlocProvider.value(
        value: customerBloc,
        child: InitialLocationPromptSheet(animate: animate),
      ),
    );
  }

  @override
  State<InitialLocationPromptSheet> createState() => _InitialLocationPromptSheetState();
}

class _InitialLocationPromptSheetState extends State<InitialLocationPromptSheet>
    with SingleTickerProviderStateMixin {
  bool _isLocating = false;
  String? _errorMessage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      value: 1.0,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.animate) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.stop();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _detectLiveLocation() async {
    setState(() {
      _isLocating = true;
      _errorMessage = null;
    });

    try {
      final pos = await LocationService.getCurrentPosition(requestIfNeeded: true);
      if (pos != null && mounted) {
        final details = await LocationService.reverseGeocodeDetails(pos.latitude, pos.longitude);
        final line1 = details['line1'] ?? 'Current Location';
        final line2 = details['line2'] ?? '';
        final city = details['city'] ?? '';
        final state = details['state'] ?? '';
        final pincode = details['pincode'] ?? '';
        final formatted = details['formatted'] ?? 'Current Location';

        if (!mounted) return;

        final saved = context.read<CustomerBloc>().state.savedAddresses;
        final existingMatches = saved.where(
          (a) =>
              a.label.toUpperCase() == 'CURRENT' ||
              ((a.lat - pos.latitude).abs() < 0.0015 && (a.lng - pos.longitude).abs() < 0.0015) ||
              (a.line1.toLowerCase().trim() == line1.toLowerCase().trim() && a.pincode == pincode),
        ).toList();

        final existing = existingMatches.isNotEmpty ? existingMatches.first : null;
        if (existing != null) {
          context.read<CustomerBloc>().add(SelectAddressEvent(existing.formattedFullAddress));
          context.read<CustomerBloc>().add(LoadCustomerDataEvent(lat: pos.latitude, lng: pos.longitude));
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Delivering to: ${existing.formattedFullAddress}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
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

        if (mounted) {
          context.read<CustomerBloc>().add(AddAddressEvent(newAddr));
          context.read<CustomerBloc>().add(LoadCustomerDataEvent(lat: pos.latitude, lng: pos.longitude));
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Delivering to: $formatted',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLocating = false;
        _errorMessage = 'Could not acquire precise GPS lock. Please select your location on the map or enter manually.';
      });
    }
  }

  Future<void> _openMapPicker() async {
    final parentContext = context;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (parentContext.mounted) {
        final result = await LocationMapPickerSheet.show(parentContext);
        if (result != null && parentContext.mounted) {
          final line1 = result.street.isNotEmpty ? result.street : result.area;
          final saved = parentContext.read<CustomerBloc>().state.savedAddresses;
          final existingMatches = saved.where(
            (a) =>
                ((a.lat - result.lat).abs() < 0.0015 && (a.lng - result.lng).abs() < 0.0015) ||
                (a.line1.toLowerCase().trim() == line1.toLowerCase().trim() && a.pincode == result.pincode),
          ).toList();

          if (existingMatches.isNotEmpty) {
            final existing = existingMatches.first;
            parentContext.read<CustomerBloc>().add(SelectAddressEvent(existing.formattedFullAddress));
            parentContext.read<CustomerBloc>().add(LoadCustomerDataEvent(lat: result.lat, lng: result.lng));

            ScaffoldMessenger.of(parentContext).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                content: Text(
                  '📍 Delivering to: ${existing.formattedFullAddress}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
            return;
          }

          final newAddr = CustomerAddressEntity(
            id: '',
            label: 'MAP',
            line1: line1,
            line2: result.area != result.street ? result.area : null,
            city: result.city,
            state: result.state,
            pincode: result.pincode,
            lat: result.lat,
            lng: result.lng,
            isDefault: true,
          );

          parentContext.read<CustomerBloc>().add(AddAddressEvent(newAddr));
          parentContext.read<CustomerBloc>().add(LoadCustomerDataEvent(lat: result.lat, lng: result.lng));

          ScaffoldMessenger.of(parentContext).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(
                '📍 Delivering to: ${newAddr.formattedFullAddress}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }
      }
    });
  }

  void _openManualAddressSheet() {
    final parentContext = context;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (parentContext.mounted) {
        CustomerAddressSheet.show(parentContext);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Drag Handle
                  Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Animated Location Icon
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryContainer.withValues(alpha: 0.6),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 3),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.near_me_rounded,
                          size: 34,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title
                  const Text(
                    'Where should we deliver?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  const Text(
                    'Enable location access to discover local stores, 10–20 minute delivery, and live stock in your neighborhood.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),

                  // Primary Button: Use Current GPS Location
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLocating ? null : _detectLiveLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _isLocating
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Locating your device...',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.my_location_rounded, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Use Current Location (GPS)',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Secondary Button: Select on Map
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _isLocating ? null : _openMapPicker,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_outlined, size: 19, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(
                              'Select Location on Map',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Responsive actions: Manual Address & Skip
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      TextButton.icon(
                        onPressed: _isLocating ? null : _openManualAddressSheet,
                        icon: const Icon(Icons.edit_location_alt_outlined, size: 16, color: Color(0xFF475569)),
                        label: const Text(
                          'Enter manually',
                          style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Explore without location',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
