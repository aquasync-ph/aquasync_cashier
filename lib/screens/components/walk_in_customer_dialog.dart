import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme.dart';
import 'top_alert.dart';

class WalkInCustomerDialog extends StatefulWidget {
  const WalkInCustomerDialog({super.key});

  @override
  State<WalkInCustomerDialog> createState() => _WalkInCustomerDialogState();
}

class _WalkInCustomerDialogState extends State<WalkInCustomerDialog> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late MapController _mapController;

  LatLng _pinnedLocation = const LatLng(14.2289, 121.3283); // Default Victoria, Laguna
  bool _isGeocoding = false;
  bool _isReverseGeocoding = false;
  bool _isUpdatingFromMapTap = false;
  Timer? _debounceTimer;
  String? _statusMessage;
  double _currentZoom = 15.0;

  @override
  void initState() {
    super.initState();
    debugPrint('WalkInCustomerDialog initState START');
    _mapController = MapController();

    final currentCustomer = context.read<AppState>().selectedCustomer;
    final isWalkIn = currentCustomer != null && !currentCustomer.isLoyal;

    _nameController = TextEditingController(text: isWalkIn ? currentCustomer.fullName : '');
    _phoneController = TextEditingController(text: isWalkIn ? currentCustomer.phone : '');
    _addressController = TextEditingController(text: isWalkIn ? (currentCustomer.address ?? '') : '');

    if (isWalkIn && currentCustomer.latitude != null && currentCustomer.longitude != null) {
      _pinnedLocation = LatLng(currentCustomer.latitude!, currentCustomer.longitude!);
      _statusMessage = '📍 Saved Pin: ${_pinnedLocation.latitude.toStringAsFixed(5)}, ${_pinnedLocation.longitude.toStringAsFixed(5)}';
    } else if (_addressController.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _geocodeAddress(_addressController.text.trim(), moveMap: false);
        }
      });
    } else {
      _statusMessage = '📍 Default: Victoria, Laguna. Tap map or search address.';
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _safeMoveMap(LatLng pos, double zoom) {
    try {
      _mapController.move(pos, zoom);
    } catch (e) {
      debugPrint('MapController move note: $e');
    }
  }

  void _onAddressChanged(String text) {
    if (_isUpdatingFromMapTap) return;

    _debounceTimer?.cancel();
    if (text.trim().length < 3) return;

    _debounceTimer = Timer(const Duration(milliseconds: 700), () {
      _geocodeAddress(text.trim(), moveMap: true);
    });
  }

  Future<void> _geocodeAddress(String query, {bool moveMap = true}) async {
    if (query.trim().isEmpty) return;

    if (mounted) {
      setState(() {
        _isGeocoding = true;
        _statusMessage = 'Searching location on map...';
      });
    }

    final encoded = Uri.encodeComponent(query.trim());
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=1');

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'AquaSyncCashierApp/1.0 (aquasync@pos.app)',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.tryParse(data[0]['lat'].toString());
          final lon = double.tryParse(data[0]['lon'].toString());

          if (lat != null && lon != null && mounted) {
            final newPos = LatLng(lat, lon);
            setState(() {
              _pinnedLocation = newPos;
              _isGeocoding = false;
              _statusMessage = '📍 Allocated on map: ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
            });
            if (moveMap) {
              _safeMoveMap(newPos, 16.0);
              _currentZoom = 16.0;
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }

    if (mounted) {
      setState(() {
        _isGeocoding = false;
        _statusMessage = '💡 Address search completed. Tap map to fine-tune pin.';
      });
    }
  }

  Future<void> _onMapTap(LatLng point) async {
    if (mounted) {
      setState(() {
        _pinnedLocation = point;
        _isReverseGeocoding = true;
        _statusMessage = '📍 Pin placed: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      });
    }

    final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json');

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'AquaSyncCashierApp/1.0 (aquasync@pos.app)',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        if (data != null && data['display_name'] != null) {
          final displayName = data['display_name'].toString();

          _isUpdatingFromMapTap = true;
          _addressController.text = displayName;
          _isUpdatingFromMapTap = false;

          setState(() {
            _statusMessage = '📍 Updated location from map pin!';
          });
        }
      }
    } catch (e) {
      debugPrint('Reverse geocoding note: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isReverseGeocoding = false;
        });
      }
    }
  }

  void _recenterMap() {
    _safeMoveMap(_pinnedLocation, 16.0);
    setState(() {
      _currentZoom = 16.0;
    });
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(3.0, 19.0);
      _safeMoveMap(_pinnedLocation, _currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(3.0, 19.0);
      _safeMoveMap(_pinnedLocation, _currentZoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('WalkInCustomerDialog build START');
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: screenWidth > 520 ? 480 : screenWidth * 0.9,
        height: screenHeight * 0.82,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightAqua,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_walk_rounded, color: AppColors.electricCyan, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Walk-In Customer Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDarkNavy),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close_rounded, color: AppColors.grayText),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Please provide customer details and pin location for delivery:',
                style: TextStyle(fontSize: 12, color: AppColors.grayText),
              ),
              const SizedBox(height: 12),

              // 2. Scrollable Form Body
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameController,
                        autofocus: false,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'e.g., Juan Dela Cruz',
                          prefixIcon: Icon(Icons.person_rounded, color: AppColors.electricCyan),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact Number *',
                          hintText: 'e.g., 09171234567',
                          prefixIcon: Icon(Icons.phone_rounded, color: AppColors.electricCyan),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressController,
                        onChanged: _onAddressChanged,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Location / Address *',
                          hintText: 'e.g., Brgy. San Jose, City',
                          prefixIcon: const Icon(Icons.location_on_rounded, color: AppColors.electricCyan),
                          suffixIcon: IconButton(
                            icon: _isGeocoding
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricCyan),
                                  )
                                : const Icon(Icons.search_rounded, color: AppColors.electricCyan),
                            tooltip: 'Search Address on Map',
                            onPressed: () => _geocodeAddress(_addressController.text.trim(), moveMap: true),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Map Section Header & Status
                      Row(
                        children: [
                          const Icon(Icons.map_rounded, size: 16, color: AppColors.electricCyan),
                          const SizedBox(width: 6),
                          const Text(
                            'Delivery Map Location Pin',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryDarkNavy),
                          ),
                          const Spacer(),
                          if (_isGeocoding || _isReverseGeocoding)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricCyan),
                            ),
                        ],
                      ),
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _statusMessage!,
                          style: const TextStyle(fontSize: 11, color: AppColors.electricCyan, fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 8),

                      // Interactive Map Box
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.electricCyan.withValues(alpha: 0.3), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Stack(
                            children: [
                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _pinnedLocation,
                                  initialZoom: _currentZoom,
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                                  ),
                                  onTap: (tapPosition, point) => _onMapTap(point),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.aquasync.cashier.app',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: _pinnedLocation,
                                        width: 44,
                                        height: 44,
                                        alignment: Alignment.topCenter,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.location_on_rounded,
                                                color: Colors.redAccent,
                                                size: 38,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // Map Overlay Controls (Top-Right)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Column(
                                  children: [
                                    Material(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      elevation: 2,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: _recenterMap,
                                        child: const Padding(
                                          padding: EdgeInsets.all(7),
                                          child: Icon(Icons.my_location_rounded, size: 18, color: AppColors.primaryDarkNavy),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Material(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      elevation: 2,
                                      child: Column(
                                        children: [
                                          InkWell(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                            onTap: _zoomIn,
                                            child: const Padding(
                                              padding: EdgeInsets.all(7),
                                              child: Icon(Icons.add, size: 18, color: AppColors.primaryDarkNavy),
                                            ),
                                          ),
                                          const Divider(height: 1, thickness: 1),
                                          InkWell(
                                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                                            onTap: _zoomOut,
                                            child: const Padding(
                                              padding: EdgeInsets.all(7),
                                              child: Icon(Icons.remove, size: 18, color: AppColors.primaryDarkNavy),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(Icons.touch_app_rounded, size: 14, color: AppColors.grayText),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Tip: Tap anywhere on map to manually adjust delivery pin location.',
                              style: TextStyle(fontSize: 11, color: AppColors.grayText, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 3. Dialog Actions (Wrapped in Expanded to prevent unconstrained width errors)
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel', style: TextStyle(color: AppColors.grayText, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const FittedBox(
                        child: Text(
                          'SAVE DETAILS',
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                      onPressed: () async {
                        final name = _nameController.text.trim();
                        final phone = _phoneController.text.trim();
                        final address = _addressController.text.trim();

                        if (name.isEmpty || phone.isEmpty || address.isEmpty) {
                          TopAlert.show(
                            context,
                            'All fields are required for walk-in customers',
                            type: AlertType.warning,
                            title: 'Incomplete Details',
                          );
                          return;
                        }

                        FocusScope.of(context).unfocus();

                        final appState = context.read<AppState>();
                        final nav = Navigator.of(context);
                        final parentContext = context;

                        try {
                          await appState.setWalkInCustomer(
                            name,
                            phone,
                            address,
                            latitude: _pinnedLocation.latitude,
                            longitude: _pinnedLocation.longitude,
                          );

                          if (mounted) {
                            nav.pop();
                          }
                          if (parentContext.mounted) {
                            TopAlert.show(
                              parentContext,
                              'Walk-in details & map location saved for $name',
                              type: AlertType.success,
                              title: 'Customer Saved',
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            nav.pop();
                          }
                          if (parentContext.mounted) {
                            TopAlert.show(
                              parentContext,
                              'Error saving walk-in details: ${e.toString().replaceAll('Exception: ', '')}',
                              type: AlertType.error,
                              title: 'Save Failed',
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
