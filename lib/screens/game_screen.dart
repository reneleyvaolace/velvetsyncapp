import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'package:flame/particles.dart';
import 'package:flame/palette.dart';
import '../ble/ble_service.dart';
import '../ble/lvs_commands.dart';
import '../main.dart'; // Para bleProvider
import '../theme.dart';

class LocalGameScreen extends ConsumerStatefulWidget {
  const LocalGameScreen({super.key});

  @override
  ConsumerState<LocalGameScreen> createState() => _LocalGameScreenState();
}

class _LocalGameScreenState extends ConsumerState<LocalGameScreen> {
  late FruitGame _game;

  @override
  void initState() {
    super.initState();
    final ble = ref.read(bleProvider);
    _game = FruitGame(ble: ble);
  }

  @override
  void dispose() {
    _game.ble.writeCommand(LvsCommands.cmdStop, label: 'Game Stop General');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: LvsColors.bg,
        body: Stack(
        children: [
          // Fondo estilo Velvet Neon (gradientes interactivos tenues)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  LvsColors.bg,
                  LvsColors.pink.withValues(alpha: 0.1),
                  LvsColors.violet.withValues(alpha: 0.1),
                  LvsColors.bg,
                ],
              ),
            ),
          ),
          
          // Malla tipo Grid o Glass para el fondo del juego
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(painter: _GridPainter()),
            ),
          ),

          // Área del juego Flame restringida a zona segura
          Positioned.fill(
            child: SafeArea(
              bottom: true, // Crucial para los botones de Android
              child: GameWidget(game: _game),
            ),
          ),
          
          // UI Superior de Controles
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botón Salir y Detener
                    ElevatedButton.icon(
                      onPressed: () {
                        // Enviar comando general de parada (0xE5157D)
                        _game.ble.writeCommand(LvsCommands.cmdStop, label: 'Game Stop General');
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LvsColors.bgCardH,
                        foregroundColor: LvsColors.red,
                        side: BorderSide(color: LvsColors.red.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('DETENER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 11)),
                    ),
                    
                    // Puntaje en pantalla
                    ValueListenableBuilder<int>(
                      valueListenable: _game.scoreNotifier,
                      builder: (context, score, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: LvsColors.pink.withValues(alpha: 0.5), width: 1.5),
                            boxShadow: [
                              BoxShadow(color: LvsColors.pink.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 1),
                            ]
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, color: LvsColors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '$score',
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ), // Cierre del SafeArea de controles superiores
        ],
      ),
    ),
    );
  }
}

// ── Pintor de Cuadrícula de Fondo (Sutil) ───────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0;
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Motor del Juego Flame ────────────────────────────────────────────────

class FruitGame extends FlameGame with HasCollisionDetection {
  final BleService ble;
  FruitGame({required this.ble});

  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  int _lastVibTime = 0;
  final Random _rand = Random();

  // Para evitar que múltiples combinaciones exploten al mismo tiempo
  final Set<String> _pendingRemovals = {};

  double spawnTimer = 0;

  @override
  Color backgroundColor() => Colors.transparent; // Se verá encima de LvsColors.bg

  @override
  Future<void> onLoad() async {
    // Agregar bordes a la pantalla
    add(ScreenHitbox());
    
    // Fruta inicial
    _spawnFruit();
  }

  void _spawnFruit() {
    final startX = _rand.nextDouble() * (size.x - 60) + 30;
    add(Fruit(
      id: DateTime.now().microsecond.toString() + _rand.nextInt(1000).toString(),
      level: 1, 
      position: Vector2(startX, 100),
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    spawnTimer += dt;
    if (spawnTimer > 3.0) { // Generar cada 3 seg
      spawnTimer = 0;
      _spawnFruit();
    }
  }

  // Manejo centralizado de colisiones
  void handleCollision(Fruit f1, Fruit f2) {
    // Solo procesar si ambos aún están vivos
    if (_pendingRemovals.contains(f1.id) || _pendingRemovals.contains(f2.id)) return;

    if (f1.level == f2.level) {
      // FUSIÓN LÓGICA (Grandes choques)
      _pendingRemovals.add(f1.id);
      _pendingRemovals.add(f2.id);

      final newLevel = f1.level + 1;
      final newPos = (f1.position + f2.position) / 2;

      f1.removeFromParent();
      f2.removeFromParent();

      scoreNotifier.value += (newLevel * 10);

      // Partículas de explosión (Visual Merge)
      _createExplosion(newPos, f1.paint.color);

      // Instanciar el nuevo nivel
      add(Fruit(
        id: DateTime.now().microsecond.toString() + _rand.nextInt(1000).toString(),
        level: newLevel,
        position: newPos,
        velocity: Vector2(0, -100), // Pequeño salto
      ));

      _fireHaptic(type: 'MERGE');
    } else {
      // CHOQUE LIGERO
      _fireHaptic(type: 'BOUNCE');
    }
  }

  // ── Explosión de Partículas ──────────────────────────────────────────
  void _createExplosion(Vector2 position, Color color) {
    final curColor = color;
    final particleComponent = ParticleSystemComponent(
      particle: Particle.generate(
        count: 20,
        lifespan: 0.8,
        generator: (i) {
          final Vector2 velocity = (Vector2.random(_rand) - Vector2(0.5, 0.5)) * 400;
          return AcceleratedParticle(
            acceleration: Vector2(0, 500), // Gravedad de partículas
            speed: velocity,
            position: position.clone(),
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final paint = Paint()
                  ..color = curColor.withOpacity(1.0 - particle.progress)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
                canvas.drawCircle(Offset.zero, 4.0 + _rand.nextDouble() * 3, paint);
              },
            ),
          );
        },
      ),
    );
    add(particleComponent);
  }

  // ── LÓGICA DE COLISIÓN HÁPTICA (Modelo 8154) ──────────────────────
  void _fireHaptic({required String type}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Throttling mejorado: 
    // Limitamos rebotes muy seguidos (150ms) pero le damos mayor prioridad a las fusiones
    if (type == 'BOUNCE' && (now - _lastVibTime < 150)) return;
    if (type == 'MERGE' && (now - _lastVibTime < 100)) return;

    _lastVibTime = now;

    if (type == 'MERGE') {
      // Fusión (Level Up): Canal 1 (Empuje Principal)
      int dynamicIntensity = (scoreNotifier.value / 10).clamp(0, 100).toInt();
      if (dynamicIntensity < 40) dynamicIntensity = 40; // Base force
      
      final cmd = LvsCommands.preciseChannel1(dynamicIntensity);
      ble.writeCommand(cmd, label: 'GAME_MERGE_CH1');
      
      // Apagar SOLO el Canal 1 sin interrumpir el Canal 2
      Future.delayed(const Duration(milliseconds: 500), () {
         ble.writeCommand(LvsCommands.preciseChannel1(0), label: 'GAME_STOP_CH1'); 
      });
      
    } else if (type == 'BOUNCE') {
      // Choques: Canal 2 (Vibración Secundaria)
      // Usando el comando formal preciseChannel2 a intensidad media-baja (ej. 30%)
      ble.writeCommand(LvsCommands.preciseChannel2(30), label: 'GAME_BOUNCE_CH2');
      
      // Apagar SOLO el Canal 2 
      Future.delayed(const Duration(milliseconds: 150), () {
         ble.writeCommand(LvsCommands.preciseChannel2(0), label: 'GAME_STOP_CH2');
      });
    }
  }
}

// ── Objeto Fruta ─────────────────────────────────────────────────────────

class Fruit extends CircleComponent with CollisionCallbacks, HasGameRef<FruitGame>, DragCallbacks {
  final String id;
  final int level;
  Vector2 velocity;
  bool isDragged = false;
  
  static const double gravity = 500.0;
  static const double bounceFactor = 0.5;

  Fruit({
    required this.id,
    required this.level,
    required super.position,
    Vector2? velocity,
  }) : velocity = velocity ?? Vector2(0, 0),
       super(
         radius: 20.0 + (level * 5.0), 
         anchor: Anchor.center,
       );

  @override
  Future<void> onLoad() async {
    // Hitbox para colisión simple
    add(CircleHitbox());
    
    // Box original transparente, pero le pasamos el color a paint
    final colors = [
      LvsColors.pink, LvsColors.violet, LvsColors.teal, 
      LvsColors.amber, LvsColors.red, Colors.deepPurpleAccent, Colors.cyanAccent, Colors.orangeAccent, Colors.greenAccent
    ];
    paint = Paint()..color = colors[(level - 1) % colors.length];
  }

  @override
  void render(Canvas canvas) {
    // 1. Sombra externa glow (Neon)
    final shadowPaint = Paint()
      ..color = paint.color.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset(radius, radius), radius * 1.05, shadowPaint);

    // 2. Esfera base degradado 3D (Glass/Neon Sphere)
    final spherePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(radius * 0.7, radius * 0.7), // Foco de luz un poco arriba a la izq
        radius * 1.5,
        [Colors.white.withOpacity(0.9), paint.color, paint.color.withOpacity(0.5)],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawCircle(Offset(radius, radius), radius, spherePaint);

    // 3. Borde brillante
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white.withOpacity(0.7);
    canvas.drawCircle(Offset(radius, radius), radius, borderPaint);

    // 4. Texto central con el "Level"
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$level',
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(1, 2))],
          fontFamily: 'Inter'
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas, 
      Offset(radius - textPainter.width / 2, radius - textPainter.height / 2)
    );
  }

  @override
  // ignore: must_call_super
  void update(double dt) {
    if (isDragged) return; // Si lo tengo agarrado, la física se pausa

    velocity.y += gravity * dt;
    position += velocity * dt;

    // Colisión simple con bordes verticales (Rebote paredes x)
    if (position.x - radius < 0) {
      position.x = radius;
      velocity.x = -velocity.x * bounceFactor;
    } else if (position.x + radius > gameRef.size.x) {
      position.x = gameRef.size.x - radius;
      velocity.x = -velocity.x * bounceFactor;
    }

    // Colisión simple con el suelo (Rebote piso y)
    if (position.y + radius > gameRef.size.y) {
      position.y = gameRef.size.y - radius;
      // Absorber impactos casi inactivos
      if (velocity.y.abs() < 50) {
        velocity.y = 0;
        velocity.x *= 0.9;
      } else {
        velocity.y = -velocity.y * bounceFactor;
      }
    }
  }

  // ── Arrastre ──
  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    isDragged = true;
    velocity = Vector2.zero();
    priority = 100; // Poner al frente
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    position += event.localDelta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    isDragged = false;
    // Otorga el momentum del dedo a la fruta al soltarla
    velocity = event.velocity / 2.0; 
    priority = 0;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    isDragged = false;
  }

  // ── Colisiones (Círculo vs Círculo o Pared) ──
  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    
    if (other is ScreenHitbox) {
      // Paredes, ya resuelto en update()
    } else if (other is Fruit) {
      // Despachar la decisión al Controller Principal
      gameRef.handleCollision(this, other);
      
      if (!gameRef._pendingRemovals.contains(id)) {
        // Pseudo-Física de rebote muy simple (intercambiar velocidades si están solapados)
        final diff = position - other.position;
        if (diff.length > 0) {
          final normal = diff.normalized();
          velocity += normal * (150.0 / level); // Se aleja
        }
      }
    }
  }
}
