/// Un succès à débloquer. Purement déclaratif : la logique de déblocage vit
/// dans BallRulerGameState (voir _unlock), ce fichier ne fait que décrire
/// la liste affichée dans l'écran des succès.
class Achievement {
  final String id;
  final String title;
  final String description;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
  });
}

const List<Achievement> allAchievements = [
  Achievement(
    id: 'first_steps',
    title: 'Premiers pas',
    description: 'Atteindre la chambre 2',
  ),
  Achievement(
    id: 'chamber_5',
    title: 'Sur la bonne voie',
    description: 'Atteindre la chambre 5',
  ),
  Achievement(
    id: 'chamber_10',
    title: 'Expert des chambres',
    description: 'Atteindre la chambre 10',
  ),
  Achievement(
    id: 'bed_bounce',
    title: 'Rebond parfait',
    description: 'Toucher un lit',
  ),
  Achievement(
    id: 'no_net',
    title: 'Sans filet',
    description: "Passer une chambre sans utiliser la réserve d'urgence",
  ),
  Achievement(
    id: 'daily_done',
    title: 'Défi relevé',
    description: 'Passer une chambre en défi du jour',
  ),
];
