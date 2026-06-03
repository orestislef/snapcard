# SnapCard

Scan a business card with your phone camera and get a real contact saved to your address book — and everything runs **100% on-device**. No servers, no uploads, works offline after a one-time model download.

I built this because I was tired of typing business cards into my phone by hand, and I didn't want some cloud service hoovering up people's contact details. The whole point is privacy: the card photo and the extracted data never leave the phone.

## What it does

- Point the camera at a business card and tap the shutter.
- An on-device multimodal model (Gemma 3n) reads the card and pulls out the fields — name, job title, company, every phone number (classified as mobile / work / fax…), emails, websites, address, notes.
- You get a review screen to fix or add anything before it's saved.
- Save it to the in-app history and/or push it straight into your phone's Contacts.

It's not dumb OCR — the model understands the layout, so it knows which number is the mobile vs the office line and splits the name into first/last.

## Features

- **On-device inference** — Gemma 3n E2B (int4, LiteRT-LM) running locally. Nothing is uploaded.
- **Two-sided cards** — snap the front and back; the model merges both into one contact.
- **In-app history** — every scan is kept locally; tap any entry to edit it or add it to Contacts later.
- **Editable review** — add/remove phones, emails and websites; nothing is written to Contacts without your confirmation.
- **Model warm-up** — the model preloads when you open the camera so scanning is fast.
- **Android + iOS** — one Flutter codebase.

## The model

| | |
|---|---|
| Model | Gemma 3n **E2B**, instruction-tuned, int4 |
| Format | LiteRT-LM (`.litertlm`) |
| Size | ~3.7 GB (downloaded once) |
| Repo | [`OrestisIqtaxi/accesseye-gemma3n-e2b`](https://huggingface.co/OrestisIqtaxi/accesseye-gemma3n-e2b) |

Gemma is used under Google's [Gemma Terms of Use](https://ai.google.dev/gemma/terms).

This is a sibling of [AccessEye](https://github.com/orestislef/AccessEye) (native iOS/Swift, LiteRT-LM) — same model, but SnapCard is Flutter so it ships Android and iOS from one codebase.

## Tech

- [Flutter](https://flutter.dev)
- [`flutter_gemma`](https://pub.dev/packages/flutter_gemma) — on-device Gemma inference
- `camera` / `image_picker` — capture
- `flutter_contacts` — writing to the address book
- `provider`, `shared_preferences`, `device_info_plus`, `path_provider`, `permission_handler`

## Running it

You need Flutter installed and a **physical device** (the model won't run well in a simulator/emulator). Vision wants a fair bit of RAM — **8 GB+ is comfortable**; less will be slow or may not load.

```bash
flutter pub get
flutter run --release
```

First launch walks you through a one-time ~3.7 GB model download (use Wi-Fi). After that it works fully offline.

### Permissions

- **Camera** — to scan cards.
- **Contacts** — only when you choose to save a contact.

## Requirements

- Android: minSdk 26, arm64-v8a.
- iOS: 16+, a device with enough memory (iPhone 15 Pro / newer for vision).

## Status

v1 does one thing well: business card → contact. Possible next steps: batch scanning at a conference, other "scan → action" flows (calendar, notes).

## License

MIT — see [LICENSE](LICENSE).
