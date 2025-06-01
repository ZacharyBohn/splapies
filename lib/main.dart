import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MainApp());
}

enum ToolType { lightning, curling, growing, splapie, food }

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SafeArea(child: SandboxGame()),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SandboxGame extends StatefulWidget {
  const SandboxGame({super.key});

  @override
  State<SandboxGame> createState() => _SandboxGameState();
}

class _SandboxGameState extends State<SandboxGame> {
  ToolType selectedTool = ToolType.lightning;
  Color selectedColor = Colors.red;

  final List<Color> availableColors = [
    Colors.red,
    Colors.blue,
    Colors.yellow,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.grey,
  ];

  List<LightningBolt> activeBolts = [];
  List<StarTrail> activeStars = [];
  List<GrowingSquare> activeSquares = [];
  List<Splapie> activeSplapies = [];
  List<Food> activeFood = [];

  Offset? _lastDragPosition;
  DateTime? _lastDragTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTicker());
  }

  void _startTicker() {
    const frameRate = Duration(milliseconds: 16);
    Future.doWhile(() async {
      await Future.delayed(frameRate);
      setState(() {
        activeBolts.removeWhere((bolt) => bolt.isExpired);
        activeStars.removeWhere((s) => s.isExpired);
        activeSquares.removeWhere((s) => s.isExpired);
        for (final splapie in activeSplapies) {
          splapie.update(activeFood);
        }
        activeSplapies.removeWhere((s) => s.isDead);
        // Lightning proximity logic: confuse splapies if near bolt
        for (final bolt in activeBolts) {
          for (final s in activeSplapies) {
            for (int i = 0; i < bolt.segments.length - 1; i += 2) {
              final lineStart = bolt.segments[i];
              final lineEnd = bolt.segments[i + 1];
              final dist = _distanceToSegment(s.origin, lineStart, lineEnd);
              if (dist < 20) {
                s.confuse(const Duration(seconds: 3));
                break;
              }
            }
          }
        }
      });
      return true;
    });
  }

  void _spawnLightning(Offset origin) {
    final bolt = LightningBolt(origin: origin, color: selectedColor);
    activeBolts.add(bolt);
  }

  void _spawnStarTrail(Offset origin) {
    final trail = StarTrail(origin: origin, color: selectedColor);
    activeStars.add(trail);
  }

  void _spawnSquare(Offset origin) {
    final square = GrowingSquare(origin: origin, color: selectedColor);
    activeSquares.add(square);
  }

  void _spawnSplapie(Offset origin) {
    if (activeSplapies.length >= 3) return;
    final splapie = Splapie(origin: origin, color: selectedColor);
    activeSplapies.add(splapie);
  }

  void _spawnFood(Offset origin) {
    final food = Food(origin: origin, color: selectedColor);
    activeFood.add(food);
  }

  void _handleTap(Offset position) {
    if (selectedTool == ToolType.lightning) {
      _spawnLightning(position);
    } else if (selectedTool == ToolType.curling) {
      _spawnStarTrail(position);
    } else if (selectedTool == ToolType.growing) {
      _spawnSquare(position);
    } else if (selectedTool == ToolType.splapie) {
      _spawnSplapie(position);
    } else if (selectedTool == ToolType.food) {
      _spawnFood(position);
    }
  }

  void _handleDrag(Offset position) {
    final now = DateTime.now();
    if (_lastDragTime == null ||
        now.difference(_lastDragTime!) >= const Duration(milliseconds: 200)) {
      _handleTap(position);
      _lastDragTime = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // Canvas area
          Expanded(
            child: GestureDetector(
              onTapDown: (details) {
                _handleTap(details.localPosition);
              },
              onPanStart: (details) {
                _lastDragPosition = details.localPosition;
                _lastDragTime = DateTime.now().subtract(
                  const Duration(milliseconds: 101),
                );
                _handleDrag(details.localPosition);
              },
              onPanUpdate: (details) {
                _handleDrag(details.localPosition);
              },
              onPanEnd: (_) {
                _lastDragPosition = null;
                _lastDragTime = null;
              },
              child: Container(
                color: Colors.black,
                child: CustomPaint(
                  painter: ComboPainter(
                    activeBolts,
                    activeStars,
                    activeSquares,
                    activeSplapies,
                    activeFood,
                  ),
                  child: Container(),
                ),
              ),
            ),
          ),

          // Tool selector
          Container(
            width: 100,
            color: Colors.grey[900],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ToolType.values.map((tool) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedTool = tool;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      border: Border.all(
                        color: selectedTool == tool
                            ? Colors.white
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    height: 60,
                    width: 60,
                    child: Center(
                      child: Icon(
                        tool == ToolType.lightning
                            ? Icons.flash_on
                            : tool == ToolType.curling
                            ? Icons.star
                            : tool == ToolType.growing
                            ? Icons.crop_square
                            : tool == ToolType.splapie
                            ? Icons.circle
                            : tool == ToolType.food
                            ? Icons.fastfood
                            : Icons.help,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.grey[800],
        padding: const EdgeInsets.only(left: 8, right: 8, top: 16, bottom: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: availableColors.map((color) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedColor = color;
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: selectedColor == color
                        ? Colors.white
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                width: 30,
                height: 30,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class LightningBolt {
  final List<Offset> segments = [];
  final List<double> widths = [];
  final Color color;
  final DateTime startTime;
  bool get isExpired =>
      DateTime.now().difference(startTime).inMilliseconds > 6000;

  LightningBolt({required Offset origin, required this.color})
    : startTime = DateTime.now() {
    _generate(origin, _randomDir(), _randInRange(20, 30));
  }

  static final _rand = Random();

  Offset _randomDir() {
    final angle = _rand.nextDouble() * 2 * pi;
    return Offset(cos(angle), sin(angle));
  }

  int _randInRange(int min, int max) => min + _rand.nextInt(max - min + 1);

  void _generate(Offset point, Offset dir, int length) {
    if (length <= 3) return;
    final stepLength = length.toDouble();
    final nextPoint = point + dir * stepLength;
    segments.add(point);
    segments.add(nextPoint);
    widths.add((length / 10).ceilToDouble());

    int branches = 1 + _rand.nextInt(2); // always 1 or 2
    for (int i = 0; i < branches; i++) {
      final angleOffset = (_rand.nextDouble() - 0.5) * pi / 3;
      final newAngle = atan2(dir.dy, dir.dx) + angleOffset;
      final newDir = Offset(cos(newAngle), sin(newAngle));
      _generate(nextPoint, newDir, length - _randInRange(1, 3));
    }
  }
}

// ComboPainter draws both lightning and star trails.
class ComboPainter extends CustomPainter {
  final List<LightningBolt> bolts;
  final List<StarTrail> stars;
  final List<GrowingSquare> squares;
  final List<Splapie> splapies;
  final List<Food> food;
  ComboPainter(this.bolts, this.stars, this.squares, this.splapies, this.food);

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    for (final bolt in bolts) {
      final age = now.difference(bolt.startTime).inMilliseconds;
      final opacity = age >= 4000 ? 1.0 - (age - 4000) / 2000.0 : 1.0;
      final alpha = (opacity * 255).clamp(0, 255).toInt();

      for (int i = 0; i < bolt.segments.length - 1; i += 2) {
        final paint = Paint()
          ..color = bolt.color.withAlpha(alpha)
          ..strokeWidth = bolt.widths[i ~/ 2];
        canvas.drawLine(bolt.segments[i], bolt.segments[i + 1], paint);
      }
    }

    for (final trail in stars) {
      final age = now.difference(trail.startTime).inMilliseconds;
      final opacity = age >= 4000 ? 1.0 - (age - 4000) / 2000.0 : 1.0;
      final alpha = (opacity * 255).clamp(0, 255).toInt();
      final paint = Paint()
        ..color = trail.color.withAlpha(alpha)
        ..style = PaintingStyle.fill;

      for (final star in trail.stars) {
        final path = _createStarPath(star.position, star.size, 5);
        canvas.drawPath(path, paint);
      }
    }

    for (final square in squares) {
      final age = now.difference(square.startTime).inMilliseconds;
      final opacity = age >= 4000 ? 1.0 - (age - 4000) / 2000.0 : 1.0;
      final alpha = (opacity * 255).clamp(0, 255).toInt();
      final size = square.currentSize();
      final rect = Rect.fromCenter(
        center: square.origin,
        width: size,
        height: size,
      );
      final paint = Paint()
        ..color = square.color.withAlpha(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawRect(rect, paint);
    }

    for (final f in food) {
      const icon = Icons.fastfood;
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 16,
          fontFamily: icon.fontFamily,
          color: Colors.orange,
          package: icon.fontPackage,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        f.origin - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    for (final s in splapies) {
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(s.origin, s.radius, paint);

      if (s.isConfused) {
        final indicatorPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        final radius = s.radius + 6;
        final angle =
            (DateTime.now().millisecondsSinceEpoch % 2000) / 2000 * 2 * pi;
        final startAngle = angle;
        final sweepAngle = pi / 3;

        canvas.drawArc(
          Rect.fromCircle(center: s.origin, radius: radius),
          startAngle,
          sweepAngle,
          false,
          indicatorPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class StarTrail {
  final List<_Star> stars = [];
  final Color color;
  final DateTime startTime;
  bool get isExpired =>
      DateTime.now().difference(startTime).inMilliseconds > 6000;

  StarTrail({required Offset origin, required this.color})
    : startTime = DateTime.now() {
    _generateStars(origin);
  }

  static final _rand = Random();

  void _generateStars(Offset center) {
    int count = 10 + _rand.nextInt(6);
    for (int i = 0; i < count; i++) {
      double angle = _rand.nextDouble() * 2 * pi;
      double radius = 10.0 + _rand.nextDouble() * 40.0;
      Offset offset = Offset(cos(angle), sin(angle)) * radius;
      Offset pos = center + offset;
      stars.add(_Star(position: pos, size: 4.0 + _rand.nextDouble() * 4.0));
    }
  }
}

class _Star {
  final Offset position;
  final double size;
  _Star({required this.position, required this.size});
}

class GrowingSquare {
  final Offset origin;
  final Color color;
  final DateTime startTime;
  bool get isExpired =>
      DateTime.now().difference(startTime).inMilliseconds > 6000;

  GrowingSquare({required this.origin, required this.color})
    : startTime = DateTime.now();

  double currentSize() {
    final ms = DateTime.now().difference(startTime).inMilliseconds;
    final scale = ms / 6000.0;
    return scale * 1000.0; // slower growth
  }
}

Path _createStarPath(Offset center, double radius, int points) {
  final path = Path();
  final angle = pi / points;
  for (int i = 0; i < points * 2; i++) {
    final r = i.isEven ? radius : radius / 2;
    final x = center.dx + r * cos(i * angle);
    final y = center.dy + r * sin(i * angle);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}

class Food {
  final Offset origin;
  final Color color;

  Food({required this.origin, required this.color});
}

class Splapie {
  Offset origin;
  double radius = 5.0;
  final Color color;
  final DateTime birth;
  DateTime _lastShrink = DateTime.now();
  bool get isDead => radius <= 0;

  DateTime? confusedUntil;

  bool get isConfused =>
      confusedUntil != null && DateTime.now().isBefore(confusedUntil!);

  void confuse(Duration duration) {
    confusedUntil = DateTime.now().add(duration);
  }

  Splapie({required this.origin, required this.color}) : birth = DateTime.now();

  void update(List<Food> foodList) {
    // shrink
    if (DateTime.now().difference(_lastShrink).inSeconds >= 3) {
      radius -= 1;
      _lastShrink = DateTime.now();
    }

    if (isDead) return;

    if (isConfused) {
      final angle = Random().nextDouble() * 2 * pi;
      origin += Offset(cos(angle), sin(angle)) * 1.0;
      return;
    }

    if (foodList.isEmpty) return;

    // find nearest food
    foodList.sort(
      (a, b) =>
          (a.origin - origin).distance.compareTo((b.origin - origin).distance),
    );
    final nearest = foodList.first;
    final dir = (nearest.origin - origin);
    final distance = dir.distance;
    if (distance < 2) {
      if (nearest.color == color) {
        radius = min(radius + 5, 40.0); // Eat and grow
      }
      foodList.remove(nearest); // Always remove the food
    } else {
      final move = Offset.fromDirection(dir.direction, min(1.5, distance));
      origin += move;
    }
  }
}

// Helper function for distance from point to segment
double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ap = p - a;
  final ab = b - a;
  final abSquared = ab.dx * ab.dx + ab.dy * ab.dy;
  final dot =
      (ap.dx * ab.dx + ap.dy * ab.dy) / (abSquared != 0 ? abSquared : 1);
  final t = dot.clamp(0.0, 1.0);
  final closest = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  return (p - closest).distance;
}
