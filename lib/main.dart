import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:solana/solana.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'metamask_connector.dart';
import 'registrator.dart';

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
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
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
  bool _isAgentActive = false;
  
  String? _chartSymbol;
  String? _chartInterval;

  late AnimationController _murmurationController;
  late AnimationController _bubbleController;
  late AnimationController _swarmController;
  late List<BirdFlock> _flocks;
  late List<BeeParticle> _swarmParticles;
  String? _walletAddress;

  late AudioPlayer _audioPlayer;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isMuted = false;
  bool _speechEnabled = false;

  final String hfSpaceUrl = 'https://tertulianoshow-terlinet.hf.space';
  final String bubblesUrl = 'https://tertulianonews.github.io/bubbleschain/#/bubbles';

  @override
  void initState() {
    super.initState();
    _murmurationController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _bubbleController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _swarmController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    
    _flocks = List.generate(6, (index) => BirdFlock(index));
    _swarmParticles = List.generate(40, (index) => BeeParticle());
    
    _audioPlayer = AudioPlayer();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) => debugPrint('STT Status: $status'),
        onError: (error) => debugPrint('STT Error: $error'),
      );
    } catch (e) { debugPrint('Erro STT: $e'); }
    setState(() {});
  }

  @override
  void dispose() {
    _murmurationController.dispose();
    _bubbleController.dispose();
    _swarmController.dispose();
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    if (!_speechEnabled) { if (!kIsWeb) await Permission.microphone.request(); await _initSpeech(); }
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          setState(() { _controller.text = result.recognizedWords; if (result.finalResult) { _isListening = false; _sendQuery(); } });
        }, localeId: "pt_BR");
      }
    } else { setState(() => _isListening = false); _speech.stop(); }
  }

  Future<void> _playVoice(String base64Audio) async {
    if (_isMuted) return;
    try {
      final Uint8List audioBytes = base64Decode(base64Audio);
      await _audioPlayer.setAudioSource(MyCustomSource(audioBytes));
      _audioPlayer.play();
    } catch (e) { debugPrint('Erro ao tocar voz: $e'); }
  }

  Future<void> _sendQuery() async {
    if (_controller.text.isEmpty) return;
    final String userText = _controller.text;
    _controller.clear();
    setState(() {
      _isLoading = true;
      _response = _isAgentActive ? "O Bee está convocando o enxame..." : "A TerlineT está processando...";
      _chartSymbol = null;
    });
    try {
      final response = await http.post(
        Uri.parse('$hfSpaceUrl/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': userText, 'is_agent': _isAgentActive}),
      ).timeout(const Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        
        setState(() {
          _response = data['text'] ?? "";
          _chartSymbol = data['chart_symbol'];
          _chartInterval = data['interval'] ?? "60";
          
          if (_chartSymbol != null && kIsWeb) {
            final String viewID = "tv-chart-${DateTime.now().millisecondsSinceEpoch}";
            final String raw = data['indicators'] ?? "BB@tv-basicstudies|SuperTrend@tv-basicstudies|PivotPointsStandard@tv-basicstudies";
            final List<Map<String, String>> studiesList = raw.split('|').map((id) => {
              "symbol": _chartSymbol!,
              "id": id
            }).toList();
            
            final String indicators = jsonEncode(studiesList);
            final bool showTools = data['show_tools'] ?? false;
            
            final String url = "https://s.tradingview.com/widgetembed/?symbol=$_chartSymbol"
                "&interval=$_chartInterval"
                "&theme=dark"
                "&style=1"
                "&studies=${Uri.encodeComponent(indicators)}"
                "&hide_side_toolbar=${showTools ? '0' : '1'}"
                "&details=true"
                "&withdateranges=true"
                "&show_popup_button=true"
                "&locale=pt_BR";
                
            registerChartWeb(viewID, url);
            _chartInterval = viewID;
          }
          if (data['audio'] != null) { _playVoice(data['audio']); }
        });
      }
    } catch (e) { setState(() => _response = "Erro de conexão!"); } 
    finally { setState(() { _isLoading = false; }); }
  }

  Future<void> _connectWallet() async { if (kIsWeb) { await _connectMetamask(); } else { await _connectMobileWallet(); } }
  Future<void> _connectMetamask() async { try { final String? address = await connectMetamaskLogic(); if (address != null) { setState(() { _walletAddress = address; _response = "Metamask conectada!"; }); } } catch (e) { setState(() => _response = "Erro Metamask."); } }
  Future<void> _connectMobileWallet() async { try { final session = await LocalAssociationScenario.create(); final client = await session.start(); final result = await client.authorize(identityUri: Uri.parse('https://terlinet.github.io/terlinet/'), identityName: 'TerlineT', cluster: 'mainnet-beta'); if (result != null) { setState(() { _walletAddress = base58encode(result.publicKey.toList()); }); } await session.close(); } catch (e) { setState(() => _response = "Erro Mobile Wallet."); } }
  Future<void> _launchBubbles() async { final Uri url = Uri.parse(bubblesUrl); if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); } }
  String base58encode(List<int> bytes) { const String alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'; var x = BigInt.zero; for (var byte in bytes) { x = x * BigInt.from(256) + BigInt.from(byte); } var res = ''; while (x > BigInt.zero) { var mod = x % BigInt.from(58); res = alphabet[mod.toInt()] + res; x = x ~/ BigInt.from(58); } return res; }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/peruibe2.jpeg'), fit: BoxFit.cover))),
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
                            _buildHeader(),
                            const SizedBox(height: 60),
                            _buildChatInput(),
                            const SizedBox(height: 30),
                            _buildResponseArea(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                      Positioned(top: 20, right: 10, child: _buildWalletBubble()),
                      Positioned(top: 20, left: 10, child: _buildBubblesBubble()),
                      Positioned(
                        bottom: 120,
                        right: 30,
                        child: VirtualBeeAgent(
                          isActive: _isAgentActive,
                          onTap: () {
                            setState(() {
                              _isAgentActive = !_isAgentActive;
                              if (!_isAgentActive) {
                                // Interrompe tudo imediatamente ao desativar
                                _audioPlayer.stop();
                                _isLoading = false;
                                _response = "Bee retornando à colmeia. Modo Agente Desativado.";
                              } else {
                                _response = "Modo Agente Ativado. O Bee está pronto para analisar.";
                              }
                              _chartSymbol = null;
                            });
                          },
                        ),
                      ),

                      if (_isLoading) _buildSwarmOverlay(),
                      if (_chartSymbol != null) _buildChartOverlay(),

                      Positioned(
                        bottom: 30,
                        right: 20,
                        child: FloatingActionButton(
                          mini: true,
                          onPressed: () => setState(() => _isMuted = !_isMuted),
                          backgroundColor: Colors.white10,
                          child: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwarmOverlay() {
    return AnimatedBuilder(
      animation: _swarmController,
      builder: (context, child) {
        return CustomPaint(
          painter: SwarmPainter(_swarmParticles, _swarmController.value, _isAgentActive),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildChartOverlay() {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent, width: 2),
          boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 20)]
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("BEE TERMINAL: $_chartSymbol", style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => setState(() => _chartSymbol = null),
                  )
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                child: HtmlElementView(viewType: _chartInterval!), // O viewID está guardado aqui
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() { return Center(child: Stack(alignment: Alignment.center, children: [AnimatedBuilder(animation: _murmurationController, builder: (context, child) => CustomPaint(painter: MurmurationPainter(_flocks, _murmurationController.value), size: const Size(400, 400))), const Row(mainAxisSize: MainAxisSize.min, children: [Text('T', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w200, color: Colors.white)), SizedBox(width: 15), Text('E R L I N E', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w200, letterSpacing: 6, color: Colors.white)), SizedBox(width: 15), Text('T', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w200, color: Colors.white))])])); }
  
  Widget _buildChatInput() { 
    final Color borderColor = _isAgentActive ? Colors.redAccent : Colors.white.withOpacity(0.15);
    return ClipRRect(
      borderRadius: BorderRadius.circular(30), 
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12), 
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 24), 
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(30), border: Border.all(color: borderColor, width: _isAgentActive ? 2 : 1)), 
          child: TextField(
            controller: _controller, 
            style: const TextStyle(color: Colors.white, fontSize: 18), 
            decoration: InputDecoration(
              hintText: _isAgentActive ? 'Comandando Bee...' : 'O que deseja saber?', 
              hintStyle: TextStyle(color: _isAgentActive ? Colors.redAccent.withOpacity(0.5) : Colors.white.withOpacity(0.5)), 
              border: InputBorder.none, 
              prefixIcon: IconButton(icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.redAccent : Colors.white), onPressed: _listen),
              suffixIcon: IconButton(icon: Icon(_isLoading ? Icons.hourglass_top : (_isAgentActive ? Icons.bolt : Icons.send_rounded), color: _isAgentActive ? Colors.redAccent : Colors.white), onPressed: _sendQuery),
            ), 
            onSubmitted: (_) => _sendQuery()
          )
        )
      )
    ); 
  }

  Widget _buildResponseArea() { if (_response.isEmpty) return const SizedBox.shrink(); return ClipRRect(borderRadius: BorderRadius.circular(24), child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.1))), child: SelectableText(_response, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, color: Colors.white, height: 1.6, fontWeight: FontWeight.w300))))); }
  Widget _buildWalletBubble() { return GestureDetector(onTap: _connectWallet, child: _buildBubble(label: 'Wallet', content: _walletAddress == null ? "🦊" : "${_walletAddress!.substring(0, 4)}..${_walletAddress!.substring(_walletAddress!.length - 4)}", contentSize: _walletAddress == null ? 32 : 11)); }
  Widget _buildBubblesBubble() { return GestureDetector(onTap: _launchBubbles, child: _buildBubble(label: 'Bubbles', content: "🫧", contentSize: 32)); }
  Widget _buildFooter() { return Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20), color: Colors.black.withOpacity(0.3), child: const Column(children: [Text('TerlineT • Conectando pessoas e informações desde 2001', style: TextStyle(color: Colors.white70, fontSize: 12)), SizedBox(height: 4), Text('bubblescoinmaster@gmail.com', style: TextStyle(color: Colors.white38, fontSize: 11))])); }
  Widget _buildBubble({required String label, required String content, required double contentSize}) { return AnimatedBuilder(animation: _bubbleController, builder: (context, child) => Container(margin: EdgeInsets.only(top: _bubbleController.value * 20), child: SizedBox(width: 150, height: 150, child: Stack(alignment: Alignment.center, children: [Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.white.withOpacity(0.05), Colors.blue.withOpacity(0.1), Colors.purple.withOpacity(0.2), Colors.pink.withOpacity(0.2), Colors.cyan.withOpacity(0.3), Colors.transparent], stops: const [0.0, 0.4, 0.7, 0.85, 0.95, 1.0], center: const Alignment(-0.2, -0.2)), border: Border.all(color: Colors.white.withOpacity(0.4), width: 0.8), boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)]), child: Stack(children: [_buildPositionPoint(top: 15, left: 25, size: 15, opacity: 0.6), _buildPositionPoint(bottom: 15, right: 20, size: 8, opacity: 0.3), Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(content, textAlign: TextAlign.center, style: TextStyle(fontSize: contentSize, color: Colors.white, fontWeight: FontWeight.w500, shadows: const [Shadow(color: Colors.black26, blurRadius: 2)]))))])), AnimatedBuilder(animation: _murmurationController, builder: (context, child) { final angle = _murmurationController.value * 2 * math.pi; return Transform.translate(offset: Offset(math.cos(angle) * 68.0, math.sin(angle) * 68.0), child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 4), Shadow(color: Colors.cyanAccent, blurRadius: 1)]))); })])))); }
  Widget _buildPositionPoint({double? top, double? left, double? right, double? bottom, required double size, required double opacity}) { return Positioned(top: top, left: left, right: right, bottom: bottom, child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(opacity), boxShadow: [BoxShadow(color: Colors.white.withOpacity(opacity), blurRadius: 10, spreadRadius: 2)]))); }
}

class MyCustomSource extends StreamAudioSource {
  final Uint8List bytes;
  MyCustomSource(this.bytes);
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0; end ??= bytes.length;
    return StreamAudioResponse(sourceLength: bytes.length, contentLength: end - start, offset: start, stream: Stream.value(bytes.sublist(start, end)), contentType: 'audio/mpeg');
  }
}

class BeeParticle {
  late double startSide; // 0 for left, 1 for right
  late double startY;
  late double orbitRadius;
  late double speed;
  late double phase;
  late double scale;

  BeeParticle() {
    final rand = math.Random();
    startSide = rand.nextBool() ? 0 : 1;
    startY = rand.nextDouble();
    orbitRadius = 40 + rand.nextDouble() * 100;
    speed = 1.0 + rand.nextDouble() * 2.0;
    phase = rand.nextDouble() * 2 * math.pi;
    scale = 0.4 + rand.nextDouble() * 0.4;
  }
}

class SwarmPainter extends CustomPainter {
  final List<BeeParticle> particles;
  final double value; // animation value 0.0 to 1.0
  final bool isAgent;
  SwarmPainter(this.particles, this.value, this.isAgent);

  @override
  void paint(Canvas canvas, Size size) {
    // Posição central do Bee Agent (bottom: 120, right: 30)
    final beeCenter = Offset(size.width - 70, size.height - 160);

    for (var p in particles) {
      // Posição inicial fora da tela
      final startX = p.startSide == 0 ? -100.0 : size.width + 100.0;
      final startY = p.startY * size.height;
      final startPos = Offset(startX, startY);

      // Progresso da entrada lateral: assume que nos primeiros 30% da animação elas voam para o Bee
      double entryProgress = (value * 3.33).clamp(0.0, 1.0);
      
      // Órbita circular ao redor do Bee
      final angle = (value * 2 * math.pi * p.speed) + p.phase;
      final orbitPos = beeCenter + Offset(math.cos(angle) * p.orbitRadius, math.sin(angle) * p.orbitRadius);

      // Interpolação entre o ponto de entrada e a órbita
      final currentPos = Offset.lerp(startPos, orbitPos, entryProgress)!;

      _drawMiniBee(canvas, currentPos, p.scale, isAgent, angle);
    }
  }

  void _drawMiniBee(Canvas canvas, Offset center, double scale, bool isActive, double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle + math.pi/2); // Gira para "olhar" na direção do voo
    canvas.scale(scale);

    final baseColor = isActive ? Colors.redAccent : Colors.yellowAccent;
    final secondaryColor = isActive ? Colors.red.shade900 : Colors.orange.shade800;

    // Asas animadas
    final wingFlap = math.sin(value * 50) * 0.4;
    final wingPaint = Paint()..color = (isActive ? Colors.redAccent : Colors.white).withOpacity(0.4)..style = PaintingStyle.fill;
    
    // Asa esquerda
    canvas.save();
    canvas.rotate(wingFlap - 0.5);
    canvas.drawOval(Rect.fromLTWH(-20, -10, 20, 10), wingPaint);
    canvas.restore();
    
    // Asa direita
    canvas.save();
    canvas.rotate(-wingFlap + 0.5);
    canvas.drawOval(Rect.fromLTWH(0, -10, 20, 10), wingPaint);
    canvas.restore();

    // Corpo listrado
    final bodyPaint = Paint()..shader = ui.Gradient.radial(
      Offset.zero, 15,
      [baseColor, secondaryColor, Colors.black],
      const [0.3, 0.7, 1.0],
    );

    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 28, height: 22), bodyPaint);
    
    final stripePaint = Paint()..color = Colors.black.withOpacity(0.8)..style = PaintingStyle.stroke..strokeWidth = 3;
    canvas.drawArc(Rect.fromCenter(center: Offset.zero, width: 28, height: 22), 0.5, 2.2, false, stripePaint);
    canvas.drawArc(Rect.fromCenter(center: Offset.zero, width: 28, height: 22), 3.5, 2.2, false, stripePaint);

    canvas.restore();
  }

  @override bool shouldRepaint(covariant SwarmPainter oldDelegate) => true;
}

class VirtualBeeAgent extends StatefulWidget {
  final VoidCallback onTap;
  final bool isActive;
  const VirtualBeeAgent({super.key, required this.onTap, this.isActive = false});
  @override State<VirtualBeeAgent> createState() => _VirtualBeeAgentState();
}

class _VirtualBeeAgentState extends State<VirtualBeeAgent> with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _wingController;
  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _wingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 50))..repeat(reverse: true);
  }
  @override
  void dispose() { _hoverController.dispose(); _wingController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_hoverController, _wingController]),
        builder: (context, child) {
          final t = _hoverController.value * 2 * math.pi;
          final dx = math.sin(t) * 15;
          final dy = math.sin(2 * t) * 10;
          final tilt = math.cos(t) * 0.15;
          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: tilt,
              child: SizedBox(width: 80, height: 80, child: CustomPaint(painter: BeePainter(wingValue: _wingController.value, isActive: widget.isActive))),
            ),
          );
        },
      ),
    );
  }
}

class BeePainter extends CustomPainter {
  final double wingValue;
  final bool isActive;
  BeePainter({required this.wingValue, this.isActive = false});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final wingPaint = Paint()..color = (isActive ? Colors.redAccent : Colors.cyanAccent).withOpacity(0.3)..style = PaintingStyle.fill..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    void drawWing(double angle, bool left) {
      canvas.save(); canvas.translate(center.dx, center.dy - 5); canvas.rotate(angle + (left ? -wingValue * 0.6 : wingValue * 0.6));
      canvas.drawOval(Rect.fromCenter(center: Offset(left ? -20 : 20, -10), width: 30, height: 10), wingPaint);
      canvas.restore();
    }
    drawWing(-0.5, true); drawWing(0.5, false);
    final bodyPaint = Paint()..shader = ui.Gradient.radial(center, 20, [isActive ? Colors.redAccent : Colors.yellowAccent, isActive ? Colors.red.shade900 : Colors.orange.shade700, Colors.black], const [0.2, 0.7, 1.0]);
    if (isActive) { canvas.drawCircle(center, 20, Paint()..color = Colors.redAccent.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)); }
    canvas.drawOval(Rect.fromCenter(center: center, width: 35, height: 28), bodyPaint);
    final stripePaint = Paint()..color = Colors.black.withOpacity(0.8)..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCenter(center: center, width: 35, height: 28), 0.5, 2.0, false, stripePaint);
    canvas.drawArc(Rect.fromCenter(center: center, width: 35, height: 28), 3.5, 2.0, false, stripePaint);
    final eyePaint = Paint()..color = Colors.black;
    final sensorPaint = Paint()..color = isActive ? Colors.redAccent : Colors.cyanAccent..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(center.dx + 10, center.dy - 4), 4, eyePaint);
    canvas.drawCircle(Offset(center.dx + 11, center.dy - 4), 1.5, sensorPaint);
    final antPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1;
    final path = Path(); path.moveTo(center.dx + 5, center.dy - 12); path.quadraticBezierTo(center.dx + 12, center.dy - 22, center.dx + 18, center.dy - 18);
    canvas.drawPath(path, antPaint); canvas.drawCircle(Offset(center.dx + 18, center.dy - 18), 1.2, sensorPaint);
  }
  @override bool shouldRepaint(BeePainter oldDelegate) => true;
}

class BirdFlock { final int id; late List<Offset> offsets; late double speedFactor; late double radiusFactor; late double phase; BirdFlock(this.id) { final random = math.Random(); speedFactor = 0.5 + random.nextDouble(); radiusFactor = 0.8 + random.nextDouble() * 0.5; phase = random.nextDouble() * math.pi * 2; offsets = List.generate(15 + random.nextInt(15), (index) => Offset((random.nextDouble() - 0.5) * 40, (random.nextDouble() - 0.5) * 40)); } }
class MurmurationPainter extends CustomPainter { final List<BirdFlock> flocks; final double animationValue; MurmurationPainter(this.flocks, this.animationValue); @override void paint(Canvas canvas, Size size) { final center = Offset(size.width / 2, size.height / 2); final t = animationValue * math.pi * 2; for (var flock in flocks) { double xBase = math.sin(t * flock.speedFactor + flock.phase) * (140 * flock.radiusFactor); double yBase = math.cos(t * 0.7 * flock.speedFactor + flock.phase * 0.5) * (100 * flock.radiusFactor); Offset flockCenter = center + Offset(xBase, yBase); for (int i = 0; i < flock.offsets.length; i++) { double birdT = t * 2 + i * 0.2; Offset pos = flockCenter + flock.offsets[i] + Offset(math.sin(birdT + flock.phase) * 12, math.cos(birdT * 0.8 + i) * 12); canvas.drawCircle(pos, 1.2, Paint()..color = Colors.white.withOpacity(0.3 + (math.sin(birdT).abs() * 0.4))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5)); } } } @override bool shouldRepaint(covariant MurmurationPainter oldDelegate) => true; }
