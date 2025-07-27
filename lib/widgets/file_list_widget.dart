import 'package:flutter/material.dart';

class FileListWidget extends StatelessWidget {
  final List<String> files;
  final Function(String) onFileSelected;

  const FileListWidget({
    super.key,
    required this.files,
    required this.onFileSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: ClampingScrollPhysics(),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return Card(
          child: ListTile(
            title: Text(file),
            trailing: const Icon(Icons.download),
            onTap: () => onFileSelected(file),
          ),
        );
      },
    );
  }
}
