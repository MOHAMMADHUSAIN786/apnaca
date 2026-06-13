import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Simple full-screen barcode scanner using `mobile_scanner`.
/// Returns the first scanned code via Navigator.pop(context, code).
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;
  bool _torch = false;
  bool _facingBack = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_scanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final String? code = barcodes.first.rawValue;
              if (code != null && code.isNotEmpty) {
                _scanned = true;
                Navigator.of(context).pop(code);
              }
            },
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FloatingActionButton.small(
                  heroTag: 'torch',
                  onPressed: () async {
                    await _controller.toggleTorch();
                    setState(() => _torch = !_torch);
                  },
                  child: Icon(_torch ? Icons.flash_on : Icons.flash_off),
                ),
                FloatingActionButton.small(
                  heroTag: 'flip',
                  onPressed: () async {
                    await _controller.switchCamera();
                    setState(() => _facingBack = !_facingBack);
                  },
                  child: Icon(Icons.cameraswitch),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
