import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase/firebase_bootstrap.dart';
import 'firebase/firebase_options.dart';
import 'game/ball_ruler_game.dart';
import 'services/auth_service.dart';
import 'services/score_service.dart';
import 'ui/auth_page.dart';
import 'ui/help_page.dart';
import 'ui/leaderboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Si la configuration Firebase manque, ensureInitialized ne lève rien : on
  // démarre en mode invité (voir FirebaseBootstrap).
  await FirebaseBootstrap.ensureInitialized().catchError((Object error) {
    debugPrint('[firebase] Initialisation impossible : $error');
  });
  runApp(const MyApp());
}

/// Rend [AuthService] disponible dans tout l'arbre et rebuild les widgets qui
/// l'écoutent quand l'état de connexion change.
class AuthScope extends InheritedNotifier<AuthService> {
  const AuthScope({super.key, required AuthService service, required super.child})
      : super(notifier: service);

  static AuthService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope est absent de l\'arbre de widgets.');
    return scope!.notifier!;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthService _auth;
  late final ScoreService _scores;

  @override
  void initState() {
    super.initState();
    _auth = AuthService(webClientId: FirebaseBuildConfig.fromEnvironment.webClientId);
    // Sans compte déjà connecté au lancement, on démarre en invité : le jeu
    // est immédiatement jouable, la connexion se propose depuis le menu.
    _auth.continueAsGuest();
    _scores = ScoreService(_auth);
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      service: _auth,
      child: MaterialApp(
        title: 'Ball Ruler Game',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: GamePage(scores: _scores),
      ),
    );
  }
}

class GamePage extends StatefulWidget {
  final ScoreService scores;

  const GamePage({super.key, required this.scores});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final GlobalKey<BallRulerGameState> _gameKey = GlobalKey();

  /// Une fois seulement par installation : l'aide s'affiche seule au premier
  /// lancement, puis le joueur s'en sert via l'icône « ? ».
  static const String _helpSeenKey = 'help_seen';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showHelpOnce());
  }

  Future<void> _showHelpOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getBool(_helpSeenKey) ?? false) return;
    await prefs.setBool(_helpSeenKey, true);
    await _openHelp();
  }

  void _restart() {
    _gameKey.currentState?.restart();
  }

  Future<void> _openHelp() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const HelpPage()),
    );
  }

  /// Fin de partie : on publie le nombre de chambres atteint si un compte est
  /// connecté. Les erreurs réseau sont volontairement silencieuses : le joueur
  /// vient de terminer une partie, il ne doit pas subir une erreur d'écriture
  /// comme une punition, et le record local est déjà sauvegardé.
  Future<void> _onGameOver(int chambersReached, GameMode mode) async {
    try {
      await widget.scores.submitScore(
        chambersReached: chambersReached,
        isDaily: mode == GameMode.daily,
      );
    } catch (e) {
      debugPrint('[scores] Publication impossible : $e');
    }
  }

  Future<void> _openAuth() async {
    final auth = AuthScope.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AuthPage(auth: auth)),
    );
  }

  Future<void> _openLeaderboard() async {
    final auth = AuthScope.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LeaderboardPage(auth: auth, scores: widget.scores),
      ),
    );
  }

  Future<void> _signOut() async {
    final auth = AuthScope.of(context);
    try {
      await auth.signOut();
      if (mounted) setState(() {});
    } on AuthFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ball Ruler Game'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _openLeaderboard,
            tooltip: 'Classement des joueurs',
            icon: const Icon(Icons.leaderboard_outlined),
          ),
          IconButton(
            onPressed: _openHelp,
            tooltip: 'Comment jouer',
            icon: const Icon(Icons.help_outline),
          ),
          // Connecté, le bandeau du bas affiche déjà le nom : inutile
          // d'en proposer un second bouton. L'icône d'accès ne sert que
          // lorsqu'on est invité.
          if (!auth.isSignedIn)
            IconButton(
              onPressed: _openAuth,
              tooltip: 'Se connecter',
              icon: const Icon(Icons.account_circle_outlined),
            )
          else
            IconButton(
              onPressed: _signOut,
              tooltip: 'Se déconnecter',
              icon: const Icon(Icons.logout),
            ),
          IconButton(
            onPressed: _restart,
            tooltip: 'Rejouer',
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(18),
          child: Container(
            width: double.infinity,
            color: auth.isSignedIn ? Colors.cyanAccent : Colors.grey.shade800,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              auth.isSignedIn
                  ? 'Connecté : ${auth.displayName}'
                  : 'Invité — score local (connexion pour le classement)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: auth.isSignedIn ? Colors.black : Colors.white70,
              ),
            ),
          ),
        ),
      ),
      body: BallRulerGame(
        key: _gameKey,
        onGameOver: _onGameOver,
        // Le jeu s'en sert pour ne pas proposer l'app Android au web à un
        // joueur déjà connecté (voir _showPlatformPromptDialog).
        isSignedIn: () => AuthScope.of(context).isSignedIn,
      ),
    );
  }
}
