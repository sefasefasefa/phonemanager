import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const TunnelScreen(),
    );
  }
}

class TunnelScreen extends StatefulWidget {
  const TunnelScreen({super.key});

  @override
  _TunnelScreenState createState() => _TunnelScreenState();
}

class _TunnelScreenState extends State<TunnelScreen> {
  Socket? _socket;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isConnected = false;
  bool _isToggled = false;
  String _log = "Ham TCP Tüneli başlatılmaya hazır...\n";
  Timer? _pingTimer;

  // VDS IP ve Ham TCP Portu (Sıfır Protokol Kısıtı)
  final String _serverIp = "185.254.28.39";
  final int _serverPort = 3001;

  void _startBackgroundAudio() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0.01);
      await _audioPlayer.play(
        UrlSource(
          'https://actions.google.com/sounds/v1/alarms/digital_watch_alarm_long.ogg',
        ),
      );
      _writeLog("Arka plan koruma motoru (Audio) ateşlendi.");
    } catch (e) {
      _writeLog("Ses motoru hatası: $e");
    }
  }

  void _stopBackgroundAudio() async {
    await _audioPlayer.stop();
    _writeLog("Arka plan koruma motoru durduruldu.");
  }

  void _connectTcpSocket() async {
    if (!_isToggled) return;

    try {
      _writeLog("TCP Sunucusuna bağlanılıyor: $_serverIp:$_serverPort");

      _socket = await Socket.connect(
        _serverIp,
        _serverPort,
        timeout: const Duration(seconds: 5),
      );

      setState(() {
        _isConnected = true;
      });
      _writeLog(
        "Ham TCP Tüneli açıldı! Operatör yuvarlama cezası engelleniyor.",
      );

      // Gelen Ham Veri Akışını Dinleme (Yankı/Echo Takibi)
      _socket!.listen(
        (List<int> data) {
          // Gelen ham veriyi stringe çevirip logluyoruz
          final response = String.fromCharCodes(data).trim();
          _writeLog("Sunucudan Gelen Yankı: $response");
        },
        onError: (error) {
          _writeLog("Tünel hatası: $error");
          _handleDisconnect();
        },
        onDone: () {
          _writeLog("Bağlantı sunucu veya şebeke tarafından kapatıldı.");
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      // Tasarrufun Kalbi: Her 8 saniyede bir sadece 1 baytlık veri ('1') fırlat
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
        if (_isConnected && _isToggled && _socket != null) {
          _socket!.write('1'); // Sadece 1 karakter = 1 Bayt
          _writeLog("Mikro veri fırlatıldı (1 Bayt)");
        }
      });
    } catch (e) {
      _writeLog("Bağlantı kurulamadı: $e");
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    setState(() {
      _isConnected = false;
    });
    _pingTimer?.cancel();
    _socket?.destroy();
    _socket = null;

    if (_isToggled) {
      _writeLog(
        "5 saniye içinde otomatik yeniden bağlanma deneniyor (Auto-Reconnect)...",
      );
      Timer(const Duration(seconds: 5), () {
        if (_isToggled && !_isConnected) {
          _connectTcpSocket();
        }
      });
    }
  }

  // İstediğin an manuel olarak tüneli test etmek için 1 baytlık veri gönderme fonksiyonu
  void _sendMicroData() {
    if (_isConnected && _socket != null) {
      _socket!.write('1');
      _writeLog("Manuel Mikro Veri Sıkıştırıldı (1 Bayt)");
    } else {
      _writeLog("Hata: Önce tüneli başlatmalısın.");
    }
  }

  void _writeLog(String message) {
    if (!mounted) return;
    setState(() {
      _log +=
          "[${DateTime.now().toString().split(' ')[1].substring(0, 8)}] $message\n";
    });
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _audioPlayer.dispose();
    _socket?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mobil Veri Tünel Terminali')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Durum Göstergesi
            Card(
              color: _isConnected
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.2),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isConnected ? Icons.gpp_good : Icons.gpp_bad,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isConnected
                          ? "HÜCRESEL TÜNEL AKTİF (KORUMADA)"
                          : "TÜNEL KAPALI (YUVARLAMA RİSKİ)",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            // Canlı Log Ekranı
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    _log,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            // Kontrol Butonları
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isToggled ? Colors.red : Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      setState(() {
                        _isToggled = !_isToggled;
                      });
                      if (_isToggled) {
                        _startBackgroundAudio();
                        _connectTcpSocket();
                      } else {
                        _stopBackgroundAudio();
                        _isToggled = false;
                        _handleDisconnect();
                        _writeLog("Kullanıcı tüneli durdurdu.");
                      }
                    },
                    child: Text(
                      _isToggled ? "Tüneli Kapat" : "Sürekli Hat Başlat",
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: _isConnected ? _sendMicroData : null,
                    child: const Text("Mikro Veri Sıkıştır"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
