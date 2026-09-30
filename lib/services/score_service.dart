import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_bootstrap.dart';
import '../models/player_score.dart';
import 'auth_service.dart';

/// Deux classements exposé par l'app :
/// - [Leaderboard.all] : le meilleur nombre de chambres de la carrière.
/// - [Leaderboard.daily] : le record du défi du jour.
enum Leaderboard { all, daily }

extension LeaderboardLabel on Leaderboard {
  String get title => this == Leaderboard.all ? 'Classement général' : 'Défi du jour';
  String get field => this == Leaderboard.all ? 'bestChambers' : 'dailyBestChambers';
  String get emptyMessage =>
      this == Leaderboard.all ? 'Aucun joueur pour le moment.' : 'Personne n\'a encore joué aujourd\'hui.';
}

/// Accès à la collection `players` de Firestore : une ligne par compte, qui
/// contient à la fois le profil et les records.
///
/// Les records ne sont écrits que par défaut (jamais à la baisse) et dans une
/// transaction, donc un envoi en double — par exemple une fin de partie
/// rejouée hors ligne puis renvoyée — ne peut pas fausser le classement.
class ScoreService {
  ScoreService(this._auth);

  final AuthService _auth;

  static const String _collection = 'players';
  static const int _maxLeaderboardSize = 50;

  bool get isEnabled => FirebaseBootstrap.isReady && _auth.isSignedIn;

  CollectionReference<Map<String, dynamic>> get _players =>
      FirebaseFirestore.instance.collection(_collection);

  /// Publie la fin d'une partie pour le compte connecté.
  ///
  /// [chambersReached] est le nombre de chambres atteint (1-indexé, comme
  /// affiché dans le game over), [isDaily] indique si la partie était le
  /// défi du jour. N'effectue rien si l'utilisateur n'est pas connecté ou si
  /// Firebase n'est pas configuré : c'est le chemin normal du mode invité.
  Future<void> submitScore({
    required int chambersReached,
    required bool isDaily,
  }) async {
    if (!isEnabled) return;
    final uid = _auth.uid;
    if (uid == null || chambersReached <= 0) return;

    final updates = <String, Object?>{
      'photoUrl': _auth.photoUrl,
      'email': _auth.email,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Firestore n'expose pas maximum() : on lit puis on écrit dans une
    // transaction, ce qui reste atomique et protège le record.
    final ref = _players.doc(uid);
    await FirebaseFirestore.instance.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final data = snap.data();
      final currentBest = (data?['bestChambers'] as num?)?.toInt() ?? 0;
      final currentDaily = (data?['dailyBestChambers'] as num?)?.toInt() ?? 0;
      final currentDate = (data?['dailyDate'] as String?) ?? '';
      final currentName = (data?['displayName'] as String?) ?? '';

      final best = chambersReached > currentBest ? chambersReached : currentBest;
      final today = todayDateString();
      // Le record quotidien repart de zéro si la ligne date d'un jour précédent.
      final dailyBase = currentDate == today ? currentDaily : 0;
      final daily =
          isDaily ? (chambersReached > dailyBase ? chambersReached : dailyBase) : dailyBase;

      updates['bestChambers'] = best;
      updates['dailyBestChambers'] = daily;
      updates['dailyDate'] = today;
      // Un nom déjà connu n'est jamais écrasé par le repli « Invité » : un
      // compte e-mail connecté plus tard garde le nom du défi quotidien.
      final newName = _auth.displayName;
      if (newName != 'Invité' || currentName.isEmpty) {
        updates['displayName'] = newName;
      }

      txn.set(ref, updates, SetOptions(merge: true));
    });
  }

  /// Lit la ligne du joueur connecté, ou `null` s'il n'a jamais joué.
  Future<PlayerScore?> fetchMyScore() async {
    if (!isEnabled) return null;
    final uid = _auth.uid;
    if (uid == null) return null;
    final doc = await _players.doc(uid).get();
    if (!doc.exists) return null;
    return PlayerScore.fromFirestore(doc);
  }

  /// Stream du classement demandé, rafraîchi à chaque écriture.
  ///
  /// Firestore ne permet pas de filtrer sur « la date du jour » et de trier
  /// sur un autre champ dans la même requête ; on filtre donc côté client sur
  /// [PlayerScore.dailyChambersForToday], qui renvoie déjà 0 pour une ligne
  /// qui date d'un autre jour.
  Stream<List<PlayerScore>> watchLeaderboard(Leaderboard which) {
    if (!isEnabled) return Stream.value(const []);
    return _players
        .orderBy(which.field, descending: true)
        .limit(_maxLeaderboardSize)
        .snapshots()
        .map((snapshot) {
      final today = todayDateString();
      return snapshot.docs
          .map(PlayerScore.fromFirestore)
          .where((p) => which == Leaderboard.all || p.dailyDate == today)
          .toList();
    });
  }
}
