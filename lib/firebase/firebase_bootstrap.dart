import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

/// Démarre Firebase, ou laisse l'application tourner en mode local/invité.
///
/// L'initialisation ne doit jamais faire planter l'app : si elle échoue (fichier
/// `google-services.json` absent, réseau indisponible au premier lancement…),
/// on retombe en mode invité, où le jeu reste pleinement jouable.
///
/// Où vient la configuration, selon la plateforme :
/// - web : les `--dart-define FIREBASE_*`, lues par le script
///   `tool/build-web.ps1` ou par le workflow GitHub Pages ;
/// - Android/iOS : `google-services.json` / `GoogleService-Info.plist`, lus par
///   le plugin et donc **indépendants des `--dart-define`**. C'est pour cela
///   qu'un `flutter run` sans aucune variable doit tout de même connecter
///   Firebase.
class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static bool _ready = false;

  /// Vrai si Firebase est utilisable dans ce build.
  static bool get isReady => _ready;

  /// Vrai si la plateforme courante a les moyens de démarrer Firebase : sur le
  /// web, cela se voit sur les variables ; ailleurs, on ne peut le savoir
  /// qu'après l'initialisation (le plugin lit son fichier de config).
  static bool get isAvailable => kIsWeb ? FirebaseBuildConfig.isConfigured : true;

  static Future<void> ensureInitialized() async {
    if (_ready) return;

    if (kIsWeb && !FirebaseBuildConfig.isConfigured) {
      debugPrint(
        '[firebase] Aucune variable FIREBASE_* fournie : le site démarre en '
        'mode invité (scores locaux uniquement).',
      );
      return;
    }

    try {
      if (kIsWeb) {
        await Firebase.initializeApp(options: FirebaseBuildConfig.fromEnvironment.options);
      } else {
        // Android/iOS : sans argument, le plugin lit sa configuration dans
        // les ressources générées depuis google-services.json.
        await Firebase.initializeApp();
      }
      _ready = true;
    } catch (error) {
      debugPrint(
        '[firebase] Initialisation impossible ($error) : l\'application démarre '
        'en mode invité. Vérifie android/app/google-services.json sur Android, '
        'ou les variables FIREBASE_* sur le web.',
      );
    }
  }
}
