// lib/web_utils.dart
// Universal Web Utils with conditional export

export 'web_utils_stub.dart'
    if (dart.library.html) 'web_utils_web.dart';
