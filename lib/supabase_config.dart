  import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url {
    const fromDartDefine = String.fromEnvironment('SUPABASE_URL');
    if (fromDartDefine.trim().isNotEmpty) {
      return fromDartDefine.trim();
    }
    final fromDotenv = dotenv.env['SUPABASE_URL'];
    if (fromDotenv != null && fromDotenv.trim().isNotEmpty) {
      return fromDotenv.trim();
    }
    return 'https://qxruxonusvoxshuwxrah.supabase.co';
  }

  static String get anonKey {
    const fromDartDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (fromDartDefine.trim().isNotEmpty) {
      return fromDartDefine.trim();
    }
    final fromDotenv = dotenv.env['SUPABASE_ANON_KEY'];
    if (fromDotenv != null && fromDotenv.trim().isNotEmpty) {
      return fromDotenv.trim();
    }
    return 'sb_publishable_MbMRR6syNwtezcWMke6yXw_Y1cozFRo';
  }

  static String get brevoApiKey {
    const fromDartDefine = String.fromEnvironment('BREVO_API_KEY');
    if (fromDartDefine.trim().isNotEmpty) {
      return fromDartDefine.trim();
    }
    final fromDotenv = dotenv.env['BREVO_API_KEY'];
    if (fromDotenv != null && fromDotenv.trim().isNotEmpty) {
      return fromDotenv.trim();
    }
    return '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';
  }
}
