import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:sign_bridge/features/auth/providers/auth_provider.dart';
import 'package:sign_bridge/features/object/ui.dart';
import 'package:sign_bridge/features/splash/screens/splash_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    try {
      await dotenv.load(fileName: "assets/.env");
    } catch (_) {
      // Ignored: AppConfig provides fallback constants if .env is missing or blocked by asset packaging.
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'SignBridge',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2B2D5D),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            home: const BlindPathNavigatorScreen(),
          );
        },
      ),
    );
  }
}