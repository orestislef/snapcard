import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/business_card.dart';
import '../history/history_screen.dart';
import '../review/review_screen.dart';
import '../settings/settings_screen.dart';

enum _PermState { checking, granted, denied, permanentlyDenied }

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  Future<void>? _initFuture;
  _PermState _perm = _PermState.checking;

  final List<Uint8List> _pending = [];
  bool _busy = false;
  String _busyLabel = '';
  bool _warming = false;
  bool _torch = false;

  static const int _maxSides = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
    _warmModel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    // Free the loaded model when leaving the camera.
    context.read<AppState>().gemma.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      cam.dispose();
      _camera = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _warmModel() async {
    setState(() => _warming = true);
    try {
      await context.read<AppState>().gemma.warmUp();
    } catch (_) {
      // First real scan will surface any load error.
    } finally {
      if (mounted) setState(() => _warming = false);
    }
  }

  Future<void> _setup() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _perm = _PermState.granted);
      await _initCamera();
    } else if (status.isPermanentlyDenied) {
      setState(() => _perm = _PermState.permanentlyDenied);
    } else {
      setState(() => _perm = _PermState.denied);
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _camera = controller;
      _initFuture = controller.initialize();
      await _initFuture;
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleTorch() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    try {
      _torch = !_torch;
      await cam.setFlashMode(_torch ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _shoot() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized || _pending.length >= _maxSides) {
      return;
    }
    try {
      final file = await cam.takePicture();
      final bytes = await file.readAsBytes();
      setState(() => _pending.add(bytes));
    } catch (e) {
      _toast('Capture failed: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    if (_pending.length >= _maxSides) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _pending.add(bytes));
    } catch (e) {
      _toast('Could not load image: $e');
    }
  }

  Future<void> _scan() async {
    if (_pending.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _busyLabel = _warming ? 'Warming up the model…' : 'Reading the card…';
    });
    final state = context.read<AppState>();
    try {
      final card = await state.gemma.extract(List<Uint8List>.from(_pending));
      if (!mounted) return;
      if (card.isEmpty) {
        _toast("Couldn't read the card — try again with better lighting.");
        setState(() => _pending.clear());
        return;
      }
      setState(() => _pending.clear());
      final result = await Navigator.of(context).push<BusinessCard>(
        MaterialPageRoute(builder: (_) => ReviewScreen(card: card)),
      );
      if (result != null && mounted) {
        _toast(result.addedToContacts ? 'Saved & added to contacts' : 'Saved');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pending.clear());
        _toast("Couldn't read the card — try again with better lighting.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.25),
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        // Light status-bar icons on the dark camera background.
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text('SnapCard'),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _preview(),
          if (_warming) _warmingChip(),
          _controls(),
          if (_busy) _busyOverlay(),
        ],
      ),
    );
  }

  Widget _preview() {
    if (_perm == _PermState.checking) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_perm != _PermState.granted) {
      return _permissionView();
    }
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(child: CameraPreview(cam));
  }

  Widget _permissionView() {
    final permanent = _perm == _PermState.permanentlyDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white70, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Camera access is needed to scan cards.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: permanent ? openAppSettings : _setup,
              child: Text(permanent ? 'Open Settings' : 'Grant camera access'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _warmingChip() {
    return Positioned(
      top: kToolbarHeight + MediaQuery.paddingOf(context).top + 8,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 8),
              Text('Warming up the model…',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls() {
    final granted = _perm == _PermState.granted;
    return Align(
      alignment: Alignment.bottomCenter,
      // Bottom-only safe area so controls clear the gesture nav bar.
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pending.isNotEmpty) _thumbs(),
              if (_pending.isNotEmpty) const SizedBox(height: 12),
              if (granted) _shutterRow(),
              if (_pending.isNotEmpty) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _scan,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(_pending.length > 1
                      ? 'Scan ${_pending.length} sides'
                      : 'Scan card'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbs() {
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < _pending.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_pending[i],
                        width: 90, height: 64, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _pending.removeAt(i)),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _shutterRow() {
    final canShoot = _pending.length < _maxSides && !_busy;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton.filledTonal(
          tooltip: 'Pick from gallery',
          iconSize: 28,
          onPressed: _busy || _pending.length >= _maxSides
              ? null
              : _pickFromGallery,
          icon: const Icon(Icons.photo_library_outlined),
        ),
        GestureDetector(
          onTap: canShoot ? _shoot : null,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: canShoot ? Colors.white : Colors.white38,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Icon(Icons.camera_alt,
                color: Colors.black.withValues(alpha: canShoot ? 1 : 0.4)),
          ),
        ),
        IconButton.filledTonal(
          tooltip: _torch ? 'Torch off' : 'Torch on',
          iconSize: 28,
          onPressed: _busy ? null : _toggleTorch,
          icon: Icon(_torch ? Icons.flash_on : Icons.flash_off),
        ),
      ],
    );
  }

  Widget _busyOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(_busyLabel,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('On-device · private',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
