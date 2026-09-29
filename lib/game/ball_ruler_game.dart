import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/chambers.dart';
import '../models/achievement.dart';
import '../models/ball.dart';
import '../models/chamber.dart';
import '../models/furniture_type.dart';
import '../models/ruler.dart';
import '../utils/physics_utils.dart';

/// À utiliser comme body d'un Scaffold (ou dans un SizedBox.expand),
/// pas de taille infinie : il a besoin de contraintes finies pour dessiner.
class BallRulerGame extends StatefulWidget {
  const BallRulerGame({super.key});

  @override
  State<BallRulerGame> createState() => BallRulerGameState();
}

/// Les deux temps du jeu de stratégie/arcade :
/// - [planning] : le temps est figé, le joueur pose ses règles avec un
///   budget limité, puis lance la chute quand il est prêt.
/// - [falling] : la physique reprend, le joueur ne peut plus poser que sa
///   réserve d'urgence (plus petite) pour corriger une erreur.
enum GamePhase { planning, falling, gameOver }

/// [endless] : partie libre, chaque chambre procédurale est différente.
/// [daily] : défi du jour — la génération procédurale est seedée sur la
/// date, donc tout le monde affronte exactement la même séquence de
/// chambres aujourd'hui (voir _dailySeed).
enum GameMode { endless, daily }

class BallRulerGameState extends State<BallRulerGame>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  static const Offset _startPosition = Offset(180, 80);
  static const int _physicsSubsteps = 4; // évite de "traverser" une règle en cas de chute rapide

  // Budgets et minuteur par défaut (à ajuster facilement une fois la
  // sensation testée) : progression hybride (chambres écrites à la main
  // puis procédurales), réserve d'urgence rechargée à chaque chambre.
  // Voir data/chambers.dart pour la progression de difficulté.
  static const int _planningBudgetPerChamber = 3;
  static const int _emergencyBudgetPerChamber = 1;
  static const double _planningDurationSeconds = 20;

  final Ball _ball = Ball(position: _startPosition);
  final List<Ruler> _activeRulers = [];

  GamePhase _phase = GamePhase.planning;
  int _chamberIndex = 0;
  double _chamberStartY = 0; // sommet de la chambre courante, coordonnées monde
  late Chamber _chamber;
  int _planningBudget = _planningBudgetPerChamber;
  int _emergencyBudget = _emergencyBudgetPerChamber;
  double _planningTimeRemaining = _planningDurationSeconds;

  double _elapsed = 0; // ne compte que le temps en chute (voir _onTick)
  Size _gameSize = Size.zero;

  // Défilement de la caméra : maintient la bille près du haut de l'écran.
  double _scrollY = 0;
  static const double _cameraTargetFraction = 0.28; // position cible de la bille à l'écran
  static const double _cameraCatchUpSpeed = 3.0; // vitesse de rattrapage

  // Meilleur score (nombre de chambres atteintes), persisté sur l'appareil.
  static const String _bestScoreKey = 'best_chamber';
  int _bestChamber = 0;
  bool _isNewBest = false;

  // Mode de jeu et défi du jour : en mode daily, la génération procédurale
  // est seedée sur la date du jour, donc identique pour tout le monde.
  GameMode _mode = GameMode.endless;
  late Random _chamberRandom;
  static const String _dailyBestScoreKey = 'daily_best_chamber';
  static const String _dailyBestDateKey = 'daily_best_date';
  int _dailyBestChamber = 0;

  // Succès débloqués, persistés sur l'appareil.
  static const String _achievementsKey = 'unlocked_achievements';
  Set<String> _unlockedAchievements = {};
  String? _achievementBanner;
  Timer? _achievementBannerTimer;

  // Vrai si la réserve d'urgence a été utilisée pendant la chute de la
  // chambre en cours (remis à zéro à chaque nouvelle chambre) : sert au
  // succès "Sans filet".
  bool _usedEmergencyThisFall = false;

  int get _currentModeBest => _mode == GameMode.daily ? _dailyBestChamber : _bestChamber;

  @override
  void initState() {
    super.initState();
    _chamberRandom = Random();
    _loadChamber(0);
    _loadBestScore();
    _loadDailyBestScore();
    _loadAchievements();
    _ticker = createTicker(_onTick)..start();
  }

  Future<void> _loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _bestChamber = prefs.getInt(_bestScoreKey) ?? 0;
    });
  }

  Future<void> _saveBestScore(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bestScoreKey, value);
  }

  // Le défi du jour se réinitialise chaque jour : si le meilleur score
  // sauvegardé date d'hier (ou avant), on repart de zéro pour aujourd'hui.
  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  int _dailySeed() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  Future<void> _loadDailyBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final storedDate = prefs.getString(_dailyBestDateKey);
    final storedScore = prefs.getInt(_dailyBestScoreKey) ?? 0;
    setState(() {
      _dailyBestChamber = storedDate == _todayDateString() ? storedScore : 0;
    });
  }

  Future<void> _saveDailyBestScore(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyBestScoreKey, value);
    await prefs.setString(_dailyBestDateKey, _todayDateString());
  }

  Future<void> _loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _unlockedAchievements = (prefs.getStringList(_achievementsKey) ?? []).toSet();
    });
  }

  Future<void> _persistAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_achievementsKey, _unlockedAchievements.toList());
  }

  /// Débloque un succès s'il ne l'est pas déjà, le sauvegarde et affiche un
  /// petit bandeau. Appelée uniquement depuis des points déjà à l'intérieur
  /// d'un setState() (voir _onTick), donc pas besoin d'en ouvrir un de plus.
  void _unlock(String id) {
    if (_unlockedAchievements.contains(id)) return;
    _unlockedAchievements = {..._unlockedAchievements, id};
    _persistAchievements();
    final achievement = allAchievements.firstWhere((a) => a.id == id);
    _showAchievementBanner('Succès débloqué : ${achievement.title}');
  }

  void _showAchievementBanner(String message) {
    _achievementBannerTimer?.cancel();
    _achievementBanner = message;
    _achievementBannerTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _achievementBanner = null);
    });
  }

  void _showAchievementsDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Succès', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: allAchievements.map((a) {
              final unlocked = _unlockedAchievements.contains(a.id);
              return ListTile(
                leading: Icon(
                  unlocked ? Icons.emoji_events : Icons.lock_outline,
                  color: unlocked ? Colors.amberAccent : Colors.white38,
                ),
                title: Text(
                  a.title,
                  style: TextStyle(color: unlocked ? Colors.white : Colors.white38),
                ),
                subtitle: Text(
                  a.description,
                  style: TextStyle(color: unlocked ? Colors.white70 : Colors.white24),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _loadChamber(int index) {
    _chamber = index < handCraftedChambers.length
        ? handCraftedChambers[index]
        : generateChamber(index, _gameSize.width > 0 ? _gameSize.width : 360.0, _chamberRandom);
    _activeRulers.addAll(_chamber.buildObstacles(_chamberStartY));
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    // ignore les gros sauts de dt (reprise d'app en arrière-plan, etc.)
    if (_phase == GamePhase.gameOver || dt <= 0 || dt > 0.05) return;

    setState(() {
      if (_phase == GamePhase.planning) {
        _planningTimeRemaining -= dt;
        if (_planningTimeRemaining <= 0) {
          _planningTimeRemaining = 0;
          _phase = GamePhase.falling; // temps écoulé : la chute démarre toute seule
        }
      } else if (_phase == GamePhase.falling) {
        _elapsed += dt;
        for (final r in _activeRulers) {
          r.update(dt); // no-op pour les obstacles statiques
        }
        _stepPhysics(dt);
        _updateCamera(dt);
        _checkCameraGameOver();
        _checkChamberBoundary();
      }
      _cullOffscreenRulers();
    });
  }

  void _cullOffscreenRulers() {
    // libère la mémoire et évite de tester des collisions inutiles contre
    // des règles largement scrollées hors champ.
    _activeRulers.removeWhere((r) => r.center.dy - _scrollY < -200);
  }

  void _updateCamera(double dt) {
    if (_gameSize.height <= 0) return;
    final targetScreenY = _gameSize.height * _cameraTargetFraction;
    final desiredScrollY = _ball.position.dy - targetScreenY;
    // ne défile que vers le bas (la caméra ne remonte jamais) et avec un
    // léger temps de rattrapage : si la bille tombe trop vite sans être
    // rattrapée par une règle, elle peut quand même sortir de l'écran.
    if (desiredScrollY > _scrollY) {
      _scrollY += (desiredScrollY - _scrollY) * min(1.0, _cameraCatchUpSpeed * dt);
    }
  }

  void _stepPhysics(double dt) {
    final subDt = dt / _physicsSubsteps;
    for (var i = 0; i < _physicsSubsteps; i++) {
      _ball.applyGravity(subDt);
      _ball.updatePosition(subDt);
      _resolveCollisions();
      _resolveWalls();
    }
  }

  void _resolveWalls() {
    if (_gameSize.width <= 0) return;
    final r = _ball.radius;
    final pos = _ball.position;
    final vel = _ball.velocity;

    if (pos.dx - r < 0) {
      _ball.position = Offset(r, pos.dy);
      if (vel.dx < 0) _ball.velocity = Offset(-vel.dx, vel.dy);
    } else if (pos.dx + r > _gameSize.width) {
      _ball.position = Offset(_gameSize.width - r, pos.dy);
      if (vel.dx > 0) _ball.velocity = Offset(-vel.dx, vel.dy);
    }
  }

  void _resolveCollisions() {
    for (final r in _activeRulers) {
      final result = ballRulerCollision(
        _ball.position,
        _ball.radius,
        r.start,
        r.end,
      );
      if (!result.hit) continue;

      if (r.furniture == FurnitureType.bed) _unlock('bed_bounce');

      // le côté où la bille touche décide du sens de bascule futur (voir
      // Ruler.registerContact) : plus de tirage au sort, c'est prévisible.
      r.registerContact(result.closestPoint);

      // repositionne la bille exactement au contact, du bon côté de la règle
      _ball.position = result.closestPoint + result.normal * _ball.radius;

      // on retire la composante de vitesse qui va VERS la règle, et on la
      // renvoie dans l'autre sens si la règle a du rebond (le lit) ; la
      // composante tangentielle est conservée, c'est elle qui fait rouler
      // la bille le long de la pente (et rouler hors de la règle une fois
      // celle-ci devenue instable/inclinée).
      final vn = _ball.velocity.dx * result.normal.dx +
          _ball.velocity.dy * result.normal.dy;
      if (vn < 0) {
        _ball.velocity -= result.normal * vn * (1 + r.restitution);
      }
    }
  }

  /// Garde-fou existant : si la bille tombe plus vite que la caméra ne peut
  /// rattraper, elle finit par sortir de l'écran visible.
  void _checkCameraGameOver() {
    final screenY = _ball.position.dy - _scrollY;
    if (_gameSize.height > 0 && screenY > _gameSize.height + 40) {
      _triggerGameOver();
    }
  }

  /// Vérifie si la bille a atteint le bas de la chambre courante : elle passe
  /// à la chambre suivante si elle est dans la zone cible, sinon la partie
  /// s'arrête (elle est "sortie" de la chambre sans avoir trouvé la sortie).
  void _checkChamberBoundary() {
    final bottomY = _chamberStartY + _chamber.height;
    if (_ball.position.dy - _ball.radius < bottomY) return;

    final withinTarget =
        (_ball.position.dx - _chamber.targetCenterX).abs() <= _chamber.targetWidth / 2;
    if (withinTarget) {
      _advanceToNextChamber();
    } else {
      _triggerGameOver();
    }
  }

  void _advanceToNextChamber() {
    // succès liés à la chambre qu'on vient de terminer, avant de réinitialiser
    // les compteurs pour la nouvelle chambre
    if (!_usedEmergencyThisFall) _unlock('no_net');
    if (_mode == GameMode.daily) _unlock('daily_done');

    _chamberIndex++;
    _chamberStartY += _chamber.height;
    _loadChamber(_chamberIndex);
    _planningBudget = _planningBudgetPerChamber;
    _emergencyBudget = _emergencyBudgetPerChamber;
    _planningTimeRemaining = _planningDurationSeconds;
    _usedEmergencyThisFall = false;
    _phase = GamePhase.planning;

    // succès liés au numéro de la chambre désormais atteinte
    if (_chamberIndex >= 1) _unlock('first_steps');
    if (_chamberIndex >= 4) _unlock('chamber_5');
    if (_chamberIndex >= 9) _unlock('chamber_10');

    // Remonte la bille en haut de la nouvelle chambre et réaligne la caméra
    // dessus (comme au tout début de la partie). Sans ça, la caméra reste
    // calée sur la fin de la chute précédente : comme les chambres
    // suivantes sont plus hautes, la zone cible (plus bas) sort de l'écran
    // visible pendant la planification.
    _ball.position = Offset(_ball.position.dx, _chamberStartY + 80);
    _ball.velocity = Offset.zero;
    _scrollY = _chamberStartY;
  }

  void _triggerGameOver() {
    _phase = GamePhase.gameOver;
    _ticker.stop();

    final reached = _chamberIndex + 1; // chambre atteinte, 1-indexée pour l'affichage
    if (_mode == GameMode.daily) {
      _isNewBest = reached > _dailyBestChamber;
      if (_isNewBest) {
        _dailyBestChamber = reached;
        _saveDailyBestScore(_dailyBestChamber); // pas besoin d'attendre, ça ne bloque pas l'UI
      }
    } else {
      _isNewBest = reached > _bestChamber;
      if (_isNewBest) {
        _bestChamber = reached;
        _saveBestScore(_bestChamber);
      }
    }
  }

  void _onTapDown(TapDownDetails details) {
    if (_phase == GamePhase.gameOver) return;
    final worldPosition = details.localPosition + Offset(0, _scrollY);
    // repli si la bille finit par toucher pile au centre : penche du côté où
    // la règle est posée à l'écran (gauche -> gauche, droite -> droite).
    final fallbackTipSign =
        _gameSize.width > 0 && worldPosition.dx < _gameSize.width / 2 ? -1.0 : 1.0;

    if (_phase == GamePhase.planning) {
      if (_planningBudget <= 0) return;
      setState(() {
        _activeRulers.add(Ruler(center: worldPosition, fallbackTipSign: fallbackTipSign));
        _planningBudget--;
      });
    } else if (_phase == GamePhase.falling) {
      if (_emergencyBudget <= 0) return;
      setState(() {
        _activeRulers.add(Ruler(center: worldPosition, fallbackTipSign: fallbackTipSign));
        _emergencyBudget--;
        _usedEmergencyThisFall = true;
      });
    }
  }

  /// Lance la chute une fois que le joueur a fini de placer ses règles.
  void _startFalling() {
    if (_phase != GamePhase.planning) return;
    setState(() => _phase = GamePhase.falling);
  }

  void restart({GameMode? mode}) {
    setState(() {
      _mode = mode ?? _mode;
      _chamberRandom = _mode == GameMode.daily ? Random(_dailySeed()) : Random();
      _ball.position = _startPosition;
      _ball.velocity = Offset.zero;
      _activeRulers.clear();
      _chamberIndex = 0;
      _chamberStartY = 0;
      _loadChamber(0);
      _planningBudget = _planningBudgetPerChamber;
      _emergencyBudget = _emergencyBudgetPerChamber;
      _planningTimeRemaining = _planningDurationSeconds;
      _usedEmergencyThisFall = false;
      _elapsed = 0;
      _phase = GamePhase.planning;
      _lastTick = Duration.zero;
      _scrollY = 0;
    });
    _ticker.start();
  }

  void _switchMode() {
    restart(mode: _mode == GameMode.endless ? GameMode.daily : GameMode.endless);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _achievementBannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _gameSize = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapDown: _onTapDown,
          child: Stack(
            children: [
              CustomPaint(
                painter: _GamePainter(
                  ball: _ball,
                  rulers: _activeRulers,
                  scrollY: _scrollY,
                  chamber: _chamber,
                  chamberStartY: _chamberStartY,
                ),
                size: _gameSize,
              ),
              Positioned(
                top: 24,
                left: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HudText('Chambre ${_chamberIndex + 1}'),
                    Text(
                      _mode == GameMode.daily ? 'Défi du jour' : 'Partie libre',
                      style: const TextStyle(fontSize: 12, color: Colors.cyanAccent),
                    ),
                    if (_currentModeBest > 0)
                      Text(
                        'Record : $_currentModeBest',
                        style: const TextStyle(fontSize: 13, color: Colors.white54),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 24,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _HudText(_elapsed.toStringAsFixed(2)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SmallIconButton(
                          icon: _mode == GameMode.endless
                              ? Icons.calendar_today
                              : Icons.all_inclusive,
                          tooltip: _mode == GameMode.endless
                              ? 'Passer au défi du jour'
                              : 'Passer en partie libre',
                          onPressed: _switchMode,
                        ),
                        const SizedBox(width: 8),
                        _SmallIconButton(
                          icon: Icons.emoji_events,
                          tooltip: 'Succès',
                          onPressed: _showAchievementsDialog,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_phase == GamePhase.planning)
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_planningTimeRemaining.ceil()} s',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _planningTimeRemaining <= 5
                              ? Colors.redAccent
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _HudText('Règles disponibles : $_planningBudget'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _startFalling,
                        child: const Text('Lancer'),
                      ),
                    ],
                  ),
                ),
              if (_phase == GamePhase.falling)
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _HudText('Urgence : $_emergencyBudget'),
                  ),
                ),
              if (_phase == GamePhase.gameOver)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Game Over',
                        style: TextStyle(fontSize: 40, color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chambre atteinte : ${_chamberIndex + 1}',
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      if (_isNewBest)
                        const Text(
                          'Nouveau record !',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent,
                          ),
                        )
                      else
                        Text(
                          'Meilleur score : $_currentModeBest',
                          style: const TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: restart,
                        child: const Text('Rejouer'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _switchMode,
                        child: Text(
                          _mode == GameMode.endless
                              ? 'Essayer le défi du jour'
                              : 'Essayer une partie libre',
                        ),
                      ),
                    ],
                  ),
                ),
              if (_achievementBanner != null)
                Positioned(
                  top: 70,
                  left: 24,
                  right: 24,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amberAccent, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events, color: Colors.amberAccent, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _achievementBanner!,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HudText extends StatelessWidget {
  final String text;
  const _HudText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 18, color: Colors.white));
  }
}

/// Petit bouton icône compact pour le HUD (mode / succès), sans les marges
/// par défaut d'un IconButton classique qui seraient trop larges ici.
class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _SmallIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  final Ball ball;
  final List<Ruler> rulers;
  final double scrollY;
  final Chamber chamber;
  final double chamberStartY;

  _GamePainter({
    required this.ball,
    required this.rulers,
    required this.scrollY,
    required this.chamber,
    required this.chamberStartY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

    final cameraOffset = Offset(0, scrollY);

    for (final r in rulers) {
      if (r.isStatic) {
        _paintFurniture(canvas, r, cameraOffset);
      } else {
        final paint = Paint()
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(Colors.greenAccent, Colors.redAccent, r.instabilityRatio)!;
        canvas.drawLine(r.start - cameraOffset, r.end - cameraOffset, paint);
      }
    }

    canvas.drawCircle(
      ball.position - cameraOffset,
      ball.radius,
      Paint()..color = Colors.blueGrey.shade300,
    );

    _paintTargetZone(canvas);
  }

  /// Dessine un obstacle fixe selon son type de meuble. La ligne
  /// start->end (celle qui sert à la collision) est toujours tracée en
  /// premier, pour que le rendu reste exactement aligné avec la physique ;
  /// le reste n'est que de la décoration par-dessus.
  void _paintFurniture(Canvas canvas, Ruler r, Offset cameraOffset) {
    final start = r.start - cameraOffset;
    final end = r.end - cameraOffset;
    final angle = r.currentAngle;
    // perpendiculaire à la règle, pointant "vers le bas" pour une règle
    // proche de l'horizontale : sert à dessiner pieds/tête de lit.
    final perp = Offset(-sin(angle), cos(angle));

    switch (r.furniture) {
      case FurnitureType.plank:
        canvas.drawLine(
          start,
          end,
          Paint()
            ..color = Colors.grey.shade300
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round,
        );
        break;

      case FurnitureType.chair:
        _paintPlatformWithLegs(
          canvas,
          start,
          end,
          perp,
          color: const Color(0xFFB07A4B),
          strokeWidth: 6,
          legLength: 10,
          legInset: 0.2,
        );
        break;

      case FurnitureType.table:
        _paintPlatformWithLegs(
          canvas,
          start,
          end,
          perp,
          color: const Color(0xFF8A5A34),
          strokeWidth: 8,
          legLength: 14,
          legInset: 0.05,
        );
        break;

      case FurnitureType.bed:
        const bedColor = Color(0xFFE08FB0);
        canvas.drawLine(
          start,
          end,
          Paint()
            ..color = bedColor
            ..strokeWidth = 14
            ..strokeCap = StrokeCap.round,
        );
        // petite tête de lit à l'extrémité "start"
        canvas.drawLine(
          start,
          start - perp * 16,
          Paint()
            ..color = bedColor
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round,
        );
        break;

      case FurnitureType.wardrobe:
        canvas.drawLine(
          start,
          end,
          Paint()
            ..color = const Color(0xFF6B4F3A)
            ..strokeWidth = 26,
        );
        // ligne fine au centre : séparation des deux portes
        final mid = Offset.lerp(start, end, 0.5)!;
        final doorSeam = Offset(cos(angle), sin(angle)) * 10;
        canvas.drawLine(
          mid - doorSeam,
          mid + doorSeam,
          Paint()
            ..color = Colors.black.withOpacity(0.4)
            ..strokeWidth = 2,
        );
        break;
    }
  }

  /// Une plateforme simple (chaise/table) : la ligne de collision, plus deux
  /// petits pieds décoratifs en dessous.
  void _paintPlatformWithLegs(
    Canvas canvas,
    Offset start,
    Offset end,
    Offset perp, {
    required Color color,
    required double strokeWidth,
    required double legLength,
    required double legInset,
  }) {
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    final legPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..strokeWidth = 3;
    final legStart = Offset.lerp(start, end, legInset)!;
    final legEnd = Offset.lerp(start, end, 1 - legInset)!;
    canvas.drawLine(legStart, legStart + perp * legLength, legPaint);
    canvas.drawLine(legEnd, legEnd + perp * legLength, legPaint);
  }

  /// Dessine la zone cible en dernier, par-dessus tout le reste, pour être
  /// certain qu'elle ne soit jamais masquée par une règle qui la traverse.
  /// C'est un repère purement visuel : elle ne bloque pas la bille.
  void _paintTargetZone(Canvas canvas) {
    final targetY = chamberStartY + chamber.height - scrollY;
    final targetLeft = chamber.targetCenterX - chamber.targetWidth / 2;
    final targetRight = chamber.targetCenterX + chamber.targetWidth / 2;

    final gatePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    // ligne principale de la zone cible
    canvas.drawLine(Offset(targetLeft, targetY), Offset(targetRight, targetY), gatePaint);

    // deux petits piquets verticaux pour bien marquer les bords de la zone,
    // même quand elle devient étroite au fil des chambres
    const postHalfHeight = 14.0;
    canvas.drawLine(
      Offset(targetLeft, targetY - postHalfHeight),
      Offset(targetLeft, targetY + postHalfHeight),
      gatePaint,
    );
    canvas.drawLine(
      Offset(targetRight, targetY - postHalfHeight),
      Offset(targetRight, targetY + postHalfHeight),
      gatePaint,
    );

    // petit texte au-dessus, pour que la sortie reste reconnaissable même
    // de loin ou quand la zone est devenue très étroite
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'SORTIE',
        style: TextStyle(
          color: Colors.cyanAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(chamber.targetCenterX - textPainter.width / 2, targetY - postHalfHeight - 16),
    );
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => true;
}
