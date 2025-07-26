import 'dart:convert';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/message_model.dart';
import '../server/server_event.dart';
import '../server/server_state.dart';

class ServerBloc extends Bloc<ServerEvent, ServerState> {
  ServerSocket? serverSocket;
  Socket? clientSocket;

  ServerBloc() : super(const ServerState.initial()) {
    on<StartServer>(_onStartServer);
    on<StopServer>(_onStopServer);
    on<SendMessage>(_onSendMessage);
    on<SendFile>(_onSendFile);
  }

  Future<void> _onStartServer(
    StartServer event,
    Emitter<ServerState> emit,
  ) async {
    try {
      emit(const ServerState.loading());
      final ip = await _getServerIp();
      serverSocket = await ServerSocket.bind(ip, event.port);
      emit(
        ServerState.running(
          ip: ip,
          port: event.port,
          qrData: '$ip:${event.port}',
          messages: [],
        ),
      );

      serverSocket!.listen((client) async {
        clientSocket = client;
        final directory = await getApplicationDocumentsDirectory();
        final files = directory
            .listSync()
            .whereType<File>()
            .map((f) => f.path.split('/').last)
            .toList();
        client.write(utf8.encoder.convert('LIST:${files.join(',')}'));

        IOSink? sink;
        String? fileName;
        int? fileSize;
        int bytesReceived = 0;

        client.listen(
          (data) async {
            final message = utf8.decode(data, allowMalformed: true);
            if (message.startsWith('MSG:')) {
              final text = message.substring(4);
              emit(
                state.copyWith(
                  messages: [
                    ...state.messages,
                    MessageModel(text: text, isSent: false),
                  ],
                ),
              );
            } else if (message.startsWith('DOWNLOAD:')) {
              final requestedFile = message.substring(9);
              final file = File('${directory.path}/$requestedFile');
              if (await file.exists()) {
                final fileSize = await file.length();
                client.write(
                  utf8.encoder.convert('FILE:$requestedFile:$fileSize'),
                );
                await for (var chunk in file.openRead()) {
                  client.write(chunk);
                }
              } else {
                client.write(utf8.encoder.convert('ERROR:File not found'));
              }
            } else if (message.startsWith('FILE:')) {
              final parts = message.split(':');
              fileName = parts[1];
              fileSize = int.parse(parts[2]);
              sink = File('${directory.path}/$fileName').openWrite();
              bytesReceived = 0;
            } else if (fileName != null && sink != null) {
              sink?.add(data);
              bytesReceived += data.length;
              if (bytesReceived >= fileSize!) {
                await sink?.close();
                sink = null;
                fileName = null;
                final files = directory
                    .listSync()
                    .whereType<File>()
                    .map((f) => f.path.split('/').last)
                    .toList();
                emit(state.copyWith(files: files));
                client.write(utf8.encoder.convert('LIST:${files.join(',')}'));
              }
            }
          },
          onError: (e) {
            client.write(utf8.encoder.convert('ERROR:$e'));
            client.close();
            clientSocket = null;
            emit(
              state.copyWith(
                messages: [
                  ...state.messages,
                  MessageModel(text: 'Client disconnected', isSent: false),
                ],
              ),
            );
          },
          onDone: () {
            sink?.close();
            client.close();
            clientSocket = null;
            emit(
              state.copyWith(
                messages: [
                  ...state.messages,
                  MessageModel(text: 'Client disconnected', isSent: false),
                ],
              ),
            );
          },
        );
      });
    } catch (e) {
      emit(ServerState.error('Error starting server: $e'));
    }
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<ServerState> emit,
  ) async {
    if (clientSocket != null) {
      clientSocket!.write('MSG:${event.message}');
      emit(
        state.copyWith(
          messages: [
            ...state.messages,
            MessageModel(text: event.message, isSent: true),
          ],
        ),
      );
    }
  }

  Future<void> _onSendFile(SendFile event, Emitter<ServerState> emit) async {
    if (clientSocket != null) {
      final file = File(event.filePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        final fileName = file.path.split('/').last;
        clientSocket!.write('FILE:$fileName:$fileSize');
        await for (var chunk in file.openRead()) {
          clientSocket!.write(chunk);
        }
        emit(
          state.copyWith(
            messages: [
              ...state.messages,
              MessageModel(text: 'Sent file: $fileName', isSent: true),
            ],
          ),
        );
      }
    }
  }

  Future<void> _onStopServer(
    StopServer event,
    Emitter<ServerState> emit,
  ) async {
    await serverSocket?.close();
    await clientSocket?.close();
    serverSocket = null;
    clientSocket = null;
    emit(const ServerState.initial());
  }

  Future<String> _getServerIp() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return 'Unable to get IP';
  }

  @override
  Future<void> close() {
    serverSocket?.close();
    clientSocket?.close();
    return super.close();
  }
}
