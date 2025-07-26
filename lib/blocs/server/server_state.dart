import '../../models/message_model.dart';

class ServerState {
  final String status;
  final String? ip;
  final int? port;
  final String? qrData;
  final List<String> files;
  final List<MessageModel> messages;
  final int connectedClients; // New field for client count

  const ServerState({
    required this.status,
    this.ip,
    this.port,
    this.qrData,
    this.files = const [],
    this.messages = const [],
    this.connectedClients = 0,
  });

  const ServerState.initial()
    : status = 'Server not started',
      ip = null,
      port = null,
      qrData = null,
      files = const [],
      messages = const [],
      connectedClients = 0;

  const ServerState.loading()
    : status = 'Starting server...',
      ip = null,
      port = null,
      qrData = null,
      files = const [],
      messages = const [],
      connectedClients = 0;

  const ServerState.running({
    required String ip,
    required int port,
    required String qrData,
    List<String> files = const [],
    List<MessageModel> messages = const [],
    int connectedClients = 0,
  }) : status = 'Server running',
       ip = ip,
       port = port,
       qrData = qrData,
       files = files,
       messages = messages,
       connectedClients = connectedClients;

  const ServerState.error(String error)
    : status = 'Error: $error',
      ip = null,
      port = null,
      qrData = null,
      files = const [],
      messages = const [],
      connectedClients = 0;

  ServerState copyWith({
    String? status,
    String? ip,
    int? port,
    String? qrData,
    List<String>? files,
    List<MessageModel>? messages,
    int? connectedClients,
  }) {
    return ServerState(
      status: status ?? this.status,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      qrData: qrData ?? this.qrData,
      files: files ?? this.files,
      messages: messages ?? this.messages,
      connectedClients: connectedClients ?? this.connectedClients,
    );
  }
}
