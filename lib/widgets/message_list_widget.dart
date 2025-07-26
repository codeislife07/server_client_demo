import 'package:flutter/material.dart';
import '../models/message_model.dart';

class MessageListWidget extends StatelessWidget {
  final List<MessageModel> messages;

  const MessageListWidget({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return Align(
          alignment: message.isSent
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Card(
            color: message.isSent ? Colors.blue[100] : Colors.grey[200],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(message.text),
            ),
          ),
        );
      },
    );
  }
}
