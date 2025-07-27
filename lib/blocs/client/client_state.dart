import 'package:equatable/equatable.dart';
import '../../models/message_model.dart';

class ClientState extends Equatable {
  final String status;
  final String? ip;
  final int? port;
  final List<MessageModel> messages;
  final List<String> files;
  final List<String> filePaths;

  const ClientState({
    required this.status,
    this.ip,
    this.port,
    this.messages = const [],
    this.files = const [],
    this.filePaths = const [],
  });

  const ClientState.initial()
      : status = 'initial',
        ip = null,
        port = null,
        messages = const [],
        files = const [],
        filePaths = const [];

  const ClientState.connecting()
      : status = 'connecting',
        ip = null,
        port = null,
        messages = const [],
        files = const [],
        filePaths = const [];

  ClientState.connected({
    required String ip,
    required int port,
    List<MessageModel> messages = const [],
    List<String> files = const [],
    List<String> filePaths = const [],
  })  : status = 'connected',
        ip = ip,
        port = port,
        messages = messages,
        files = files,
        filePaths = filePaths;

  ClientState.error(String error)
      : status = 'error: $error',
        ip = null,
        port = null,
        messages = const [],
        files = const [],
        filePaths = const [];

  ClientState copyWith({
    String? status,
    String? ip,
    int? port,
    List<MessageModel>? messages,
    List<String>? files,
    List<String>? filePaths,
  }) {
    return ClientState(
      status: status ?? this.status,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      messages: messages ?? this.messages,
      files: files ?? this.files,
      filePaths: filePaths ?? this.filePaths,
    );
  }

  @override
  List<Object?> get props => [status, ip, port, messages, files, filePaths];
}
