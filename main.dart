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
  },
};

// ───────── App state & Bluetooth link ─────────
class Ctl {
  static final lang = ValueNotifier<String>('fa');
  static final messenger = GlobalKey<ScaffoldMessengerState>();
  static final connected = ValueNotifier<bool>(false);
  static final acc = ValueNotifier<bool?>(null);
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
    void lost(Object? _) {
      if (port == p) {
        port = null;
        connected.value = false;
        acc.value = null;
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
  Widget build(BuildContext context) => SizedBox(
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
      );
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
              trailing: IconButton(
                icon: const Icon(Icons.settings, color: cCy),
                onPressed: openSettings,
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: Ctl.connected,
              builder: (_, ok, __) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration:
                    hud().copyWith(borderRadius: BorderRadius.circular(30)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.bluetooth, color: cCy, size: 22),
                  const SizedBox(width: 8),
                  Text(Ctl.deviceName,
                      style: const TextStyle(
                          color: cCy, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ok ? cGr : cRd,
                      boxShadow: [
                        BoxShadow(color: ok ? cGr : cRd, blurRadius: 10)
                      ],
                    ),
                  ),
                ]),
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
            const SizedBox(height: 12),
            NeonButton(
              height: 48,
              onTap: openSettings,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.settings, color: cCy, size: 20),
                const SizedBox(width: 8),
                Text(Ctl.t('custom'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
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
  const StepField({super.key, required this.value, required this.onChanged});
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
    v = v.clamp(1, 9999);
    c.text = '$v';
    widget.onChanged(v);
  }

  Widget sb(String t, int d) => SizedBox(
        width: 44,
        height: 44,
        child: NeonButton(
          radius: 12,
          color: cLine,
          onTap: () => setV((int.tryParse(c.text) ?? 1) + d),
          child: Text(t, style: const TextStyle(fontSize: 22)),
        ),
      );

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          sb('−', -5),
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
              onChanged: (s) =>
                  widget.onChanged((int.tryParse(s) ?? 1).clamp(1, 9999)),
            ),
          ),
          const SizedBox(width: 8),
          sb('+', 5),
        ]),
      );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: hud(),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Row(children: [
                  Icon(Icons.language, color: cCy, size: 22),
                  SizedBox(width: 8),
                  Text('زبان / Language', style: TextStyle(fontWeight: FontWeight.w700)),
                ]),
                const LangSwitch(),
              ]),
            ),
            const SizedBox(height: 14),
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
