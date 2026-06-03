import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// Reads total device RAM so we can warn before downloading the model.
///
/// Vision Gemma 3n on `.litertlm` wants ~8 GB. Below [minComfortableMb] we warn
/// the user but still let them proceed at their own risk (see CLAUDE.md §9).
class DeviceGate {
  /// Physical RAM in megabytes, or null if it couldn't be read.
  int? totalRamMb;

  /// Devices under this are warned (6 GB).
  static const int minComfortableMb = 6 * 1024;

  bool get isLowRam => totalRamMb != null && totalRamMb! < minComfortableMb;

  String get ramLabel =>
      totalRamMb == null ? 'Unknown' : '${(totalRamMb! / 1024).toStringAsFixed(1)} GB';

  Future<int?> read() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        totalRamMb = (await info.androidInfo).physicalRamSize;
      } else if (Platform.isIOS) {
        totalRamMb = (await info.iosInfo).physicalRamSize;
      }
    } catch (_) {
      totalRamMb = null;
    }
    return totalRamMb;
  }
}
