import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/fake_gps_service.dart';

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
  bool _isRunning = false;
  bool _isLoading = false;

  // Mặc định trung tâm Hà Nội
  static const LatLng _defaultCenter = LatLng(21.0278, 105.8342);

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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
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
          SizedBox(
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
        ],
      ),
    );
  }
}
