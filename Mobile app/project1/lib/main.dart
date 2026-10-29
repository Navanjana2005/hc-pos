import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase.
  // In a real app, these values would come from .env or config.
  // For now, we initialize with placeholders if the real ones aren't available,
  // but since we are falling back to mock data anyway if it fails, it's fine.
  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
    // Perform anonymous sign in if not already signed in
    if (Supabase.instance.client.auth.currentSession == null) {
      await Supabase.instance.client.auth.signInAnonymously();
    }
  } catch (e) {
    debugPrint('Supabase init failed: $e');
  }

  runApp(
    const ProviderScope(
      child: HcPosApp(),
    ),
  );
}

class HcPosApp extends ConsumerWidget {
  const HcPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
