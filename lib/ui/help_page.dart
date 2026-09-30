import 'package:flutter/material.dart';

/// Écran d'aide : les règles du jeu, pour un joueur qui découvre l'app.
///
/// Affiché automatiquement au premier lancement, et à tout moment depuis
/// l'icône « ? » de la barre du titre.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comment jouer'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: const [
            _Section(
              title: 'Le principe',
              icon: Icons.sports_cricket,
              body: 'Une bille tombe du haut de chaque chambre. Tu places des '
                  'règles pour la guider, et tu dois l\'amener dans la zone '
                  'cyan marquée SORTIE en bas de la chambre.',
            ),
            _Section(
              title: 'Deux temps',
              icon: Icons.timer_outlined,
              body: 'PLANIFICATION : le temps est figé. Tu as 20 secondes et '
                  '3 règles pour construire ton passage, puis tu lances la '
                  'chute avec le bouton « Lancer ».\n\n'
                  'CHUTE : la physique reprend. Tu ne peux plus construire '
                  'que 1 règle d\'urgence, pour corriger une erreur — une '
                  'seule, et elle est réapprovisionnée à chaque chambre.',
            ),
            _Section(
              title: 'Les meubles',
              icon: Icons.chair_outlined,
              body: 'Chaque chambre contient du mobilier qui se comporte '
                  'différemment : la chaise et la table te servent d\'appui, '
                  'le lit fait rebondir la bille, l\'armoire agit comme un '
                  'mur à contourner. Regarde bien avant de lancer.',
            ),
            _Section(
              title: 'La difficulté',
              icon: Icons.trending_up,
              body: 'Chaque chambre franchie rétrécit la zone de sortie et '
                  'ajoute des obstacles. Les trois premières chambres sont '
                  'fixes, le reste est généré à chaque partie.',
            ),
            _Section(
              title: 'Les deux modes',
              icon: Icons.calendar_today,
              body: 'PARTIE LIBRE : une nouvelle séquence à chaque partie.\n\n'
                  'DÉFI DU JOUR : tout le monde affronte exactement la même '
                  'séquence aujourd\'hui. Le bouton en haut à droite change '
                  'de mode et relance la partie.',
            ),
            _Section(
              title: 'Succès et classement',
              icon: Icons.emoji_events,
              body: 'Les succès se débloquent au fil des parties ; '
                  'l\'icône médaille en haut à droite les affiche tous.\n\n'
                  'En mode invité, tes records restent sur cet appareil. '
                  'Connecte-toi avec ton compte Google ou ton e-mail depuis '
                  'l\'icône en haut de l\'écran : ton score est alors publié '
                  'et tu apparais dans le classement général et dans celui du '
                  'défi du jour.',
            ),
            _Section(
              title: 'Les commandes',
              icon: Icons.touch_app_outlined,
              body: 'Touche l\'écran pour poser une règle à cet endroit. '
                  'Chaque règle s\'incline et roule : elles ne restent pas '
                  'parfaitement fixes, la pente compte.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final String body;

  const _Section({
    required this.title,
    required this.icon,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }
}