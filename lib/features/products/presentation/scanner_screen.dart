import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController controller = MobileScannerController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const PhosphorIcon(PhosphorIconsRegular.lightningSlash, color: Colors.grey);
                  case TorchState.on:
                    return const PhosphorIcon(PhosphorIconsRegular.lightning, color: Colors.yellow);
                  case TorchState.auto: // Handle auto case
                    return const PhosphorIcon(PhosphorIconsRegular.lightning, color: Colors.white);
                  case TorchState.unavailable:
                    return const PhosphorIcon(PhosphorIconsRegular.lightningSlash, color: Colors.grey);
                }
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, state, child) {
                switch (state.cameraDirection) {
                  case CameraFacing.front:
                    return const PhosphorIcon(PhosphorIconsRegular.camera);
                  case CameraFacing.back:
                    return const PhosphorIcon(PhosphorIconsRegular.cameraRotate);
                  case CameraFacing.external:
                    return const PhosphorIcon(PhosphorIconsRegular.camera);
                  default:
                    return const PhosphorIcon(PhosphorIconsRegular.camera);
                }
              },
            ),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              // Use addPostFrameCallback to avoid "setState during build" or safe context usage
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  controller.dispose();
                  Navigator.pop(context, barcode.rawValue);
                }
              });
              break;
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
