abstract class ServerEvent {
  const ServerEvent();
}

class StartServer extends ServerEvent {
  final int port;

  const StartServer(this.port);
}

class StopServer extends ServerEvent {
  const StopServer();
}

class SendMessage extends ServerEvent {
  final String message;

  const SendMessage(this.message);
}

class SendFile extends ServerEvent {
  final String filePath;

  const SendFile(this.filePath);
}

class ReceiveMessage extends ServerEvent {
  final String message;

  const ReceiveMessage(this.message);
}

class ReceiveFileList extends ServerEvent {
  final List<String> files;

  const ReceiveFileList(this.files);
}

class ReceiveFile extends ServerEvent {
  final String fileName;

  const ReceiveFile(this.fileName);
}

class ReceiveError extends ServerEvent {
  final String error;

  const ReceiveError(this.error);
}

class ClientConnected extends ServerEvent {
  const ClientConnected();
}

class ClientDisconnected extends ServerEvent {
  const ClientDisconnected();
}
