import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bluetooth_serial_next/bluetooth_serial_next.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ───────── Commands (must match the Arduino sketch) ─────────
const kStart = 'start';
const kAccOn = 'acc';
const kAccOff = 'acc off';
const kCutoff = ['1', '2', '3'];
const kCutoffStop = '0';
const kArabi = ['4', '5', '6'];
const kArabiStop = 'a0';
String cutoffCustom(int on, int off) => '#$on,$off';
String arCustom(int on, int off) => 'ar$on,$off';
String alCustom(int on, int off) => 'al$on,$off';

// ───────── Theme ─────────
const cBg = Color(0xFF04060F);
const cPanel = Color(0xFF0B1226);
const cLine = Color(0xFF1D3B8F);
const cCy = Color(0xFF19E3FF);
const cVi = Color(0xFF8B5CF6);
const cGr = Color(0xFF2DFF8A);
const cRd = Color(0xFFFF4A5E);
const cMu = Color(0xFF7F93B8);

const _s = {
  'fa': {
    'pick': 'انتخاب دستگاه بلوتوث',
    'connect': 'اتصال',
    'connecting': 'در حال اتصال به HC-05…',
    'okMsg': 'اتصال با موفقیت انجام شد',
    'lost': 'اتصال قطع شد!',
    'retryHint': 'برای اتصال مجدد روی دکمه بزنید',
    'retry': 'اتصال مجدد',
    'custom': 'تنظیم ریتم دلخواه',
    'channel': 'انتخاب کانال:',
    'onT': 'زمان روشن (ms):',
    'offT': 'زمان خاموش (ms):',
    'save': 'ذخیره و ارسال',
    'send': 'ارسال',
    'sendBoth': 'ارسال هر دو',
    'notConn': 'ابتدا به HC-05 وصل شوید',
    'noDev':
        'دستگاهی جفت‌شده نیست. ابتدا HC-05 را در تنظیمات بلوتوث گوشی جفت کنید (رمز: 1234 یا 0000).',
    'refresh': 'بروزرسانی',
    'err': 'اتصال برقرار نشد',
    'perm': 'دسترسی بلوتوث داده نشد',
    'viewAll': 'همه رویدادها',
    'noTag': 'NFC هنوز اسکن نشده',
    'allowed': 'مجاز',
    'denied': 'رد شد',
    'evAccOn': 'ACC روشن شد',
    'evAccOff': 'ACC خاموش شد',
    'evStart': 'استارت زده شد',
    'evRun': 'فعال',
    'evStop': 'متوقف شد',
    'evTagOk': 'NFC مجاز',
    'evTagNo': 'NFC نامعتبر',
    'evErr': 'فرمان نامفهوم',
    'noEv': 'هنوز رویدادی دریافت نشده',
    'noEvSub': 'وقتی آردوینو پیامی بفرستد، اینجا نشان داده می‌شود.',
    'settings': 'تنظیمات',
    'language': 'زبان',
    'rpmSec': 'نمایش RPM',
    'mNeedle': 'عقربه‌ای',
    'mLinear': 'خطی',
    'mDigital': 'عددی',
    'maxRpm': 'حداکثر RPM',
    'redline': 'ناحیه‌ی قرمز (Redline)',
    'teeth': 'دندانه‌ی چرخ سنسور',
    'rhythmSec': 'ریتم',
  },
  'en': {
    'pick': 'Choose Bluetooth device',
    'connect': 'Connect',
    'connecting': 'Connecting to HC-05…',
    'okMsg': 'Connected successfully',
    'lost': 'Connection lost!',
    'retryHint': 'Tap to reconnect',
    'retry': 'Reconnect',
    'custom': 'Custom rhythm',
    'channel': 'Channel:',
    'onT': 'On time (ms):',
    'offT': 'Off time (ms):',
    'save': 'Save & send',
    'send': 'Send',
    'sendBoth': 'Send both',
    'notConn': 'Connect to HC-05 first',
    'noDev':
        'No paired device. Pair HC-05 in the phone Bluetooth settings first (PIN: 1234 or 0000).',
    'refresh': 'Refresh',
    'err': 'Could not connect',
    'perm': 'Bluetooth permission denied',
    'viewAll': 'All events',
    'noTag': 'No NFC scanned yet',
    'allowed': 'ALLOWED',
    'denied': 'DENIED',
    'evAccOn': 'ACC turned on',
    'evAccOff': 'ACC turned off',
    'evStart': 'START fired',
    'evRun': 'running',
    'evStop': 'stopped',
    'evTagOk': 'Allowed NFC',
    'evTagNo': 'Unknown NFC',
    'evErr': 'Not understood',
    'noEv': 'No events yet',
    'noEvSub': 'Messages from the Arduino will show up here.',
    'settings': 'Settings',
    'language': 'Language',
    'rpmSec': 'RPM display',
    'mNeedle': 'Needle',
    'mLinear': 'Linear',
    'mDigital': 'Digital',
    'maxRpm': 'Max RPM',
    'redline': 'Redline',
    'teeth': 'Sensor wheel teeth',
    'rhythmSec': 'Rhythm',
  },
};

// ───────── App state & Bluetooth link ─────────
class FbEvent {
  final DateTime t = DateTime.now();
  final String kind;
  final String data;
  FbEvent(this.kind, this.data);
}

class Ctl {
  static final lang = ValueNotifier<String>('fa');
  static final messenger = GlobalKey<ScaffoldMessengerState>();
  static final connected = ValueNotifier<bool>(false);
  static final acc = ValueNotifier<bool?>(null);
  // feedback coming back from the Arduino
  static final events = ValueNotifier<List<FbEvent>>([]);
  static final lastTag = ValueNotifier<FbEvent?>(null);
  static final seq = ValueNotifier<int>(0);
  static final rpm = ValueNotifier<double>(0);
  static final nfcFlash = ValueNotifier<int>(0); // 0 idle, 1 allowed, 2 denied
  static final rpmMode = ValueNotifier<int>(0); // 0 needle, 1 linear, 2 digital
  static final rpmStyle = ValueNotifier<int>(0);
  static final rpmMax = ValueNotifier<int>(12000);
  static final rpmRed = ValueNotifier<int>(10000);
  static final rpmTeeth = ValueNotifier<int>(8);
  static Timer? _rpmT, _nfcT;

  static void loadPrefs(SharedPreferences p) {
    void bind(String k, ValueNotifier<int> n) {
      n.value = p.getInt(k) ?? n.value;
      n.addListener(() => p.setInt(k, n.value));
    }

    bind('rpmMode', rpmMode);
    bind('rpmStyle', rpmStyle);
    bind('rpmMax', rpmMax);
    bind('rpmRed', rpmRed);
    bind('rpmTeeth', rpmTeeth);
  }
  static final outs = ValueNotifier<Map<String, String>>(_zero());
  static Timer? _seqT;
  static String _buf = '';

  static Map<String, String> _zero() =>
      {'ACC': '0', 'START': '0', 'CUT': '0', 'AR': '0', 'AL': '0'};

  static void _setOut(String k, String v) => outs.value = {...outs.value, k: v};

  // mirrors the preset rhythms in the Arduino sketch (on ms, off ms) - the real values
  // coming back from the Arduino (EV:...) always replace these
  static const _cutP = [[100, 100], [200, 200], [400, 400]];
  static const _arP = [[150, 150], [0, 0], [150, 150]];
  static const _alP = [[0, 0], [150, 150], [150, 150]];
  static String _fmt(List<int> p) => p[0] == 0 ? '0' : '${p[0]},${p[1]}';

  static void _optimistic(String c) {
    final x = c.trim().toLowerCase();
    if (x == 'acc') {
      _setOut('ACC', '1');
    } else if (x == 'acc off') {
      _setOut('ACC', '0');
    } else if (x == 'start') {
      _setOut('START', '1');
      Timer(const Duration(milliseconds: 550), () => _setOut('START', '0'));
    } else if (x == '0') {
      _setOut('CUT', '0');
    } else if (x == 'a0') {
      _setOut('AR', '0');
      _setOut('AL', '0');
    } else if (x == '1' || x == '2' || x == '3') {
      _setOut('CUT', _fmt(_cutP[int.parse(x) - 1]));
    } else if (x == '4' || x == '5' || x == '6') {
      final i = int.parse(x) - 4;
      _setOut('AR', _fmt(_arP[i]));
      _setOut('AL', _fmt(_alP[i]));
    } else if (x.startsWith('#')) {
      _setOut('CUT', x.substring(1));
    } else if (x.startsWith('ar')) {
      _setOut('AR', x.substring(2));
    } else if (x.startsWith('al')) {
      _setOut('AL', x.substring(2));
    }
  }

  static void _add(FbEvent e) {
    final l = [e, ...events.value];
    if (l.length > 60) l.removeRange(60, l.length);
    events.value = l;
  }

  static void _step(int n) {
    seq.value = n;
    _seqT?.cancel();
    _seqT = Timer(const Duration(seconds: 5), () => seq.value = 0);
  }

  static void _feed(String chunk) {
    _buf += chunk;
    int i;
    while ((i = _buf.indexOf('\n')) >= 0) {
      final line = _buf.substring(0, i).trim();
      _buf = _buf.substring(i + 1);
      if (line.isNotEmpty) _line(line);
    }
    if (_buf.length > 200) _buf = '';
  }

  static void _line(String l) {
    if (l.startsWith('ERR ')) {
      _add(FbEvent('err', l.substring(4)));
      return;
    }
    if (!l.startsWith('EV:')) return;
    final p = l.substring(3).split(':');
    switch (p[0]) {
      case 'ACC':
        {
          final on = p.length > 1 && p[1] == '1';
          _setOut('ACC', on ? '1' : '0');
          acc.value = on;
          _add(FbEvent('acc', on ? '1' : '0'));
          if (on && seq.value == 1) _step(2);
        }
      case 'START':
        {
          final on = p.length > 1 && p[1] == '1';
          _setOut('START', on ? '1' : '0');
          if (on) {
            _add(FbEvent('start', ''));
            if (seq.value >= 1) _step(3);
          }
        }
      case 'CUT':
      case 'AR':
      case 'AL':
        {
          final v = p.length > 1 ? p[1] : '0';
          _setOut(p[0], v);
          _add(FbEvent(p[0].toLowerCase(), v));
        }
      case 'RPM':
        {
          // the Arduino sends pulses per minute; revolutions = pulses / teeth
          final ppm = double.tryParse(p.length > 1 ? p[1] : '') ?? 0;
          final teeth = rpmTeeth.value < 1 ? 1 : rpmTeeth.value;
          rpm.value = ppm / teeth;
          _rpmT?.cancel();
          _rpmT = Timer(const Duration(milliseconds: 1500), () => rpm.value = 0);
        }
      case 'TAG':
      case 'NFC':
        {
          final ok = p.contains('OK');
          final e = FbEvent(ok ? 'tag_ok' : 'tag_no', '');
          lastTag.value = e;
          _add(e);
          nfcFlash.value = ok ? 1 : 2;
          _nfcT?.cancel();
          _nfcT = Timer(const Duration(milliseconds: 2500), () => nfcFlash.value = 0);
          if (ok) {
            _step(1);
            HapticFeedback.mediumImpact();
          } else {
            HapticFeedback.heavyImpact();
          }
        }
    }
  }
  static BluetoothSerialPort? port;
  static String deviceName = 'HC-05';

  static String t(String k) => _s[lang.value]![k] ?? k;

  static void toast(String m) {
    messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: const Color(0xFF14305F),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  static Future<void> setLang(String l) async {
    lang.value = l;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('lang', l);
    } catch (_) {}
  }

  static Future<void> connect(String address, String name) async {
    final p = await BluetoothSerial.instance.open(address);
    port = p;
    deviceName = name;
    connected.value = true;
    _buf = '';
    outs.value = _zero();
    p.input?.listen((d) => _feed(String.fromCharCodes(d)), onError: (_) {});
    void lost(Object? _) {
      if (port == p) {
        port = null;
        connected.value = false;
        acc.value = null;
        outs.value = _zero();
        rpm.value = 0;
      }
    }

    p.closed.then(lost, onError: lost);
  }

  static Future<bool> send(String cmd) async {
    final p = port;
    if (p == null) {
      toast(t('notConn'));
      return false;
    }
    try {
      await p.writeText('$cmd\n');
      _optimistic(cmd);
      HapticFeedback.lightImpact();
      return true;
    } catch (e) {
      toast('$e');
      return false;
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  try {
    final p = await SharedPreferences.getInstance();
    Ctl.lang.value = p.getString('lang') ?? 'fa';
    Ctl.loadPrefs(p);
  } catch (_) {}
  runApp(const VistaApp());
}

class VistaApp extends StatelessWidget {
  const VistaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: Ctl.lang,
      builder: (_, l, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: Ctl.messenger,
        title: 'Vista Control',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: cBg,
          colorScheme: const ColorScheme.dark(primary: cCy, surface: cPanel),
        ),
        builder: (c, child) => Directionality(
          textDirection: l == 'fa' ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

// ───────── Shared widgets ─────────
BoxDecoration neon({Color c = cCy, double r = 16}) => BoxDecoration(
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: c, width: 1.8),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [c.withValues(alpha: .22), c.withValues(alpha: .06)],
      ),
      boxShadow: [BoxShadow(color: c.withValues(alpha: .4), blurRadius: 16)],
    );

BoxDecoration hud() => BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: cLine, width: 1.5),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0E1A3A), Color(0xFF091125)],
      ),
    );

class NeonButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final double height;
  final double radius;
  const NeonButton({
    super.key,
    required this.child,
    this.onTap,
    this.color = cCy,
    this.height = 56,
    this.radius = 16,
  });
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: neon(c: color, r: radius),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            splashColor: color.withValues(alpha: .35),
            onTap: onTap,
            child: Center(child: child),
          ),
        ),
      );
}

class AppBg extends StatelessWidget {
  final Widget child;
  const AppBg({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -1.1),
              radius: 1.2,
              colors: [Color(0xFF0D1F55), cBg],
              stops: [0, .65],
            ),
          ),
          child: SafeArea(child: child),
        ),
      );
}

class LangSwitch extends StatelessWidget {
  const LangSwitch({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: Ctl.lang,
        builder: (_, l, __) => Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: cLine),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final e in {'fa': 'فارسی', 'en': 'English'}.entries)
                GestureDetector(
                  onTap: () => Ctl.setLang(e.key),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    color: l == e.key ? cCy : Colors.transparent,
                    child: Text(e.value,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: l == e.key
                                ? const Color(0xFF001018)
                                : cMu)),
                  ),
                ),
            ]),
          ),
        ),
      );
}

class TitleBar extends StatelessWidget {
  final Widget? leading;
  final Widget? trailing;
  final String? title;
  const TitleBar({super.key, this.leading, this.trailing, this.title});
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
        height: 48,
        child: Row(children: [
          SizedBox(width: 48, child: leading),
          Expanded(
            child: Center(
              child: Text(
                title ?? 'VISTA CONTROL',
                style: TextStyle(
                  fontSize: title == null ? 20 : 18,
                  fontWeight: FontWeight.w800,
                  fontStyle:
                      title == null ? FontStyle.italic : FontStyle.normal,
                  letterSpacing: title == null ? 1.2 : 0,
                  color: cCy,
                  shadows: const [Shadow(color: cCy, blurRadius: 12)],
                ),
              ),
            ),
          ),
          SizedBox(width: 48, child: trailing),
        ]),
      ));
}

Future<void> showNeonDialog(BuildContext context,
    {required Widget icon,
    required String title,
    String? sub,
    required String button,
    Color color = cCy,
    required VoidCallback onTap}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xCC02050D),
    builder: (dctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: hud(),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          icon,
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(color: cMu)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: NeonButton(
              color: color,
              onTap: () {
                Navigator.of(dctx).pop();
                onTap();
              },
              child: Text(button,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    ),
  );
}

Widget circleIcon(IconData i, Color c, {double size = 76}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c, width: 3),
        boxShadow: [BoxShadow(color: c.withValues(alpha: .5), blurRadius: 24)],
      ),
      child: Icon(i, color: c, size: size * .55),
    );

// ───────── Splash ─────────
class RingPainter extends CustomPainter {
  final double t;
  RingPainter(this.t);
  @override
  void paint(Canvas c, Size s) {
    final w = s.width;
    final rect = Rect.fromLTWH(w * .248, w * .053, w * .507, w * .507);
    c.save();
    // cut the ring before the logo so it passes behind "VISTA"
    c.clipRect(Rect.fromLTWH(0, 0, w, rect.top + rect.height * .8));
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .012
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3)
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.transparent,
          cCy.withValues(alpha: .85),
          Colors.white
        ],
        stops: const [0, .62, .88, 1],
        transform: GradientRotation(t * 2 * math.pi),
      ).createShader(rect);
    c.drawOval(rect, p);
    c.restore();
  }

  @override
  bool shouldRepaint(RingPainter o) => o.t != t;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController main = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 4300));
  late final AnimationController ring = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    main.forward().whenComplete(() {
      if (mounted) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ConnectScreen()));
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    main.dispose();
    ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02040C),
      body: AnimatedBuilder(
        animation: Listenable.merge([main, ring]),
        builder: (_, __) {
          final a = Curves.easeOutCubic.transform((main.value / .85).clamp(0.0, 1.0));
          final prog = Curves.easeInOut.transform(((main.value - .14) / .7).clamp(0.0, 1.0));
          return Stack(fit: StackFit.expand, children: [
            // the artwork, blurred and darkened, fills the whole screen
            Opacity(
              opacity: (main.value / .2).clamp(0.0, 1.0),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: Image.asset('assets/splash.jpg', fit: BoxFit.cover),
              ),
            ),
            Container(color: const Color(0x8F000000)),
            Center(
              child: LayoutBuilder(builder: (_, bc) {
                final w = bc.maxWidth;
                return SizedBox(
                  width: w,
                  height: w,
                  child: Stack(children: [
                    Opacity(
                      opacity: (main.value / .25).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 1.1 - .1 * a,
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (r) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                            stops: [0, .1, .9, 1],
                          ).createShader(r),
                          child: Image.asset('assets/splash.jpg', width: w, height: w, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Opacity(
                        opacity: (main.value / .15).clamp(0.0, 1.0),
                        child: CustomPaint(painter: RingPainter(ring.value)),
                      ),
                    ),
                    Positioned(
                      left: w * .173,
                      top: w * .852,
                      width: w * .655,
                      height: w * .043,
                      child: Opacity(
                        opacity: (main.value / .12).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF050A1A),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: const Color(0xFF7A4BD6), width: 2),
                          ),
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: prog,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                gradient: const LinearGradient(colors: [Color(0xFF0A8FF0), cCy]),
                                boxShadow: const [BoxShadow(color: cCy, blurRadius: 12)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                );
              }),
            ),
          ]);
        },
      ),
    );
  }
}

// ───────── Connect ─────────
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});
  @override
  State<ConnectScreen> createState() => _ConnectState();
}

class _ConnectState extends State<ConnectScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))
    ..repeat(reverse: true);
  List<BluetoothSerialDevice> devs = [];
  BluetoothSerialDevice? sel;
  bool busy = false;
  String? err;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final bt = BluetoothSerial.instance;
    try {
      if (!await bt.requestPermissions() || !await bt.requestEnable()) {
        if (mounted) setState(() => err = Ctl.t('perm'));
        return;
      }
      final l = await bt.bondedDevices();
      int rank(BluetoothSerialDevice d) =>
          (d.name ?? '').toUpperCase().contains('HC') ? 0 : 1;
      l.sort((a, b) => rank(a).compareTo(rank(b)));
      if (!mounted) return;
      setState(() {
        err = null;
        devs = l;
        sel = l.isEmpty ? null : l.first;
      });
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    }
  }

  Future<void> connect() async {
    final d = sel;
    if (d == null || busy) return;
    setState(() => busy = true);
    try {
      await Ctl.connect(d.address, d.name ?? d.address);
      if (!mounted) return;
      setState(() => busy = false);
      await showNeonDialog(context,
          icon: circleIcon(Icons.check_rounded, cGr),
          title: Ctl.t('okMsg'),
          sub: d.name ?? d.address,
          button: 'OK',
          onTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainScreen())));
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      await showNeonDialog(context,
          icon: circleIcon(Icons.bluetooth_disabled, cRd),
          title: Ctl.t('err'),
          sub: '$e',
          color: cRd,
          button: Ctl.t('retry'),
          onTap: () {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: Ctl.lang,
      builder: (_, __, ___) => AppBg(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(children: [
            const TitleBar(),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: pulse,
              builder: (_, __) => Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cCy, width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: cCy.withValues(alpha: .35 + .25 * pulse.value),
                        blurRadius: 28 + 14 * pulse.value),
                  ],
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                            color: cCy, strokeWidth: 3))
                    : const Icon(Icons.bluetooth, color: cCy, size: 64),
              ),
            ),
            const SizedBox(height: 18),
            Text(busy ? Ctl.t('connecting') : Ctl.t('pick'),
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Expanded(
              child: devs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(err ?? Ctl.t('noDev'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: cMu, height: 1.6)),
                          const SizedBox(height: 12),
                          TextButton.icon(
                              onPressed: load,
                              icon: const Icon(Icons.refresh, color: cCy),
                              label: Text(Ctl.t('refresh'),
                                  style: const TextStyle(color: cCy))),
                        ]),
                      ),
                    )
                  : ListView(children: [
                      for (final d in devs)
                        GestureDetector(
                          onTap: () => setState(() => sel = d),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: hud().copyWith(
                              border: Border.all(
                                  color: sel == d ? cCy : cLine,
                                  width: sel == d ? 2 : 1.5),
                            ),
                            child: Row(children: [
                              const Icon(Icons.bluetooth,
                                  color: cCy, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(d.name ?? d.address,
                                          style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800)),
                                      Directionality(
                                          textDirection: TextDirection.ltr,
                                          child: Text(d.address,
                                              style: const TextStyle(
                                                  color: cMu, fontSize: 12))),
                                    ]),
                              ),
                              if (sel == d)
                                const Icon(Icons.check_circle, color: cCy),
                            ]),
                          ),
                        ),
                    ]),
            ),
            SizedBox(
              width: double.infinity,
              child: NeonButton(
                onTap: (sel == null || busy) ? null : connect,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(Ctl.t('connect'),
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  const Icon(Icons.link, color: cCy),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────── Main control ─────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainState();
}

class _MainState extends State<MainScreen> {
  int? selA, selB;
  bool lostShown = false;

  @override
  void initState() {
    super.initState();
    Ctl.connected.addListener(onConn);
  }

  @override
  void dispose() {
    Ctl.connected.removeListener(onConn);
    super.dispose();
  }

  void onConn() {
    if (Ctl.connected.value || !mounted || lostShown) return;
    lostShown = true;
    showNeonDialog(context,
        icon: circleIcon(Icons.bluetooth_disabled, cRd),
        title: Ctl.t('lost'),
        sub: Ctl.t('retryHint'),
        color: cRd,
        button: Ctl.t('retry'),
        onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ConnectScreen())));
  }

  void openSettings() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  Widget powerBtn(bool on) => ValueListenableBuilder<bool?>(
        valueListenable: Ctl.acc,
        builder: (_, acc, __) {
          final c = on ? cGr : cRd;
          final lit = acc == on;
          final dim = acc != null && acc != on;
          return Opacity(
            opacity: dim ? .45 : 1,
            child: Container(
              height: 128,
              decoration: neon(c: c).copyWith(
                boxShadow: [
                  BoxShadow(
                      color: c.withValues(alpha: lit ? .7 : .25),
                      blurRadius: lit ? 28 : 10)
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  splashColor: c.withValues(alpha: .35),
                  onTap: () async {
                    if (await Ctl.send(on ? kAccOn : kAccOff)) {
                      Ctl.acc.value = on;
                    }
                  },
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.power_settings_new_rounded,
                            color: c, size: 56),
                        Text(on ? 'ON' : 'OFF',
                            style: TextStyle(
                                color: c,
                                fontSize: 22,
                                fontWeight: FontWeight.w900)),
                      ]),
                ),
              ),
            ),
          );
        },
      );

  Widget rhythmGroup(String title, List<String> cmds, String stop, int? sel,
      ValueChanged<int?> onSel, int base) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: hud(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 10),
          Row(children: [
            for (var i = 0; i < cmds.length; i++) ...[
              Expanded(
                child: NeonButton(
                  height: 54,
                  radius: 27,
                  color: sel == i ? cCy : cLine,
                  onTap: () async {
                    if (await Ctl.send(cmds[i])) onSel(i);
                  },
                  child: Text('${base + i}',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: sel == i ? Colors.white : cMu)),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: NeonButton(
                height: 54,
                radius: 14,
                color: cLine,
                onTap: () async {
                  if (await Ctl.send(stop)) onSel(null);
                },
                child: const Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.stop_rounded, size: 20),
                  Text('Stop', style: TextStyle(fontSize: 12)),
                ]),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: Ctl.lang,
      builder: (_, __, ___) => AppBg(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(children: [
            TitleBar(
              leading: const BtBadge(),
              trailing: IconButton(
                icon: const Icon(Icons.settings, color: cCy),
                onPressed: openSettings,
              ),
            ),
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(children: [
                Expanded(child: powerBtn(true)),
                const SizedBox(width: 12),
                Expanded(child: powerBtn(false)),
              ]),
            ),
            const SizedBox(height: 14),
            NeonButton(
              height: 64,
              color: cVi,
              onTap: () => Ctl.send(kStart),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bolt, color: Color(0xFFCDB8FF), size: 30),
                SizedBox(width: 8),
                Text('START',
                    style: TextStyle(
                        fontSize: 26,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFCDB8FF))),
              ]),
            ),
            const SizedBox(height: 14),
            rhythmGroup('CUTOFF', kCutoff, kCutoffStop, selA,
                (v) => setState(() => selA = v), 1),
            const SizedBox(height: 12),
            rhythmGroup('ARABI', kArabi, kArabiStop, selB,
                (v) => setState(() => selB = v), 4),
            const SizedBox(height: 14),
            const FeedbackPanel(),
          ]),
        ),
      ),
    );
  }
}

// ───────── Feedback ─────────
String _two(int n) => n.toString().padLeft(2, '0');
String fmtTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

({IconData i, Color c, String t}) describeEv(FbEvent e) {
  String run(String name, String v) =>
      v == '0' ? '$name ${Ctl.t('evStop')}' : '$name ${Ctl.t('evRun')} ($v ms)';
  switch (e.kind) {
    case 'acc':
      return e.data == '1'
          ? (i: Icons.power_settings_new_rounded, c: cGr, t: Ctl.t('evAccOn'))
          : (i: Icons.power_settings_new_rounded, c: cRd, t: Ctl.t('evAccOff'));
    case 'start':
      return (i: Icons.bolt, c: cVi, t: Ctl.t('evStart'));
    case 'cut':
      return (i: Icons.content_cut, c: cCy, t: run('CUTOFF', e.data));
    case 'ar':
      return (i: Icons.graphic_eq, c: cCy, t: run('ARABI ar', e.data));
    case 'al':
      return (i: Icons.graphic_eq, c: cCy, t: run('ARABI al', e.data));
    case 'tag_ok':
      return (i: Icons.verified, c: cGr, t: Ctl.t('evTagOk'));
    case 'tag_no':
      return (i: Icons.gpp_bad, c: cRd, t: Ctl.t('evTagNo'));
    default:
      return (i: Icons.error_outline, c: cRd, t: '${Ctl.t('evErr')}: ${e.data}');
  }
}

class LedTile extends StatefulWidget {
  final String label;
  final String value;
  final Color color;
  final bool rhythm;
  final bool compact;
  const LedTile(
      {super.key,
      required this.label,
      required this.value,
      required this.color,
      this.rhythm = false,
      this.compact = false});
  @override
  State<LedTile> createState() => _LedTileState();
}

class _LedTileState extends State<LedTile> {
  Timer? t;
  bool lit = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(LedTile o) {
    super.didUpdateWidget(o);
    if (o.value != widget.value) _setup();
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  // the LED blinks with the real on/off times reported by the Arduino
  void _setup() {
    t?.cancel();
    final v = widget.value;
    if (!widget.rhythm || !v.contains(',')) {
      lit = v != '0';
      return;
    }
    final p = v.split(',');
    final on = (int.tryParse(p[0]) ?? 100).clamp(40, 3000);
    final off = (int.tryParse(p.length > 1 ? p[1] : '') ?? 100).clamp(40, 3000);
    lit = true;
    void tick(bool s) {
      t = Timer(Duration(milliseconds: s ? on : off), () {
        if (!mounted) return;
        setState(() => lit = !s);
        tick(!s);
      });
    }

    tick(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final sub = widget.rhythm && widget.value.contains(',')
        ? widget.value.replaceAll(',', '/')
        : null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      padding: EdgeInsets.symmetric(vertical: widget.compact ? 6 : 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF07101F),
        border: Border.all(color: lit ? c : cLine.withValues(alpha: .6), width: lit ? 1.8 : 1.2),
        boxShadow: lit ? [BoxShadow(color: c.withValues(alpha: .45), blurRadius: 14)] : null,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: widget.compact ? 10 : 16,
          height: widget.compact ? 10 : 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lit ? c : const Color(0xFF16233F),
            boxShadow: lit ? [BoxShadow(color: c, blurRadius: 10)] : null,
          ),
        ),
        SizedBox(height: widget.compact ? 3 : 6),
        Text(widget.label,
            style: TextStyle(
                fontSize: widget.compact ? 9.5 : 10.5,
                fontWeight: FontWeight.w800,
                color: lit ? Colors.white : cMu)),
        SizedBox(
          height: widget.compact ? 10 : 12,
          child: sub == null
              ? null
              : Text(sub, style: const TextStyle(fontSize: 8.5, color: cMu)),
        ),
      ]),
    );
  }
}

class SeqStepper extends StatelessWidget {
  const SeqStepper({super.key});

  Widget step(IconData i, String label, bool on) => Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? cCy.withValues(alpha: .18) : const Color(0xFF07101F),
            border: Border.all(color: on ? cCy : cLine, width: on ? 2 : 1.2),
            boxShadow: on ? [BoxShadow(color: cCy.withValues(alpha: .5), blurRadius: 14)] : null,
          ),
          child: Icon(i, size: 20, color: on ? cCy : cMu),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: on ? cCy : cMu)),
      ]);

  Widget line(bool on) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: on ? cCy : cLine,
              boxShadow: on ? [BoxShadow(color: cCy.withValues(alpha: .6), blurRadius: 8)] : null,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: Ctl.seq,
        builder: (_, n, __) => Directionality(
          textDirection: TextDirection.ltr,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            step(Icons.nfc, 'NFC', n >= 1),
            line(n >= 2),
            step(Icons.power_settings_new_rounded, 'ACC', n >= 2),
            line(n >= 3),
            step(Icons.bolt, 'START', n >= 3),
          ]),
        ),
      );
}

// ───────── Bluetooth badge (top-left) ─────────
class BtBadge extends StatelessWidget {
  const BtBadge({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: Ctl.connected,
        builder: (_, ok, __) => IconButton(
          icon: Icon(ok ? Icons.bluetooth : Icons.bluetooth_disabled,
              color: ok ? cCy : cRd,
              shadows: [Shadow(color: ok ? cCy : cRd, blurRadius: 12)]),
          onPressed: ok
              ? null
              : () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ConnectScreen())),
        ),
      );
}

// ───────── RPM styles ─────────
class RpmStyle {
  final String name, sub;
  final Color main, accent;
  final double sweep; // gauge arc in degrees
  final int needle; // 0 line, 1 tapered, 2 thin + hub
  final bool dots; // dotted ticks
  final bool italic;
  final int segs; // segments of the linear bar
  const RpmStyle(this.name, this.sub, this.main, this.accent,
      {this.sweep = 250,
      this.needle = 0,
      this.dots = false,
      this.italic = true,
      this.segs = 28});
}

const kStyles = <RpmStyle>[
  RpmStyle('Vista Neon', 'Signature', Color(0xFF19E3FF), Color(0xFF8B5CF6), sweep: 250, needle: 0, segs: 28),
  RpmStyle('Lamborghini', 'Giallo Orion', Color(0xFFFFD400), Color(0xFFFFFFFF), sweep: 270, needle: 1, segs: 36),
  RpmStyle('Kawasaki Ninja H2', 'Lime Green', Color(0xFF6BFF00), Color(0xFFC5FF8A), sweep: 240, needle: 1, dots: true, segs: 32),
  RpmStyle('Ferrari', 'Rosso Corsa', Color(0xFFFF2B1F), Color(0xFFFFD100), sweep: 260, needle: 0, segs: 30),
  RpmStyle('Ducati Panigale V4', 'Corse Red', Color(0xFFE10600), Color(0xFFFFFFFF), sweep: 235, needle: 2, segs: 24),
  RpmStyle('Yamaha YZF-R1', 'Racing Blue', Color(0xFF2F7BFF), Color(0xFFE8F1FF), sweep: 245, needle: 1, dots: true, segs: 26),
  RpmStyle('McLaren', 'Papaya Orange', Color(0xFFFF8000), Color(0xFF00D1FF), sweep: 255, needle: 2, segs: 34),
  RpmStyle('Bugatti Chiron', 'Atlantic Blue', Color(0xFF2A6BFF), Color(0xFFC9D6FF), sweep: 265, needle: 0, dots: true, segs: 40),
  RpmStyle('Porsche 911', 'Classic Amber', Color(0xFFFFC145), Color(0xFFFFFFFF), sweep: 250, needle: 2, italic: false, segs: 22),
  RpmStyle('Honda CBR RR-R', 'HRC Tricolor', Color(0xFFFF2D2D), Color(0xFF2D6BFF), sweep: 240, needle: 1, segs: 28),
  RpmStyle('Suzuki Hayabusa', 'Metallic Silver', Color(0xFFE0E6F0), Color(0xFF3D8BFF), sweep: 255, needle: 0, dots: true, segs: 30),
  RpmStyle('Tesla Plaid', 'Minimal White', Color(0xFFFFFFFF), Color(0xFFFF2E2E), sweep: 220, needle: 2, italic: false, segs: 20),
];

void _drawText(Canvas c, String s, Offset center, double size, Color col,
    {FontWeight w = FontWeight.w700, bool italic = false}) {
  final tp = TextPainter(
    text: TextSpan(
        text: s,
        style: TextStyle(
            fontSize: size,
            color: col,
            fontWeight: w,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

class GaugePainter extends CustomPainter {
  final double rpm, max, red;
  final RpmStyle st;
  GaugePainter(this.rpm, this.max, this.red, this.st);

  @override
  void paint(Canvas c, Size sz) {
    final r = math.min(sz.width, sz.height) / 2;
    final ctr = Offset(sz.width / 2, sz.height / 2);
    final start = (90 + (360 - st.sweep) / 2) * math.pi / 180;
    final sw = st.sweep * math.pi / 180;
    final f = (rpm / max).clamp(0.0, 1.0);
    final fr = (red / max).clamp(0.0, 1.0);
    final arcR = r * .86;
    final rect = Rect.fromCircle(center: ctr, radius: arcR);
    final stroke = r * .07;

    Paint ring(Color col, {double blur = 0}) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = col
      ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;

    c.drawArc(rect, start, sw, false, ring(const Color(0xFF14203F)));
    if (fr < 1) {
      c.drawArc(rect, start + sw * fr, sw * (1 - fr), false, ring(cRd.withValues(alpha: .5)));
    }
    final live = rpm >= red ? cRd : st.main;
    if (f > .004) {
      c.drawArc(rect, start, sw * f, false, ring(live.withValues(alpha: .7), blur: r * .06));
      c.drawArc(rect, start, sw * f, false, ring(live));
    }

    // ticks + numbers (thousands)
    final steps = (max / 1000).round().clamp(1, 40);
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final a = start + sw * t;
      final dir = Offset(math.cos(a), math.sin(a));
      final col = t > fr ? cRd : st.accent;
      if (st.dots) {
        c.drawCircle(ctr + dir * (arcR - r * .14), r * .02, Paint()..color = col);
      } else {
        c.drawLine(ctr + dir * (arcR - r * .1), ctr + dir * (arcR - r * .2),
            Paint()
              ..color = col
              ..strokeWidth = r * .02);
      }
      if (steps <= 14 || i % 2 == 0) {
        _drawText(c, '$i', ctr + dir * (arcR - r * .33), r * .11, col.withValues(alpha: .9), italic: st.italic);
      }
    }

    // needle
    final a = start + sw * f;
    final dir = Offset(math.cos(a), math.sin(a));
    final nrm = Offset(-dir.dy, dir.dx);
    final tip = ctr + dir * (arcR * .74);
    if (st.needle == 1) {
      final b1 = ctr + nrm * (r * .05) - dir * (r * .1);
      final b2 = ctr - nrm * (r * .05) - dir * (r * .1);
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(b1.dx, b1.dy)
        ..lineTo(b2.dx, b2.dy)
        ..close();
      c.drawPath(
          path,
          Paint()
            ..color = live.withValues(alpha: .6)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .04));
      c.drawPath(path, Paint()..color = live);
    } else {
      final w = st.needle == 2 ? r * .022 : r * .04;
      final tail = ctr - dir * (r * .12);
      c.drawLine(
          tail,
          tip,
          Paint()
            ..color = live.withValues(alpha: .6)
            ..strokeWidth = w * 2
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .04));
      c.drawLine(
          tail,
          tip,
          Paint()
            ..color = live
            ..strokeWidth = w
            ..strokeCap = StrokeCap.round);
    }
    c.drawCircle(ctr, r * .08, Paint()..color = const Color(0xFF0B1226));
    c.drawCircle(
        ctr,
        r * .08,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .025
          ..color = live);

    // readout
    _drawText(c, rpm.round().toString(), ctr + Offset(0, r * .58), r * .2, Colors.white,
        w: FontWeight.w800, italic: st.italic);
    _drawText(c, 'RPM', ctr + Offset(0, r * .78), r * .1, st.accent, w: FontWeight.w700);
  }

  @override
  bool shouldRepaint(GaugePainter o) => true;
}

class LinearPainter extends CustomPainter {
  final double rpm, max, red;
  final RpmStyle st;
  LinearPainter(this.rpm, this.max, this.red, this.st);

  @override
  void paint(Canvas c, Size sz) {
    final n = st.segs;
    const gap = 2.0;
    final segW = (sz.width - gap * (n - 1)) / n;
    final top = sz.height * .42;
    final h = sz.height * .3;
    final f = (rpm / max).clamp(0.0, 1.0);
    final fr = (red / max).clamp(0.0, 1.0);
    for (var i = 0; i < n; i++) {
      final p = (i + 1) / n;
      final col = p > fr ? cRd : (p > fr * .72 ? st.accent : st.main);
      final lit = (i + .5) / n <= f;
      final rr = RRect.fromRectAndRadius(
          Rect.fromLTWH(i * (segW + gap), top, segW, h), const Radius.circular(2));
      if (lit) {
        c.drawRRect(
            rr,
            Paint()
              ..color = col.withValues(alpha: .7)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        c.drawRRect(rr, Paint()..color = col);
      } else {
        c.drawRRect(rr, Paint()..color = col.withValues(alpha: .14));
      }
    }
    final live = rpm >= red ? cRd : st.main;
    _drawText(c, rpm.round().toString(), Offset(sz.width / 2, sz.height * .16), sz.height * .3, live,
        w: FontWeight.w900, italic: st.italic);
    final k = (max / 1000).toStringAsFixed(max % 1000 == 0 ? 0 : 1);
    final m = (max / 2000).toStringAsFixed(max % 2000 == 0 ? 0 : 1);
    _drawText(c, '0', Offset(segW / 2, sz.height * .86), sz.height * .14, st.accent.withValues(alpha: .8));
    _drawText(c, m, Offset(sz.width / 2, sz.height * .86), sz.height * .14, st.accent.withValues(alpha: .8));
    _drawText(c, k, Offset(sz.width - segW / 2 - 4, sz.height * .86), sz.height * .14, st.accent.withValues(alpha: .8));
  }

  @override
  bool shouldRepaint(LinearPainter o) => true;
}

class RpmView extends StatelessWidget {
  final double rpm, max, red;
  final int mode; // 0 needle, 1 linear, 2 digital
  final RpmStyle style;
  const RpmView(
      {super.key,
      required this.rpm,
      required this.max,
      required this.red,
      required this.mode,
      required this.style});

  Widget digital(double w) {
    final f = (rpm / max).clamp(0.0, 1.0);
    final fr = (red / max).clamp(0.0, 1.0);
    final col = rpm >= red ? cRd : style.main;
    const n = 10;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: w * .9,
        child: Row(children: [
          for (var i = 0; i < n; i++)
            Expanded(
              child: Builder(builder: (_) {
                final p = (i + 1) / n;
                final lit = p <= f + .001;
                final cc = p > fr ? cRd : (p > fr * .7 ? style.accent : style.main);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: lit ? cc : cc.withValues(alpha: .14),
                    boxShadow: lit ? [BoxShadow(color: cc, blurRadius: 6)] : null,
                  ),
                );
              }),
            ),
        ]),
      ),
      const SizedBox(height: 6),
      FittedBox(
        child: Text(rpm.round().toString(),
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
              color: col,
              letterSpacing: 1,
              shadows: [Shadow(color: col, blurRadius: 14)],
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            )),
      ),
      Text('RPM', style: TextStyle(fontSize: 11, letterSpacing: 3, color: style.accent, fontWeight: FontWeight.w700)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, bc) {
      final w = bc.maxWidth.isFinite ? bc.maxWidth : 160.0;
      final h = bc.maxHeight.isFinite ? bc.maxHeight : 140.0;
      switch (mode) {
        case 1:
          return Center(
              child: SizedBox(
                  width: w,
                  height: 80,
                  child: CustomPaint(painter: LinearPainter(rpm, max, red, style))));
        case 2:
          return Center(child: digital(w));
        default:
          final d = math.min(w, h);
          return Center(
              child: SizedBox(
                  width: d,
                  height: d,
                  child: CustomPaint(painter: GaugePainter(rpm, max, red, style))));
      }
    });
  }
}

class RpmLive extends StatelessWidget {
  const RpmLive({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([Ctl.rpm, Ctl.rpmMode, Ctl.rpmStyle, Ctl.rpmMax, Ctl.rpmRed]),
        builder: (_, __) => TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: Ctl.rpm.value),
          duration: const Duration(milliseconds: 180),
          builder: (_, v, __) => RpmView(
            rpm: v,
            mode: Ctl.rpmMode.value,
            style: kStyles[Ctl.rpmStyle.value.clamp(0, kStyles.length - 1)],
            max: Ctl.rpmMax.value.toDouble(),
            red: math.min(Ctl.rpmRed.value, Ctl.rpmMax.value).toDouble(),
          ),
        ),
      );
}

// ───────── Feedback panel ─────────
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
      decoration: hud(),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.sensors, color: cCy, size: 20),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const FeedbackScreen())),
            child: Text(Ctl.t('viewAll'), style: const TextStyle(color: cCy)),
          ),
        ]),
        ValueListenableBuilder<Map<String, String>>(
          valueListenable: Ctl.outs,
          builder: (_, o, __) => Directionality(
            textDirection: TextDirection.ltr,
            child: Column(children: [
              SizedBox(
                height: 140,
                child: Row(children: [
                  SizedBox(width: 58, child: LedTile(label: 'ACC', value: o['ACC']!, color: cGr)),
                  const SizedBox(width: 6),
                  const Expanded(child: RpmLive()),
                  const SizedBox(width: 6),
                  SizedBox(width: 58, child: LedTile(label: 'START', value: o['START']!, color: cVi)),
                ]),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: LedTile(compact: true, label: 'CUTOFF', value: o['CUT']!, color: cCy, rhythm: true)),
                const SizedBox(width: 8),
                Expanded(child: LedTile(compact: true, label: 'AL', value: o['AL']!, color: cCy, rhythm: true)),
                const SizedBox(width: 8),
                Expanded(child: LedTile(compact: true, label: 'AR', value: o['AR']!, color: cCy, rhythm: true)),
                const SizedBox(width: 8),
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: Ctl.nfcFlash,
                    builder: (_, v, __) => LedTile(
                        compact: true,
                        label: 'NFC',
                        value: v == 0 ? '0' : '1',
                        color: v == 2 ? cRd : cGr),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: Ctl.lang,
      builder: (_, __, ___) => AppBg(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(children: [
            TitleBar(
              title: Ctl.t('viewAll'),
              leading: IconButton(
                icon: const Icon(Icons.chevron_left, color: cCy, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_sweep, color: cMu),
                onPressed: () {
                  Ctl.events.value = [];
                  Ctl.lastTag.value = null;
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ValueListenableBuilder<List<FbEvent>>(
                valueListenable: Ctl.events,
                builder: (_, list, __) {
                  if (list.isEmpty) {
                    return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.sensors, color: cLine, size: 64),
                        const SizedBox(height: 12),
                        Text(Ctl.t('noEv'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(Ctl.t('noEvSub'), textAlign: TextAlign.center, style: const TextStyle(color: cMu)),
                      ]),
                    );
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final e = list[i];
                      final d = describeEv(e);
                      return TweenAnimationBuilder<double>(
                        key: ValueKey(e.t.microsecondsSinceEpoch),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: hud().copyWith(
                              border: Border.all(color: d.c.withValues(alpha: .6), width: 1.4)),
                          child: Row(children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: d.c.withValues(alpha: .16),
                                border: Border.all(color: d.c),
                              ),
                              child: Icon(d.i, color: d.c, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(d.t, style: const TextStyle(fontWeight: FontWeight.w700))),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(fmtTime(e.t),
                                  style: const TextStyle(color: cMu, fontSize: 12, fontFamily: 'monospace')),
                            ),
                          ]),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────── Custom rhythm settings ─────────
class StepField extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min, max, step;
  const StepField(
      {super.key,
      required this.value,
      required this.onChanged,
      this.min = 1,
      this.max = 9999,
      this.step = 5});
  @override
  State<StepField> createState() => _StepFieldState();
}

class _StepFieldState extends State<StepField> {
  late final TextEditingController c =
      TextEditingController(text: '${widget.value}');

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void setV(int v) {
    v = v.clamp(widget.min, widget.max);
    c.text = '$v';
    widget.onChanged(v);
  }

  Widget sb(String t, int d) => SizedBox(
        width: 44,
        height: 44,
        child: NeonButton(
          radius: 12,
          color: cLine,
          onTap: () => setV((int.tryParse(c.text) ?? widget.min) + d * widget.step),
          child: Text(t, style: const TextStyle(fontSize: 22)),
        ),
      );

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          sb('−', -1),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            height: 44,
            child: TextField(
              controller: c,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF050B17),
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: cLine, width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: cCy, width: 2)),
              ),
              onChanged: (s) => widget.onChanged(
                  (int.tryParse(s) ?? widget.min).clamp(widget.min, widget.max)),
            ),
          ),
          const SizedBox(width: 8),
          sb('+', 1),
        ]),
      );
}

class RhythmScreen extends StatefulWidget {
  const RhythmScreen({super.key});
  @override
  State<RhythmScreen> createState() => _RhythmState();
}

class _RhythmState extends State<RhythmScreen> {
  bool arabi = false;
  final Map<String, List<int>> v = {
    'cutoff': [65, 65],
    'ar': [65, 65],
    'al': [65, 65],
  };

  Widget card(String title, String key,
      {bool withSend = false, String Function(int, int)? cmd}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: hud(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(title,
              style: const TextStyle(
                  color: cCy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
        ),
        const SizedBox(height: 10),
        for (final f in [0, 1])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child:
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(Ctl.t(f == 0 ? 'onT' : 'offT')),
              StepField(
                  key: ValueKey('$key$f'),
                  value: v[key]![f],
                  onChanged: (x) => v[key]![f] = x),
            ]),
          ),
        if (withSend)
          NeonButton(
            height: 46,
            onTap: () => Ctl.send(cmd!(v[key]![0], v[key]![1])),
            child: Text(Ctl.t('send'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
      ]),
    );
  }

  Future<void> sendAll() async {
    if (!arabi) {
      await Ctl.send(cutoffCustom(v['cutoff']![0], v['cutoff']![1]));
    } else {
      await Ctl.send(arCustom(v['ar']![0], v['ar']![1]));
      await Future.delayed(const Duration(milliseconds: 200));
      await Ctl.send(alCustom(v['al']![0], v['al']![1]));
    }
    if (Ctl.connected.value && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: Ctl.lang,
      builder: (_, __, ___) => AppBg(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(children: [
            TitleBar(
              title: Ctl.t('custom'),
              leading: IconButton(
                icon: const Icon(Icons.chevron_left, color: cCy, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 10),
            Align(
                alignment: AlignmentDirectional.centerStart,
                child:
                    Text(Ctl.t('channel'), style: const TextStyle(color: cMu))),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Container(
                decoration: hud(),
                clipBehavior: Clip.antiAlias,
                child: Row(children: [
                  for (final e in [false, true])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => arabi = e),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          color: arabi == e ? cCy : Colors.transparent,
                          child: Text(e ? 'ARABI' : 'CUTOFF',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: arabi == e
                                      ? const Color(0xFF001018)
                                      : cMu)),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(children: [
                if (!arabi) card('CUTOFF', 'cutoff'),
                if (arabi) ...[
                  card('ar', 'ar', withSend: true, cmd: arCustom),
                  card('al', 'al', withSend: true, cmd: alCustom),
                ],
              ]),
            ),
            SizedBox(
              width: double.infinity,
              child: NeonButton(
                onTap: sendAll,
                child: Text(Ctl.t(arabi ? 'sendBoth' : 'save'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────── Settings hub (gear icon) ─────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _HubState();
}

class _HubState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late final AnimationController demo =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);

  @override
  void dispose() {
    demo.dispose();
    super.dispose();
  }

  Widget section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(t, style: const TextStyle(color: cMu, fontWeight: FontWeight.w700)),
      );

  Widget valueRow(String label, Widget field) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(label)),
          field,
        ]),
      );

  Widget modeChip(int i, String key) {
    final sel = Ctl.rpmMode.value == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => Ctl.rpmMode.value = i,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: sel ? cCy : const Color(0xFF0B1226),
            border: Border.all(color: sel ? cCy : cLine, width: 1.5),
            boxShadow: sel ? [BoxShadow(color: cCy.withValues(alpha: .5), blurRadius: 14)] : null,
          ),
          child: Text(Ctl.t(key),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: sel ? const Color(0xFF001018) : cMu)),
        ),
      ),
    );
  }

  Widget styleCard(int i) {
    final st = kStyles[i];
    final sel = Ctl.rpmStyle.value == i;
    return GestureDetector(
      onTap: () => Ctl.rpmStyle.value = i,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: hud().copyWith(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? st.main : cLine, width: sel ? 2 : 1.3),
          boxShadow: sel ? [BoxShadow(color: st.main.withValues(alpha: .45), blurRadius: 14)] : null,
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [st.main, st.accent]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(st.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                Text(st.sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: cMu)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([Ctl.lang, Ctl.rpmMode, Ctl.rpmStyle, Ctl.rpmMax, Ctl.rpmRed, Ctl.rpmTeeth]),
      builder: (_, __) => AppBg(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(children: [
            TitleBar(
              title: Ctl.t('settings'),
              leading: IconButton(
                icon: const Icon(Icons.chevron_left, color: cCy, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: ListView(children: [
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: hud(),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      const Icon(Icons.language, color: cCy, size: 22),
                      const SizedBox(width: 8),
                      Text(Ctl.t('language'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                    const LangSwitch(),
                  ]),
                ),
                section(Ctl.t('rpmSec')),
                // live preview with a demo sweep
                Container(
                  height: 190,
                  padding: const EdgeInsets.all(10),
                  decoration: hud(),
                  child: AnimatedBuilder(
                    animation: demo,
                    builder: (_, __) {
                      final max = Ctl.rpmMax.value.toDouble();
                      return RpmView(
                        rpm: Curves.easeInOut.transform(demo.value) * max * .98,
                        max: max,
                        red: math.min(Ctl.rpmRed.value, Ctl.rpmMax.value).toDouble(),
                        mode: Ctl.rpmMode.value,
                        style: kStyles[Ctl.rpmStyle.value.clamp(0, kStyles.length - 1)],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(children: [
                    modeChip(0, 'mNeedle'),
                    modeChip(1, 'mLinear'),
                    modeChip(2, 'mDigital'),
                  ]),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.5,
                  children: [for (var i = 0; i < kStyles.length; i++) styleCard(i)],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: hud(),
                  child: Column(children: [
                    valueRow(
                        Ctl.t('maxRpm'),
                        StepField(
                            key: const ValueKey('max'),
                            value: Ctl.rpmMax.value,
                            min: 4000,
                            max: 30000,
                            step: 500,
                            onChanged: (v) {
                              Ctl.rpmMax.value = v;
                              if (Ctl.rpmRed.value > v) Ctl.rpmRed.value = v;
                            })),
                    valueRow(
                        Ctl.t('redline'),
                        StepField(
                            key: const ValueKey('red'),
                            value: Ctl.rpmRed.value,
                            min: 2000,
                            max: 30000,
                            step: 500,
                            onChanged: (v) => Ctl.rpmRed.value = v)),
                    valueRow(
                        Ctl.t('teeth'),
                        StepField(
                            key: const ValueKey('teeth'),
                            value: Ctl.rpmTeeth.value,
                            min: 1,
                            max: 120,
                            step: 1,
                            onChanged: (v) => Ctl.rpmTeeth.value = v)),
                  ]),
                ),
                section(Ctl.t('rhythmSec')),
                NeonButton(
                  height: 54,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const RhythmScreen())),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.graphic_eq, color: cCy, size: 22),
                    const SizedBox(width: 10),
                    Text(Ctl.t('custom'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: cCy),
                  ]),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
