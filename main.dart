import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  runApp(const KariesApp());
}

class KariesApp extends StatelessWidget {
  const KariesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deteksi Karies Gigi',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Interpreter? _interpreter;
  File? _image;
  String _result = "Belum ada prediksi";
  bool _isKaries = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      var options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        'assets/model.tflite',
        options: options,
      );
      debugPrint("✅ Model berhasil dimuat");
    } catch (e) {
      debugPrint("❌ Gagal load model: $e");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _result = "Sedang memproses...";
        _isKaries = false;
      });
      await _runOnPickedImage(File(pickedFile.path));
    }
  }

  Future<void> _runOnPickedImage(File imageFile) async {
    if (_interpreter == null) {
      setState(() {
        _result = "Model belum siap!";
      });
      return;
    }

    try {
      final raw = File(imageFile.path).readAsBytesSync();
      img.Image? oriImage = img.decodeImage(raw);
      img.Image resized = img.copyResize(oriImage!, width: 224, height: 224);

      var input = List.generate(
        1,
        (i) => List.generate(
          224,
          (j) => List.generate(224, (k) => List.filled(3, 0.0)),
        ),
      );
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resized.getPixel(x, y);
          input[0][y][x][0] = pixel.r / 255.0;
          input[0][y][x][1] = pixel.g / 255.0;
          input[0][y][x][2] = pixel.b / 255.0;
        }
      }

      var outputTensors = _interpreter!.getOutputTensors();
      var shape = outputTensors.first.shape;

      String label = "Tidak diketahui";
      double probSehat = 0.0, probKaries = 0.0;

      if (shape[1] == 1) {
        var output = List.filled(1, 0.0).reshape([1, 1]);
        _interpreter!.run(input, output);

        double value = output[0][0];
        label = value > 0.5 ? "Karies ⚠️" : "Sehat 🦷";
        probKaries = value;
        probSehat = 1 - value;
      } else if (shape[1] == 2) {
        var output = List.filled(2, 0.0).reshape([1, 2]);
        _interpreter!.run(input, output);

        probSehat = output[0][0];
        probKaries = output[0][1];
        label = probSehat > probKaries ? "Sehat 🦷" : "Karies ⚠️";
      }

      setState(() {
        _result =
            "$label\nSehat: ${(probSehat * 100).toStringAsFixed(2)}%\nKaries: ${(probKaries * 100).toStringAsFixed(2)}%";
        _isKaries = label.contains("Karies");
      });
    } catch (e) {
      debugPrint("❌ Error saat prediksi: $e");
      setState(() {
        _result = "Terjadi error saat memproses gambar.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Deteksi Karies Gigi")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ✅ Gambar full width
            Container(
              width: double.infinity,
              height: 250,
              color: Colors.grey[300],
              child: _image != null
                  ? Image.file(_image!, fit: BoxFit.cover)
                  : const Icon(Icons.image, size: 150, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // ✅ Hasil prediksi dengan warna dinamis
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                _result,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isKaries ? Colors.red : Colors.green,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ✅ Tombol full kiri-kanan
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Kamera"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo),
                    label: const Text("Galeri"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
