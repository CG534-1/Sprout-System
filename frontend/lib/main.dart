import 'package:flutter/material.dart';
import 'package:sprout/app.dart';
import 'package:sprout/core/config.dart';
import 'package:sprout/core/notifications/push_service.dart';
import 'package:sprout/core/theme/theme_controller.dart';
import 'package:sprout/data/app_services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = SproutConfig.fromEnvironment();
  if (!config.ready) {
    runApp(const _ConfigMissing());
    return;
  }
  await Supabase.initialize(url: config.supabaseUrl, publishableKey: config.supabaseAnonKey);
  final services = AppServices.remote(
    supabase: Supabase.instance.client,
    apiBase: config.apiBaseUrl,
  );
  await services.auth.restore();
  final theme = ThemeController();
  await theme.load();
  if (services.auth.isSignedIn) {
    await PushService.start(services.profile);
  }
  runApp(SproutApp(services: services, theme: theme));
}

class _ConfigMissing extends StatelessWidget {
  const _ConfigMissing();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Sprout needs SUPABASE_URL, SUPABASE_ANON_KEY, and API_BASE_URL.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
