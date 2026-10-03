import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/widgets/BottomNav.dart';
import 'package:client/screens/LoginPageScreen.dart';
import 'package:client/screens/RegisterScreen.dart';
import 'package:client/providers/likedArticleProvider.dart';
import 'package:client/widgets/applogo.dart';
import 'package:client/widgets/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LikedArticlesProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'NewsInsights',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
        routes: {
          'home/': (context) => const BottomNav(),
          'login/': (context) => const LoginPage(),
          'register/': (context) => const MyRegisterPage(),
        },
      ),
    );
  }
}

/// Restores the saved session (and syncs likes) before choosing the first screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final provider = context.read<LikedArticlesProvider>();
    await provider.ensureInitialized();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(provider.isLoggedIn ? 'home/' : 'login/');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CommonLogo()),
    );
  }
}
