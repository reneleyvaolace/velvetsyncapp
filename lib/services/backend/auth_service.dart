// ════════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/backend/auth_service.dart
// Servicio de autenticación con Firebase Auth (migración desde Supabase)
// ════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  String? get userId => _user?.uid;
  bool get isAnonymous => _user?.isAnonymous ?? false;
  String? get email => _user?.email;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  AuthService() {
    try {
      _user = _auth.currentUser;
      if (_user != null) {
        _status = AuthStatus.authenticated;
      }
      _auth.authStateChanges().listen((User? user) {
        _user = user;
        if (user != null) {
          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.unauthenticated;
        }
        notifyListeners();
      });
    } catch (e) {
      lvsLog('AuthService: Firebase no inicializado (modo offline): $e', tag: 'AUTH');
      _user = null;
      _status = AuthStatus.unauthenticated;
    }
  }

  /// Número máximo de reintentos ante errores de rate limit
  static const int _maxRetries = 3;
  /// Delay base en segundos para backoff exponencial (2s, 4s, 8s)
  static const int _baseDelaySeconds = 2;

  /// Detecta si un error de Firebase es por rate limit
  bool _isRateLimitError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('rate limit') ||
        lower.contains('too many requests') ||
        lower.contains('too many') ||
        lower.contains('quota') ||
        lower.contains('429');
  }

  /// Ejecuta una acción de autenticación con reintentos y backoff exponencial.
  Future<bool> _withRetry(
    Future<bool> Function() action, {
    required String operationName,
    required String email,
  }) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final result = await action();
        if (result) return true;
        return false;
      } on FirebaseAuthException catch (e) {
        _status = AuthStatus.error;
        _errorMessage = _mapFirebaseError(e);
        lvsError('Error $operationName (intento $attempt): ${e.message}', tag: 'AUTH');
        notifyListeners();

        if (_isRateLimitError(e.message ?? '') && attempt < _maxRetries) {
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
    _status = AuthStatus.error;
    _errorMessage = 'Demasiados intentos. Espera unos minutos y vuelve a intentar.';
    notifyListeners();
    return false;
  }

  /// Mapea errores de Firebase a mensajes en español
  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Usuario no encontrado';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'email-already-in-use':
        return 'El correo ya está en uso';
      case 'weak-password':
        return 'La contraseña es demasiado débil';
      case 'invalid-email':
        return 'Correo electrónico inválido';
      case 'user-disabled':
        return 'Usuario deshabilitado';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera y vuelve a intentar.';
      case 'operation-not-allowed':
        return 'Operación no permitida';
      case 'invalid-credential':
        return 'Credenciales inválidas';
      case 'requires-recent-login':
        return 'Sesión expirada. Vuelve a iniciar sesión.';
      case 'network-request-failed':
        return 'Error de conexión a internet';
      default:
        return e.message ?? 'Error de autenticación';
    }
  }

  Future<bool> signUp(String email, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final isCurrentlyAnonymous = _user?.isAnonymous ?? false;

      if (isCurrentlyAnonymous) {
        // Vincular cuenta anónima con email y contraseña
        try {
          final credential = EmailAuthProvider.credential(email: email, password: password);
          await _user!.linkWithCredential(credential);
          await _user!.reload();
          _user = _auth.currentUser;
          _status = AuthStatus.authenticated;
          lvsLog('Cuenta anónima vinculada a email: $email', tag: 'AUTH');
          notifyListeners();
          return true;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'provider-already-linked') {
            _errorMessage = 'Este correo ya está vinculado a otra cuenta';
          } else {
            _errorMessage = _mapFirebaseError(e);
          }
          notifyListeners();
          return false;
        }
      } else {
        final success = await _withRetry(
          () async {
            final credential = await _auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
            if (credential.user != null) {
              _user = credential.user;
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
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _mapFirebaseError(e);
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
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        _user = credential.user;
        _status = AuthStatus.authenticated;
        lvsLog('Inicio de sesión: $email', tag: 'AUTH');
        notifyListeners();
        return true;
      }

      _status = AuthStatus.error;
      _errorMessage = 'Credenciales inválidas';
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _mapFirebaseError(e);
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

  /// Envía un enlace de acceso sin contraseña al email (Email Link)
  Future<bool> sendSignInLink(String email) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://velvetsync.app/complete-sign-in',
        handleCodeInApp: true,
        androidPackageName: 'com.velvetsync.app',
        androidInstallApp: true,
        androidMinimumVersion: '1',
        iOSBundleId: 'com.velvetsync.app',
      );

      await FirebaseAuth.instance.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );

      _status = AuthStatus.unauthenticated;
      notifyListeners();
      lvsLog('Enlace de acceso enviado: $email', tag: 'AUTH');
      return true;
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _mapFirebaseError(e);
      lvsError('Error sendSignInLink: ${e.message}', tag: 'AUTH');
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Error de conexión';
      lvsError('Error sendSignInLink: $e', tag: 'AUTH');
      notifyListeners();
      return false;
    }
  }

  /// Completa el inicio de sesión usando el enlace recibido por email
  Future<bool> signInWithEmailLink(String email, String emailLink) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!FirebaseAuth.instance.isSignInWithEmailLink(emailLink)) {
        _errorMessage = 'El enlace no es válido o ha expirado';
        _status = AuthStatus.error;
        notifyListeners();
        return false;
      }

      final credential = await FirebaseAuth.instance.signInWithEmailLink(
        email: email,
        emailLink: emailLink,
      );

      if (credential.user != null) {
        _user = credential.user;
        _status = AuthStatus.authenticated;
        notifyListeners();
        lvsLog('Inicio de sesión con enlace: $email', tag: 'AUTH');
        return true;
      }

      _status = AuthStatus.error;
      _errorMessage = 'No se pudo iniciar sesión con el enlace';
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _mapFirebaseError(e);
      lvsError('Error signInWithEmailLink: ${e.message}', tag: 'AUTH');
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Error de conexión';
      lvsError('Error signInWithEmailLink: $e', tag: 'AUTH');
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      // Firebase Auth maneja el reset de contraseña nativamente
      await _auth.sendPasswordResetEmail(email: email);
      lvsLog('Email de recuperación enviado: $email', tag: 'AUTH');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _mapFirebaseError(e);
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
      if (_user == null) {
        _errorMessage = 'No hay sesión activa';
        return false;
      }
      await _user!.updatePassword(newPassword);
      lvsLog('Contraseña cambiada', tag: 'AUTH');
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e);
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
      if (_user == null || !_user!.isAnonymous) {
        _errorMessage = 'No hay cuenta anónima activa';
        notifyListeners();
        return false;
      }

      final credential = EmailAuthProvider.credential(email: email, password: password);
      await _user!.linkWithCredential(credential);
      await _user!.reload();
      _user = _auth.currentUser;
      _status = AuthStatus.authenticated;
      lvsLog('Correo vinculado: $email', tag: 'AUTH');
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      if (e.code == 'provider-already-linked') {
        _errorMessage = 'Este correo ya está vinculado a otra cuenta';
      } else {
        _errorMessage = _mapFirebaseError(e);
      }
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
      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      if (user != null) {
        _user = user;
        _status = AuthStatus.authenticated;
        lvsLog('Sesión anónima iniciada: ${user.uid}', tag: 'AUTH');
        notifyListeners();
        return true;
      }
      _status = AuthStatus.error;
      _errorMessage = 'No se pudo iniciar sesión como invitado';
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _mapFirebaseError(e);
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
    await _auth.signOut();
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
      final user = _auth.currentUser;
      if (user == null) {
        _errorMessage = 'No hay sesión activa';
        _status = AuthStatus.error;
        notifyListeners();
        return false;
      }

      await user.delete();
      _user = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      lvsLog('Cuenta eliminada', tag: 'AUTH');
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      if (e.code == 'requires-recent-login') {
        _errorMessage = 'Sesión expirada. Vuelve a iniciar sesión para eliminar tu cuenta.';
      } else {
        _errorMessage = _mapFirebaseError(e);
      }
      lvsError('Error deleteAccount: ${e.message}', tag: 'AUTH');
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
