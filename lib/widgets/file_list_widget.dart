import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class FileListWidget extends StatelessWidget {
  final List<String> files;
  final List<String> filePaths;
  final Function(String) onFileSelected;

  const FileListWidget({
    super.key,
    required this.files,
    required this.filePaths,
    required this.onFileSelected,
  });

  Future<void> _openFile(BuildContext context, String fileName) async {
    var path = await getApplicationDocumentsDirectory();
    final filePath = filePaths.firstWhere(
      (path) => path.endsWith(fileName),
      orElse: () => '${(path).path}/$fileName',
    );
    final file = File(filePath);

    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File not found: $fileName')),
      );
      return;
    }

    final extension = fileName.split('.').last.toLowerCase();
    if (['png', 'jpg', 'jpeg'].contains(extension)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FilePreviewScreen(filePath: filePath, fileType: 'image'),
        ),
      );
    } else if (extension == 'pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FilePreviewScreen(filePath: filePath, fileType: 'pdf'),
        ),
      );
    } else if (['txt', 'log'].contains(extension)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FilePreviewScreen(filePath: filePath, fileType: 'text'),
        ),
      );
    } else {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: ${result.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return Card(
          child: ListTile(
            title: Text(file),
            trailing: IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => onFileSelected(file),
            ),
            onTap: () => _openFile(context, file),
          ),
        );
      },
    );
  }
}

class FilePreviewScreen extends StatelessWidget {
  final String filePath;
  final String fileType;

  const FilePreviewScreen({
    super.key,
    required this.filePath,
    required this.fileType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Preview: ${filePath.split('/').last}')),
      body: Center(
        child: FutureBuilder<Widget>(
          future: _buildPreview(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            return snapshot.data ?? const Text('Unable to preview file');
          },
        ),
      ),
    );
  }

  Future<Widget> _buildPreview() async {
    final file = File(filePath);
    if (!await file.exists()) {
      return const Text('File not found');
    }

    switch (fileType) {
      case 'image':
        final imageBytes = await file.readAsBytes();
        final decodedImage = img.decodeImage(imageBytes);
        if (decodedImage == null) {
          return const Text('Invalid image file');
        }
        return Image.memory(imageBytes);
      case 'pdf':
        return PDFView(filePath: filePath);
      case 'text':
        final content = await file.readAsString();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Text(content),
        );
      default:
        return const Text('Unsupported file type');
    }
  }
}
