import 'package:cloud_firestore/cloud_firestore.dart';

/// Un joueur tel qu'il est stocké dans la collection `players` de Firestore :
/// une seule ligne par compte, qui sert à la fois de profil (nom, avatar) et
/// de ligne de classement (meilleur nombre de chambres, global et quotidien).
class PlayerScore {
  /// Identifiant du compte = uid de Firebase Auth.
  final String uid;
  final String displayName;
  final String? photoUrl;

  /// Meilleur nombre de chambres atteint, tous modes confondus, sur la
  /// carrière du compte.
  final int bestChambers;

  /// Record du défi du jour, remis à zéro chaque jour (voir [dailyDate]).
  final int dailyBestChambers;

  /// Date (yyyy-mm-dd) à laquelle [dailyBestChambers] a été obtenu. Si elle
  /// ne correspond pas à aujourd'hui, le record quotidien est considéré
  /// comme nul — même logique que le record local (voir _dailyDateKey).
  final String dailyDate;

  final DateTime? updatedAt;

  const PlayerScore({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.bestChambers,
    required this.dailyBestChambers,
    required this.dailyDate,
    this.updatedAt,
  });

  factory PlayerScore.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final updated = data?['updatedAt'];
    return PlayerScore(
      uid: doc.id,
      displayName: (data?['displayName'] as String?)?.trim().isNotEmpty == true
          ? data!['displayName'] as String
          : 'Joueur anonyme',
      photoUrl: data?['photoUrl'] as String?,
      bestChambers: (data?['bestChambers'] as num?)?.toInt() ?? 0,
      dailyBestChambers: (data?['dailyBestChambers'] as num?)?.toInt() ?? 0,
      dailyDate: (data?['dailyDate'] as String?) ?? '',
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }

  /// Le record quotidien n'est valable que pour la date du jour.
  int get dailyChambersForToday {
    return dailyDate == todayDateString() ? dailyBestChambers : 0;
  }
}

/// Date du jour au format `yyyy-mm-dd`, utilisé comme clé de journée pour le
/// défi quotidien (le même format que [todayDateString] côté jeu).
String todayDateString() {
  final now = DateTime.now();
  return '${now.year}-${now.month}-${now.day}';
}
