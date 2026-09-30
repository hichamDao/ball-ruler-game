import 'package:ball_ruler_game/main.dart';
import 'package:ball_ruler_game/models/player_score.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Les records locaux sont lus au lancement du jeu.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('PlayerScore', () {
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';

    test('le record quotidien vaut 0 si la ligne date d\'un jour précédent', () {
      const score = PlayerScore(
        uid: 'uid1',
        displayName: 'Joueur',
        bestChambers: 12,
        dailyBestChambers: 8,
        dailyDate: '1999-1-1',
      );
      expect(score.dailyChambersForToday, 0);
      // Le record général, lui, ne dépend pas de la date.
      expect(score.bestChambers, 12);
    });

    test('le record quotidien est valable le jour meme de la partie', () {
      final score = PlayerScore(
        uid: 'uid1',
        displayName: 'Joueur',
        bestChambers: 12,
        dailyBestChambers: 8,
        dailyDate: today,
      );
      expect(score.dailyChambersForToday, 8);
    });
  });

  testWidgets('l\'application démarre en mode invité, jeu immédiatement jouable',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Le bandeau d'invité est affiché, et le terrain de jeu est monté.
    expect(find.textContaining('Invité'), findsOneWidget);
    expect(find.text('Chambre 1'), findsOneWidget);
    // Le bouton de connexion est accessible depuis la barre du haut.
    expect(find.byTooltip('Se connecter'), findsOneWidget);
  });

  testWidgets('l\'écran de connexion propose e-mail et Google', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    await tester.tap(find.byTooltip('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Connexion'), findsWidgets);
    expect(find.text('Continuer avec Google'), findsOneWidget);
    expect(find.text("Pas encore de compte ? S'inscrire"), findsOneWidget);
    // Le mode invité reste proposé : on n'impose jamais un compte.
    expect(find.text('Continuer en invité'), findsOneWidget);
  });
}
