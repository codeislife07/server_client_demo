import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../blocs/server/server_bloc.dart';
import '../blocs/server/server_event.dart';
import '../blocs/server/server_state.dart';
import '../widgets/qr_code_widget.dart';
import '../widgets/file_list_widget.dart';
import '../widgets/message_list_widget.dart';

class ServerScreen extends StatelessWidget {
  const ServerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final messageController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Server')),
      body: BlocBuilder<ServerBloc, ServerState>(
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height - 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            state.status,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Connected Clients: ${state.connectedClients}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (state.ip != null && state.qrData != null)
                            QrCodeWidget(
                              qrData: state.qrData!,
                              ip: state.ip!,
                              port: state.port!,
                            ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: state.status == 'Server running'
                                    ? null
                                    : () {
                                        context.read<ServerBloc>().add(
                                          const StartServer(5000),
                                        );
                                      },
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Start Server'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: state.status == 'Server running'
                                    ? () {
                                        context.read<ServerBloc>().add(
                                          const StopServer(),
                                        );
                                      }
                                    : null,
                                icon: const Icon(Icons.stop),
                                label: const Text('Stop Server'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Available Files:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: FileListWidget(
                              files: state.files,
                              onFileSelected: (file) {
                                context.read<ServerBloc>().add(
                                  SendFile('$file'),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Messages:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: MessageListWidget(messages: state.messages),
                          ),
                        ],
                      ),
                    ),
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
                              context.read<ServerBloc>().add(
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
                              context.read<ServerBloc>().add(
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
          );
        },
      ),
    );
  }
}
