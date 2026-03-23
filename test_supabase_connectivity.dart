
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// ignore_for_file: avoid_print
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final url = dotenv.env['SUPABASE_URL'] ?? '';
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // ignore: avoid_print


  print('Testing Supabase Connection to $url...');
  
  try {
    // ignore: avoid_print
    print('✅ Supabase initialized');
    await Supabase.initialize(url: url, anonKey: anonKey);
    final supabase = Supabase.instance.client;
    
    // Probar tabla device_catalog
    final response = await supabase.from('device_catalog').select().limit(1);
    // ignore: avoid_print

    print('✅ Connection Successful! Data: $response');
  } catch (e) {
    // ignore: avoid_print

    print('❌ Connection Failed: $e');
  }
}
