import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
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
  Map<Socket, StringBuffer> headerBuffers = {};
  final Uuid _uuid = const Uuid();

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
      serverSocket = await ServerSocket.bind(ip, event.port, shared: true);
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
        log('Client connected: ${client.remoteAddress.address}:${client.remotePort}');
        clientSockets.add(client);
        headerBuffers[client] = StringBuffer();
        add(const ClientConnected());

        final directory = await getApplicationDocumentsDirectory();
        final files = directory
            .listSync()
            .whereType<File>()
            .map((f) => f.path.split('/').last)
            .toList();
        final header = jsonEncode({
          'type': 'list',
          'files': files,
          'fileId': _uuid.v4(),
        });
        client.write(utf8.encoder.convert('$header\n'));
        await client.flush();

        client.listen(
          (data) async {
            final message = utf8.decode(data, allowMalformed: true);
            if (fileNames[client] == null && message.contains('\n')) {
              headerBuffers[client]!.write(message);
              final parts = headerBuffers[client]!.toString().split('\n');
              headerBuffers[client]!.clear();
              for (var part in parts) {
                if (part.isEmpty) continue;
                try {
                  final header = jsonDecode(part);
                  log('Received header from client: $header');
                  if (header['type'] == 'message') {
                    final text = header['text'] as String;
                    log('Received message: $text');
                    add(ReceiveMessage(text));
                    for (var socket in clientSockets) {
                      if (socket != client) {
                        socket.write(utf8.encoder.convert('$header\n'));
                        await socket.flush();
                      }
                    }
                  } else if (header['type'] == 'download') {
                    final requestedFile = header['fileName'] as String;
                    final file = File('${directory.path}/$requestedFile');
                    if (await file.exists()) {
                      final fileSize = await file.length();
                      log('Sending file $requestedFile ($fileSize bytes) to client');
                      final fileHeader = jsonEncode({
                        'type': 'file',
                        'fileName': requestedFile,
                        'fileSize': fileSize,
                        'fileId': _uuid.v4(),
                      });
                      client.write(utf8.encoder.convert('$fileHeader\n'));
                      await client.flush();
                      await for (var chunk in file.openRead()) {
                        client.write(chunk);
                      }
                      await client.flush();
                    } else {
                      log('File not found: $requestedFile');
                      final errorHeader = jsonEncode({
                        'type': 'error',
                        'message': 'File not found: $requestedFile',
                        'fileId': _uuid.v4(),
                      });
                      client.write(utf8.encoder.convert('$errorHeader\n'));
                      await client.flush();
                      add(ReceiveError('File not found: $requestedFile'));
                    }
                  } else if (header['type'] == 'file') {
                    final fileName = header['fileName'] as String?;
                    final fileSize = header['fileSize'] as int?;
                    if (fileName == null || fileSize == null) {
                      log('Invalid file header: missing fileName or fileSize');
                      final errorHeader = jsonEncode({
                        'type': 'error',
                        'message': 'Invalid file header',
                        'fileId': _uuid.v4(),
                      });
                      client.write(utf8.encoder.convert('$errorHeader\n'));
                      await client.flush();
                      add(ReceiveError('Invalid file header'));
                      continue;
                    }
                    fileNames[client] = fileName;
                    fileSizes[client] = fileSize;
                    final filePath = '${directory.path}/$fileName';
                    fileSinks[client] = File(filePath).openWrite();
                    bytesReceived[client] = 0;
                    log('Preparing to receive file: $fileName ($fileSize bytes) at $filePath');
                  } else {
                    log('Unknown header type: ${header['type']}');
                    final errorHeader = jsonEncode({
                      'type': 'error',
                      'message': 'Unknown header type: ${header['type']}',
                      'fileId': _uuid.v4(),
                    });
                    client.write(utf8.encoder.convert('$errorHeader\n'));
                    await client.flush();
                    add(ReceiveError('Unknown header type: ${header['type']}'));
                  }
                } catch (e) {
                  log('Invalid header: $part, error: $e');
                  final errorHeader = jsonEncode({
                    'type': 'error',
                    'message': 'Invalid header: $e',
                    'fileId': _uuid.v4(),
                  });
                  client.write(utf8.encoder.convert('$errorHeader\n'));
                  await client.flush();
                  headerBuffers[client]!.write('$part\n');
                  add(ReceiveError('Invalid header: $e'));
                }
              }
            } else if (fileNames[client] != null && fileSinks[client] != null) {
              try {
                fileSinks[client]!.add(data);
                bytesReceived[client] = bytesReceived[client]! + data.length;
                log('Receiving file data: ${fileNames[client]} (${bytesReceived[client]} / ${fileSizes[client]})');

                if (bytesReceived[client]! >= fileSizes[client]!) {
                  await fileSinks[client]!.flush();
                  await fileSinks[client]!.close();
                  final filePath =
                      '${(await getApplicationDocumentsDirectory()).path}/${fileNames[client]}';
                  final savedFile = File(filePath);
                  final savedSize = await savedFile.length();
                  if (savedSize == fileSizes[client]) {
                    log('File received and verified: ${fileNames[client]} ($savedSize bytes) at $filePath');
                    add(ReceiveFile(fileNames[client]!, filePath));
                  } else {
                    log('File size mismatch for ${fileNames[client]}: expected ${fileSizes[client]}, got $savedSize');
                    final errorHeader = jsonEncode({
                      'type': 'error',
                      'message': 'File size mismatch for ${fileNames[client]}',
                      'fileId': _uuid.v4(),
                    });
                    for (var socket in clientSockets) {
                      socket.write(utf8.encoder.convert('$errorHeader\n'));
                      await socket.flush();
                    }
                    add(ReceiveError(
                        'File size mismatch for ${fileNames[client]}'));
                  }
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

                  final fileListHeader = jsonEncode({
                    'type': 'list',
                    'files': updatedFiles,
                    'fileId': _uuid.v4(),
                  });
                  for (var socket in clientSockets) {
                    socket.write(utf8.encoder.convert('$fileListHeader\n'));
                    await socket.flush();
                  }
                }
              } catch (e) {
                log('Error writing file ${fileNames[client]}: $e');
                final errorHeader = jsonEncode({
                  'type': 'error',
                  'message': 'Error writing file: $e',
                  'fileId': _uuid.v4(),
                });
                for (var socket in clientSockets) {
                  socket.write(utf8.encoder.convert('$errorHeader\n'));
                  await socket.flush();
                }
                add(ReceiveError(
                    'Error writing file ${fileNames[client]}: $e'));
                _cleanupClient(client);
              }
            } else {
              headerBuffers[client]!.write(message);
            }
          },
          onError: (e) {
            log('Error from client: $e');
            final errorHeader = jsonEncode({
              'type': 'error',
              'message': e.toString(),
              'fileId': _uuid.v4(),
            });
            client.write(utf8.encoder.convert('$errorHeader\n'));
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
    headerBuffers.remove(client);
    client.close();
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<ServerState> emit,
  ) async {
    log('Broadcasting message to clients: ${event.message}');
    final header = jsonEncode({
      'type': 'message',
      'text': event.message,
      'fileId': _uuid.v4(),
    });

    for (var socket in clientSockets) {
      socket!.write('$header\n');
      await socket!.flush();
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

  Future<void> _onSendFile(
    SendFile event,
    Emitter<ServerState> emit,
  ) async {
    final file = File(event.filePath);
    if (await file.exists()) {
      final fileSize = await file.length();
      final fileName = file.path.split('/').last;
      log('Sending file: $fileName ($fileSize bytes) to all clients');
      final header = jsonEncode({
        'type': 'file',
        'fileName': fileName,
        'fileSize': fileSize,
        'fileId': _uuid.v4(),
      });
      for (var socket in clientSockets) {
        socket.write('$header\n');
        await socket.flush();
        await for (var chunk in file.openRead()) {
          socket.add(chunk);
        }
        await socket.flush();
      }
      emit(
        state.copyWith(
          messages: [
            ...state.messages,
            MessageModel(
              text: 'Sent file: $fileName',
              isSent: true,
              files: [],
              filePath: event.filePath,
            ),
          ],
          filePaths: [...state.filePaths, event.filePath],
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
    log('File received event: ${event.fileName} at ${event.filePath}');
    emit(
      state.copyWith(
        messages: [
          ...state.messages,
          MessageModel(
            text: 'Received file: ${event.fileName}',
            isSent: false,
            files: [],
            filePath: event.filePath,
          ),
        ],
        filePaths: [...state.filePaths, event.filePath],
      ),
    );
  }

  Future<void> _onReceiveError(
    ReceiveError event,
    Emitter<ServerState> emit,
  ) async {
    log('Server error: ${event.error}');
    emit(state.copyWith(
      messages: [
        ...state.messages,
        MessageModel(
          text: 'Error: ${event.error}',
          isSent: false,
          files: [],
        ),
      ],
    ));
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
    headerBuffers.clear();
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
    return '0.0.0.0';
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
