import '../../models/message_model.dart';

class ServerState {
  final String status;
  final String? ip;
  final int? port;
  final String? qrData;
  final List<String> files;
  final List<MessageModel> messages;

  const ServerState({
    required this.status,
    this.ip,
    this.port,
    this.qrData,
    this.files = const [],
    this.messages = const [],
  });

  const ServerState.initial()
    : status = 'Server not started',
      ip = null,
      port = null,
      qrData = null,
      files = const [],
      messages = const [];

  const ServerState.loading()
    : status = 'Starting server...',
      ip = null,
      port = null,
      qrData = null,
      files = const [],
      messages = const [];

  const ServerState.running({
    required String ip,
    required int port,
    required String qrData,
    List<String> files = const [],
    List<MessageModel> messages = const [],
  }) : status = 'Server running',
       ip = ip,
       port = port,
       qrData = qrData,
       files = files,
       messages = messages;

  const ServerState.error(String message)
    : status = message,
      ip = null,
      port = null,
      qrData = null,
      files = const [],
      messages = const [];

  ServerState copyWith({
    String? status,
    String? ip,
    int? port,
    String? qrData,
    List<String>? files,
    List<MessageModel>? messages,
  }) {
    return ServerState(
      status: status ?? this.status,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      qrData: qrData ?? this.qrData,
      files: files ?? this.files,
      messages: messages ?? this.messages,
    );
  }
}
