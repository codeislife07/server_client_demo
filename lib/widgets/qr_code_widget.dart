import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeWidget extends StatelessWidget {
  final String qrData;
  final String ip;
  final int port;

  const QrCodeWidget({
    super.key,
    required this.qrData,
    required this.ip,
    required this.port,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Scan this QR code to connect:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            QrImageView(data: qrData, size: 200, backgroundColor: Colors.white),
            const SizedBox(height: 8),
            Text('Server IP: $ip:$port', style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
