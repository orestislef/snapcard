import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart' show CancelToken;
import 'package:shared_preferences/shared_preferences.dart';

import 'contact_service.dart';
import 'device_gate.dart';
import 'gemma_service.dart';
import 'history_service.dart';
import 'model_state.dart';

/// App-wide state: model lifecycle, onboarding flag, device RAM, HF token.
/// Scanning, contacts and history are driven through the services it exposes.
class AppState extends ChangeNotifier {
  final GemmaService gemma = GemmaService();
  final ContactService contacts = ContactService();
  final HistoryService history = HistoryService();
  final DeviceGate deviceGate = DeviceGate();

  ModelState modelState = ModelState.notDownloaded;
  int downloadProgress = 0;
  String? errorMessage;
  bool onboardingSeen = false;
  bool bootstrapped = false;

  CancelToken? _cancelToken;
  DateTime? _dlStart;
  double _speedMbs = 0; // live download speed in MB/s

  bool get isDownloading => modelState == ModelState.downloading;
  bool get modelReady => modelState == ModelState.ready;

  String get downloadSpeedText =>
      _speedMbs <= 0 ? '—' : '${_speedMbs.toStringAsFixed(1)} MB/s';

  /// Rough remaining time, derived from average speed so far. '—' until known.
  String get etaText {
    if (_speedMbs <= 0 || downloadProgress <= 0 || downloadProgress >= 100) {
      return '—';
    }
    final remainMb = kModelSizeGb * 1024 * (100 - downloadProgress) / 100;
    final secs = (remainMb / _speedMbs).round();
    final m = secs ~/ 60;
    final s = secs % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  static const String _kOnboarding = 'onboarding_seen';

  /// Loads persisted flags, reads RAM, and detects whether the model is present.
  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    onboardingSeen = prefs.getBool(_kOnboarding) ?? false;
    await deviceGate.read();
    try {
      modelState = await gemma.isInstalled()
          ? ModelState.ready
          : ModelState.notDownloaded;
    } catch (_) {
      modelState = ModelState.notDownloaded;
    }
    bootstrapped = true;
    notifyListeners();
  }

  Future<void> setOnboardingSeen() async {
    onboardingSeen = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarding, true);
  }

  /// Starts (or restarts) the model download.
  Future<void> startDownload() async {
    if (isDownloading) return;
    final token = _cancelToken = CancelToken();
    modelState = ModelState.downloading;
    downloadProgress = 0;
    _speedMbs = 0;
    _dlStart = DateTime.now();
    errorMessage = null;
    notifyListeners();
    try {
      await gemma.download(
        cancelToken: token,
        onProgress: (p) {
          downloadProgress = p;
          final start = _dlStart;
          if (start != null && p > 0) {
            final elapsed =
                DateTime.now().difference(start).inMilliseconds / 1000.0;
            if (elapsed > 0.5) {
              final doneMb = kModelSizeGb * 1024 * p / 100;
              _speedMbs = doneMb / elapsed;
            }
          }
          notifyListeners();
        },
      );
      modelState = ModelState.ready;
    } catch (e) {
      if (CancelToken.isCancel(e) || token.isCancelled) {
        // Cancelled: return to a clean paused state, not a broken one.
        modelState = ModelState.notDownloaded;
        downloadProgress = 0;
      } else {
        modelState = ModelState.error;
        errorMessage = _friendlyError(e);
      }
    } finally {
      _cancelToken = null;
      notifyListeners();
    }
  }

  void cancelDownload() => _cancelToken?.cancel('User cancelled');

  Future<void> deleteModel() async {
    await gemma.delete();
    modelState = ModelState.notDownloaded;
    downloadProgress = 0;
    errorMessage = null;
    notifyListeners();
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('401') || s.contains('403')) {
      return 'Download was refused. This model repo may be gated — add a '
          'HuggingFace access token and retry.';
    }
    if (s.contains('404')) {
      return 'Model not found at the download URL (404).';
    }
    if (s.toLowerCase().contains('space') || s.toLowerCase().contains('storage')) {
      return 'Not enough free storage for the ~3.7 GB model.';
    }
    return 'Download failed. Check your connection and retry.\n$s';
  }
}
