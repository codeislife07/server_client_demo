# Flutter TCP File Sharing App

A cross-platform Flutter application for file sharing and messaging over TCP sockets, supporting multi-client connections, QR code scanning for easy server discovery, and file previews. The app is designed to work seamlessly on both iOS and Android, with platform-specific handling for file paths and socket communication.

## Features

- **Multi-Client Support**: Connect multiple clients (iOS/Android) to a single server for simultaneous file sharing and messaging.
- **File Sharing**: Send and receive files (e.g., images, PDFs, text) with size verification and error handling.
- **Real-Time Messaging**: Exchange text messages between server and clients with reliable delivery.
- **QR Code Scanning**: Scan QR codes to auto-connect clients to the server using the `mobile_scanner` package.
- **File Previews**: Preview received files (e.g., PDFs, images) using `flutter_pdfview` and `image` packages.
- **Platform-Specific Handling**: Optimized for iOS (sandboxed file paths) and Android (direct file access).
- **State Management**: Uses `flutter_bloc` for robust state management of server and client operations.
- **Error Handling**: Comprehensive logging and UI feedback for connection, file transfer, and header parsing errors.

## Prerequisites

- **Flutter SDK**: Version 3.24.0 or higher.
- **Dart**: Version 3.5.0 or higher.
- **Devices**: iOS 14.0+ or Android 7.0+.
- **Network**: Devices must be on the same Wi-Fi network for TCP communication.
- **IDE**: Android Studio, VS Code, or any Flutter-compatible IDE.

## Installation

1. **Clone the Repository**:
   ```bash
   git clone <repository-url>
   cd flutter-tcp-file-sharing
   ```

2. **Install Dependencies**:
   Ensure `pubspec.yaml` contains the following dependencies, then run:
   ```bash
   flutter pub get
   ```

3. **Configure iOS Permissions**:
   Update `ios/Runner/Info.plist` to include:
   ```xml
   <key>NSPhotoLibraryUsageDescription</key>
   <string>Access photos for file sharing</string>
   <key>NSFileProviderDomainUsageDescription</key>
   <string>Access files for sharing</string>
   <key>NSCameraUsageDescription</key>
   <string>Access camera for QR code scanning</string>
   ```

4. **Run the App**:
   ```bash
   flutter run
   ```

## Dependencies

Below are the key dependencies used in the project, with keywords for their purpose:

- **flutter_bloc: ^8.1.3**
  - **Keywords**: State management, BLoC pattern, reactive UI
  - Manages server and client states (`ServerBloc`, `ClientBloc`) for robust UI updates.
- **path_provider: ^2.1.1**
  - **Keywords**: File system, storage, cross-platform
  - Accesses app-specific directories for file storage and retrieval.
- **mobile_scanner: ^7.0.1**
  - **Keywords**: QR code, barcode, camera
  - Enables QR code scanning for server IP/port discovery.
- **file_picker: ^8.0.0**
  - **Keywords**: File selection, cross-platform, file access
  - Allows users to pick files for sharing from device storage.
- **uuid: ^4.4.2**
  - **Keywords**: Unique ID, UUID generation
  - Generates unique file IDs for tracking file transfers.
- **open_file_plus: ^4.0.0**
  - **Keywords**: File opening, cross-platform
  - Opens received files (e.g., PDFs, images) in native viewers.
- **flutter_pdfview: ^1.3.2**
  - **Keywords**: PDF viewer, file preview
  - Displays PDF files in the app for previewing.
- **image: ^4.2.0**
  - **Keywords**: Image processing, file preview
  - Handles image file previews and rendering.

Add these to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^8.1.3
  path_provider: ^2.1.1
  mobile_scanner: ^7.0.1
  file_picker: ^8.0.0
  uuid: ^4.4.2
  open_file_plus: ^4.0.0
  flutter_pdfview: ^1.3.2
  image: ^4.2.0
```

## Usage

1. **Start the Server**:
   - Launch the app on a device (e.g., Android tablet).
   - Navigate to the `ServerScreen`.
   - Start the server (default port: 5000).
   - Note the IP address and QR code displayed.

2. **Connect Clients**:
   - On client devices (iOS/Android), open the `ClientScreen`.
   - Scan the QR code or manually enter the server IP and port.
   - Connect to the server.

3. **Send Messages**:
   - On `ClientScreen`, type a message and press the send button.
   - On `ServerScreen`, send messages to all connected clients.
   - Messages appear in the `MessageListWidget` on both screens.

4. **Share Files**:
   - On `ClientScreen`, tap the attach file button to pick a file.
   - Files are sent to the server and appear in `FileListWidget`.
   - Tap files in `FileListWidget` to preview or download.

5. **Preview Files**:
   - Received files (e.g., PDFs, images) can be previewed by tapping in `FileListWidget` or `MessageListWidget`.
   - Uses `flutter_pdfview` for PDFs and `image` for images.

## Project Structure

- **blocs/**
  - `server/server_bloc.dart`: Manages server operations (start, stop, send/receive messages/files).
  - `client/client_bloc.dart`: Handles client connections and file/message transfers.
- **screens/**
  - `server_screen.dart`: UI for starting/stopping server and managing transfers.
  - `client_screen.dart`: UI for connecting to server and sending/receiving data.
- **widgets/**
  - `file_list_widget.dart`: Displays available files with preview/download options.
  - `message_list_widget.dart`: Shows message history with file attachments.
- **models/**
  - `message_model.dart`: Data model for messages and file metadata.

## Troubleshooting

- **Connection Issues**:
  - Ensure all devices are on the same Wi-Fi network.
  - Verify port 5000 is open (`telnet <ip> 5000` or `nc <ip> 5000`).
  - Check server logs for `Server running at <ip>:5000`.
- **Invalid Header Errors**:
  - Share server logs (`Raw header received`, `Invalid header`).
  - Test with simple file names (e.g., `test.txt`).
  - Verify iOS file paths are copied to app directory.
- **Messages Not Sent/Received**:
  - Check client logs for `Sending header`, `Error sending message`.
  - Ensure server logs show `Received message: <text>`.
- **iOS File Issues**:
  - Confirm `Info.plist` permissions for camera and file access.
  - Verify file copy logs in `ClientScreen`.
- **File Previews**:
  - Ensure `flutter_pdfview` and `image` packages are correctly installed.
  - Test with supported file types (PDF, JPEG, PNG).

## Known Limitations

- **Security**: Uses unencrypted TCP; consider SSL/TLS for production.
- **File Size**: Large files may require chunked transfer optimizations.
- **Network**: Requires same Wi-Fi network; no internet support.
- **Error Recovery**: Limited retry logic for failed transfers.

## Future Enhancements

- Add SSL/TLS for secure communication.
- Implement file transfer progress indicators.
- Support internet-based connections via WebSocket.
- Add retry mechanism for failed messages/files.
- Include file checksums for integrity verification.

## Contributing

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/<name>`).
3. Commit changes (`git commit -m "Add feature"`).
4. Push to branch (`git push origin feature/<name>`).
5. Open a pull request.

## License

MIT License. See [LICENSE](LICENSE) for details.
