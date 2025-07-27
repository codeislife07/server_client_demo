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
      socket = await Socket.connect(
        event.ip,
        event.port,
        timeout: const Duration(seconds: 10),
      );
      log('Connected to server');
      emit(ClientState.connected(ip: event.ip, port: event.port, messages: []));

      IOSink? sink;
      String? fileName;
      int? fileSize;
      int bytesReceived = 0;
      StringBuffer headerBuffer = StringBuffer();

      socket!.listen(
        (data) async {
          final message = utf8.decode(data, allowMalformed: true);
          if (fileName == null && message.contains('\n')) {
            headerBuffer.write(message);
            final parts = headerBuffer.toString().split('\n');
            headerBuffer.clear();
            for (var part in parts) {
              if (part.isEmpty) continue;
              try {
                final header = jsonDecode(part);
                log('Received header: $header');
                if (header['type'] == 'message') {
                  final text = header['text'] as String;
                  log('Received text message: $text');
                  add(ReceiveMessage(text));
                } else if (header['type'] == 'list') {
                  final files = (header['files'] as List<dynamic>)
                      .cast<String>();
                  log('Received file list: $files');
                  add(ReceiveFileList(files));
                } else if (header['type'] == 'file') {
                  fileName = header['fileName'] as String;
                  fileSize = header['fileSize'] as int;
                  final filePath =
                      '${(await getApplicationDocumentsDirectory()).path}/$fileName';
                  log(
                    'Receiving file: $fileName ($fileSize bytes) at $filePath',
                  );
                  sink = File(filePath).openWrite();
                  bytesReceived = 0;
                } else if (header['type'] == 'error') {
                  final error = header['message'] as String;
                  log('Server error: $error');
                  add(ReceiveMessage('Error: $error'));
                }
              } catch (e) {
                log('Invalid header: $part, error: $e');
                headerBuffer.write('$part\n');
              }
            }
          } else if (fileName != null && sink != null) {
            sink?.add(data);
            bytesReceived += data.length;
            log('Receiving file chunk: $bytesReceived / $fileSize');
            if (bytesReceived >= fileSize!) {
              await sink?.close();
              log('File received completely: $fileName');
              add(ReceiveFile(fileName!));
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
          'fileName': event.fileName,
          'fileId': _uuid.v4(),
        });
        socket!.write('$header\n');
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
      log('Sending message: ${event.message}');
      final header = jsonEncode({
        'type': 'message',
        'text': event.message,
        'fileId': _uuid.v4(),
      });
      socket!.write('$header\n');
      emit(
        state.copyWith(
          messages: [
            ...state.messages,
            MessageModel(text: event.message, files: [], isSent: true),
          ],
        ),
      );
    } else {
      log('Send message failed: Socket is null');
      emit(ClientState.error('Error: Socket not connected'));
    }
  }

  Future<void> _onSendFile(SendFile event, Emitter<ClientState> emit) async {
    if (socket != null) {
      final file = File(event.filePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        final fileName = file.path.split('/').last;
        log('Sending file: $fileName ($fileSize bytes)');

        final header = jsonEncode({
          'type': 'file',
          'fileName': fileName,
          'fileSize': fileSize,
          'fileId': _uuid.v4(),
        });
        socket!.write('$header\n');
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
              ),
            ],
          ),
        );
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
