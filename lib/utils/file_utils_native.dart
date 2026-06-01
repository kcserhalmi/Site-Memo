// Native (non-web) implementation using dart:io
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

Widget appImage(String path,
    {BoxFit fit = BoxFit.cover,
    Widget? fallback,
    int? cacheWidth,
    int? cacheHeight}) {
  if (!File(path).existsSync()) {
    return fallback ??
        Container(
          color: const Color(0xFF2A2A2A),
          child: const Icon(Icons.image, color: Color(0xFF9E8E78)),
        );
  }
  return Image.file(
    File(path),
    fit: fit,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
    errorBuilder: (_, __, ___) =>
        fallback ??
        Container(
          color: const Color(0xFF2A2A2A),
          child: const Icon(Icons.image, color: Color(0xFF9E8E78)),
        ),
  );
}

bool fileExists(String path) => File(path).existsSync();

Future<String> getAudioRecordPath() async {
  final dir = await getApplicationDocumentsDirectory();
  final audioDir = Directory('${dir.path}/site_memo_audio');
  if (!await audioDir.exists()) await audioDir.create(recursive: true);
  return '${audioDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
}
