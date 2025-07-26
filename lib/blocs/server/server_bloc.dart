import 'dart:convert';
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
            if (message.startsWith('MSG:')) {
              final text = message.substring(4);
              add(ReceiveMessage(text));
              // Broadcast message to all other clients
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
                client.write(
                  utf8.encoder.convert('FILE:$requestedFile:$fileSize'),
                );
                await for (var chunk in file.openRead()) {
                  client.write(chunk);
                }
              } else {
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
            } else if (fileNames[client] != null && fileSinks[client] != null) {
              fileSinks[client]!.add(data);
              bytesReceived[client] = bytesReceived[client]! + data.length;
              if (bytesReceived[client]! >= fileSizes[client]!) {
                await fileSinks[client]!.close();
                add(ReceiveFile(fileNames[client]!));
                fileSinks[client] = null;
                fileNames[client] = null;
                fileSizes[client] = null;
                bytesReceived[client] = 0;
                final files = directory
                    .listSync()
                    .whereType<File>()
                    .map((f) => f.path.split('/').last)
                    .toList();
                add(ReceiveFileList(files));
                // Broadcast updated file list to all clients
                for (var socket in clientSockets) {
                  socket.write(utf8.encoder.convert('LIST:${files.join(',')}'));
                }
              }
            }
          },
          onError: (e) {
            client.write(utf8.encoder.convert('ERROR:$e'));
            _cleanupClient(client);
            add(const ClientDisconnected());
          },
          onDone: () {
            _cleanupClient(client);
            add(const ClientDisconnected());
          },
        );
      });
    } catch (e) {
      add(ReceiveError('Error starting server: $e'));
    }
  }

  void _cleanupClient(Socket client) {
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
      add(ReceiveError('File not found: ${event.filePath}'));
    }
  }

  Future<void> _onReceiveMessage(
    ReceiveMessage event,
    Emitter<ServerState> emit,
  ) async {
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
    emit(state.copyWith(files: event.files));
  }

  Future<void> _onReceiveFile(
    ReceiveFile event,
    Emitter<ServerState> emit,
  ) async {
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
    emit(ServerState.error(event.error));
  }

  Future<void> _onClientConnected(
    ClientConnected event,
    Emitter<ServerState> emit,
  ) async {
    emit(state.copyWith(connectedClients: clientSockets.length));
  }

  Future<void> _onClientDisconnected(
    ClientDisconnected event,
    Emitter<ServerState> emit,
  ) async {
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
    return 'Unable to get IP';
  }

  @override
  Future<void> close() {
    serverSocket?.close();
    for (var socket in clientSockets) {
      socket.close();
    }
    return super.close();
  }
}
