import 'dart:convert';
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
      emit(const ClientState.connecting());
      socket = await Socket.connect(event.ip, event.port);
      emit(ClientState.connected(ip: event.ip, port: event.port, messages: []));

      IOSink? sink;
      String? fileName;
      int? fileSize;
      int bytesReceived = 0;

      socket!.listen(
        (data) async {
          final message = utf8.decode(data, allowMalformed: true);
          if (message.startsWith('MSG:')) {
            final text = message.substring(4);
            add(ReceiveMessage(text));
          } else if (message.startsWith('LIST:')) {
            final files = message
                .substring(5)
                .split(',')
                .where((f) => f.isNotEmpty)
                .toList();
            add(ReceiveFileList(files));
          } else if (message.startsWith('FILE:')) {
            final parts = message.split(':');
            fileName = parts[1];
            fileSize = int.parse(parts[2]);
            sink = File(
              '${(await getApplicationDocumentsDirectory()).path}/$fileName',
            ).openWrite();
            bytesReceived = 0;
          } else if (fileName != null && sink != null) {
            sink?.add(data);
            bytesReceived += data.length;
            if (bytesReceived >= fileSize!) {
              sink?.close();
              add(ReceiveFile(fileName!));
              sink = null;
              fileName = null;
            }
          } else if (message.startsWith('ERROR:')) {
            add(ReceiveMessage(message));
          }
        },
        onError: (e) {
          add(ReceiveMessage('Error: $e'));
          socket?.close();
          emit(const ClientState.initial());
        },
        onDone: () {
          add(ReceiveMessage('Server disconnected'));
          emit(const ClientState.initial());
          socket?.close();
        },
      );
    } catch (e) {
      emit(ClientState.error('Error connecting: $e'));
    }
  }

  Future<void> _onDownloadFile(
    DownloadFile event,
    Emitter<ClientState> emit,
  ) async {
    try {
      socket!.write('DOWNLOAD:${event.fileName}');
      emit(state.copyWith(status: 'Downloading ${event.fileName}...'));
    } catch (e) {
      emit(ClientState.error('Error: $e'));
    }
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<ClientState> emit,
  ) async {
    if (socket != null) {
      socket!.write('MSG:${event.message}');
      emit(
        state.copyWith(
          messages: [
            ...state.messages,
            MessageModel(text: event.message, files: [], isSent: true),
          ],
        ),
      );
    }
  }

  Future<void> _onSendFile(SendFile event, Emitter<ClientState> emit) async {
    if (socket != null) {
      final file = File(event.filePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        final fileName = file.path.split('/').last;
        socket!.write('FILE:$fileName:$fileSize');
        await for (var chunk in file.openRead()) {
          socket!.write(chunk);
        }
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
      }
    }
  }

  Future<void> _onReceiveMessage(
    ReceiveMessage event,
    Emitter<ClientState> emit,
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
    Emitter<ClientState> emit,
  ) async {
    emit(state.copyWith(files: event.files));
  }

  Future<void> _onReceiveFile(
    ReceiveFile event,
    Emitter<ClientState> emit,
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

  Future<void> _onDisconnect(
    Disconnect event,
    Emitter<ClientState> emit,
  ) async {
    socket?.close();
    socket = null;
    emit(const ClientState.initial());
  }

  @override
  Future<void> close() {
    socket?.close();
    return super.close();
  }
}
