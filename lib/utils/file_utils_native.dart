// Native (non-web) implementation using dart:io
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

Widget appImage(String path,
    {BoxFit fit = BoxFit.cover,
    Widget? fallback,
    int? cacheWidth,
    int? cacheHeight,
    String? networkUrl}) {
  if (!File(path).existsSync()) {
    // Local copy is gone (new device, reinstall, purged cache) —
    // fall back to the cloud copy when one exists.
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return Image.network(
        networkUrl,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(
                color: const Color(0xFF2A2A2A),
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF9E8E78)),
                  ),
                ),
              ),
        errorBuilder: (_, __, ___) => _imageFallback(fallback),
      );
    }
    return _imageFallback(fallback);
  }
  return Image.file(
    File(path),
    fit: fit,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
    errorBuilder: (_, __, ___) => _imageFallback(fallback),
  );
}

Widget _imageFallback(Widget? fallback) =>
    fallback ??
    Container(
      color: const Color(0xFF2A2A2A),
      child: const Icon(Icons.image, color: Color(0xFF9E8E78)),
    );

bool fileExists(String path) => File(path).existsSync();

/// Copies a freshly captured photo out of the OS temp/cache directory
/// into the app's permanent documents storage. Returns the new path,
/// or the original path if the copy fails.
Future<String> persistPhotoFile(String srcPath) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${dir.path}/site_memo_photos');
    if (!photosDir.existsSync()) photosDir.createSync(recursive: true);
    final dot = srcPath.lastIndexOf('.');
    final ext = dot >= 0 ? srcPath.substring(dot) : '.jpg';
    final dest =
        '${photosDir.path}/photo_${DateTime.now().microsecondsSinceEpoch}$ext';
    await File(srcPath).copy(dest);
    return dest;
  } catch (_) {
    return srcPath;
  }
}

/// Returns the directory where annotated photos should be written.
Future<String> photoStorageDirPath() async {
  final dir = await getApplicationDocumentsDirectory();
  final photosDir = Directory('${dir.path}/site_memo_photos');
  if (!photosDir.existsSync()) photosDir.createSync(recursive: true);
  return photosDir.path;
}

/// Deletes a photo file from disk, but only files the app owns
/// (inside site_memo_photos or legacy annotated_ files) — never
/// user gallery paths.
Future<void> deleteLocalPhotoFile(String path) async {
  try {
    final owned = path.contains('site_memo_photos') ||
        path.contains('${Platform.pathSeparator}annotated_') ||
        path.contains('/annotated_');
    if (!owned) return;
    final f = File(path);
    if (f.existsSync()) await f.delete();
  } catch (_) {}
}
