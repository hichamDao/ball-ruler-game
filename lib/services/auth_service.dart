import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase/firebase_bootstrap.dart';

/// Erreur d'authentification traduite en français, prête à être affichée
/// telle quelle à l'utilisateur.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);

  @override
  String toString() => message;
}

/// État d'authentification de l'application, avec le mode invité.
///
/// Trois situations possibles :
/// - [status] == [AuthStatus.signedIn] : un compte Firebase est connecté,
///   les scores peuvent être poussés sur Firestore.
/// - [status] == [AuthStatus.guest] : l'utilisateur a choisi « Continuer en
///   invité », la partie est jouable mais reste en local.
/// - [status] == [AuthStatus.unavailable] : le build n'a pas de configuration
///   Firebase ; l'identification est masquée et tout est local.
class AuthService extends ChangeNotifier {
  /// [webClientId] est le client OAuth Web : sur le web, c'est lui que
  /// google_sign_in utilise pour ouvrir la fenêtre de consentement Google
  /// (sur Android, l'information vient de google-services.json). Passé `null`
  /// ou vide, la connexion Google sur le web n'est simplement pas proposée.
  AuthService({String? webClientId}) {
    _google = webClientId != null && webClientId.isNotEmpty
        ? GoogleSignIn(clientId: webClientId)
        : GoogleSignIn();
    _bind();
  }

  /// Accès paresseux à Firebase Auth : null quand Firebase n'a pas pu
  /// démarrer (build sans configuration), ce qui bascule l'app en invité.
  /// Paresseux plutôt que final pour ne pas dépendre de l'ordre entre
  /// [FirebaseBootstrap.ensureInitialized] et la construction du service.
  FirebaseAuth? get _auth =>
      _authInstance ??= FirebaseBootstrap.isReady ? FirebaseAuth.instance : null;

  FirebaseAuth? _authInstance;
  GoogleSignIn _google = GoogleSignIn();

  User? _user;
  AuthStatus _status = AuthStatus.unavailable;
  bool _busy = false;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get uid => _user?.uid;
  bool get isSignedIn => _status == AuthStatus.signedIn;
  bool get isGuest => _status == AuthStatus.guest;
  bool get busy => _busy;

  /// Nom affiché : pseudo Google, sinon partie de l'e-mail, sinon « Invité ».
  String get displayName {
    final name = _user?.displayName;
    if (name != null && name.isNotEmpty) return name;
    final email = _user?.email;
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Invité';
  }

  String? get photoUrl => _user?.photoURL;
  String? get email => _user?.email;

  void _bind() {
    final auth = _auth;
    if (auth == null) {
      _status = AuthStatus.unavailable;
      return;
    }
    _user = auth.currentUser;
    _status = _user != null ? AuthStatus.signedIn : AuthStatus.guest;
    auth.authStateChanges().listen((user) {
      _user = user;
      _status = user != null ? AuthStatus.signedIn : AuthStatus.guest;
      notifyListeners();
    });
  }

  /// Passe en mode invité (utilisé par défaut si aucun compte n'est déjà
  /// connecté au lancement).
  void continueAsGuest() {
    final auth = _auth;
    if (auth == null) {
      _status = AuthStatus.unavailable;
    } else {
      _status = auth.currentUser != null ? AuthStatus.signedIn : AuthStatus.guest;
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    final auth = _requireAuth();
    await _run(() async {
      await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    });
  }

  Future<void> register(String email, String password) async {
    final auth = _requireAuth();
    if (password.length < 6) {
      throw const AuthFailure('Le mot de passe doit contenir au moins 6 caractères.');
    }
    await _run(() async {
      await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    });
  }

  Future<void> signInWithGoogle() async {
    final auth = _requireAuth();
    await _run(() async {
      final signInAccount = await _google.signIn();
      if (signInAccount == null) {
        // Annulation volontaire de l'utilisateur : ce n'est pas une erreur.
        return;
      }
      final googleAuth = await signInAccount.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      await auth.signInWithCredential(credential);
    });
  }

  Future<void> signOut() async {
    final auth = _auth;
    if (auth == null) {
      continueAsGuest();
      return;
    }
    await _run(() async {
      await auth.signOut();
    });
  }

  FirebaseAuth _requireAuth() {
    final auth = _auth;
    if (auth == null) {
      throw const AuthFailure(
        'La connexion n\'est pas disponible dans ce build (configuration Firebase manquante).',
      );
    }
    return auth;
  }

  /// Exécute une opération d'authentification en gardant [_busy] à jour et en
  /// convertissant les exceptions Firebase en messages lisibles.
  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_translate(e));
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw const AuthFailure(
        'Connexion impossible. Vérifiez votre connexion internet.',
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Traduit les codes d'erreur Firebase en messages compréhensibles, pour
  /// éviter d'afficher du code brut à l'utilisateur.
  String _translate(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Adresse e-mail invalide.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'E-mail ou mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cet e-mail.';
      case 'weak-password':
        return 'Mot de passe trop faible (6 caractères minimum).';
      case 'network-request-failed':
        return 'Pas de connexion internet.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessaie dans un instant.';
      case 'popup-closed-by-user':
      case 'canceled':
        return 'Connexion annulée.';
      case 'web-context-canceled':
        return 'Connexion Google annulée.';
      default:
        return 'Erreur d\'authentification (${e.code}).';
    }
  }
}

enum AuthStatus { unavailable, guest, signedIn }
