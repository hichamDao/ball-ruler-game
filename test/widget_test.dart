import 'package:ball_ruler_game/game/ball_ruler_game.dart';
import 'package:ball_ruler_game/main.dart';
import 'package:ball_ruler_game/models/player_score.dart';
import 'package:flutter/material.dart';
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
    // L'aide s'ouvre toute seule au premier lancement : il faut la fermer
    // avant d'atteindre la barre du titre.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    if (find.text('Comment jouer').evaluate().isNotEmpty) {
      await tester.pageBack();
      // pump() et non pumpAndSettle() : de retour sur le jeu, son ticker
      // redemande des frames en continu et pumpAndSettle ne terminerait
      // jamais. 400 ms couvrent l'animation de retour.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.byTooltip('Se connecter'), findsOneWidget);
    await tester.tap(find.byTooltip('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Connexion'), findsWidgets);
    expect(find.text('Continuer avec Google'), findsOneWidget);
    expect(find.text("Pas encore de compte ? S'inscrire"), findsOneWidget);
    // Le mode invité reste proposé : on n'impose jamais un compte.
    expect(find.text('Continuer en invité'), findsOneWidget);
  });

  testWidgets('l\'aide explique les règles du jeu', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    // Le premier lancement ouvre l'écran d'aide automatiquement.
    expect(find.text('Comment jouer'), findsOneWidget);
    expect(find.text('Le principe'), findsOneWidget);
    expect(find.textContaining('SORTIE'), findsWidgets);

    // Une fois refermée, l'icône de la barre du titre la rouvre.
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Le principe'), findsNothing);

    await tester.tap(find.byTooltip('Comment jouer'));
    await tester.pumpAndSettle();
    expect(find.text('Le principe'), findsOneWidget);
  });

  testWidgets('l\'aide ne s\'affiche qu\'une seule fois', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    // On quitte l'aide, puis on relance l'app comme si on rouvrait le jeu.
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Le principe'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Le principe'), findsNothing);
    // L'icône reste disponible dans la barre du titre.
    expect(find.byTooltip('Comment jouer'), findsOneWidget);
  });

  test('le jeu ne propose pas l\'app Android à un joueur connecté', () {
    // La règle est testable séparément du dialogue, qui ne s'ouvre que sur le
    // web : ce qui compte ici est qu'elle dépende de l'état de connexion.
    expect(gameOffersAndroidApp(isSignedIn: true), isFalse);
    expect(gameOffersAndroidApp(isSignedIn: false), isTrue);
  });
}
