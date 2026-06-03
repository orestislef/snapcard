import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../models/business_card.dart';

/// Direct download URL for the multimodal Gemma 3n E2B int4 `.litertlm` model.
const String kModelUrl =
    'https://huggingface.co/OrestisIqtaxi/accesseye-gemma3n-e2b/resolve/main/gemma-3n-E2B-it-int4.litertlm';

/// File name as it lands on disk (basename of the URL path).
const String kModelFilename = 'gemma-3n-E2B-it-int4.litertlm';

/// Approximate on-disk size, shown in the UI.
const double kModelSizeGb = 3.66;

const String _systemPrompt =
    'You are a business-card parser. You receive one or more photos of a single '
    'business card and output ONLY a JSON object with the contact\'s details. Do '
    'not add commentary, markdown, or code fences. If a field is missing on the '
    'card, use null. Never invent data.';

String _userPrompt(int imageCount) {
  final intro = imageCount > 1
      ? 'You are given $imageCount photos of the SAME business card (e.g. front '
          'and back). Merge all the details into one contact.'
      : 'Extract the contact details from this business card.';
  return '''$intro Output ONLY this JSON shape:
{
  "fullName": string|null,
  "firstName": string|null,
  "lastName": string|null,
  "jobTitle": string|null,
  "company": string|null,
  "phones": [{ "label": "mobile"|"work"|"home"|"fax"|"other", "number": string }],
  "emails": [{ "label": "work"|"personal"|"other", "address": string }],
  "websites": [string],
  "address": string|null,
  "notes": string|null
}
Rules:
- Split name into first/last when possible; also keep fullName.
- Classify each phone by its printed label (Mobile/Cell/M -> mobile, Office/Tel/T -> work, Fax -> fax).
- Preserve country codes and formatting in numbers.
- Merge duplicate fields found on multiple sides; do not list the same value twice.
- Read non-English cards and transliterate names to Latin script in notes if useful.''';
}

const String _retryPrompt =
    'Your previous output was not valid JSON. Output ONLY the JSON object, no '
    'code fences, no extra text.';

/// Wraps `flutter_gemma`: download / delete / is-installed / extract.
///
/// Inference is 100% on-device. A fresh model is created per extraction and
/// closed afterwards so we never hold two models (or their KV caches) at once.
class GemmaService {
  /// The warmed, loaded model kept alive across scans for speed. Held open only
  /// while the capture screen is active; freed via [dispose].
  InferenceModel? _model;

  /// Backend + context size, set by [AppState] from device RAM. Low-RAM phones
  /// use CPU (mmaps weights from disk instead of copying ~3.7 GB into GPU
  /// memory) and a smaller KV cache to avoid OOM.
  PreferredBackend? preferredBackend;
  int maxTokens = 2048;

  /// True once the model weights are loaded and a scan will be fast.
  bool get isWarm => _model != null;

  /// Whether the model file is present on disk.
  Future<bool> isInstalled() => FlutterGemma.isModelInstalled(kModelFilename);

  /// Downloads the model with progress (0–100). [cancelToken] lets the UI abort.
  /// Uses the foreground-service download path (auto for >500 MB) so it survives
  /// the app being backgrounded. Idempotent: skips download if already present.
  Future<void> download({
    required void Function(int progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    var builder = FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.litertlm,
    ).fromNetwork(kModelUrl).withProgress(onProgress);
    if (cancelToken != null) builder = builder.withCancelToken(cancelToken);
    await builder.install();
  }

  /// Marks the (already-installed) model active so [extract] can load it.
  /// Cheap and offline-safe — skips download when the file is present.
  Future<void> ensureActive() async {
    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.litertlm,
    ).fromNetwork(kModelUrl).install();
  }

  /// Pre-loads the model into the runtime so the first scan is fast.
  ///
  /// This is the slow step (weights load); call it when the capture screen opens
  /// and show a "Warming up the model…" indicator. Subsequent [extract] calls
  /// reuse the loaded model. No-op if already warm.
  Future<void> warmUp() async {
    if (_model != null) return;
    await ensureActive();
    _model = await FlutterGemma.getActiveModel(
      maxTokens: maxTokens,
      supportImage: true,
      maxNumImages: 2, // allow front+back of a card in one query
      preferredBackend: preferredBackend, // null = plugin default (GPU)
    );
  }

  /// Frees the loaded model from memory. Call when leaving the capture screen.
  Future<void> dispose() async {
    final m = _model;
    _model = null;
    if (m != null) await m.close();
  }

  /// Frees the ~3.7 GB on disk (and unloads the model first).
  Future<void> delete() async {
    await dispose();
    await FlutterGemma.uninstallModel(kModelFilename);
  }

  /// Runs vision inference on 1–2 card photos and returns the parsed card.
  ///
  /// Reuses the warmed model (warming up first if needed). Retries once with a
  /// stricter prompt if the first response isn't valid JSON. Throws
  /// [GemmaParseException] if both attempts fail to parse.
  Future<BusinessCard> extract(List<Uint8List> images) async {
    assert(images.isNotEmpty);
    if (_model == null) await warmUp();
    final model = _model!;

    final chat = await model.createChat(
      supportImage: true,
      systemInstruction: _systemPrompt,
      modelType: ModelType.gemmaIt,
    );
    try {
      final message = images.length == 1
          ? Message.withImage(
              text: _userPrompt(1),
              imageBytes: images.first,
              isUser: true,
            )
          : Message.withImages(
              text: _userPrompt(images.length),
              imageBytes: images,
              isUser: true,
            );
      await chat.addQueryChunk(message);

      var raw = _text(await chat.generateChatResponse());
      var card = _tryParse(raw);

      if (card == null) {
        // Stricter second attempt — same chat keeps the image in context.
        await chat.addQueryChunk(Message.text(text: _retryPrompt, isUser: true));
        raw = _text(await chat.generateChatResponse());
        card = _tryParse(raw);
      }

      if (card == null) {
        throw GemmaParseException(raw);
      }
      return card;
    } finally {
      // Drop this scan's session/context but keep the model weights warm.
      await chat.close();
    }
  }

  String _text(ModelResponse r) => r is TextResponse ? r.token : '';

  /// Pulls a JSON object out of the model text and parses it leniently.
  BusinessCard? _tryParse(String raw) {
    final jsonStr = _extractJsonObject(raw);
    if (jsonStr == null) return null;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return BusinessCard.fromGemmaJson(decoded);
      }
      if (decoded is Map) {
        return BusinessCard.fromGemmaJson(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      debugPrint('GemmaService: JSON parse failed: $e');
    }
    return null;
  }

  /// Strips code fences / prose and returns the outermost `{...}` block.
  String? _extractJsonObject(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    // Remove ```json ... ``` fences if present.
    s = s.replaceAll(RegExp(r'```[a-zA-Z]*'), '').replaceAll('```', '').trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    return s.substring(start, end + 1);
  }
}

/// Thrown when the model output couldn't be parsed into a card after retrying.
class GemmaParseException implements Exception {
  GemmaParseException(this.rawResponse);
  final String rawResponse;
  @override
  String toString() => 'GemmaParseException: could not parse card from response';
}
