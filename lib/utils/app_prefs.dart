import 'package:shared_preferences/shared_preferences.dart';

/// Simple key-value store for user preferences.
/// Single SharedPreferences instance cached for the app lifetime.
class AppPrefs {
  static const _name = 'inspector_name';
  static const _autoTranscribe = 'auto_transcribe';
  static const _highQuality = 'high_quality';

  static SharedPreferences? _cache;
  static Future<SharedPreferences> _p() async {
    _cache ??= await SharedPreferences.getInstance();
    return _cache!;
  }

  static Future<String> getInspectorName() async =>
      (await _p()).getString(_name) ?? '';

  static Future<void> setInspectorName(String v) async =>
      (await _p()).setString(_name, v.trim());

  static Future<bool> getAutoTranscribe() async =>
      (await _p()).getBool(_autoTranscribe) ?? true;

  static Future<void> setAutoTranscribe(bool v) async =>
      (await _p()).setBool(_autoTranscribe, v);

  static Future<bool> getHighQuality() async =>
      (await _p()).getBool(_highQuality) ?? false;

  static Future<void> setHighQuality(bool v) async =>
      (await _p()).setBool(_highQuality, v);
}
