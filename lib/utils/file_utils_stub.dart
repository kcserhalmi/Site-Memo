// Web stub — dart:io is not available in browser
import 'package:flutter/material.dart';

Widget appImage(String path,
    {BoxFit fit = BoxFit.cover,
    Widget? fallback,
    int? cacheWidth,
    int? cacheHeight,
    String? networkUrl}) {
  // On web the "path" is a blob URL that only lives for the session;
  // prefer the durable cloud URL when available.
  final src = (networkUrl != null && networkUrl.isNotEmpty) ? networkUrl : path;
  return Image.network(
    src,
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

bool fileExists(String path) => path.isNotEmpty;

Future<String> persistPhotoFile(String srcPath) async => srcPath;

Future<String> photoStorageDirPath() async => '';

Future<void> deleteLocalPhotoFile(String path) async {}
