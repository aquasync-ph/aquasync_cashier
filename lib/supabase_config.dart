import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url =>
      dotenv.env['SUPABASE_URL'] ?? 'https://qxruxonusvoxshuwxrah.supabase.co';

  static String get anonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      'sb_publishable_MbMRR6syNwtezcWMke6yXw_Y1cozFRo';

  static String get brevoApiKey =>
      dotenv.env['BREVO_API_KEY'] ??
      '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';
}
