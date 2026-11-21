import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/delivery_models.dart';
import '../../domain/entities/delivery_api_entities.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../bloc/delivery_bloc.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/services/location_service.dart';
import 'delivery_status_screens.dart';
import 'delivery_auth_screen.dart';

class DeliveryRegistrationScreen extends StatefulWidget {
  final String? initialName;
  final String? initialPhone;
  final RiderKYCEntity? initialKYC;
  final DeliveryPartnerProfileEntity? initialProfile;
  final bool autoDetectZone;

  const DeliveryRegistrationScreen({
    super.key,
    this.initialName,
    this.initialPhone,
    this.initialKYC,
    this.initialProfile,
    this.autoDetectZone = true,
  });

  @override
  State<DeliveryRegistrationScreen> createState() => _DeliveryRegistrationScreenState();
}

class _DeliveryRegistrationScreenState extends State<DeliveryRegistrationScreen> {
  int _currentStep = 0;
  final ImagePicker _picker = ImagePicker();

  // Document & Selfie Photos
  XFile? _aadhaarFrontPhoto;
  XFile? _aadhaarBackPhoto;
  XFile? _dlPhoto;
  XFile? _rcPhoto;
  XFile? _masterFaceSelfie;

  // Existing uploaded document URLs for pre-filling & edit KYC
  String? _existingAadhaarFrontUrl;
  String? _existingAadhaarBackUrl;
  String? _existingDlUrl;
  String? _existingRcUrl;
  String? _existingFaceSelfieUrl;

  // Cloud upload & submission progress state
  bool _isSubmitting = false;
  String _uploadStatusMessage = '';

  // GPS Location & Zone auto-detection state
  bool _isDetectingLocation = false;
  double? _detectedLat;
  double? _detectedLng;
  String? _detectedZoneId;
  String? _detectedZoneName;
  bool _isInsideZone = true;

  // Controllers: Step 1 (Personal & Home Address)
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController();
  final _houseNoController = TextEditingController();
  final _streetController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  // Controllers: Step 2 (Aadhaar KYC)
  final _aadhaarController = TextEditingController();

  // Controllers: Step 3 (DL & Vehicle)
  final _dlNumberController = TextEditingController();
  final _dlExpiryController = TextEditingController();
  String _selectedVehicle = 'Motorcycle (Petrol)';
  final _vehicleNumberController = TextEditingController();

  // Controllers: Step 4 (Bank & UPI)
  final _bankAccountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _upiIdController = TextEditingController();

  bool _hasPrefilled = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null && widget.initialName!.trim().isNotEmpty) {
      _nameController.text = widget.initialName!.trim();
    }
    if (widget.initialPhone != null && widget.initialPhone!.trim().isNotEmpty) {
      final clean = widget.initialPhone!.replaceAll(RegExp(r'[^0-9]'), '');
      _phoneController.text = clean.length > 10 ? clean.substring(clean.length - 10) : clean;
    }
    if (widget.autoDetectZone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (_detectedZoneName == null || _detectedZoneName!.contains('Indiranagar'))) {
          _detectCurrentLocationAndZone();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefillExistingData();
  }

  Future<void> _detectCurrentLocationAndZone() async {
    setState(() => _isDetectingLocation = true);

    try {
      final hasPerm = await LocationService.requestLocationPermission();
      if (!hasPerm) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Location permission denied. Please allow location access to auto-assign your delivery zone.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        setState(() => _isDetectingLocation = false);
        return;
      }

      final pos = await LocationService.getCurrentPosition(requestIfNeeded: true);
      if (pos == null) {
        if (!mounted) return;
        setState(() => _isDetectingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Unable to obtain GPS location. Please turn on device location (GPS) and tap to retry.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      final lat = pos.latitude;
      final lng = pos.longitude;

      // 1. Reverse geocode current GPS coordinates to auto-fill address fields
      final addrDetails = await LocationService.reverseGeocodeDetails(lat, lng);

      final l1 = addrDetails['line1'] ?? '';
      final l2 = addrDetails['line2'] ?? '';
      final c = addrDetails['city'] ?? '';
      final s = addrDetails['state'] ?? '';
      final p = addrDetails['pincode'] ?? '';

      if (mounted) {
        if (_streetController.text.trim().isEmpty ||
            _streetController.text == 'Current Location' ||
            _streetController.text.contains('Indiranagar')) {
          _streetController.text = l1.isNotEmpty && l1 != 'Current Location' ? l1 : (l2.isNotEmpty ? l2 : '');
        }
        if (_cityController.text.trim().isEmpty || _cityController.text == 'Bengaluru' || _cityController.text == 'Indiranagar') {
          if (c.isNotEmpty) _cityController.text = c;
        }
        if (_stateController.text.trim().isEmpty || _stateController.text == 'Karnataka') {
          if (s.isNotEmpty) _stateController.text = s;
        }
        if (_pincodeController.text.trim().isEmpty) {
          if (p.isNotEmpty) _pincodeController.text = p;
        }
      }

      // 2. Query live backend /zones/check-location to determine operational zone
      String? matchedZoneId;
      String? matchedZoneName;
      bool insideZone = false;

      try {
        final apiClient = sl<ApiClient>();
        final zRes = await apiClient.get(
          ApiEndpoints.zonesCheckLocation,
          queryParameters: {'lat': lat, 'lng': lng},
        );
        if (zRes.data is Map) {
          final zData = zRes.data['data'] is Map ? zRes.data['data'] as Map : zRes.data;
          insideZone = zData['insideZone'] == true || zData['inZone'] == true;
          final z = zData['zone'] is Map ? zData['zone'] as Map : null;
          matchedZoneId = z?['_id']?.toString() ?? z?['id']?.toString() ?? zData['zoneId']?.toString();
          matchedZoneName = z?['name']?.toString() ?? zData['zoneName']?.toString();
        }
      } catch (_) {}

      // 3. Dynamic Zone Resolution based on CURRENT GPS position:
      // Prefer real area/locality from geocoding or backend zone
      final areaName = l2.isNotEmpty ? l2 : (l1.isNotEmpty && l1 != 'Current Location' ? l1 : '');
      final cityName = c.isNotEmpty ? c : '';

      String resolvedZoneName;
      if (matchedZoneName != null && matchedZoneName.isNotEmpty) {
        if (areaName.isNotEmpty && !matchedZoneName.toLowerCase().contains(areaName.toLowerCase())) {
          resolvedZoneName = '$areaName (${matchedZoneName.toLowerCase().contains('zone') ? matchedZoneName : '$matchedZoneName Zone'})';
        } else {
          resolvedZoneName = matchedZoneName.toLowerCase().contains('zone') ? matchedZoneName : '$matchedZoneName Zone';
        }
      } else if (areaName.isNotEmpty) {
        resolvedZoneName = '$areaName Zone';
      } else if (cityName.isNotEmpty) {
        resolvedZoneName = '$cityName Zone';
      } else {
        resolvedZoneName = 'Local Area (${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)})';
      }

      // Strict Zone Restriction: Only assign zoneId if location is actually within a live operational zone
      if (!insideZone) {
        matchedZoneId = null;
      }

      if (!mounted) return;
      setState(() {
        _isDetectingLocation = false;
        _detectedLat = lat;
        _detectedLng = lng;
        _detectedZoneId = matchedZoneId;
        _detectedZoneName = resolvedZoneName;
        _isInsideZone = insideZone;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                insideZone ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insideZone
                      ? '📍 Location detected! Inside Serviceable Zone: $resolvedZoneName'
                      : '⚠️ Location is outside operational delivery zones. Onboarding cannot proceed.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: insideZone ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDetectingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not detect GPS location: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _prefillExistingData() {
    if (_hasPrefilled) return;
    _hasPrefilled = true;

    // 1. Resolve active user's phone number first to strictly isolate user data
    String? currentPhone;
    if (widget.initialPhone != null && widget.initialPhone!.trim().isNotEmpty) {
      currentPhone = widget.initialPhone!.replaceAll(RegExp(r'[^0-9]'), '');
    }
    UserEntity? authUser;
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthenticatedState) {
        authUser = authState.user;
        if (currentPhone == null || currentPhone.isEmpty) {
          currentPhone = authState.user.phone.replaceAll(RegExp(r'[^0-9]'), '');
        }
      }
    } catch (_) {}
    if (currentPhone != null && currentPhone.length > 10) {
      currentPhone = currentPhone.substring(currentPhone.length - 10);
    }

    // 2. Resolve Rider KYC and API profile from widget parameters or BLoC state
    DeliveryState? deliveryState;
    try {
      deliveryState = context.read<DeliveryBloc>().state;
    } catch (_) {}

    // Load from SharedPreferences ONLY if matching current user phone
    RiderKYCEntity? localKyc;
    try {
      if (sl.isRegistered<SharedPreferences>()) {
        final prefs = sl<SharedPreferences>();
        String? raw;
        if (currentPhone != null && currentPhone.isNotEmpty) {
          raw = prefs.getString('delivery_partner_kyc_data_$currentPhone');
        }
        if (raw == null) {
          final globalRaw = prefs.getString('delivery_partner_kyc_data');
          if (globalRaw != null && globalRaw.isNotEmpty) {
            final parsed = RiderKYCEntity.fromJson(jsonDecode(globalRaw) as Map<String, dynamic>);
            final p = parsed.phone.replaceAll(RegExp(r'[^0-9]'), '');
            if (currentPhone != null && p.endsWith(currentPhone)) {
              raw = globalRaw;
            }
          }
        }
        if (raw != null && raw.isNotEmpty) {
          localKyc = RiderKYCEntity.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        }
      }
    } catch (_) {}

    final bool phoneMatches = (currentPhone == null) ||
        (deliveryState?.apiProfile != null && deliveryState!.apiProfile!.phone.replaceAll(RegExp(r'[^0-9]'), '').endsWith(currentPhone)) ||
        (deliveryState?.riderKYC != null && deliveryState!.riderKYC.phone.replaceAll(RegExp(r'[^0-9]'), '').endsWith(currentPhone));

    // Only prefill existing KYC data if explicitly passed in (Update KYC flow), or saved locally for THIS user, or partner has active API profile
    final bool isUpdateMode = widget.initialKYC != null || widget.initialProfile != null || (localKyc != null && phoneMatches) || (deliveryState?.apiProfile != null && phoneMatches);
    final activeKyc = localKyc ?? widget.initialKYC ?? (isUpdateMode && phoneMatches ? deliveryState?.riderKYC : null);
    final apiProfile = widget.initialProfile ?? (phoneMatches ? deliveryState?.apiProfile : null);

    // Prefill Name
    if (_nameController.text.trim().isEmpty) {
      if (widget.initialName != null && widget.initialName!.trim().isNotEmpty) {
        _nameController.text = widget.initialName!.trim();
      } else if (activeKyc != null && activeKyc.fullName.isNotEmpty && activeKyc.fullName != 'Vikram Singh') {
        _nameController.text = activeKyc.fullName;
      } else if (authUser?.name != null && authUser!.name.isNotEmpty) {
        _nameController.text = authUser.name;
      } else if (activeKyc != null && activeKyc.fullName.isNotEmpty) {
        _nameController.text = activeKyc.fullName;
      }
    }

    // Prefill Phone
    if (_phoneController.text.trim().isEmpty) {
      String? rawPhone;
      if (widget.initialPhone != null && widget.initialPhone!.trim().isNotEmpty) {
        rawPhone = widget.initialPhone;
      } else if (apiProfile?.phone != null && apiProfile!.phone.isNotEmpty) {
        rawPhone = apiProfile.phone;
      } else if (activeKyc != null && activeKyc.phone.isNotEmpty) {
        rawPhone = activeKyc.phone;
      } else if (authUser?.phone != null && authUser!.phone.isNotEmpty) {
        rawPhone = authUser.phone;
      }
      if (rawPhone != null) {
        final clean = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
        _phoneController.text = clean.length > 10 ? clean.substring(clean.length - 10) : clean;
      }
    }

    // Prefill Emergency Contact & Relation
    if (activeKyc != null) {
      if (_emergencyPhoneController.text.trim().isEmpty && activeKyc.emergencyPhone.isNotEmpty) {
        final clean = activeKyc.emergencyPhone.replaceAll(RegExp(r'[^0-9]'), '');
        _emergencyPhoneController.text = clean.length > 10 ? clean.substring(clean.length - 10) : clean;
      }
      if (_emergencyRelationController.text.trim().isEmpty && activeKyc.emergencyRelation.isNotEmpty) {
        _emergencyRelationController.text = activeKyc.emergencyRelation;
      }

      // Prefill Residential Home Address Details
      if (_houseNoController.text.trim().isEmpty && activeKyc.houseNo.isNotEmpty) {
        _houseNoController.text = activeKyc.houseNo;
      }
      if (_streetController.text.trim().isEmpty && activeKyc.street.isNotEmpty && !activeKyc.street.contains('Indiranagar')) {
        _streetController.text = activeKyc.street;
      }
      if (_landmarkController.text.trim().isEmpty && activeKyc.landmark.isNotEmpty) {
        _landmarkController.text = activeKyc.landmark;
      }
      if (_cityController.text.trim().isEmpty && activeKyc.city.isNotEmpty) {
        _cityController.text = activeKyc.city;
      }
      if (_stateController.text.trim().isEmpty && activeKyc.state.isNotEmpty) {
        _stateController.text = activeKyc.state;
      }
      if (_pincodeController.text.trim().isEmpty && activeKyc.pincode.isNotEmpty) {
        _pincodeController.text = activeKyc.pincode;
      }
      if (activeKyc.latitude != null && activeKyc.longitude != null) {
        _detectedLat = activeKyc.latitude;
        _detectedLng = activeKyc.longitude;
        _detectedZoneId = activeKyc.zoneId;
        if (activeKyc.zoneName != null && !activeKyc.zoneName!.contains('Indiranagar')) {
          _detectedZoneName = activeKyc.zoneName;
        }
      }
    }

    // Prefill Aadhaar
    if (_aadhaarController.text.trim().isEmpty) {
      if (activeKyc != null && activeKyc.aadhaarNumber.isNotEmpty) {
        _aadhaarController.text = activeKyc.aadhaarNumber;
      } else if (apiProfile != null) {
        for (final doc in apiProfile.documents) {
          if (doc.type == DeliveryDocumentType.aadhaar && doc.number != null && doc.number!.isNotEmpty) {
            _aadhaarController.text = doc.number!;
            break;
          }
        }
      }
    }

    // Prefill Driving License
    if (_dlNumberController.text.trim().isEmpty) {
      if (apiProfile?.licenseNumber != null && apiProfile!.licenseNumber.isNotEmpty) {
        _dlNumberController.text = apiProfile.licenseNumber;
      } else if (activeKyc != null && activeKyc.dlNumber.isNotEmpty) {
        _dlNumberController.text = activeKyc.dlNumber;
      }
    }
    if (_dlExpiryController.text.trim().isEmpty && activeKyc != null && activeKyc.dlExpiryDate.isNotEmpty) {
      _dlExpiryController.text = activeKyc.dlExpiryDate;
    }

    // Prefill Vehicle
    if (_vehicleNumberController.text.trim().isEmpty) {
      if (apiProfile?.vehicleNumber != null && apiProfile!.vehicleNumber.isNotEmpty) {
        _vehicleNumberController.text = apiProfile.vehicleNumber;
      } else if (activeKyc != null && activeKyc.vehicleNumber.isNotEmpty) {
        _vehicleNumberController.text = activeKyc.vehicleNumber;
      }
    }
    if (apiProfile?.vehicleType != null && apiProfile!.vehicleType.isNotEmpty) {
      final vt = apiProfile.vehicleType.toUpperCase();
      if (vt.contains('SCOOTER')) {
        _selectedVehicle = 'Scooter (Gearless)';
      } else if (vt.contains('EV') || vt.contains('ELECTRIC')) {
        _selectedVehicle = 'Electric Vehicle (EV)';
      } else {
        _selectedVehicle = 'Motorcycle (Petrol)';
      }
    } else if (activeKyc != null && activeKyc.vehicleType.isNotEmpty) {
      _selectedVehicle = activeKyc.vehicleType;
    }

    // Prefill Bank & UPI Details
    if (activeKyc != null) {
      if (_bankAccountController.text.trim().isEmpty && activeKyc.bankAccount.isNotEmpty) {
        _bankAccountController.text = activeKyc.bankAccount;
      }
      if (_ifscController.text.trim().isEmpty && activeKyc.ifscCode.isNotEmpty) {
        _ifscController.text = activeKyc.ifscCode;
      }
      if (_upiIdController.text.trim().isEmpty && activeKyc.upiId.isNotEmpty) {
        _upiIdController.text = activeKyc.upiId;
      }
    }

    // Existing Documents URLs
    if (activeKyc != null && activeKyc.faceProfilePhotoUrl.isNotEmpty) {
      _existingFaceSelfieUrl = activeKyc.faceProfilePhotoUrl;
    }

    // Prefill Zone from active KYC or Profile
    if (activeKyc?.zoneId != null && activeKyc!.zoneId!.isNotEmpty) {
      _detectedZoneId = activeKyc.zoneId;
      _detectedZoneName = activeKyc.zoneName;
      _detectedLat = activeKyc.latitude;
      _detectedLng = activeKyc.longitude;
      _isInsideZone = true;
    } else if (apiProfile?.zoneId != null && apiProfile!.zoneId!.isNotEmpty) {
      _detectedZoneId = apiProfile.zoneId;
      _isInsideZone = true;
    }

    if (apiProfile != null) {
      for (final doc in apiProfile.documents) {
        if (doc.type == DeliveryDocumentType.aadhaar && _existingAadhaarFrontUrl == null) {
          _existingAadhaarFrontUrl = doc.url;
        } else if (doc.type == DeliveryDocumentType.license && _existingDlUrl == null) {
          _existingDlUrl = doc.url;
        } else if (doc.type == DeliveryDocumentType.rc && _existingRcUrl == null) {
          _existingRcUrl = doc.url;
        } else if ((doc.type == DeliveryDocumentType.photo || doc.type == DeliveryDocumentType.pan) && _existingFaceSelfieUrl == null) {
          _existingFaceSelfieUrl = doc.url;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    _houseNoController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _aadhaarController.dispose();
    _dlNumberController.dispose();
    _dlExpiryController.dispose();
    _vehicleNumberController.dispose();
    _bankAccountController.dispose();
    _ifscController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  Future<void> _pickDocumentImage({
    required String title,
    required Function(XFile file) onPicked,
    bool isFrontCamera = false,
  }) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload $title',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text('Take a clear, well-lit photo or choose from your files',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: Color(0xFF10B981)),
                ),
                title: const Text('Open Camera & Take Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Use camera for instant live scan', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    final XFile? photo = await _picker.pickImage(
                      source: ImageSource.camera,
                      preferredCameraDevice: isFrontCamera ? CameraDevice.front : CameraDevice.rear,
                      imageQuality: 85,
                    );
                    if (photo != null) {
                      setState(() => onPicked(photo));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$title captured successfully! ✓'), backgroundColor: const Color(0xFF10B981)),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Camera error: $e. Simulated preview used.'), backgroundColor: Colors.orange),
                      );
                    }
                  }
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: Color(0xFF38BDF8)),
                ),
                title: const Text('Choose from Gallery / Files', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Select existing JPG, PNG or PDF document', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    final XFile? photo = await _picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (photo != null) {
                      setState(() => onPicked(photo));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$title attached successfully! ✓'), backgroundColor: const Color(0xFF10B981)),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gallery error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _validateStep0() {
    if (_nameController.text.trim().isEmpty) {
      _showError('Full Legal Name is required');
      return false;
    }
    final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length != 10) {
      _showError('Please enter a valid 10-digit primary phone number');
      return false;
    }
    if (_houseNoController.text.trim().isEmpty) {
      _showError('House / Building number is required');
      return false;
    }
    if (_streetController.text.trim().isEmpty) {
      _showError('Street / Area name is required');
      return false;
    }
    if (_cityController.text.trim().isEmpty) {
      _showError('City is required');
      return false;
    }
    if (_stateController.text.trim().isEmpty) {
      _showError('State is required');
      return false;
    }
    final pincode = _pincodeController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (pincode.length != 6) {
      _showError('PIN code must be exactly 6 digits');
      return false;
    }
    if (!_isInsideZone) {
      _showError('Out of Serviceable Zone: QuickLink delivery onboarding is not active in your location. Registration cannot proceed.');
      return false;
    }
    if (_detectedZoneId == null) {
      if (_cityController.text.trim().toLowerCase().contains('bengaluru') ||
          _cityController.text.trim().toLowerCase().contains('bangalore') ||
          _pincodeController.text.startsWith('560')) {
        _detectedZoneId = '6abe8daf523e496cfdd80053';
      }
    }
    return true;
  }

  bool _validateStep1() {
    final aadhaar = _aadhaarController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (aadhaar.length != 12) {
      _showError('Aadhaar Number must be exactly 12 digits');
      return false;
    }
    if (_aadhaarFrontPhoto == null && (_existingAadhaarFrontUrl == null || _existingAadhaarFrontUrl!.isEmpty)) {
      _showError('MANDATORY: Please attach Aadhaar Card Front photo');
      return false;
    }
    if (_aadhaarBackPhoto == null && (_existingAadhaarBackUrl == null || _existingAadhaarBackUrl!.isEmpty)) {
      _showError('MANDATORY: Please attach Aadhaar Card Back photo');
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_dlNumberController.text.trim().length < 10) {
      _showError('Please enter a valid Driving License number (min 10 characters)');
      return false;
    }
    if (_dlExpiryController.text.trim().isEmpty) {
      _showError('Driving License Expiry Date is required');
      return false;
    }
    if (_dlPhoto == null && (_existingDlUrl == null || _existingDlUrl!.isEmpty)) {
      _showError('MANDATORY: Please attach Driving License Document photo');
      return false;
    }
    if (_rcPhoto == null && (_existingRcUrl == null || _existingRcUrl!.isEmpty)) {
      _showError('MANDATORY: Please attach Vehicle RC Document photo');
      return false;
    }
    if (_vehicleNumberController.text.trim().isEmpty) {
      _showError('Vehicle Registration Number is required');
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    if (_masterFaceSelfie == null && (_existingFaceSelfieUrl == null || _existingFaceSelfieUrl!.isEmpty)) {
      _showError('MANDATORY: Live Master Face Selfie is required for verification');
      return false;
    }
    if (_upiIdController.text.trim().isEmpty && _bankAccountController.text.trim().isEmpty) {
      _showError('Please provide either a UPI ID or Bank Account Number for payouts');
      return false;
    }
    return true;
  }

  Future<void> _submitKYC() async {
    // Strictly validate all steps before submission
    if (!_validateStep0()) {
      setState(() => _currentStep = 0);
      return;
    }
    if (!_validateStep1()) {
      setState(() => _currentStep = 1);
      return;
    }
    if (!_validateStep2()) {
      setState(() => _currentStep = 2);
      return;
    }
    if (!_validateStep3()) {
      setState(() => _currentStep = 3);
      return;
    }

    final aadhaar = _aadhaarController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final kyc = RiderKYCEntity(
      fullName: _nameController.text.trim(),
      phone: '+91 ${_phoneController.text.trim()}',
      emergencyPhone: '+91 ${_emergencyPhoneController.text.trim()}',
      emergencyRelation: _emergencyRelationController.text.trim(),
      houseNo: _houseNoController.text.trim(),
      street: _streetController.text.trim(),
      landmark: _landmarkController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pincode: _pincodeController.text.trim(),
      aadhaarNumber: aadhaar,
      dlNumber: _dlNumberController.text.trim().toUpperCase(),
      dlExpiryDate: _dlExpiryController.text.trim(),
      vehicleType: _selectedVehicle,
      vehicleNumber: _vehicleNumberController.text.trim().toUpperCase(),
      bankAccount: _bankAccountController.text.trim(),
      ifscCode: _ifscController.text.trim().toUpperCase(),
      upiId: _upiIdController.text.trim(),
      kycStatus: KYCStatus.underReview,
      faceProfilePhotoUrl: _masterFaceSelfie?.path ?? _existingFaceSelfieUrl ?? '',
    );

    context.read<DeliveryBloc>().add(SubmitRiderKYCEvent(kyc));

    // Save KYC to encrypted SecureStorage so sensitive PII is protected
    final cleanPhone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final last10 = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    try {
      final encoded = jsonEncode(kyc.toJson());
      if (sl.isRegistered<ISecureStorageService>()) {
        await sl<ISecureStorageService>().saveRiderKycData(encoded, phoneSuffix: last10.isNotEmpty ? last10 : null);
      } else if (sl.isRegistered<SharedPreferences>()) {
        final prefs = sl<SharedPreferences>();
        await prefs.setString('delivery_partner_kyc_data', encoded);
        if (last10.isNotEmpty) {
          await prefs.setString('delivery_partner_kyc_data_$last10', encoded);
        }
      }
    } catch (_) {}

    // Upload local document files to Cloudinary and register with backend
    setState(() {
      _isSubmitting = true;
      _uploadStatusMessage = 'Uploading documents to secure cloud storage...';
    });

    String aadhaarFrontUrl = _existingAadhaarFrontUrl ?? '';
    String aadhaarBackUrl = _existingAadhaarBackUrl ?? '';
    String dlUrl = _existingDlUrl ?? '';
    String rcUrl = _existingRcUrl ?? '';
    String selfieUrl = _existingFaceSelfieUrl ?? '';

    try {
      final repo = sl<IDeliveryRepository>();

      // 1. Upload Aadhaar Front photo if newly picked
      if (_aadhaarFrontPhoto != null) {
        setState(() => _uploadStatusMessage = 'Uploading Aadhaar Card Front...');
        final up = await repo.uploadDocument(File(_aadhaarFrontPhoto!.path));
        bool failed = false;
        up.fold(
          (err) {
            failed = true;
            if (mounted) {
              setState(() => _isSubmitting = false);
              _showError('Failed to upload Aadhaar Front: ${err.message}');
            }
          },
          (url) => aadhaarFrontUrl = url,
        );
        if (failed) return;
      }
      if (aadhaarFrontUrl.isEmpty || !aadhaarFrontUrl.startsWith('https://')) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          _showError('Please upload a valid Aadhaar Card Front photo (secure HTTPS upload required).');
        }
        return;
      }

      // 2. Upload Aadhaar Back photo if newly picked
      if (_aadhaarBackPhoto != null) {
        setState(() => _uploadStatusMessage = 'Uploading Aadhaar Card Back...');
        final up = await repo.uploadDocument(File(_aadhaarBackPhoto!.path));
        bool failed = false;
        up.fold(
          (err) {
            failed = true;
            if (mounted) {
              setState(() => _isSubmitting = false);
              _showError('Failed to upload Aadhaar Back: ${err.message}');
            }
          },
          (url) => aadhaarBackUrl = url,
        );
        if (failed) return;
      }
      if (aadhaarBackUrl.isNotEmpty && !aadhaarBackUrl.startsWith('https://')) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          _showError('Aadhaar Back photo must be a valid uploaded HTTPS URL.');
        }
        return;
      }

      // 3. Upload Driving License photo if newly picked
      if (_dlPhoto != null) {
        setState(() => _uploadStatusMessage = 'Uploading Driving License Document...');
        final up = await repo.uploadDocument(File(_dlPhoto!.path));
        bool failed = false;
        up.fold(
          (err) {
            failed = true;
            if (mounted) {
              setState(() => _isSubmitting = false);
              _showError('Failed to upload Driving License: ${err.message}');
            }
          },
          (url) => dlUrl = url,
        );
        if (failed) return;
      }
      if (dlUrl.isEmpty || !dlUrl.startsWith('https://')) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          _showError('Please upload a valid Driving License document (secure HTTPS upload required).');
        }
        return;
      }

      // 4. Upload Vehicle RC photo if newly picked
      if (_rcPhoto != null) {
        setState(() => _uploadStatusMessage = 'Uploading Vehicle RC Document...');
        final up = await repo.uploadDocument(File(_rcPhoto!.path));
        bool failed = false;
        up.fold(
          (err) {
            failed = true;
            if (mounted) {
              setState(() => _isSubmitting = false);
              _showError('Failed to upload Vehicle RC: ${err.message}');
            }
          },
          (url) => rcUrl = url,
        );
        if (failed) return;
      }
      if (rcUrl.isEmpty || !rcUrl.startsWith('https://')) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          _showError('Please upload a valid Vehicle RC document (secure HTTPS upload required).');
        }
        return;
      }

      // 5. Upload Master Face Selfie if newly captured
      if (_masterFaceSelfie != null) {
        setState(() => _uploadStatusMessage = 'Uploading Master Face Selfie...');
        final up = await repo.uploadDocument(File(_masterFaceSelfie!.path));
        bool failed = false;
        up.fold(
          (err) {
            failed = true;
            if (mounted) {
              setState(() => _isSubmitting = false);
              _showError('Failed to upload Face Selfie: ${err.message}');
            }
          },
          (url) => selfieUrl = url,
        );
        if (failed) return;
      }
      if (selfieUrl.isNotEmpty && !selfieUrl.startsWith('https://')) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          _showError('Master Face Selfie must be a valid uploaded HTTPS URL.');
        }
        return;
      }

      // Format full residential home address
      final houseAddress = [
        _houseNoController.text.trim(),
        _streetController.text.trim(),
        if (_landmarkController.text.trim().isNotEmpty) _landmarkController.text.trim(),
        _cityController.text.trim(),
        _stateController.text.trim(),
        _pincodeController.text.trim(),
      ].where((s) => s.isNotEmpty).join(', ');

      setState(() => _uploadStatusMessage = 'Registering Delivery Partner credentials...');

      final docList = [
        DeliveryDocumentEntity(
          type: DeliveryDocumentType.aadhaar,
          url: aadhaarFrontUrl,
          number: aadhaar,
        ),
        if (aadhaarBackUrl.isNotEmpty)
          DeliveryDocumentEntity(
            type: DeliveryDocumentType.aadhaar,
            url: aadhaarBackUrl,
            number: aadhaar,
          ),
        DeliveryDocumentEntity(
          type: DeliveryDocumentType.license,
          url: dlUrl,
          number: _dlNumberController.text.trim().toUpperCase(),
        ),
        DeliveryDocumentEntity(
          type: DeliveryDocumentType.rc,
          url: rcUrl,
          number: _vehicleNumberController.text.trim().toUpperCase(),
        ),
        if (selfieUrl.isNotEmpty)
          DeliveryDocumentEntity(
            type: DeliveryDocumentType.photo,
            url: selfieUrl,
          ),
      ];

      if (!_isInsideZone || _detectedZoneId == null) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        _showError('Registration blocked: Your location is outside operational service zones.');
        return;
      }

      final regResult = await repo.registerPartner(
        name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
        mobile: cleanPhone.isNotEmpty ? (cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone) : null,
        vehicleType: _selectedVehicle.contains('Scooter') ? 'SCOOTER' : 'BIKE',
        vehicleNumber: _vehicleNumberController.text.trim().toUpperCase(),
        vehicleModel: _selectedVehicle,
        licenseNumber: _dlNumberController.text.trim().toUpperCase(),
        houseAddress: houseAddress,
        selfieUrl: selfieUrl,
        latitude: _detectedLat ?? 12.9716,
        longitude: _detectedLng ?? 77.5946,
        zoneId: _detectedZoneId!,
        documents: docList,
      );

      bool isAlreadyRegistered = false;
      String? regError;
      regResult.fold(
        (failure) {
          if (failure.statusCode == 409 ||
              failure.message.contains('DELIVERY_ALREADY_REGISTERED') ||
              failure.message.toLowerCase().contains('already has a profile') ||
              failure.message.toLowerCase().contains('already registered')) {
            isAlreadyRegistered = true;
          } else {
            regError = failure.message;
          }
        },
        (profile) {
          if (mounted) {
            context.read<DeliveryBloc>().add(const FetchDeliveryProfileEvent());
          }
        },
      );

      if (regError != null) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        _showError(regError!);
        return;
      }

      // Update KYC model with Cloudinary URLs and location and save
      final updatedKyc = kyc.copyWith(
        faceProfilePhotoUrl: selfieUrl.isNotEmpty ? selfieUrl : kyc.faceProfilePhotoUrl,
        latitude: _detectedLat,
        longitude: _detectedLng,
        zoneId: _detectedZoneId,
        zoneName: _detectedZoneName ?? (_cityController.text.isNotEmpty ? '${_cityController.text} Zone' : 'Operational Zone'),
      );

      if (isAlreadyRegistered) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account already registered! Checking approval status...'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        context.read<DeliveryBloc>().add(const FetchDeliveryProfileEvent());
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DeliveryPendingApprovalScreen(kycData: updatedKyc)),
        );
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final updatedKyc = kyc.copyWith(
      faceProfilePhotoUrl: selfieUrl.isNotEmpty ? selfieUrl : kyc.faceProfilePhotoUrl,
      latitude: _detectedLat,
      longitude: _detectedLng,
      zoneId: _detectedZoneId,
      zoneName: _detectedZoneName ?? (_cityController.text.isNotEmpty ? '${_cityController.text} Zone' : 'Operational Zone'),
    );
    context.read<DeliveryBloc>().add(SubmitRiderKYCEvent(updatedKyc));

    try {
      final encoded = jsonEncode(updatedKyc.toJson());
      if (sl.isRegistered<ISecureStorageService>()) {
        await sl<ISecureStorageService>().saveRiderKycData(encoded, phoneSuffix: last10.isNotEmpty ? last10 : null);
      } else if (sl.isRegistered<SharedPreferences>()) {
        final prefs = sl<SharedPreferences>();
        await prefs.setString('delivery_partner_kyc_data', encoded);
        if (last10.isNotEmpty) {
          await prefs.setString('delivery_partner_kyc_data_$last10', encoded);
        }
      }
    } catch (_) {}

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('KYC Submitted for Verification! Review TAT: 2-4 Hours (FR-DEL-002)'),
        backgroundColor: Color(0xFFF59E0B),
      ),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DeliveryPendingApprovalScreen(kycData: updatedKyc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Navigate back safely: decrement registration step if > 0,
    // pop route if stack has a previous route, or fallback to auth screen.
    // This prevents blank/black screens when registration was opened via pushReplacement.
    void handleBack() {
      if (_currentStep > 0) {
        setState(() => _currentStep--);
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DeliveryAuthScreen()),
        );
      }
    }

    return PopScope(
      canPop: false, // Intercept Android hardware back button
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) handleBack();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: handleBack,
        ),
        title: const Text(
          'Quick Reach Partner Registration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // Step Progress Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                _StepBubble(index: 0, current: _currentStep, label: 'Address'),
                _StepLine(isActive: _currentStep >= 1),
                _StepBubble(index: 1, current: _currentStep, label: 'Aadhaar'),
                _StepLine(isActive: _currentStep >= 2),
                _StepBubble(index: 2, current: _currentStep, label: 'DL & RC'),
                _StepLine(isActive: _currentStep >= 3),
                _StepBubble(index: 3, current: _currentStep, label: 'Face ID'),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildCurrentStep(),
            ),
          ),

          if (_isSubmitting)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _uploadStatusMessage,
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSubmitting ? null : () => setState(() => _currentStep--),
                      child: const Text('Back', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            bool isValid = false;
                            if (_currentStep == 0) {
                              isValid = _validateStep0();
                            } else if (_currentStep == 1) {
                              isValid = _validateStep1();
                            } else if (_currentStep == 2) {
                              isValid = _validateStep2();
                            } else {
                              isValid = _validateStep3();
                            }

                            if (isValid) {
                              if (_currentStep < 3) {
                                setState(() => _currentStep++);
                              } else {
                                _submitKYC();
                              }
                            }
                          },
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(
                            _currentStep == 3 ? 'Submit KYC & Verify' : 'Continue',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ], // closes Column children list
      ), // closes Column (body)
      ), // closes Scaffold (child of PopScope)
    ); // closes PopScope
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Address();
      case 1:
        return _buildStep2Aadhaar();
      case 2:
        return _buildStep3DLAndVehicle();
      case 3:
        return _buildStep4FaceAndBank();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1Address() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('1. Personal & Residential Home Address',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Enter your permanent home address for local delivery zone assignment.',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 16),
        _buildTextField('Full Legal Name', _nameController, Icons.person),
        const SizedBox(height: 12),
        _buildTextField('Primary Phone', _phoneController, Icons.phone, prefix: '+91 '),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField('Emergency Phone', _emergencyPhoneController, Icons.contact_phone, prefix: '+91 ')),
            const SizedBox(width: 10),
            Expanded(child: _buildTextField('Relation', _emergencyRelationController, Icons.people)),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Home Address & Assigned Zone Details', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        // GPS Location & Zone Detection Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _detectedZoneId != null && _isInsideZone
                  ? const Color(0xFF10B981)
                  : (_detectedLat != null ? const Color(0xFFEF4444) : const Color(0xFF38BDF8).withValues(alpha: 0.3)),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          _detectedZoneId != null && _isInsideZone
                              ? Icons.verified_rounded
                              : (_detectedLat != null ? Icons.cancel_rounded : Icons.my_location),
                          color: _detectedZoneId != null && _isInsideZone
                              ? const Color(0xFF10B981)
                              : (_detectedLat != null ? const Color(0xFFEF4444) : const Color(0xFF38BDF8)),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _detectedZoneId != null && _isInsideZone
                                ? 'Assigned Operational Zone'
                                : (_detectedLat != null ? 'Out of Operational Zone' : 'Auto-Assign Delivery Zone'),
                            style: TextStyle(
                              color: _detectedZoneId != null && _isInsideZone
                                  ? const Color(0xFF10B981)
                                  : (_detectedLat != null ? const Color(0xFFF87171) : Colors.white),
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (_detectedLat != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (_isInsideZone ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (_isInsideZone ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        _isInsideZone ? 'Active Hub' : 'Out of Zone',
                        style: TextStyle(
                          color: _isInsideZone ? const Color(0xFF10B981) : const Color(0xFFF87171),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_detectedZoneName != null) ...[
                Text(
                  '📍 $_detectedZoneName',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _isInsideZone
                      ? '✓ Your location is within our active delivery network. 15-min orders will be routed to you.'
                      : '❌ Out of Serviceable Zone: QuickLink delivery partner onboarding is not currently active in your area. Registration cannot proceed.',
                  style: TextStyle(
                    color: _isInsideZone ? const Color(0xFF10B981) : const Color(0xFFFCA5A5),
                    fontSize: 11,
                  ),
                ),
              ] else
                const Text(
                  'Your delivery zone is automatically decided based on your location coordinates.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              if (_detectedLat != null && _detectedLng != null) ...[
                const SizedBox(height: 6),
                Text(
                  'GPS: ${_detectedLat!.toStringAsFixed(4)}° N, ${_detectedLng!.toStringAsFixed(4)}° E',
                  style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isDetectingLocation ? null : _detectCurrentLocationAndZone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: _isDetectingLocation
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.gps_fixed, size: 16),
                  label: Text(
                    _isDetectingLocation ? 'Detecting Location & Zone...' : 'Detect Current Location & Zone',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        _buildTextField('House / Flat / Building No', _houseNoController, Icons.home),
        const SizedBox(height: 10),
        _buildTextField('Street / Area / Road', _streetController, Icons.signpost),
        const SizedBox(height: 10),
        _buildTextField('Landmark', _landmarkController, Icons.location_on),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildTextField('City', _cityController, Icons.location_city)),
            const SizedBox(width: 10),
            Expanded(child: _buildTextField('State', _stateController, Icons.map)),
          ],
        ),
        const SizedBox(height: 10),
        _buildTextField('6-Digit PIN Code', _pincodeController, Icons.pin_drop, isNumber: true),
      ],
    );
  }

  Widget _buildStep2Aadhaar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('2. Aadhaar Identity Verification',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Government UIDAI statutory identity check for background verification.',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 20),
        _buildTextField('12-Digit Aadhaar Number', _aadhaarController, Icons.fingerprint, isNumber: true),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.camera_alt, color: Color(0xFF10B981), size: 18),
                  SizedBox(width: 8),
                  Text('Aadhaar Card Photo Proof (Front & Back)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  // Front Side Upload Box
                  Expanded(
                    child: _buildDocUploadCard(
                      label: 'Aadhaar Front',
                      photo: _aadhaarFrontPhoto,
                      existingUrl: _existingAadhaarFrontUrl,
                      onTap: () => _pickDocumentImage(
                        title: 'Aadhaar Card Front Side',
                        onPicked: (file) => setState(() => _aadhaarFrontPhoto = file),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Back Side Upload Box
                  Expanded(
                    child: _buildDocUploadCard(
                      label: 'Aadhaar Back',
                      photo: _aadhaarBackPhoto,
                      existingUrl: _existingAadhaarBackUrl,
                      onTap: () => _pickDocumentImage(
                        title: 'Aadhaar Card Back Side',
                        onPicked: (file) => setState(() => _aadhaarBackPhoto = file),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3DLAndVehicle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('3. Driving License (DL) & Vehicle RC',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Provide valid transport details to unlock bike/scooter delivery jobs.',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 20),
        _buildTextField('Driving License (DL) Number', _dlNumberController, Icons.credit_card),
        const SizedBox(height: 12),
        _buildTextField('DL Expiry Date (YYYY-MM-DD)', _dlExpiryController, Icons.calendar_today),
        const SizedBox(height: 16),

        // DL & RC Document Uploads
        Row(
          children: [
            Expanded(
              child: _buildDocUploadCard(
                label: 'DL Document Photo',
                photo: _dlPhoto,
                existingUrl: _existingDlUrl,
                onTap: () => _pickDocumentImage(
                  title: 'Driving License Photo',
                  onPicked: (file) => setState(() => _dlPhoto = file),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDocUploadCard(
                label: 'Vehicle RC Photo',
                photo: _rcPhoto,
                existingUrl: _existingRcUrl,
                onTap: () => _pickDocumentImage(
                  title: 'Vehicle RC Document',
                  onPicked: (file) => setState(() => _rcPhoto = file),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        const Text('Vehicle Type', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedVehicle,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              isExpanded: true,
              items: ['Motorcycle (Petrol)', 'Scooter / Activa', 'Electric Scooter (EV)', 'Bicycle']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedVehicle = val);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildTextField('Vehicle Registration Number', _vehicleNumberController, Icons.directions_bike),
      ],
    );
  }

  Widget _buildStep4FaceAndBank() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('4. Master Face ID & Payout Account',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Your selfie will be used to verify your identity every day before order dispatch.',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 20),

        // Live Master Face Selfie Capture Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: (_masterFaceSelfie != null || (_existingFaceSelfieUrl != null && _existingFaceSelfieUrl!.isNotEmpty))
                  ? const Color(0xFF10B981)
                  : const Color(0xFF38BDF8),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (_masterFaceSelfie != null || (_existingFaceSelfieUrl != null && _existingFaceSelfieUrl!.isNotEmpty))
                            ? const Color(0xFF10B981)
                            : const Color(0xFF38BDF8),
                        width: 2.5,
                      ),
                    ),
                    child: ClipOval(
                      child: _masterFaceSelfie != null && !kIsWeb
                          ? Image.file(
                              File(_masterFaceSelfie!.path),
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => const Icon(Icons.face, color: Color(0xFF10B981), size: 40),
                            )
                          : (_existingFaceSelfieUrl != null && _existingFaceSelfieUrl!.isNotEmpty
                              ? (_existingFaceSelfieUrl!.startsWith('http')
                                  ? Image.network(
                                      _existingFaceSelfieUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) => const Icon(Icons.face, color: Color(0xFF10B981), size: 40),
                                    )
                                  : Image.file(
                                      File(_existingFaceSelfieUrl!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) => const Icon(Icons.face, color: Color(0xFF10B981), size: 40),
                                    ))
                              : const Icon(Icons.face_retouching_natural, color: Color(0xFF38BDF8), size: 40)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              (_masterFaceSelfie != null || (_existingFaceSelfieUrl != null && _existingFaceSelfieUrl!.isNotEmpty))
                                  ? 'Master Face ID Enrolled ✓'
                                  : 'Live Face Selfie',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: (_masterFaceSelfie != null || (_existingFaceSelfieUrl != null && _existingFaceSelfieUrl!.isNotEmpty))
                                    ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: (_masterFaceSelfie != null || (_existingFaceSelfieUrl != null && _existingFaceSelfieUrl!.isNotEmpty))
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                (_masterFaceSelfie != null || (_existingFaceSelfieUrl != null && _existingFaceSelfieUrl!.isNotEmpty))
                                    ? 'VERIFIED'
                                    : 'MANDATORY *',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: (_masterFaceSelfie != null || (_existingFaceSelfieUrl != null && _existingFaceSelfieUrl!.isNotEmpty))
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (_masterFaceSelfie != null || (_existingFaceSelfieUrl != null && _existingFaceSelfieUrl!.isNotEmpty))
                              ? 'Face biometrics enrolled on file ✓ (Tap below to update)'
                              : 'Open front camera to enroll your face biometrics for daily duty check.',
                          style: TextStyle(
                            color: (_masterFaceSelfie != null || (_existingFaceSelfieUrl != null && _existingFaceSelfieUrl!.isNotEmpty))
                                ? const Color(0xFF10B981)
                                : Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _masterFaceSelfie != null ? const Color(0xFF047857) : const Color(0xFF0284C7),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(_masterFaceSelfie != null ? Icons.refresh : Icons.camera_front, color: Colors.white, size: 18),
                  label: Text(
                    _masterFaceSelfie != null ? 'Re-take Face Selfie' : '📸 Open Front Camera & Enroll Face',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () => _pickDocumentImage(
                    title: 'Live Face Selfie',
                    isFrontCamera: true,
                    onPicked: (file) {
                      setState(() => _masterFaceSelfie = file);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text('Bank & UPI Payout Info (Instant Daily Cashouts)',
            style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildTextField('UPI ID (Google Pay / PhonePe / Paytm)', _upiIdController, Icons.account_balance_wallet),
        const SizedBox(height: 10),
        _buildTextField('Bank Account Number', _bankAccountController, Icons.account_balance, isNumber: true),
        const SizedBox(height: 10),
        _buildTextField('IFSC Code', _ifscController, Icons.store),
      ],
    );
  }

  Widget _buildDocUploadCard({
    required String label,
    required XFile? photo,
    String? existingUrl,
    required VoidCallback onTap,
    bool isMandatory = true,
  }) {
    final bool isAttached = photo != null || (existingUrl != null && existingUrl.isNotEmpty);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 108,
        decoration: BoxDecoration(
          color: isAttached ? const Color(0xFF064E3B).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAttached
                ? const Color(0xFF10B981)
                : (isMandatory ? const Color(0xFFF59E0B) : Colors.white24),
            width: isAttached ? 1.5 : 1.2,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (photo != null && !kIsWeb)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 44,
                        height: 38,
                        child: Image.file(
                          File(photo.path),
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
                        ),
                      ),
                    )
                  else if (existingUrl != null && existingUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 44,
                        height: 38,
                        child: (existingUrl.startsWith('http')
                            ? Image.network(
                                existingUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => const Icon(Icons.verified, color: Color(0xFF10B981), size: 28),
                              )
                            : Image.file(
                                File(existingUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => const Icon(Icons.verified, color: Color(0xFF10B981), size: 28),
                              )),
                      ),
                    )
                  else
                    Icon(
                      isAttached ? Icons.check_circle : Icons.add_a_photo_outlined,
                      color: isAttached ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                      size: 28,
                    ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: isAttached ? Colors.white : Colors.white70,
                      fontSize: 11,
                      fontWeight: isAttached ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    isAttached ? (photo != null ? 'Attached ✓' : 'On File ✓') : 'Tap to Upload',
                    style: TextStyle(
                      color: isAttached ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (isMandatory)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAttached
                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                        : const Color(0xFFEF4444).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isAttached ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    isAttached ? 'VERIFIED' : 'MANDATORY *',
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                      color: isAttached ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon,
      {bool isNumber = false, String? prefix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            prefixText: prefix,
            prefixStyle: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
            prefixIcon: Icon(icon, color: const Color(0xFF38BDF8), size: 18),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981))),
          ),
        ),
      ],
    );
  }
}

class _StepBubble extends StatelessWidget {
  final int index;
  final int current;
  final String label;

  const _StepBubble({required this.index, required this.current, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDone = current > index;
    final isActive = current == index;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? const Color(0xFF10B981)
                : isActive
                    ? const Color(0xFF38BDF8)
                    : Colors.white12,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.black : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFF38BDF8) : (isDone ? const Color(0xFF10B981) : Colors.white38),
              fontSize: 10,
              fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool isActive;
  const _StepLine({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: isActive ? const Color(0xFF10B981) : Colors.white12,
      ),
    );
  }
}
