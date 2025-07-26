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
