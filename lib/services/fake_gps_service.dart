import 'package:flutter/services.dart';

class FakeGpsService {
  static const MethodChannel _channel =
      MethodChannel('com.example.fakegps/mock_location');

  static Future<void> startMockLocation(double lat, double lng) async {
    await _channel.invokeMethod<bool>('startMockLocation', {
      'latitude': lat,
      'longitude': lng,
    });
  }

  static Future<void> updateLocation(double lat, double lng) async {
    await _channel.invokeMethod('updateLocation', {
      'latitude': lat,
      'longitude': lng,
    });
  }

  static Future<void> stopMockLocation() async {
    await _channel.invokeMethod('stopMockLocation');
  }
}
