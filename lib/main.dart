import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Para detectar Web
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;
import 'package:solana/solana.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'metamask_connector.dart'; // Importação condicional para Metamask

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TerlineT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const TerlineTPage(),
    );
  }
}

class TerlineTPage extends StatefulWidget {
  const TerlineTPage({super.key});

  @override
  State<TerlineTPage> createState() => _TerlineTPageState();
}

class _TerlineTPageState extends State<TerlineTPage> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  String _response = "";
  bool _isLoading = false;
  late AnimationController _murmurationController;
  late AnimationController _bubbleController;
  
  late List<BirdFlock> _flocks;
  String? _walletAddress;

  final String hfSpaceUrl = 'https://tertulianoshow-terlinet.hf.space';

  @override
  void initState() {
    super.initState();
    _murmurationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _flocks = List.generate(6, (index) => BirdFlock(index));
  }

  @override
  void dispose() {
    _murmurationController.dispose();
    _bubbleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // Lógica de Conexão Híbrida
  Future<void> _connectWallet() async {
    if (kIsWeb) {
      await _connectMetamask();
    } else {
      await _connectMobileWallet();
    }
  }

  // CONEXÃO METAMASK (Web - Isolada via conector para permitir APK)
  Future<void> _connectMetamask() async {
    try {
      final String? address = await connectMetamaskLogic();
      if (address != null) {
        setState(() {
          _walletAddress = address;
          _response = "Metamask conectada com sucesso!";
        });
      }
    } catch (e) {
      debugPrint('Erro Metamask: $e');
      setState(() => _response = "Erro ao conectar com a Metamask.");
    }
  }

  // CONEXÃO MOBILE (App Nativo - Solana Mobile Stack)
  Future<void> _connectMobileWallet() async {
    try {
      final session = await LocalAssociationScenario.create();
      final client = await session.start();
      
      final result = await client.authorize(
        identityUri: Uri.parse('https://terlinet.github.io/terlinet/'),
        identityName: 'TerlineT',
        cluster: 'mainnet-beta',
      );
      
      if (result != null) {
        setState(() {
          _walletAddress = base58encode(result.publicKey.toList());
        });
      }
      
      await session.close();
    } catch (e) {
      debugPrint('Erro Mobile Wallet: $e');
      setState(() => _response = "Certifique-se que o app da Phantom está instalado.");
    }
  }

  String base58encode(List<int> bytes) {
    const String alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var x = BigInt.zero;
    for (var byte in bytes) {
      x = x * BigInt.from(256) + BigInt.from(byte);
    }
    var res = '';
    while (x > BigInt.zero) {
      var mod = x % BigInt.from(58);
      res = alphabet[mod.toInt()] + res;
      x = x ~/ BigInt.from(58);
    }
    for (var byte in bytes) {
      if (byte == 0) {
        res = alphabet[0] + res;
      } else {
        break;
      }
    }
    return res;
  }

  Future<void> _sendQuery() async {
    if (_controller.text.isEmpty) return;
    final String userText = _controller.text;
    _controller.clear();
    setState(() {
      _isLoading = true;
      _response = "A TerlineT está processando...";
    });
    try {
      final response = await http.post(
        Uri.parse('$hfSpaceUrl/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': userText}),
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        setState(() {
          String decodedResponse = utf8.decode(response.bodyBytes);
          _response = decodedResponse.replaceAll('"', '').replaceAll('\\n', '\n');
        });
      }
    } catch (e) {
      setState(() => _response = "Erro de conexão!");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/peruibe2.jpeg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.45)),
          
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _murmurationController,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        painter: MurmurationPainter(_flocks, _murmurationController.value),
                                        size: const Size(400, 400),
                                      );
                                    },
                                  ),
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('T', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w200, color: Colors.white)),
                                      SizedBox(width: 15),
                                      Text('E R L I N E', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w200, letterSpacing: 6, color: Colors.white)),
                                      SizedBox(width: 15),
                                      Text('T', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w200, color: Colors.white)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 60),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                                  ),
                                  child: TextField(
                                    controller: _controller,
                                    style: const TextStyle(color: Colors.white, fontSize: 18),
                                    decoration: InputDecoration(
                                      hintText: 'O que deseja saber?',
                                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                      border: InputBorder.none,
                                      suffixIcon: IconButton(
                                        icon: Icon(_isLoading ? Icons.hourglass_top : Icons.send_rounded, color: Colors.white),
                                        onPressed: _sendQuery,
                                      ),
                                    ),
                                    onSubmitted: (_) => _sendQuery(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            if (_response.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: SelectableText(
                                      _response,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 17, color: Colors.white, height: 1.6, fontWeight: FontWeight.w300),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),

                      // BOLHA REALÍSTICA COM ÓRBITA
                      AnimatedBuilder(
                        animation: _bubbleController,
                        builder: (context, child) {
                          return Positioned(
                            top: 20 + (_bubbleController.value * 20),
                            right: 10,
                            child: GestureDetector(
                              onTap: _connectWallet,
                              child: SizedBox(
                                width: 150,
                                height: 150,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.05),
                                            Colors.blue.withOpacity(0.1),
                                            Colors.purple.withOpacity(0.2),
                                            Colors.pink.withOpacity(0.2),
                                            Colors.cyan.withOpacity(0.3),
                                            Colors.transparent,
                                          ],
                                          stops: const [0.0, 0.4, 0.7, 0.85, 0.95, 1.0],
                                          center: const Alignment(-0.2, -0.2),
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.4),
                                          width: 0.8,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.cyan.withOpacity(0.2),
                                            blurRadius: 15,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        children: [
                                          PositionPoint(top: 15, left: 25, size: 15, opacity: 0.6),
                                          PositionPoint(bottom: 15, right: 20, size: 8, opacity: 0.3),
                                          Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text(
                                                _walletAddress == null 
                                                    ? "🦊"
                                                    : "${_walletAddress!.substring(0, 4)}..${_walletAddress!.substring(_walletAddress!.length - 4)}",
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: _walletAddress == null ? 32 : 11, 
                                                  color: Colors.white, 
                                                  fontWeight: FontWeight.w500,
                                                  shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    AnimatedBuilder(
                                      animation: _murmurationController,
                                      builder: (context, child) {
                                        final double angle = _murmurationController.value * 2 * math.pi;
                                        const double radius = 68.0;
                                        return Transform.translate(
                                          offset: Offset(
                                            math.cos(angle) * radius,
                                            math.sin(angle) * radius,
                                          ),
                                          child: const Text(
                                            'Wallet',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(color: Colors.black, blurRadius: 4),
                                                Shadow(color: Colors.cyanAccent, blurRadius: 1),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  color: Colors.black.withOpacity(0.3),
                  child: const Column(
                    children: [
                      Text('TerlineT • Conectando pessoas e informações desde 2001', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      SizedBox(height: 4),
                      Text('bubblescoinmaster@gmail.com', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PositionPoint extends StatelessWidget {
  final double? top, left, right, bottom;
  final double size, opacity;
  PositionPoint({this.top, this.left, this.right, this.bottom, required this.size, required this.opacity});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, left: left, right: right, bottom: bottom,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
          boxShadow: [
            BoxShadow(color: Colors.white.withOpacity(opacity), blurRadius: 10, spreadRadius: 2)
          ],
        ),
      ),
    );
  }
}

class BirdFlock {
  final int id;
  late List<Offset> offsets;
  late double speedFactor;
  late double radiusFactor;
  late double phase;
  BirdFlock(this.id) {
    final random = math.Random();
    speedFactor = 0.5 + random.nextDouble();
    radiusFactor = 0.8 + random.nextDouble() * 0.5;
    phase = random.nextDouble() * math.pi * 2;
    int birdCount = 15 + random.nextInt(15);
    offsets = List.generate(birdCount, (index) => Offset((random.nextDouble() - 0.5) * 40, (random.nextDouble() - 0.5) * 40));
  }
}

class MurmurationPainter extends CustomPainter {
  final List<BirdFlock> flocks;
  final double animationValue;
  MurmurationPainter(this.flocks, this.animationValue);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final t = animationValue * math.pi * 2;
    for (var flock in flocks) {
      double xBase = math.sin(t * flock.speedFactor + flock.phase) * (140 * flock.radiusFactor);
      double yBase = math.cos(t * 0.7 * flock.speedFactor + flock.phase * 0.5) * (100 * flock.radiusFactor);
      Offset flockCenter = center + Offset(xBase, yBase);
      for (int i = 0; i < flock.offsets.length; i++) {
        double birdT = t * 2 + i * 0.2;
        Offset pos = flockCenter + flock.offsets[i] + Offset(math.sin(birdT + flock.phase) * 12, math.cos(birdT * 0.8 + i) * 12);
        double opacity = 0.3 + (math.sin(birdT).abs() * 0.4);
        final paint = Paint()..color = Colors.white.withOpacity(opacity)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5);
        canvas.drawCircle(pos, 1.2, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant MurmurationPainter oldDelegate) => true;
}
