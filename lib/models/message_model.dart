class MessageModel {
  final String text;
  final List<String> files;
  final bool isSent;
  final String? filePath;

  MessageModel({
    required this.text,
    this.files = const [],
    required this.isSent,
    this.filePath,
  });

  MessageModel copyWith({
    String? text,
    List<String>? files,
    bool? isSent,
    String? filePath,
  }) {
    return MessageModel(
      text: text ?? this.text,
      files: files ?? this.files,
      isSent: isSent ?? this.isSent,
      filePath: filePath ?? this.filePath,
    );
  }
}
