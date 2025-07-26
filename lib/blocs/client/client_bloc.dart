import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/message_model.dart';
import '../client/client_event.dart';
import '../client/client_state.dart';

class ClientBloc extends Bloc<ClientEvent, ClientState> {
  Socket? socket;

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
      socket = await Socket.connect(event.ip, event.port);
      log('Connected to server');
      emit(ClientState.connected(ip: event.ip, port: event.port, messages: []));

      IOSink? sink;
      String? fileName;
      int? fileSize;
      int bytesReceived = 0;

      socket!.listen(
        (data) async {
          final message = utf8.decode(data, allowMalformed: true);
          log('Received raw data: $message');

          if (message.startsWith('MSG:')) {
            final text = message.substring(4);
            log('Received text message: $text');
            add(ReceiveMessage(text));
          } else if (message.startsWith('LIST:')) {
            final files = message
                .substring(5)
                .split(',')
                .where((f) => f.isNotEmpty)
                .toList();
            log('Received file list: $files');
            add(ReceiveFileList(files));
          } else if (message.startsWith('FILE:')) {
            final parts = message.split(':');
            fileName = parts[1];
            fileSize = int.parse(parts[2]);
            final filePath =
                '${(await getApplicationDocumentsDirectory()).path}/$fileName';
            log('Receiving file: $fileName ($fileSize bytes) at $filePath');
            sink = File(filePath).openWrite();
            bytesReceived = 0;
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
            }
          } else if (message.startsWith('ERROR:')) {
            log('Server error message: $message');
            add(ReceiveMessage(message));
          }
        },
        onError: (e) {
          log('Socket error: $e');
          add(ReceiveMessage('Error: $e'));
          socket?.close();
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
      log('Sending download request for file: ${event.fileName}');
      socket!.write('DOWNLOAD:${event.fileName}');
      emit(state.copyWith(status: 'Downloading ${event.fileName}...'));
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
      socket!.write('MSG:${event.message}');
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
    }
  }

  Future<void> _onSendFile(SendFile event, Emitter<ClientState> emit) async {
    if (socket != null) {
      final file = File(event.filePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        final fileName = file.path.split('/').last;
        log('Sending file: $fileName ($fileSize bytes)');

        socket!.write('FILE:$fileName:$fileSize');
        await for (var chunk in file.openRead()) {
          socket!.add(chunk);
        }

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
