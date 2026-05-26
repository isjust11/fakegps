import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_location.dart';

class LocationHistoryService {
  static const _key = 'saved_locations';

  static Future<List<SavedLocation>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => SavedLocation.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  static Future<void> save(List<SavedLocation> locations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      locations.map((l) => jsonEncode(l.toJson())).toList(),
    );
  }

  static Future<List<SavedLocation>> add(SavedLocation location) async {
    final list = await load();
    list.insert(0, location);
    await save(list);
    return list;
  }

  static Future<List<SavedLocation>> remove(String id) async {
    final list = await load();
    list.removeWhere((l) => l.id == id);
    await save(list);
    return list;
  }

  static Future<List<SavedLocation>> rename(String id, String newName) async {
    final list = await load();
    final idx = list.indexWhere((l) => l.id == id);
    if (idx != -1) {
      list[idx] = SavedLocation(
        id: list[idx].id,
        name: newName,
        latitude: list[idx].latitude,
        longitude: list[idx].longitude,
        savedAt: list[idx].savedAt,
      );
      await save(list);
    }
    return list;
  }
}
