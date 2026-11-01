import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url {
    final envUrl = dotenv.env['SUPABASE_URL'];
    if (envUrl != null && envUrl.trim().isNotEmpty) {
      return envUrl.trim();
    }
    return 'https://qxruxonusvoxshuwxrah.supabase.co';
  }

  static String get anonKey {
    final envKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (envKey != null && envKey.trim().isNotEmpty) {
      return envKey.trim();
    }
    return 'sb_publishable_MbMRR6syNwtezcWMke6yXw_Y1cozFRo';
  }

  static String get brevoApiKey {
    final envKey = dotenv.env['BREVO_API_KEY'];
    if (envKey != null && envKey.trim().isNotEmpty) {
      return envKey.trim();
    }
    return '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';
  }
}
