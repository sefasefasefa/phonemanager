import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
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
      theme: ThemeData.dark(), // Terminal havası için dark tema
      home: const TunnelScreen(),
    );
  }
}

class TunnelScreen extends StatefulWidget {
  const TunnelScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _TunnelScreenState createState() => _TunnelScreenState();
}

class _TunnelScreenState extends State<TunnelScreen> {
  IOWebSocketChannel? _channel;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isConnected = false;
  bool _isToggled = false;
  String _log = "Tünel başlatılmaya hazır...\n";
  Timer? _pingTimer;

  // BURAYA KENDİ VDS IP ADRESİNİ VE PORTUNU YAZACAKSIN
  final String _serverUrl = "ws://185.254.28.39:3001";

  // Arka planı aldatmak için sessiz ses döngüsünü başlatır
  // İnternetten 1 saniyelik tamamen sessiz bir mp3 linki verilmiştir
  void _startBackgroundAudio() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0.01); // Sesi tamamen kısığa yakın yapıyoruz
      await _audioPlayer.play(
        UrlSource(
          'https://actions.google.com/sounds/v1/alarms/digital_watch_alarm_long.ogg',
        ),
      ); // Örnek kaynak, buraya sessiz bir ses koyulmalı
      _writeLog("Arka plan koruma motoru (Audio) ateşlendi.");
    } catch (e) {
      _writeLog("Ses motoru hatası: $e");
    }
  }

  void _stopBackgroundAudio() async {
    await _audioPlayer.stop();
    _writeLog("Arka plan koruma motoru durduruldu.");
  }

  void _connectWebSocket() {
    if (!_isToggled) return; // Kullanıcı tüneli kapattıysa zorla bağlanma

    try {
      _writeLog("Sunucuya bağlanılıyor: $_serverUrl");
      _channel = IOWebSocketChannel.connect(Uri.parse(_serverUrl));

      setState(() {
        _isConnected = true;
      });
      _writeLog("Tünel açıldı! Operatör yuvarlama cezası engelleniyor.");

      // Gelen Veri Akışını Dinleme
      _channel!.stream.listen(
        (message) {
          _writeLog("Sunucudan Gelen Yanıt: $message");
        },
        onError: (error) {
          _writeLog("Bağlantı hatası: $error");
          _handleDisconnect();
        },
        onDone: () {
          _writeLog("Bağlantı sunucu veya şebeke tarafından kapatıldı.");
          _handleDisconnect();
        },
      );

      // Heartbeat: 30 Saniyede Bir Operatör Hattı Kapatmasın Diye Ping Gönder
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (_isConnected && _isToggled) {
          final pingPayload = jsonEncode({
            "type": "ping",
            "timestamp": DateTime.now().millisecondsSinceEpoch,
          });
          _channel!.sink.add(pingPayload);
          _writeLog("Canlılık sinyali (1 KB altı ping) gönderildi.");
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

    if (_isToggled) {
      _writeLog(
        "5 saniye içinde otomatik yeniden bağlanma deneniyor (Auto-Reconnect)...",
      );
      Timer(const Duration(seconds: 5), () {
        if (_isToggled && !_isConnected) {
          _connectWebSocket();
        }
      });
    }
  }

  // İstediğin an manuel olarak 1 KB altı veri gönderme fonksiyonu
  void _sendMicroData() {
    if (_isConnected && _channel != null) {
      final data = jsonEncode({
        "action": "data_stream",
        "payload": "Hizli_Veri_Paketi",
      });
      _channel!.sink.add(data);
      _writeLog("Mikro Veri Gönderildi: $data");
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
    _channel?.sink.close();
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
                  reverse: true, // Log eklendikçe otomatik aşağı kaydırır
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
                        _connectWebSocket();
                      } else {
                        _stopBackgroundAudio();
                        _channel?.sink.close();
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
