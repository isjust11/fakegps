import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/saved_location.dart';
import '../services/fake_gps_service.dart';
import '../services/location_history_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  bool _isRunning = false;
  bool _isLoading = false;
  StreamSubscription<Position>? _positionStream;
  List<SavedLocation> _savedLocations = [];
 final controller = TextEditingController();

  // Mặc định trung tâm Hà Nội
  static const LatLng _defaultCenter = LatLng(21.0278, 105.8342);

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await LocationHistoryService.load();
    if (mounted) setState(() => _savedLocations = list);
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final current = LatLng(position.latitude, position.longitude);
      setState(() => _currentLocation = current);
      _mapController.move(current, 15.0);

      // Tiếp tục theo dõi vị trí thực
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(pos.latitude, pos.longitude);
          });
        }
      });
    } catch (_) {
      // Không có GPS hoặc bị từ chối, giữ mặc định
    }
  }

  Future<void> _moveToCurrentLocation() async {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15.0);
    } else {
      await _initLocation();
    }
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      _selectedLocation = point;
      _latController.text = point.latitude.toStringAsFixed(6);
      _lngController.text = point.longitude.toStringAsFixed(6);
    });
    if (_isRunning) {
      FakeGpsService.updateLocation(point.latitude, point.longitude);
    }
  }

  Future<void> _toggleFakeGps() async {
    if (_isRunning) {
      setState(() => _isLoading = true);
      await FakeGpsService.stopMockLocation();
      if (mounted) {
        setState(() {
          _isRunning = false;
          _isLoading = false;
        });
      }
      return;
    }

    if (_selectedLocation == null) {
      _showSnack('Hãy nhấn vào bản đồ để chọn vị trí trước');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FakeGpsService.startMockLocation(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );
      if (mounted) {
        setState(() {
          _isRunning = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Lỗi: $e');
      }
    }
  }

  void _applyManualCoords() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      _showSnack('Tọa độ không hợp lệ');
      return;
    }
    final location = LatLng(lat, lng);
    setState(() => _selectedLocation = location);
    _mapController.move(location, 14.0);
    FocusScope.of(context).unfocus();
    if (_isRunning) {
      FakeGpsService.updateLocation(lat, lng);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showSaveDialog() async {
    if (_selectedLocation == null) {
      _showSnack('Hãy chọn vị trí trên bản đồ trước');
      return;
    }
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đặt tên vị trí'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ví dụ: Nhà, Cơ quan...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    // controller.dispose();
    if (name == null || name.isEmpty) return;

    final entry = SavedLocation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      savedAt: DateTime.now(),
    );
    final updated = await LocationHistoryService.add(entry);
    if (mounted) {
      setState(() => _savedLocations = updated);
      _showSnack('Đã lưu "$name"');
    }
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _HistorySheet(
        locations: _savedLocations,
        onSelect: (loc) {
          Navigator.pop(context);
          final point = LatLng(loc.latitude, loc.longitude);
          setState(() {
            _selectedLocation = point;
            _latController.text = loc.latitude.toStringAsFixed(6);
            _lngController.text = loc.longitude.toStringAsFixed(6);
          });
          _mapController.move(point, 15.0);
          if (_isRunning) {
            FakeGpsService.updateLocation(loc.latitude, loc.longitude);
          }
        },
        onDelete: (id) async {
          final updated = await LocationHistoryService.remove(id);
          if (mounted) setState(() => _savedLocations = updated);
        },
        onRename: (id, currentName) async {
          controller.text = currentName;
          final name = await showDialog<String>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Đổi tên'),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Huỷ'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
                  child: const Text('Lưu'),
                ),
              ],
            ),
          );
          if (name != null && name.isNotEmpty) {
            final updated = await LocationHistoryService.rename(id, name);
            if (mounted) setState(() => _savedLocations = updated);
          }
        },
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hướng dẫn sử dụng'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Bật Developer Options trên thiết bị Android',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('Vào Cài đặt → Giới thiệu về điện thoại → nhấn "Số phiên bản" 7 lần.'),
              SizedBox(height: 12),
              Text(
                '2. Chọn ứng dụng giả mạo vị trí',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('Vào Cài đặt → Tuỳ chọn nhà phát triển → Chọn ứng dụng vị trí mô phỏng → chọn "Fake GPS".'),
              SizedBox(height: 12),
              Text(
                '3. Sử dụng ứng dụng',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('• Nhấn lên bản đồ để chọn vị trí\n• Hoặc nhập tọa độ thủ công rồi nhấn Go\n• Nhấn "Bắt đầu Fake GPS"\n• Các ứng dụng khác sẽ nhận vị trí giả này'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _latController.dispose();
    _lngController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fake GPS'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isRunning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.location_on, color: Colors.green),
            ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'Lịch sử vị trí',
                onPressed: _showHistorySheet,
              ),
              if (_savedLocations.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isRunning)
            Container(
              width: double.infinity,
              color: Colors.green.shade100,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Đang giả mạo GPS: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 13.0,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.fakegps',
                ),
                // Marker vị trí thực của user (chấm xanh)
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                // Marker vị trí fake được chọn
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.location_pin,
                          color: _isRunning ? Colors.green : Colors.red,
                          size: 44,
                          shadows: const [
                            Shadow(blurRadius: 4, color: Colors.black38),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          _buildControlPanel(),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latController,
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lngController,
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _applyManualCoords,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Go'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _toggleFakeGps,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRunning ? Colors.red.shade600 : Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(_isRunning ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                    label: Text(
                      _isRunning ? 'Dừng Fake GPS' : 'Bắt đầu Fake GPS',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: _moveToCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Vị trí hiện tại',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: _selectedLocation != null
                      ? Colors.orange.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: _selectedLocation != null ? _showSaveDialog : null,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  tooltip: 'Lưu vị trí này',
                  color: _selectedLocation != null
                      ? Colors.orange.shade700
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── History bottom sheet ──────────────────────────────────────────────────

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({
    required this.locations,
    required this.onSelect,
    required this.onDelete,
    required this.onRename,
  });

  final List<SavedLocation> locations;
  final void Function(SavedLocation) onSelect;
  final void Function(String id) onDelete;
  final void Function(String id, String currentName) onRename;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.bookmark, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Vị trí đã lưu (${locations.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: locations.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_border, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'Chưa có vị trí nào được lưu',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Chọn vị trí rồi nhấn 🔖 để lưu',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    itemCount: locations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                    itemBuilder: (_, i) {
                      final loc = locations[i];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_pin, color: Colors.orange),
                        ),
                        title: Text(
                          loc.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: 'Đổi tên',
                              onPressed: () => onRename(loc.id, loc.name),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.red.shade400,
                              ),
                              tooltip: 'Xoá',
                              onPressed: () => onDelete(loc.id),
                            ),
                          ],
                        ),
                        onTap: () => onSelect(loc),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
