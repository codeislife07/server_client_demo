import 'package:equatable/equatable.dart';
import '../../models/message_model.dart';

class ServerState extends Equatable {
  final String status;
  final String? ip;
  final int? port;
  final String? qrData;
  final List<MessageModel> messages;
  final List<String> files;
  final int connectedClients;
  final List<String> filePaths;

  const ServerState({
    required this.status,
    this.ip,
    this.port,
    this.qrData,
    this.messages = const [],
    this.files = const [],
    this.connectedClients = 0,
    this.filePaths = const [],
  });

  const ServerState.initial()
      : status = 'initial',
        ip = null,
        port = null,
        qrData = null,
        messages = const [],
        files = const [],
        connectedClients = 0,
        filePaths = const [];

  const ServerState.loading()
      : status = 'loading',
        ip = null,
        port = null,
        qrData = null,
        messages = const [],
        files = const [],
        connectedClients = 0,
        filePaths = const [];

  ServerState.running({
    required String ip,
    required int port,
    required String qrData,
    List<MessageModel> messages = const [],
    List<String> files = const [],
    int connectedClients = 0,
    List<String> filePaths = const [],
  })  : status = 'running',
        ip = ip,
        port = port,
        qrData = qrData,
        messages = messages,
        files = files,
        connectedClients = connectedClients,
        filePaths = filePaths;

  ServerState.error(String error)
      : status = 'error: $error',
        ip = null,
        port = null,
        qrData = null,
        messages = const [],
        files = const [],
        connectedClients = 0,
        filePaths = const [];

  ServerState copyWith({
    String? status,
    String? ip,
    int? port,
    String? qrData,
    List<MessageModel>? messages,
    List<String>? files,
    int? connectedClients,
    List<String>? filePaths,
  }) {
    return ServerState(
      status: status ?? this.status,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      qrData: qrData ?? this.qrData,
      messages: messages ?? this.messages,
      files: files ?? this.files,
      connectedClients: connectedClients ?? this.connectedClients,
      filePaths: filePaths ?? this.filePaths,
    );
  }

  @override
  List<Object?> get props =>
      [status, ip, port, qrData, messages, files, connectedClients, filePaths];
}
