import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// Variable global para almacenar las cámaras disponibles
List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Avocado Ripeness Checker',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        hintColor: Colors.lightGreenAccent,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: 28.0,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(fontSize: 16.0, color: Colors.white70),
        ),
      ),
      home: const CameraScreen(),
    );
  }
}

// ---
// Nuevos Widgets Separados para la UI
// ---

class FeedbackCard extends StatelessWidget {
  final Widget content;
  final Color backgroundColor;

  const FeedbackCard({
    super.key,
    required this.content,
    this.backgroundColor = Colors.black54,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: content,
    );
  }
}

class CameraOverlay extends StatelessWidget {
  final String message;
  final Widget feedbackWidget;
  final bool showCameraFrame; // Nuevo: para mostrar el marco guía
  final bool showAvocadoGuide; // Nuevo: para mostrar la silueta de aguacate

  const CameraOverlay({
    super.key,
    required this.message,
    required this.feedbackWidget,
    this.showCameraFrame = false,
    this.showAvocadoGuide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      // Usamos Stack para superponer el marco y la silueta
      children: [
        if (showCameraFrame)
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7, // 70% del ancho
              height:
                  MediaQuery.of(context).size.width *
                  0.7, // Cuadrado para el aguacate
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.lightGreenAccent.withOpacity(0.7),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                // Para la silueta
                alignment: Alignment.center,
                children: [
                  if (showAvocadoGuide)
                    Opacity(
                      opacity: 0.3, // Silueta semi-transparente
                      child: Image.asset(
                        'assets/avocado_outline.png', // Necesitas crear esta imagen de silueta
                        width: MediaQuery.of(context).size.width * 0.5,
                      ),
                    ),
                ],
              ),
            ),
          ),
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 40.0, left: 20, right: 20),
              child: FeedbackCard(
                backgroundColor: Colors.black.withOpacity(0.6),
                content: Text(
                  message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                bottom: 100.0,
              ), // Espacio para el FAB
              child: FeedbackCard(
                content: feedbackWidget,
                backgroundColor: Colors.black.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---
// Pantalla Principal de la Cámara
// ---

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

enum AppState { initial, cameraReady, analyzing, result, error }

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  String _ripenessResult = '';
  AppState _appState = AppState.initial;

  // Ruta a la imagen temporal del aguacate, para mostrar el preview después de tomar la foto
  String? _capturedImagePath;

  static const String _apiKey = 'Your API KEY'; // <--- REEMPLAZA CON TU API KEY

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (cameras == null || cameras!.isEmpty) {
      setState(() {
        _ripenessResult = 'No cameras found. Please check device settings.';
        _appState = AppState.error;
      });
      return;
    }

    _controller = CameraController(
      cameras![0],
      ResolutionPreset.high,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller!
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {
            _appState = AppState.cameraReady;
            _ripenessResult = 'Center the avocado and tap the button.';
          });
        })
        .catchError((e) {
          if (e is CameraException) {
            switch (e.code) {
              case 'CameraAccessDenied':
                setState(() {
                  _ripenessResult =
                      'Camera access denied. Please grant permissions in settings.';
                  _appState = AppState.error;
                });
                break;
              default:
                setState(() {
                  _ripenessResult =
                      'Error initializing camera: ${e.description}';
                  _appState = AppState.error;
                });
                break;
            }
          }
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePictureAndAnalyze() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      setState(() {
        _ripenessResult = 'Camera not initialized.';
        _appState = AppState.error;
      });
      return;
    }

    if (_appState == AppState.analyzing) return; // Evitar múltiples clics

    setState(() {
      _appState = AppState.analyzing;
      _ripenessResult = 'Analyzing ripeness...';
      _capturedImagePath = null; // Limpiar imagen previa
    });

    try {
      final XFile image = await _controller!.takePicture();
      setState(() {
        _capturedImagePath =
            image.path; // Guardar la ruta para mostrar el preview
      });

      final imageBytes = await File(image.path).readAsBytes();

      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final content = [
        Content.multi([
          TextPart(
            'Analyze this image of an avocado. Is it ripe, unripe, or overripe? Give a concise answer (e.g., "Ripe", "Unripe", "Overripe") and a brief explanation.',
          ),
          DataPart('image/jpeg', imageBytes),
        ]),
      ];

      final response = await model.generateContent(content);

      setState(() {
        _ripenessResult = response.text ?? 'Could not determine ripeness.';
        _appState = AppState.result;
      });
    } catch (e) {
      setState(() {
        _ripenessResult = 'Error analyzing: ${e.toString()}';
        _appState = AppState.error;
      });
      print('Error en _takePictureAndAnalyze: $e');
    }
  }

  /// Función para determinar el widget de feedback basado en el resultado de Gemini
  Widget _buildRipenessFeedbackWidget() {
    switch (_appState) {
      case AppState.initial:
      case AppState.cameraReady:
        return _buildResultDisplay(
          icon: Icons.photo_camera_outlined,
          color: Colors.white70,
          message: 'Ready to scan!',
          subMessage: 'Tap the button to check your avocado.',
          imagePath: 'assets/avocado_placeholder.png', // Placeholder para guiar
        );
      case AppState.analyzing:
        return _buildResultDisplay(
          icon: Icons.hourglass_empty,
          color: Colors.lightGreenAccent,
          message: 'Analyzing...',
          subMessage: 'Please wait a moment while we process the image.',
          imagePath: 'assets/loading.png', // GIF de carga animado
        );
      case AppState.result:
        final lowerCaseResult = _ripenessResult.toLowerCase();
        if (lowerCaseResult.contains('ripe') &&
            !lowerCaseResult.contains('unripe') &&
            !lowerCaseResult.contains('overripe')) {
          return _buildResultDisplay(
            icon: Icons.check_circle_outline,
            color: Colors.greenAccent,
            message: 'Perfect! Ready to Eat.',
            subMessage: _ripenessResult,
            imagePath: 'assets/ripe.png',
          );
        } else if (lowerCaseResult.contains('unripe') ||
            lowerCaseResult.contains('not ripe')) {
          return _buildResultDisplay(
            icon: Icons.access_time,
            color: Colors.orangeAccent,
            message: 'Still Unripe.',
            subMessage: _ripenessResult,
            imagePath: 'assets/not_ripe.png',
          );
        } else if (lowerCaseResult.contains('overripe') ||
            lowerCaseResult.contains('too ripe')) {
          return _buildResultDisplay(
            icon: Icons.warning_amber,
            color: Colors.redAccent,
            message: 'Overripe.',
            subMessage: _ripenessResult,
            imagePath: 'assets/overripe.png',
          );
        } else {
          return _buildResultDisplay(
            icon: Icons.help_outline,
            color: Colors.grey,
            message: 'Result Unclear.',
            subMessage: _ripenessResult,
            imagePath: 'assets/avocado_placeholder.png',
          );
        }
      case AppState.error:
        return _buildResultDisplay(
          icon: Icons.error_outline,
          color: Colors.red,
          message: 'Error!',
          subMessage: _ripenessResult,
          imagePath: 'assets/error.png', // Necesitas crear esta imagen
        );
    }
  }

  /// Helper para construir la vista de resultados con íconos y texto
  Widget _buildResultDisplay({
    required IconData icon,
    required Color color,
    required String message,
    required String subMessage,
    String? imagePath,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: color),
        const SizedBox(height: 10),
        Text(
          message,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          subMessage, // La respuesta directa de Gemini
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        if (imagePath != null)
          Padding(
            padding: const EdgeInsets.only(top: 15.0),
            child:
                imagePath.endsWith('.gif') // Detecta si es un GIF
                    ? Image.asset(imagePath, width: 80, height: 80)
                    : Image.asset(imagePath, width: 80, height: 80),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Avocado Sense',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (_controller!.value.isInitialized) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child:
                        _capturedImagePath != null
                            ? Image.file(
                              File(_capturedImagePath!),
                              fit: BoxFit.cover,
                            )
                            : CameraPreview(_controller!),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.5),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // Solo mostrar el marco de la cámara y la guía si estamos en estado cameraReady
                  CameraOverlay(
                    message: _ripenessResult, // El mensaje dinámico
                    feedbackWidget: _buildRipenessFeedbackWidget(),
                    showCameraFrame: _appState == AppState.cameraReady,
                    showAvocadoGuide: _appState == AppState.cameraReady,
                  ),
                  Positioned(
                    bottom: 30,
                    child: FloatingActionButton(
                      onPressed:
                          _appState == AppState.analyzing
                              ? null
                              : _takePictureAndAnalyze,
                      backgroundColor:
                          (_appState == AppState.analyzing)
                              ? Colors
                                  .grey // Deshabilitado
                              : Colors.green[700],
                      child:
                          (_appState == AppState.analyzing)
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : const Icon(Icons.camera_alt, size: 30),
                    ),
                  ),
                ],
              );
            } else {
              // Si la cámara no se inicializó por alguna razón
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    _ripenessResult,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
          } else {
            // Mientras la cámara se está cargando por primera vez
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
