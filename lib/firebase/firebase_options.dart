/// Configuration Firebase, alimentée par des variables passées au build avec
/// `--dart-define` (voir README.md, section « Configuration Firebase »).
///
/// Volontairement écrite à la main plutôt que générée par
/// `flutterfire configure` : les valeurs ne sont jamais committées, elles
/// arrivent par le système de build, ce qui évite de mettre une clé API dans
/// le dépôt. Le fichier reste tolérant : si rien n'est fourni,
/// [FirebaseBuildConfig.isConfigured] vaut false et l'app démarre en mode
/// invité local, sans plantage (voir firebase_bootstrap.dart).
library;

import 'package:firebase_core/firebase_core.dart';

/// Les options Firebase lues depuis l'environnement de compilation.
class FirebaseBuildConfig {
  const FirebaseBuildConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    required this.authDomain,
    required this.storageBucket,
    required this.measurementId,
    required this.iosBundleId,
    required this.webClientId,
  });

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String authDomain;
  final String storageBucket;
  final String measurementId;
  final String iosBundleId;

  /// Client OAuth Web (le `client_id` de l'app Web dans la console Firebase).
  /// Sur le web, c'est lui que google_sign_in utilise pour ouvrir la fenêtre
  /// de consentement Google ; sur Android, l'information équivalente vient de
  /// google-services.json.
  final String webClientId;

  /// Instance unique lue au démarrage de l'application.
  static final FirebaseBuildConfig fromEnvironment = FirebaseBuildConfig(
    apiKey: const String.fromEnvironment('FIREBASE_API_KEY').trim(),
    appId: const String.fromEnvironment('FIREBASE_APP_ID').trim(),
    messagingSenderId:
        const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID').trim(),
    projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID').trim(),
    authDomain: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN').trim(),
    storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET').trim(),
    measurementId: const String.fromEnvironment('FIREBASE_MEASUREMENT_ID').trim(),
    iosBundleId: const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID').trim(),
    webClientId: const String.fromEnvironment('FIREBASE_WEB_CLIENT_ID').trim(),
  );

  /// Vrai si les valeurs indispensables pour parler à Firebase sont là.
  static bool get isConfigured {
    final c = fromEnvironment;
    return c.apiKey.isNotEmpty && c.appId.isNotEmpty && c.projectId.isNotEmpty;
  }

  /// Les [FirebaseOptions] correspondant à la plateforme courante.
  ///
  /// `webClientId` n'existe pas dans [FirebaseOptions] : côté web, le client
  /// OAuth est transmis directement à google_sign_in (voir AuthService).
  FirebaseOptions get options => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain.isEmpty ? null : authDomain,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
        measurementId: measurementId.isEmpty ? null : measurementId,
        iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
      );
}
