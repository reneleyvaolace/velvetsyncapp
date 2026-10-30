import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:velvet_sync/config/app_env.dart';
import 'package:velvet_sync/utils/logger.dart';

final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
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
    try {
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
    } catch (e) {
      lvsLog('AuthService: Supabase no inicializado (modo offline): $e', tag: 'AUTH');
      _user = null;
      _status = AuthStatus.unauthenticated;
    }
  }

  /// Número máximo de reintentos ante errores de rate limit
  static const int _maxRetries = 3;
  /// Delay base en segundos para backoff exponencial (2s, 4s, 8s)
  static const int _baseDelaySeconds = 2;

  /// Detecta si un error de AuthException es por rate limit de Supabase
  bool _isRateLimitError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('rate limit') ||
        lower.contains('too many requests') ||
        lower.contains('too many') ||
        lower.contains('429');
  }

  /// Ejecuta una acción de autenticación con reintentos y backoff exponencial.
  /// Devuelve true si tuvo éxito, false si falló tras agotar los reintentos.
  Future<bool> _withRetry(
    Future<bool> Function() action, {
    required String operationName,
    required String email,
  }) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final result = await action();
        if (result) return true;
        // Si la acción devolvió false sin lanzar excepción, no reintentamos
        return false;
      } on AuthException catch (e) {
        _status = AuthStatus.error;
        _errorMessage = e.message;
        lvsError('Error $operationName (intento $attempt): ${e.message}', tag: 'AUTH');
        notifyListeners();

        if (_isRateLimitError(e.message) && attempt < _maxRetries) {
          final delay = _baseDelaySeconds * pow(2, attempt - 1);
          lvsLog('Rate limit detectado. Reintentando en ${delay}s...', tag: 'AUTH');
          await Future.delayed(Duration(seconds: delay.toInt()));
          continue;
        }
        rethrow;
      } catch (e) {
        _status = AuthStatus.error;
        _errorMessage = 'Error de conexión';
        lvsError('Error $operationName (intento $attempt): $e', tag: 'AUTH');
        notifyListeners();
        rethrow;
      }
    }
    // Si llegamos aquí, agotamos los reintentos
    _status = AuthStatus.error;
    _errorMessage = 'Demasiados intentos. Espera unos minutos y vuelve a intentar.';
    notifyListeners();
    return false;
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
        final success = await _withRetry(
          () async {
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
            return false;
          },
          operationName: 'registro',
          email: email,
        );
        return success;
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
      // Usar el método nativo de Supabase para restablecer contraseña
      // Redirigir a la página de restablecimiento en Vercel tras hacer clic en el enlace
      final success = await _withRetry(
        () async {
          await _client.auth.resetPasswordForEmail(
            email,
            redirectTo: AppEnv.resetPasswordRedirect,
          );
          lvsLog('Email de recuperación enviado: $email', tag: 'AUTH');
          _status = AuthStatus.unauthenticated;
          notifyListeners();
          return true;
        },
        operationName: 'restablecimiento de contraseña',
        email: email,
      );
      return success;
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

  /// Cambia la contraseña del usuario autenticado sin modificar el correo
  Future<bool> changePassword(String newPassword) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      if (response.user != null) {
        lvsLog('Contraseña cambiada', tag: 'AUTH');
        return true;
      }
      return false;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      lvsError('Error changePassword: ${e.message}', tag: 'AUTH');
      return false;
    } catch (e) {
      _errorMessage = 'Error de conexión';
      lvsError('Error changePassword: $e', tag: 'AUTH');
      return false;
    }
  }

  /// Vincula un correo y contraseña a la cuenta anónima actual
  Future<bool> linkEmail(String email, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.auth.updateUser(
        UserAttributes(email: email, password: password),
      );
      if (response.user != null) {
        _user = response.user;
        _status = AuthStatus.authenticated;
        lvsLog('Correo vinculado: $email', tag: 'AUTH');
        notifyListeners();
        return true;
      }

      _status = AuthStatus.error;
      _errorMessage = 'No se pudo vincular el correo';
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      lvsError('Error linkEmail: ${e.message}', tag: 'AUTH');
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Error de conexión';
      lvsError('Error linkEmail: $e', tag: 'AUTH');
      notifyListeners();
      return false;
    }
  }

  /// Autentica al usuario anónimamente (modo invitado)
  Future<bool> signInAnonymously() async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.auth.signInAnonymously();
      final user = response.user;
      if (user != null) {
        _user = user;
        _status = AuthStatus.authenticated;
        lvsLog('Sesión anónima iniciada: ${user.id}', tag: 'AUTH');
        notifyListeners();
        return true;
      }
      _status = AuthStatus.error;
      _errorMessage = 'No se pudo iniciar sesión como invitado';
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      lvsError('Error signInAnonymously: ${e.message}', tag: 'AUTH');
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Error de conexión';
      lvsError('Error signInAnonymously: $e', tag: 'AUTH');
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
      final supabaseUrl = AppEnv.supabaseUrl;
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