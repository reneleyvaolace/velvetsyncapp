import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:velvet_sync/utils/logger.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

enum AuthStatus { unauthenticated, authenticating, authenticated, error }

class AuthService extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unauthenticated;
  String? _errorMessage;
  User? _user;

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  User? get user => _user;
  bool get isAuthenticated => _user != null;
  String? get userId => _user?.id;
  bool get isAnonymous => _user?.isAnonymous ?? false;
  String? get email => _user?.email;

  SupabaseClient get _client => Supabase.instance.client;

  AuthService() {
    _user = _client.auth.currentUser;
    if (_user != null) {
      _status = AuthStatus.authenticated;
    }
    _client.auth.onAuthStateChange.listen((event) {
      _user = event.session?.user;
      if (_user != null) {
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    });
  }

  Future<bool> signUp(String email, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final isCurrentlyAnonymous = _user?.isAnonymous ?? false;

      if (isCurrentlyAnonymous) {
        final response = await _client.auth.updateUser(
          UserAttributes(email: email, password: password),
        );
        if (response.user != null) {
          _user = response.user;
          _status = AuthStatus.authenticated;
          lvsLog('Cuenta anónima vinculada a email: $email', tag: 'AUTH');
          notifyListeners();
          return true;
        }
      } else {
        final response = await _client.auth.signUp(
          email: email,
          password: password,
        );
        if (response.user != null) {
          _user = response.user;
          _status = AuthStatus.authenticated;
          lvsLog('Cuenta creada: $email', tag: 'AUTH');
          notifyListeners();
          return true;
        }
      }

      _status = AuthStatus.error;
      _errorMessage = 'No se pudo crear la cuenta';
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      lvsError('Error signUp: ${e.message}', tag: 'AUTH');
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Error de conexión';
      lvsError('Error signUp: $e', tag: 'AUTH');
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        _user = response.user;
        _status = AuthStatus.authenticated;
        lvsLog('Inicio de sesión: $email', tag: 'AUTH');
        notifyListeners();
        return true;
      }

      _status = AuthStatus.error;
      _errorMessage = 'Credenciales inválidas';
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      lvsError('Error signIn: ${e.message}', tag: 'AUTH');
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Error de conexión';
      lvsError('Error signIn: $e', tag: 'AUTH');
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _client.auth.resetPasswordForEmail(email);
      lvsLog('Email de recuperación enviado: $email', tag: 'AUTH');
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      lvsError('Error resetPassword: ${e.message}', tag: 'AUTH');
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Error de conexión';
      lvsError('Error resetPassword: $e', tag: 'AUTH');
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
    lvsLog('Sesión cerrada', tag: 'AUTH');
  }

  Future<bool> deleteAccount() async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      final session = _client.auth.currentSession;
      if (session == null) {
        _errorMessage = 'No hay sesión activa';
        _status = AuthStatus.error;
        notifyListeners();
        return false;
      }

      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/delete-user'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        await _client.auth.signOut();
        _user = null;
        _status = AuthStatus.unauthenticated;
        _errorMessage = null;
        lvsLog('Cuenta eliminada', tag: 'AUTH');
        notifyListeners();
        return true;
      }

      _errorMessage = 'No se pudo eliminar la cuenta. Asegúrate de crear la función en Supabase.';
      _status = AuthStatus.error;
      lvsLog('Error deleteAccount: ${response.statusCode} ${response.body}', tag: 'AUTH');
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Error de conexión al eliminar cuenta';
      lvsError('Error deleteAccount: $e', tag: 'AUTH');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
