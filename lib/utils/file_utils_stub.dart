// Web stub — dart:io is not available in browser
import 'package:flutter/material.dart';

Widget appImage(String path, {BoxFit fit = BoxFit.cover, Widget? fallback}) {
  return Image.network(
    path,
    fit: fit,
    errorBuilder: (_, __, ___) =>
        fallback ??
        Container(
          color: const Color(0xFF2A2A2A),
          child: const Icon(Icons.image, color: Color(0xFF9E8E78)),
        ),
  );
}

bool fileExists(String path) => path.isNotEmpty;

Future<String> getAudioRecordPath() async {
  return 'voice_${DateTime.now().millisecondsSinceEpoch}.webm';
}
