import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/client/client_bloc.dart';
import 'blocs/server/server_bloc.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const FileSharingApp());
}

class FileSharingApp extends StatelessWidget {
  const FileSharingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => ServerBloc()),
        BlocProvider(create: (context) => ClientBloc()),
      ],
      child: MaterialApp(
        title: 'File Sharing App',
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.grey[100],
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            shadowColor: Colors.black26,
          ),
          cardTheme: CardThemeData(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
