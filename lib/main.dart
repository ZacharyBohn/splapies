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

enum ToolType { lightning, curling, growing }

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SandboxGame(),
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

  void _handleTap(Offset position) {
    if (selectedTool == ToolType.lightning) {
      _spawnLightning(position);
    } else if (selectedTool == ToolType.curling) {
      _spawnStarTrail(position);
    } else if (selectedTool == ToolType.growing) {
      _spawnSquare(position);
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
                            : Icons.crop_square,
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
  ComboPainter(this.bolts, this.stars, this.squares);

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
