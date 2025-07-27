abstract class ClientEvent {
  const ClientEvent();
}

class ConnectToServer extends ClientEvent {
  final String ip;
  final int port;

  const ConnectToServer(this.ip, this.port);
}

class DownloadFile extends ClientEvent {
  final String fileName;

  const DownloadFile(this.fileName);
}

class SendMessage extends ClientEvent {
  final String message;

  const SendMessage(this.message);
}

class SendFile extends ClientEvent {
  final String filePath;

  const SendFile(this.filePath);
}

class Disconnect extends ClientEvent {
  const Disconnect();
}

class ReceiveMessage extends ClientEvent {
  final String message;

  const ReceiveMessage(this.message);
}

class ReceiveFileList extends ClientEvent {
  final List<String> files;

  const ReceiveFileList(this.files);
}

class ReceiveFile extends ClientEvent {
  final String fileName;
  final String filePath;
  const ReceiveFile(this.fileName, this.filePath);
}
