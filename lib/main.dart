import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InstantSOSApp());
}

class InstantSOSApp extends StatelessWidget {
  const InstantSOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Instant SOS',
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      home: const SOSHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SOSHomePage extends StatefulWidget {
  const SOSHomePage({super.key});

  @override
  State<SOSHomePage> createState() => _SOSHomePageState();
}

class _SOSHomePageState extends State<SOSHomePage> {
  static const platform = MethodChannel('com.example.sos/emergency');

  final String pusherAppId = "2176890";
  final String pusherKey = "163dad2d478fe38aa1cf";
  final String pusherSecret = "81ae586cffe7bf12c117";
  final String pusherCluster = "eu";

  String username = "";
  bool isAccessibilityGranted = false;
  final TextEditingController _nameController = TextEditingController();
  bool isAlarmTriggered = false;

  @override
  void initState() {
    super.initState();
    _initUser();
    _checkPermissions();
    _initPusher();
    _listenToNativeTriggers();
  }

  // الاستماع للإشارات القادمة من Kotlin (عند ضغط زر الصوت 5 مرات والشاشة مغلقة)
  void _listenToNativeTriggers() {
    platform.setMethodCallHandler((call) async {
      if (call.method == "triggerSOS") {
        if (!isAlarmTriggered) _sendSOS();
      }
    });
  }

  Future<void> _initUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? "";
      _nameController.text = username;
    });
  }

  Future<void> _saveUsername(String name) async {
    if (name.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', name.trim());
    setState(() => username = name.trim());
  }

  Future<void> _checkPermissions() async {
    bool granted = await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
    bool locationGranted = await Geolocator.checkPermission() == LocationPermission.always || await Geolocator.checkPermission() == LocationPermission.whileInUse;
    if (!locationGranted) {
      await Geolocator.requestPermission();
    }
    setState(() => isAccessibilityGranted = granted);
  }

  Future<void> _requestPermission() async {
    await FlutterAccessibilityService.requestAccessibilityPermission();
    _checkPermissions();
  }

  Future<void> _sendSOS() async {
    if (username.isEmpty) return;
    setState(() { isAlarmTriggered = true; });

    try {
      // جلب البطارية والموقع
      int batteryLevel = await Battery().batteryLevel;
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      String mapsLink = "[https://maps.google.com/?q=$](https://maps.google.com/?q=$){position.latitude},${position.longitude}";

      String messageDetails = "حالة طوارئ!\nالمستخدم: $username بخطر ويحتاج مساعدة فورية!\nالبطارية: $batteryLevel\%\nالموقع: $mapsLink";

      String eventData = jsonEncode({
        "message": messageDetails,
        "sender": username
      });

      String body = jsonEncode({
        "name": "sos-alert",
        "channels": ["sos-channel"],
        "data": eventData
      });

      String bodyMd5 = md5.convert(utf8.encode(body)).toString();
      String timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      String queryParams = "auth_key=$pusherKey&auth_timestamp=$timestamp&auth_version=1.0&body_md5=$bodyMd5";
      String path = "/apps/$pusherAppId/events";
      String stringToSign = "POST\\n$path\\n$queryParams";
      String signature = Hmac(sha256, utf8.encode(pusherSecret)).convert(utf8.encode(stringToSign)).toString();

      String url = "https://api-$pusherCluster.pusher.com$path?$queryParams&auth_signature=$signature";

      await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: body,
      );
    } catch (e) {
      print("خطأ: $e");
    }

    Future.delayed(const Duration(seconds: 5), () {
      setState(() { isAlarmTriggered = false; });
    });
  }

  Future<void> _initPusher() async {
    final pusher = PusherChannelsFlutter.getInstance();
    try {
      await pusher.init(
        apiKey: pusherKey,
        cluster: pusherCluster,
        onEvent: _onPusherEvent,
      );
      await pusher.subscribe(channelName: "sos-channel");
      await pusher.connect();
    } catch (e) {}
  }

  void _onPusherEvent(PusherEvent event) {
    if (event.eventName == "sos-alert") {
      final data = jsonDecode(event.data.toString());
      if (data['sender'] != username) {
        // تشغيل الشاشة الحمراء مع الصوت العالي من الجانب الأصلي (Kotlin)
        platform.invokeMethod('showEmergencyScreen', {"message": data['message']});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instant SOS'), backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'اسم المستخدم',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: const Icon(Icons.save), onPressed: () => _saveUsername(_nameController.text)),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.all(20)),
              onPressed: _sendSOS,
              child: const Text('اختبار إرسال استغاثة', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 20),
            if (!isAccessibilityGranted)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                icon: const Icon(Icons.settings),
                label: const Text('تفعيل صلاحية الأزرار'),
                onPressed: _requestPermission,
              ),
          ],
        ),
      ),
    );
  }
}
