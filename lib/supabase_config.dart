import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Vos clés Supabase
  static const String supabaseUrl = 'https://jjnggbkofkadtstxvteo.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpqbmdnYmtvZmthZHRzdHh2dGVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3OTA0OTMsImV4cCI6MjA5MzM2NjQ5M30.R-Tz8bblhv98TDe4pYFxH_0mvoUGwG03TB6qO6Go5W4';

  // Instance Supabase globale
  static SupabaseClient get client => Supabase.instance.client;

  // Authentification
  static GoTrueClient get auth => client.auth;

  // Stockage
  static SupabaseStorageClient get storage => client.storage;
}