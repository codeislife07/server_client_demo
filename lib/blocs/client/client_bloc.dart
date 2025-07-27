import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/message_model.dart';
import '../client/client_event.dart';
import '../client/client_state.dart';

class ClientBloc extends Bloc<ClientEvent, ClientState> {
  Socket? socket;
  final Uuid _uuid = const Uuid();

  ClientBloc() : super(const ClientState.initial()) {
    on<ConnectToServer>(_onConnectToServer);
    on<DownloadFile>(_onDownloadFile);
    on<SendMessage>(_onSendMessage);
    on<SendFile>(_onSendFile);
    on<Disconnect>(_onDisconnect);
    on<ReceiveMessage>(_onReceiveMessage);
    on<ReceiveFileList>(_onReceiveFileList);
    on<ReceiveFile>(_onReceiveFile);
  }

  Future<void> _onConnectToServer(
    ConnectToServer event,
    Emitter<ClientState> emit,
  ) async {
    try {
      log('Connecting to server at ${event.ip}:${event.port}');
      emit(const ClientState.connecting());
      socket = await Socket.connect(event.ip, event.port,
          timeout: const Duration(seconds: 10));
      log('Connected to server');
      emit(ClientState.connected(ip: event.ip, port: event.port, messages: []));

      IOSink? sink;
      String? fileName;
      int? fileSize;
      int bytesReceived = 0;
      StringBuffer headerBuffer = StringBuffer();

      socket!.listen(
        (data) async {
          final message = utf8
              .decode(data, allowMalformed: true)
              .replaceAll('\r\n', '\n')
              .trim();
          if (fileName == null && message.contains('\n')) {
            headerBuffer.write(message);
            final parts = headerBuffer.toString().split('\n');
            headerBuffer.clear();
            for (var part in parts) {
              if (part.isEmpty || part.trim().isEmpty) continue;
              try {
                log('Raw header received: $part');
                final header = jsonDecode(part.trim());
                log('Parsed header: $header');
                if (header['type'] == 'message') {
                  final text = header['text'] as String?;
                  if (text == null) {
                    throw FormatException('Missing text in message header');
                  }
                  log('Received text message: $text');
                  add(ReceiveMessage(text));
                } else if (header['type'] == 'list') {
                  final files =
                      (header['files'] as List<dynamic>?)?.cast<String>();
                  if (files == null) {
                    throw FormatException('Missing files in list header');
                  }
                  log('Received file list: $files');
                  add(ReceiveFileList(files));
                } else if (header['type'] == 'file') {
                  fileName = header['fileName'] as String?;
                  fileSize = header['fileSize'] as int?;
                  if (fileName == null || fileSize == null) {
                    throw FormatException(
                        'Missing fileName or fileSize in file header');
                  }
                  final sanitizedFileName =
                      fileName?.replaceAll(RegExp(r'[^\w\.\-]'), '_');
                  final filePath =
                      '${(await getApplicationDocumentsDirectory()).path}/$sanitizedFileName';
                  log('Receiving file: $sanitizedFileName ($fileSize bytes) at $filePath');
                  sink = File(filePath).openWrite();
                  bytesReceived = 0;
                } else if (header['type'] == 'error') {
                  final error = header['message'] as String?;
                  if (error == null) {
                    throw FormatException('Missing message in error header');
                  }
                  log('Server error: $error');
                  add(ReceiveMessage('Error: $error'));
                }
              } catch (e) {
                log('Invalid header: $part, error: $e');
                headerBuffer.write('$part\n');
                add(ReceiveMessage('Error: Invalid header received'));
              }
            }
          } else if (fileName != null && sink != null) {
            sink?.add(data);
            bytesReceived += data.length;
            log('Receiving file chunk: $bytesReceived / $fileSize');
            if (bytesReceived >= fileSize!) {
              await sink?.flush();
              await sink?.close();
              final filePath =
                  '${(await getApplicationDocumentsDirectory()).path}/$fileName';
              final savedFile = File(filePath);
              final savedSize = await savedFile.length();
              if (savedSize == fileSize) {
                log('File received and verified: $fileName ($savedSize bytes)');
                add(ReceiveFile(fileName!, filePath));
              } else {
                log('File size mismatch for $fileName: expected $fileSize, got $savedSize');
                add(ReceiveMessage('Error: File size mismatch for $fileName'));
              }
              sink = null;
              fileName = null;
              fileSize = null;
              bytesReceived = 0;
            }
          } else {
            headerBuffer.write(message);
          }
        },
        onError: (e) {
          log('Socket error: $e');
          add(ReceiveMessage('Error: $e'));
          socket?.close();
          emit(const ClientState.initial());
        },
        onDone: () {
          log('Server disconnected');
          add(ReceiveMessage('Server disconnected'));
          emit(const ClientState.initial());
          socket?.close();
        },
      );
    } catch (e) {
      log('Connection error: $e');
      emit(ClientState.error('Error connecting: $e'));
    }
  }

  Future<void> _onDownloadFile(
    DownloadFile event,
    Emitter<ClientState> emit,
  ) async {
    try {
      if (socket != null) {
        log('Sending download request for file: ${event.fileName}');
        final header = jsonEncode({
          'type': 'download',
          'fileName': event.fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_'),
          'fileId': _uuid.v4(),
        });
        socket!.write('$header\n');
        await socket!.flush();
        emit(state.copyWith(status: 'Downloading ${event.fileName}...'));
      } else {
        log('Download failed: Socket is null');
        emit(ClientState.error('Error: Socket not connected'));
      }
    } catch (e) {
      log('Download error: $e');
      emit(ClientState.error('Error: $e'));
    }
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<ClientState> emit,
  ) async {
    if (socket != null) {
      try {
        log('Sending message: ${event.message}');
        final header = jsonEncode({
          'type': 'message',
          'text': event.message,
          'fileId': _uuid.v4(),
        });
        log('Sending header: $header');
        socket!.write('$header\n');
        await socket!.flush();
        emit(
          state.copyWith(
            messages: [
              ...state.messages,
              MessageModel(text: event.message, files: [], isSent: true),
            ],
          ),
        );
      } catch (e) {
        log('Error sending message: $e');
        emit(ClientState.error('Error sending message: $e'));
        socket?.close();
        emit(const ClientState.initial());
      }
    } else {
      log('Send message failed: Socket is null');
      emit(ClientState.error('Error: Socket not connected'));
    }
  }

  Future<void> _onSendFile(
    SendFile event,
    Emitter<ClientState> emit,
  ) async {
    if (socket != null) {
      final file = File(event.filePath);
      if (await file.exists()) {
        try {
          final fileSize = await file.length();
          final fileName = file.path
              .split(Platform.pathSeparator)
              .last
              .replaceAll(RegExp(r'[^\w\.\-]'), '_');
          log('Sending file: $fileName ($fileSize bytes)');

          final header = jsonEncode({
            'type': 'file',
            'fileName': fileName,
            'fileSize': fileSize,
            'fileId': _uuid.v4(),
            'platform': Platform.isIOS ? 'ios' : 'android',
          });
          log('Sending header: $header');
          socket!.write('$header\n');
          await socket!.flush();
          await for (var chunk in file.openRead()) {
            socket!.add(chunk);
          }
          await socket!.flush();
          log('File sent: $fileName');
          emit(
            state.copyWith(
              messages: [
                ...state.messages,
                MessageModel(
                  text: 'Sent file: $fileName',
                  files: [],
                  isSent: true,
                  filePath: event.filePath,
                ),
              ],
              filePaths: [...state.filePaths, event.filePath],
            ),
          );
        } catch (e) {
          log('Error sending file: $e');
          emit(ClientState.error('Error sending file: $e'));
        }
      } else {
        log('File not found: ${event.filePath}');
        emit(ClientState.error('File not found: ${event.filePath}'));
      }
    } else {
      log('Send file failed: Socket is null');
      emit(ClientState.error('Error: Socket not connected'));
    }
  }

  Future<void> _onReceiveMessage(
    ReceiveMessage event,
    Emitter<ClientState> emit,
  ) async {
    log('Processing received message: ${event.message}');
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
    Emitter<ClientState> emit,
  ) async {
    log('Updating file list in state: ${event.files}');
    emit(state.copyWith(files: event.files));
  }

  Future<void> _onReceiveFile(
    ReceiveFile event,
    Emitter<ClientState> emit,
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

  Future<void> _onDisconnect(
    Disconnect event,
    Emitter<ClientState> emit,
  ) async {
    log('Disconnecting from server');
    socket?.close();
    socket = null;
    emit(const ClientState.initial());
  }

  @override
  Future<void> close() {
    log('Bloc closed and socket closed');
    socket?.close();
    return super.close();
  }
}
