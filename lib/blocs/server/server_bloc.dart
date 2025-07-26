import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/message_model.dart';
import '../server/server_event.dart';
import '../server/server_state.dart';

class ServerBloc extends Bloc<ServerEvent, ServerState> {
  ServerSocket? serverSocket;
  List<Socket> clientSockets = [];
  Map<Socket, IOSink?> fileSinks = {};
  Map<Socket, String?> fileNames = {};
  Map<Socket, int?> fileSizes = {};
  Map<Socket, int> bytesReceived = {};

  ServerBloc() : super(const ServerState.initial()) {
    on<StartServer>(_onStartServer);
    on<StopServer>(_onStopServer);
    on<SendMessage>(_onSendMessage);
    on<SendFile>(_onSendFile);
    on<ReceiveMessage>(_onReceiveMessage);
    on<ReceiveFileList>(_onReceiveFileList);
    on<ReceiveFile>(_onReceiveFile);
    on<ReceiveError>(_onReceiveError);
    on<ClientConnected>(_onClientConnected);
    on<ClientDisconnected>(_onClientDisconnected);
  }

  Future<void> _onStartServer(
    StartServer event,
    Emitter<ServerState> emit,
  ) async {
    try {
      log('Starting server on port ${event.port}');
      emit(const ServerState.loading());
      final ip = await _getServerIp();
      serverSocket = await ServerSocket.bind(ip, event.port);
      log('Server running at $ip:${event.port}');
      emit(
        ServerState.running(
          ip: ip,
          port: event.port,
          qrData: '$ip:${event.port}',
          messages: [],
        ),
      );

      serverSocket!.listen((client) async {
        log(
          'Client connected: ${client.remoteAddress.address}:${client.remotePort}',
        );
        clientSockets.add(client);
        add(const ClientConnected());

        final directory = await getApplicationDocumentsDirectory();
        final files = directory
            .listSync()
            .whereType<File>()
            .map((f) => f.path.split('/').last)
            .toList();
        client.write(utf8.encoder.convert('LIST:${files.join(',')}'));

        client.listen(
          (data) async {
            final message = utf8.decode(data, allowMalformed: true);
            log('Received data from client: $message');

            if (message.startsWith('MSG:')) {
              final text = message.substring(4);
              log('Received message: $text');
              add(ReceiveMessage(text));

              for (var socket in clientSockets) {
                if (socket != client) {
                  socket.write(utf8.encoder.convert('MSG:$text'));
                }
              }
            } else if (message.startsWith('DOWNLOAD:')) {
              final requestedFile = message.substring(9);
              final file = File('${directory.path}/$requestedFile');
              if (await file.exists()) {
                final fileSize = await file.length();
                log('Sending file $requestedFile ($fileSize bytes) to client');
                client.write(
                  utf8.encoder.convert('FILE:$requestedFile:$fileSize'),
                );
                await for (var chunk in file.openRead()) {
                  client.write(chunk);
                }
              } else {
                log('File not found: $requestedFile');
                client.write(utf8.encoder.convert('ERROR:File not found'));
                add(ReceiveError('File not found: $requestedFile'));
              }
            } else if (message.startsWith('FILE:')) {
              final parts = message.split(':');
              fileNames[client] = parts[1];
              fileSizes[client] = int.parse(parts[2]);
              fileSinks[client] = File(
                '${directory.path}/${parts[1]}',
              ).openWrite();
              bytesReceived[client] = 0;
              log('Preparing to receive file: ${parts[1]} (${parts[2]} bytes)');
            } else if (fileNames[client] != null && fileSinks[client] != null) {
              fileSinks[client]!.add(data);
              bytesReceived[client] = bytesReceived[client]! + data.length;
              log(
                'Receiving file data: ${fileNames[client]} (${bytesReceived[client]} / ${fileSizes[client]})',
              );

              if (bytesReceived[client]! >= fileSizes[client]!) {
                await fileSinks[client]!.close();
                log('File received completely: ${fileNames[client]}');
                add(ReceiveFile(fileNames[client]!));

                fileSinks[client] = null;
                fileNames[client] = null;
                fileSizes[client] = null;
                bytesReceived[client] = 0;

                final updatedFiles = directory
                    .listSync()
                    .whereType<File>()
                    .map((f) => f.path.split('/').last)
                    .toList();
                add(ReceiveFileList(updatedFiles));

                for (var socket in clientSockets) {
                  socket.write(
                    utf8.encoder.convert('LIST:${updatedFiles.join(',')}'),
                  );
                }
              }
            }
          },
          onError: (e) {
            log('Error from client: $e');
            client.write(utf8.encoder.convert('ERROR:$e'));
            _cleanupClient(client);
            add(const ClientDisconnected());
          },
          onDone: () {
            log('Client disconnected: ${client.remoteAddress.address}');
            _cleanupClient(client);
            add(const ClientDisconnected());
          },
        );
      });
    } catch (e) {
      log('Error starting server: $e');
      add(ReceiveError('Error starting server: $e'));
    }
  }

  void _cleanupClient(Socket client) {
    log('Cleaning up client: ${client.remoteAddress.address}');
    fileSinks[client]?.close();
    clientSockets.remove(client);
    fileSinks.remove(client);
    fileNames.remove(client);
    fileSizes.remove(client);
    bytesReceived.remove(client);
    client.close();
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<ServerState> emit,
  ) async {
    log('Broadcasting message to clients: ${event.message}');
    for (var socket in clientSockets) {
      socket.write(utf8.encoder.convert('MSG:${event.message}'));
    }
    emit(
      state.copyWith(
        messages: [
          ...state.messages,
          MessageModel(text: event.message, isSent: true, files: []),
        ],
      ),
    );
  }

  Future<void> _onSendFile(SendFile event, Emitter<ServerState> emit) async {
    final file = File(event.filePath);
    if (await file.exists()) {
      final fileSize = await file.length();
      final fileName = file.path.split('/').last;
      log('Sending file: $fileName ($fileSize bytes) to all clients');
      for (var socket in clientSockets) {
        socket.write(utf8.encoder.convert('FILE:$fileName:$fileSize'));
        await for (var chunk in file.openRead()) {
          socket.write(chunk);
        }
      }
      emit(
        state.copyWith(
          messages: [
            ...state.messages,
            MessageModel(text: 'Sent file: $fileName', isSent: true, files: []),
          ],
        ),
      );
    } else {
      log('File not found to send: ${event.filePath}');
      add(ReceiveError('File not found: ${event.filePath}'));
    }
  }

  Future<void> _onReceiveMessage(
    ReceiveMessage event,
    Emitter<ServerState> emit,
  ) async {
    log('Received message event: ${event.message}');
    emit(
      state.copyWith(
        messages: [
          ...state.messages,
          MessageModel(text: event.message, isSent: false, files: []),
        ],
      ),
    );
  }

  Future<void> _onReceiveFileList(
    ReceiveFileList event,
    Emitter<ServerState> emit,
  ) async {
    log('Updating file list in state');
    emit(state.copyWith(files: event.files));
  }

  Future<void> _onReceiveFile(
    ReceiveFile event,
    Emitter<ServerState> emit,
  ) async {
    log('File received event: ${event.fileName}');
    emit(
      state.copyWith(
        messages: [
          ...state.messages,
          MessageModel(
            text: 'Received file: ${event.fileName}',
            isSent: false,
            files: [],
          ),
        ],
      ),
    );
  }

  Future<void> _onReceiveError(
    ReceiveError event,
    Emitter<ServerState> emit,
  ) async {
    log('Server error: ${event.error}');
    emit(ServerState.error(event.error));
  }

  Future<void> _onClientConnected(
    ClientConnected event,
    Emitter<ServerState> emit,
  ) async {
    log('Client connected. Total clients: ${clientSockets.length}');
    emit(state.copyWith(connectedClients: clientSockets.length));
  }

  Future<void> _onClientDisconnected(
    ClientDisconnected event,
    Emitter<ServerState> emit,
  ) async {
    log('Client disconnected. Remaining clients: ${clientSockets.length}');
    emit(
      state.copyWith(
        connectedClients: clientSockets.length,
        messages: [
          ...state.messages,
          MessageModel(text: 'Client disconnected', isSent: false, files: []),
        ],
      ),
    );
  }

  Future<void> _onStopServer(
    StopServer event,
    Emitter<ServerState> emit,
  ) async {
    log('Stopping server...');
    await serverSocket?.close();
    for (var socket in clientSockets) {
      socket.close();
    }
    clientSockets.clear();
    fileSinks.clear();
    fileNames.clear();
    fileSizes.clear();
    bytesReceived.clear();
    serverSocket = null;
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
    return '127.0.0.1';
  }

  @override
  Future<void> close() {
    log('Closing server and all connections');
    serverSocket?.close();
    for (var socket in clientSockets) {
      socket.close();
    }
    return super.close();
  }
}
