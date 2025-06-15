import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';
import 'package:flutter/services.dart'
    show rootBundle; // Para cargar la imagen como bytes

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
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  String _ripenessResult = 'Take a picture of an avocado!';
  bool _isLoading = false;

  // ¡IMPORTANTE! Reemplaza con tu clave de API de Gemini
  // Para producción, NUNCA expongas tu clave directamente en el código del cliente.
  // Considera usar un proxy de backend o Firebase Functions para esto.
  static const String _apiKey = 'API_Key'; // <--- REEMPLAZA ESTO

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (cameras == null || cameras!.isEmpty) {
      setState(() {
        _ripenessResult = 'No cameras found.';
      });
      return;
    }

    _controller = CameraController(
      cameras![0], // Usar la primera cámara disponible (generalmente la trasera)
      ResolutionPreset.medium,
    );

    _initializeControllerFuture = _controller!
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});
        })
        .catchError((e) {
          if (e is CameraException) {
            switch (e.code) {
              case 'CameraAccessDenied':
                setState(() {
                  _ripenessResult =
                      'Camera access denied. Please grant permissions.';
                });
                break;
              default:
                setState(() {
                  _ripenessResult =
                      'Error initializing camera: ${e.description}';
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
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _ripenessResult = 'Analyzing...';
    });

    try {
      final XFile image = await _controller!.takePicture();
      final imageBytes = await File(image.path).readAsBytes();

      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final content = [
        Content.multi([
          TextPart(
            'Analyze this image of an avocado. Is it ripe, unripe, or overripe? Give a concise answer.',
          ),
          DataPart('image/jpeg', imageBytes),
        ]),
      ];

      final response = await model.generateContent(content);

      setState(() {
        _ripenessResult = response.text ?? 'Could not determine ripeness.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _ripenessResult = 'Error analyzing: $e';
        _isLoading = false;
      });
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avocado Ripeness Checker')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (_controller!.value.isInitialized) {
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned.fill(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _ripenessResult,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FloatingActionButton(
                          onPressed: _isLoading ? null : _takePictureAndAnalyze,
                          child:
                              _isLoading
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : const Icon(Icons.camera_alt),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            } else {
              return Center(child: Text(_ripenessResult));
            }
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
