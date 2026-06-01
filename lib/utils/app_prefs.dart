import 'package:shared_preferences/shared_preferences.dart';

/// Simple key-value store for user preferences.
class AppPrefs {
  static const _name = 'inspector_name';
  static const _autoTranscribe = 'auto_transcribe';
  static const _highQuality = 'high_quality';

  static Future<String> getInspectorName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_name) ?? '';
  }

  static Future<void> setInspectorName(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_name, v);
  }

  static Future<bool> getAutoTranscribe() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_autoTranscribe) ?? true;
  }

  static Future<void> setAutoTranscribe(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_autoTranscribe, v);
  }

  static Future<bool> getHighQuality() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_highQuality) ?? false;
  }

  static Future<void> setHighQuality(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_highQuality, v);
  }
}
