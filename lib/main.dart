import 'dart:io';

import 'package:biocaldensmartlifefabrica/Devices/calefactores.dart';
import 'package:biocaldensmartlifefabrica/Devices/detectores.dart';
import 'package:biocaldensmartlifefabrica/Devices/iodevice.dart';
import 'package:biocaldensmartlifefabrica/firebase_options.dart';
import 'package:biocaldensmartlifefabrica/login.dart';
import 'package:biocaldensmartlifefabrica/master.dart';
import 'package:biocaldensmartlifefabrica/menu.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  FlutterError.onError = (FlutterErrorDetails details) async {
    String errorReport = generateErrorReport(details);
    final fileName = 'error_report_${DateTime.now().toIso8601String()}.txt';
    final directory = await getExternalStorageDirectory();
    if (directory != null) {
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(errorReport);
      sendReportOnWhatsApp(file.path);
    } else {
      printLog('Failed to get external storage directory');
    }
  };
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Biocalden Smart Life',
      theme: ThemeData(
        primaryColor: const Color(0xFF2B124C),
        primaryColorLight: const Color(0xFF522B5B),
        textSelectionTheme: const TextSelectionThemeData(
          selectionColor: Color(0xFFdfb6b2),
          selectionHandleColor: Color(0xFFdfb6b2),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2B124C),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/perm',
      routes: {
        '/perm': (context) => const PermissionHandler(),
        '/login': (context) => const LoginPage(),
        '/menu': (context) => const MenuPage(),
        '/loading': (context) => const LoadingPage(),
        '/detector': (context) => const DetectorTabs(),
        '/calefactor':(context) => const CalefactoresTab(),
        '/io':(context) => const IODevicesTab(),
      },
    );
  }
}

//PERMISOS //PRIMERA PARTE

class PermissionHandler extends StatefulWidget {
  const PermissionHandler({super.key});

  @override
  PermissionHandlerState createState() => PermissionHandlerState();
}

class PermissionHandlerState extends State<PermissionHandler> {
  Future<Widget> permissionCheck() async {
    var permissionStatus1 = await Permission.bluetoothConnect.request();

    if (!permissionStatus1.isGranted) {
      await Permission.bluetoothConnect.request();
    }
    permissionStatus1 = await Permission.bluetoothConnect.status;

    var permissionStatus2 = await Permission.bluetoothScan.request();

    if (!permissionStatus2.isGranted) {
      await Permission.bluetoothScan.request();
    }
    permissionStatus2 = await Permission.bluetoothScan.status;

    var permissionStatus3 = await Permission.location.request();

    if (!permissionStatus3.isGranted) {
      await Permission.location.request();
    }
    permissionStatus3 = await Permission.location.status;

    if (permissionStatus1.isGranted &&
        permissionStatus2.isGranted &&
        permissionStatus3.isGranted) {
      return const LoginPage();
    } else {
      return AlertDialog(
        title: const Text('Permisos requeridos'),
        content: const Text(
            'No se puede seguir sin los permisos\n Por favor activalos manualmente'),
        actions: [
          TextButton(
            child: const Text('Abrir opciones de la app'),
            onPressed: () => openAppSettings(),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${snapshot.error} occured',
                style: const TextStyle(fontSize: 18),
              ),
            );
          } else {
            return snapshot.data as Widget;
          }
        }
        return const Center(
          child: CircularProgressIndicator(
            color: Color.fromARGB(255, 189, 189, 189),
          ),
        );
      },
      future: permissionCheck(),
    );
  }
}
