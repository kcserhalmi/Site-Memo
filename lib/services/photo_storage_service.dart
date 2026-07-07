import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart' show XFile;

/// Uploads inspection photos to Firebase Storage so they survive
/// reinstalls and appear on other devices. Files live under
/// users/{uid}/photos/{photoId}.{jpg|png}.
class PhotoStorageService {
  static Reference _ref(String uid, String photoId, String ext) =>
      FirebaseStorage.instance.ref('users/$uid/photos/$photoId$ext');

  static String _extFor(String path) =>
      path.toLowerCase().endsWith('.png') ? '.png' : '.jpg';

  /// Uploads the file at [localPath] and returns its download URL.
  /// Throws on failure — callers queue a retry.
  static Future<String> upload(
      String uid, String photoId, String localPath) async {
    final ext = _extFor(localPath);
    final ref = _ref(uid, photoId, ext);
    final bytes = await XFile(localPath).readAsBytes();
    await ref.putData(
      bytes,
      SettableMetadata(
          contentType: ext == '.png' ? 'image/png' : 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  /// Best-effort delete of a photo's remote copy. The extension isn't
  /// stored, so try both.
  static Future<void> delete(String uid, String photoId) async {
    for (final ext in const ['.jpg', '.png']) {
      try {
        await _ref(uid, photoId, ext).delete();
      } catch (_) {}
    }
  }

  /// Best-effort delete of everything under users/{uid}/photos —
  /// used by account deletion.
  static Future<void> deleteAllForUser(String uid) async {
    try {
      final listing =
          await FirebaseStorage.instance.ref('users/$uid/photos').listAll();
      for (final item in listing.items) {
        try {
          await item.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }
}
