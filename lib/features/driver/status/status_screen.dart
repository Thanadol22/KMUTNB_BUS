import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../core/services/firebase_auth.dart';
import '../../../core/services/firebase_database.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/constants/app_constants.dart';
import 'dart:async';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen>
    with SingleTickerProviderStateMixin {
  String? _currentStatusCode;
  String? _busDocId;
  String? _licensePlate;
  String? _busType;
  String? _busBrand;
  int? _busSeats;
  double? _batteryLevel;
  String? _currentBusId;
  bool _isLoading = true;
  bool _isSaving = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription? _trackingSubscription;

  final List<String> _statusCodes = [
    'status_ready',
    'status_stop',
    'status_maintain',
    'status_fuel',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _trackingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final uid = await AuthService.getCurrentUserId();
      if (uid == null) return;

      Map<String, dynamic>? userData;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        userData = userDoc.data();
      }

      // 2. Load Bus Info (Status, License Plate, Bus ID)
      final busSnapshot = await DatabaseService().getBusForDriver(uid);
      if (busSnapshot != null && busSnapshot.docs.isNotEmpty) {
        final busDoc = busSnapshot.docs.first;
        final busData = busDoc.data() as Map<String, dynamic>;

        final status = busData['status']?.toString() ?? AppConstants.statusReady;
        final statusCode = AppConstants.statusTextToCode[status] ?? AppConstants.defaultStatusCode;

        final brand = busData['bus_brand']?.toString() ?? userData?['bus_brand']?.toString();
        final type = busData['bus_type']?.toString() ?? userData?['bus_type']?.toString();
        
        int? seats;
        final seatsRaw = busData['bus_seats'] ?? userData?['bus_seats'];
        if (seatsRaw is int) {
          seats = seatsRaw;
        } else if (seatsRaw != null) {
          seats = int.tryParse(seatsRaw.toString());
        }

        if (mounted) {
          setState(() {
            _busBrand = brand;
            _busType = type;
            _busSeats = seats;
            _currentStatusCode = statusCode;
            _busDocId = busDoc.id;
            _licensePlate = busData['license_plate']?.toString();
            _currentBusId = busData['bus_id']?.toString() ?? busDoc.id;
            _isLoading = false;
          });

          if (_currentBusId != null) {
            _listenToTrackingData(_currentBusId!);
          }
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenToTrackingData(String busId) {
    _trackingSubscription?.cancel();
    final dbRef = FirebaseDatabase.instance
        .ref()
        .child('tracking')
        .child(_normalizeBusId(busId));

    _trackingSubscription = dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) return;

      final nodeMap = _safeMap(data);
      final boardData = _extractLatestBoardData(nodeMap);

      if (mounted) {
        setState(() {
          // Check in nested data first, then root if not found. Prioritize 'battery_percent'.
          final batt =
              boardData['battery_percent'] ??
              boardData['battery'] ??
              boardData['batt'] ??
              nodeMap['battery_percent'] ??
              nodeMap['battery'] ??
              nodeMap['batt'];
          if (batt != null) {
            _batteryLevel = _toDouble(batt);
          }
        });
      }
    });
  }

  String _normalizeBusId(String rawBusId) {
    final cleaned = rawBusId.replaceAll(RegExp(r'[\s_\-]+'), '').toUpperCase();
    return cleaned.replaceFirst(RegExp(r'^BUSO(?=\d)'), 'BUS0');
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Map<String, dynamic> _safeMap(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) {
      final map = <String, dynamic>{};
      raw.forEach((k, v) => map[k.toString()] = v);
      return map;
    }
    if (raw is List) {
      final map = <String, dynamic>{};
      for (int i = 0; i < raw.length; i++) {
        if (raw[i] != null) {
          map[i.toString()] = raw[i];
        }
      }
      return map;
    }
    return {};
  }

  Map<String, dynamic> _extractLatestBoardData(Map<String, dynamic> nodeMap) {
    bool hasNestedMap = nodeMap.values.any((v) => v is Map);
    if (hasNestedMap) {
      final mapKeys = nodeMap.keys.where((k) => nodeMap[k] is Map).toList()
        ..sort();
      if (mapKeys.isNotEmpty) {
        return Map<String, dynamic>.from(nodeMap[mapKeys.last] as Map);
      }
    } else {
      return nodeMap;
    }
    return {};
  }

  Future<void> _changeStatus(String newStatusCode) async {
    if (_currentStatusCode == newStatusCode || _isSaving) return;

    setState(() {
      _currentStatusCode = newStatusCode;
      _isSaving = true;
    });

    try {
      final statusThai = AppConstants.statusCodeToText[newStatusCode] ?? AppConstants.statusReady;

      if (_busDocId != null) {
        await FirebaseFirestore.instance
            .collection('buses')
            .doc(_busDocId!)
            .update({'status': statusThai});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context, 'status_updated')} $statusThai',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _updateVehicleField(String field, dynamic value) async {
    try {
      final uid = await AuthService.getCurrentUserId();
      if (uid == null) return;

      if (['license_plate', 'bus_brand', 'bus_type', 'bus_seats'].contains(field) && _busDocId != null) {
        await FirebaseFirestore.instance
            .collection('buses')
            .doc(_busDocId!)
            .update({field: value});
      } else {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          field: value,
        });
      }
      _loadData();
    } catch (e) {
      debugPrint('Error updating field: $e');
    }
  }

  void _showEditDialog(
    String title,
    String field,
    String currentVal, {
    bool isNumber = false,
    bool isDropdown = false,
  }) {
    final controller = TextEditingController(text: currentVal);
    String? selectedType = currentVal;
    final busTypes = AppConstants.busTypeOptions;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${AppLocalizations.of(context, 'edit_prefix')} ${AppLocalizations.of(context, title)}',
        ),
        content: isDropdown
            ? DropdownButtonFormField<String>(
                initialValue: busTypes.contains(selectedType) ? selectedType : null,
                items: busTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(AppLocalizations.of(context, t))))
                    .toList(),
                onChanged: (val) => setState(() => selectedType = val),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              )
            : TextField(
                controller: controller,
                keyboardType: isNumber
                    ? TextInputType.number
                    : TextInputType.text,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                autofocus: true,
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final newVal = isDropdown ? selectedType : controller.text.trim();
              if (newVal != null && newVal != currentVal) {
                _updateVehicleField(
                  field,
                  isNumber ? int.tryParse(newVal) : newVal,
                );
              }
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context, 'save_data')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context, 'manage_status'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFF4009),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(40),
                          bottomRight: Radius.circular(40),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: _getStatusColor(_currentStatusCode ?? ''),
                            width: 4,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _getStatusColor(_currentStatusCode ?? '').withOpacity(isDark ? 0.2 : 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.only(bottom: 40, top: 20),
                      child: Column(
                        children: [
                          // Battery Indicator
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        ((_batteryLevel ?? 0) > 20
                                                ? Colors.greenAccent
                                                : Colors.redAccent)
                                            .withOpacity(0.15),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 170,
                                  height: 170,
                                  child: CircularProgressIndicator(
                                    value: (_batteryLevel ?? 0) / 100,
                                    strokeWidth: 12,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor: isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[100],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      (_batteryLevel ?? 0) > 20
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFFFF5252),
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          _batteryLevel != null
                                              ? _batteryLevel!.toStringAsFixed(0)
                                              : '--',
                                          style: TextStyle(
                                            fontSize: 64,
                                            fontWeight: FontWeight.w900,
                                            color: textColor,
                                          ),
                                        ),
                                        const Text(
                                          '%',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    const Icon(
                                      Icons.bolt,
                                      color: Colors.amber,
                                      size: 32,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 25),
                          Text(
                            _currentBusId ?? '---',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context, 'service_status'),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: _statusCodes
                                .map(
                                  (code) => Expanded(
                                    child: _buildStatusButton(
                                      code,
                                      Theme.of(context).cardColor,
                                      isDark,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 32),

                          Text(
                            AppLocalizations.of(context, 'vehicle_info'),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.3,
                            children: [
                              _buildInfoCard(
                                AppLocalizations.of(
                                  context,
                                  'license_plate_title',
                                ),
                                _licensePlate ?? '-',
                                Icons.tag,
                                Theme.of(context).cardColor,
                                textColor,
                                isDark,
                                () => _showEditDialog(
                                  'license_plate_title',
                                  'license_plate',
                                  _licensePlate ?? '',
                                ),
                              ),
                              _buildInfoCard(
                                AppLocalizations.of(context, 'bus_type_title'),
                                AppLocalizations.of(context, _busType ?? '-'),
                                Icons.directions_bus,
                                Theme.of(context).cardColor,
                                textColor,
                                isDark,
                                () => _showEditDialog(
                                  'bus_type_title',
                                  'bus_type',
                                  _busType ?? '',
                                  isDropdown: true,
                                ),
                              ),
                              _buildInfoCard(
                                AppLocalizations.of(context, 'bus_brand_title'),
                                _busBrand ?? '-',
                                Icons.branding_watermark,
                                Theme.of(context).cardColor,
                                textColor,
                                isDark,
                                () => _showEditDialog(
                                  'bus_brand_title',
                                  'bus_brand',
                                  _busBrand ?? '',
                                ),
                              ),
                              _buildInfoCard(
                                AppLocalizations.of(context, 'bus_seats_title'),
                                _busSeats?.toString() ?? '-',
                                Icons.event_seat,
                                Theme.of(context).cardColor,
                                textColor,
                                isDark,
                                () => _showEditDialog(
                                  'bus_seats_title',
                                  'bus_seats',
                                  _busSeats?.toString() ?? '',
                                  isNumber: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusButton(String code, Color cardBg, bool isDark) {
    bool isActive = _currentStatusCode == code;
    Color statusColor = _getStatusColor(code);
    IconData icon;
    switch (code) {
      case 'status_ready':
        icon = Icons.check_circle_outline;
        break;
      case 'status_stop':
        icon = Icons.pause_circle_outline;
        break;
      case 'status_maintain':
        icon = Icons.build_circle_outlined;
        break;
      case 'status_fuel':
        icon = Icons.local_gas_station_outlined;
        break;
      default:
        icon = Icons.help_outline;
    }

    return GestureDetector(
      onTap: () => _changeStatus(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? statusColor : cardBg,
          borderRadius: BorderRadius.circular(15),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: statusColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: isDark ? Colors.black38 : Colors.black12,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? Colors.white : statusColor, size: 22),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context, code),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon,
    Color cardBg,
    Color? textColor,
    bool isDark,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: const Color(0xFFFF4009).withOpacity(0.1),
        highlightColor: const Color(0xFFFF4009).withOpacity(0.05),
        child: Ink(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getStatusColor(_currentStatusCode ?? '').withOpacity(isDark ? 0.6 : 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black38 : Colors.black12,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: const Color(0xFFFF4009)),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String code) {
    switch (code) {
      case 'status_ready':
        return const Color(0xFF4CAF50);
      case 'status_stop':
        return const Color(0xFF9E9E9E);
      case 'status_maintain':
        return const Color(0xFFFF5252);
      case 'status_fuel':
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFFFF4009);
    }
  }
}
