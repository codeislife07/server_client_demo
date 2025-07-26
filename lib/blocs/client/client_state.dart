import '../../models/message_model.dart';

class ClientState {
  final String status;
  final String? ip;
  final int? port;
  final List<String> files;
  final List<MessageModel> messages;

  const ClientState({
    required this.status,
    this.ip,
    this.port,
    this.files = const [],
    this.messages = const [],
  });

  const ClientState.initial()
    : status = 'Not connected',
      ip = null,
      port = null,
      files = const [],
      messages = const [];

  const ClientState.connecting()
    : status = 'Connecting...',
      ip = null,
      port = null,
      files = const [],
      messages = const [];

  const ClientState.connected({
    required String ip,
    required int port,
    List<String> files = const [],
    List<MessageModel> messages = const [],
    String status = 'Connected',
  }) : status = status,
       ip = ip,
       port = port,
       files = files,
       messages = messages;

  ClientState copyWith({
    String? status,
    String? ip,
    int? port,
    List<String>? files,
    List<MessageModel>? messages,
  }) {
    return ClientState(
      status: status ?? this.status,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      files: files ?? this.files,
      messages: messages ?? this.messages,
    );
  }
}
