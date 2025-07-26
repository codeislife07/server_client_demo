import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../blocs/client/client_bloc.dart';
import '../blocs/client/client_event.dart';
import '../blocs/client/client_state.dart';
import '../widgets/file_list_widget.dart';
import '../widgets/message_list_widget.dart';
import '../services/permission_service.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  _ClientScreenState createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final TextEditingController ipController = TextEditingController();
  final TextEditingController portController = TextEditingController(
    text: '5000',
  );
  final TextEditingController messageController = TextEditingController();
  MobileScannerController? scannerController;

  @override
  void initState() {
    super.initState();
    PermissionService.requestPermissions();
    scannerController = MobileScannerController();
  }

  void _onQRCodeDetected(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final qrData = barcodes.first.rawValue;
      if (qrData != null) {
        final parts = qrData.split(':');
        if (parts.length == 2) {
          ipController.text = parts[0];
          portController.text = parts[1];
          context.read<ClientBloc>().add(
            ConnectToServer(parts[0], int.parse(parts[1])),
          );
          scannerController?.stop();
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  void dispose() {
    scannerController?.dispose();
    ipController.dispose();
    portController.dispose();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Client')),
      body: BlocBuilder<ClientBloc, ClientState>(
        builder: (context, state) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.status,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: ipController,
                            decoration: const InputDecoration(
                              labelText: 'Server IP',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: portController,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  context.read<ClientBloc>().add(
                                    ConnectToServer(
                                      ipController.text,
                                      int.parse(portController.text),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.connect_without_contact),
                                label: const Text('Connect'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      child: SizedBox(
                                        width: 300,
                                        height: 300,
                                        child: MobileScanner(
                                          controller: scannerController,
                                          onDetect: _onQRCodeDetected,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text('Scan QR'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Available Files:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Flexible(
                    child: SizedBox(
                      height: 200, // Fixed height for file list
                      child: FileListWidget(
                        files: state.files,
                        onFileSelected: (file) {
                          context.read<ClientBloc>().add(DownloadFile(file));
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Messages:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Flexible(
                    child: SizedBox(
                      height: 200, // Fixed height for message list
                      child: MessageListWidget(messages: state.messages),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: messageController,
                              decoration: const InputDecoration(
                                labelText: 'Send a message',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (messageController.text.isNotEmpty) {
                                context.read<ClientBloc>().add(
                                  SendMessage(messageController.text),
                                );
                                messageController.clear();
                              }
                            },
                            icon: const Icon(Icons.send),
                          ),
                          IconButton(
                            onPressed: () async {
                              final result = await FilePicker.platform
                                  .pickFiles();
                              if (result != null &&
                                  result.files.single.path != null) {
                                context.read<ClientBloc>().add(
                                  SendFile(result.files.single.path!),
                                );
                              }
                            },
                            icon: const Icon(Icons.attach_file),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
