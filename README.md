# Aguacate Cam

Aguacate Cam is a Flutter application that helps you check the ripeness of avocados using your device's camera and Google Generative AI.

## Features

- Take a picture of an avocado with your device's camera.
- Analyze the image to determine the ripeness of the avocado.
- Cross-platform: Android, iOS, Windows, Linux, macOS, and Web.

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- Dart SDK (comes with Flutter)
- A device or emulator for your target platform

### Installation

1. **Clone the repository:**

   ```sh
   git clone https://github.com/yourusername/aguacate_cam.git
   cd aguacate_cam
   ```

2. **Install dependencies:**

   ```sh
   flutter pub get
   ```

3. **Add your Google Generative AI API key:**

   - Open [`lib/old_code.dart`](lib/old_code.dart)
   - Replace the value of `_apiKey` with your API key.
   - **Warning:** Never expose your API key in production. Use a backend or secure storage.

4. **Run the app:**
   ```sh
   flutter run
   ```

## Project Structure

- `lib/` - Main Dart source code
- `assets/` - Images and other assets
- `android/`, `ios/`, `windows/`, `linux/`, `macos/`, `web/` - Platform-specific code

## Dependencies

- [camera](https://pub.dev/packages/camera)
- [google_generative_ai](https://pub.dev/packages/google_generative_ai)
- [path_provider](https://pub.dev/packages/path_provider)
- [flutter](https://flutter.dev)

## Video Tutorial

Watch the full YouTube video on how this app was made:

[![Aguacate Cam - YouTube Tutorial](https://img.youtube.com/vi/YOUR_VIDEO_ID/0.jpg)](https://www.youtube.com/watch?v=YOUR_VIDEO_ID)

## Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License

[MIT](LICENSE)

---

**Note:** This project is for educational purposes. Do not expose sensitive API keys in client-side code.
