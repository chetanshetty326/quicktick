import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/location_service.dart';
import '../bloc/delivery_bloc.dart';

/// Responsive Emergency & SOS Action Bottom Sheet for Delivery Partners.
/// Provides instant one-tap access to National Emergency (112), personal emergency contacts,
/// 24x7 QuickTick Safety Helpline, and live GPS location sharing.
class DeliverySosSheet extends StatefulWidget {
  const DeliverySosSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const DeliverySosSheet(),
    );
  }

  @override
  State<DeliverySosSheet> createState() => _DeliverySosSheetState();
}

class _DeliverySosSheetState extends State<DeliverySosSheet> {
  double _currentLat = 12.9716;
  double _currentLng = 77.5946;
  bool _isLoadingLocation = true;
  bool _sosDispatched = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final pos = await LocationService.getCurrentPosition(requestIfNeeded: false);
      if (pos != null && mounted) {
        setState(() {
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;
          _isLoadingLocation = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _dispatchSosAlert() {
    if (_sosDispatched) return;
    _sosDispatched = true;
    context.read<DeliveryBloc>().add(
          TriggerEmergencySosEvent(
            latitude: _currentLat,
            longitude: _currentLng,
            note: 'SOS triggered from Delivery Navigation Screen',
          ),
        );
  }

  Future<void> _callNumber(String phone) async {
    _dispatchSosAlert();
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _shareLiveLocation() async {
    _dispatchSosAlert();
    final message = Uri.encodeComponent(
      '🚨 EMERGENCY SOS! QuickTick Delivery Rider needs immediate assistance at: https://maps.google.com/?q=$_currentLat,$_currentLng',
    );
    final smsUri = Uri.parse('sms:?body=$message');
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isTablet = media.size.width > 600;

    return BlocBuilder<DeliveryBloc, DeliveryState>(
      builder: (context, state) {
        final emergencyPhone = state.riderKYC.emergencyPhone.trim();
        final emergencyRelation = state.riderKYC.emergencyRelation.trim();
        final hasCustomEmergencyContact = emergencyPhone.isNotEmpty && emergencyPhone != '+91';

        return Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: media.size.height * 0.85,
            maxWidth: isTablet ? 550 : double.infinity,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.25),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pull pill
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Badge & Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.redAccent, width: 2),
                        ),
                        child: const Icon(Icons.emergency_rounded, color: Colors.redAccent, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EMERGENCY SOS',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Instant safety assistance & live location dispatch',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Live GPS Coordinates Tag
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFF38BDF8), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isLoadingLocation
                                ? 'Acquiring high-accuracy GPS coordinates...'
                                : 'Live GPS: ${_currentLat.toStringAsFixed(5)}, ${_currentLng.toStringAsFixed(5)}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action 1: Call 112 (National Emergency)
                  _buildEmergencyCard(
                    title: 'Call 112 (Police / Ambulance)',
                    subtitle: 'Direct dial to National Emergency Response Center',
                    icon: Icons.local_police_rounded,
                    color: const Color(0xFFDC2626),
                    onTap: () => _callNumber('112'),
                  ),
                  const SizedBox(height: 10),

                  // Action 2: Personal Emergency Contact (from KYC)
                  _buildEmergencyCard(
                    title: hasCustomEmergencyContact
                        ? 'Call Emergency Contact (${emergencyRelation.isNotEmpty ? emergencyRelation : "Family"})'
                        : 'Call Emergency Contact',
                    subtitle: hasCustomEmergencyContact ? emergencyPhone : 'Saved contact from your KYC registration profile',
                    icon: Icons.contact_phone_rounded,
                    color: const Color(0xFFEA580C),
                    onTap: () {
                      if (hasCustomEmergencyContact) {
                        _callNumber(emergencyPhone);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No emergency contact saved. Please update in KYC settings.'),
                            backgroundColor: Color(0xFFEA580C),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  // Action 3: QuickTick 24x7 Safety Helpline
                  _buildEmergencyCard(
                    title: 'QuickTick 24x7 Safety Desk',
                    subtitle: 'Immediate dispatch support for accidents or road breakdown',
                    icon: Icons.support_agent_rounded,
                    color: const Color(0xFF2563EB),
                    onTap: () => _callNumber('18002008888'),
                  ),
                  const SizedBox(height: 10),

                  // Action 4: Share Live GPS Coordinates via SMS/WhatsApp
                  _buildEmergencyCard(
                    title: 'Share Live Location (SMS / WhatsApp)',
                    subtitle: 'Send Google Maps pin with emergency text to contacts',
                    icon: Icons.share_location_rounded,
                    color: const Color(0xFF059669),
                    onTap: _shareLiveLocation,
                  ),
                  const SizedBox(height: 16),

                  // Safety Disclaimer
                  Text(
                    '⚠️ Misuse of emergency services is prohibited. Use this tool only during accidents, medical distress, or safety emergencies.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmergencyCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
