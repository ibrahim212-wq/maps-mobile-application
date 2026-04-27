import 'package:flutter/foundation.dart' show kIsWeb;

/// `true` when running in Chrome / WASM web preview. Use to gate mocks only.
bool get isWebDevPreview => kIsWeb;
