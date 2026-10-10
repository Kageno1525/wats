import 'package:flutter/material.dart';
import 'widgets.dart';
import 'whatsapp_bridge.dart';

class HomePage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const HomePage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _phoneCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _countCtrl = TextEditingController(text: '1');
  final _delayCtrl = TextEditingController(text: '5');

  final ValueNotifier<List<String>> _logs =
      ValueNotifier<List<String>>(<String>[]);

  int _count = 1;
  int _delaySeconds = 5;
  bool _running = false;
  bool _stopRequested = false;
  int _currentIndex = 0;

  bool _accessibilityOn = false;
  bool _whatsappOk = false;
  bool _businessOk = false;

  bool _useBusiness = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _msgCtrl.dispose();
    _countCtrl.dispose();
    _delayCtrl.dispose();
    _logs.dispose();
    super.dispose();
  }

  void _log(String msg) {
    final cur = _logs.value;
    final upd = <String>['${_timeNow()}  $msg', ...cur];
    if (upd.length > 200) upd.removeRange(200, upd.length);
    _logs.value = upd;
  }

  String _timeNow() {
    final t = DateTime.now();
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }

  Future<void> _bootstrap() async {
    await _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final a = await WhatsAppBridge.isAccessibilityEnabled();
    final w = await WhatsAppBridge.isWhatsAppInstalled(business: false);
    final wb = await WhatsAppBridge.isWhatsAppInstalled(business: true);

    if (!mounted) return;
    setState(() {
      _accessibilityOn = a;
      _whatsappOk = w;
      _businessOk = wb;
    });
  }

  // ═══ Phone formatting ═══
  String _cleanPhone(String raw) {
    var s = raw.replaceAll(RegExp(r'[^0-9]'), '');
    // لو الرقم بيبدأ بـ 0 (خط محلي) نشيله — عادة بدولة بتبدأ بكود
    // نخليه للمستخدم يكتب كامل بكود الدولة
    return s;
  }

  // ═══ Start sending ═══
  Future<void> _start() async {
    final phone = _cleanPhone(_phoneCtrl.text);
    final message = _msgCtrl.text.trim();

    if (phone.isEmpty) {
      _log('⚠️ اكتب رقم');
      return;
    }
    if (message.isEmpty) {
      _log('⚠️ اكتب الرسالة');
      return;
    }
    if (!_accessibilityOn) {
      _log('⚠️ فعّل Accessibility الأول');
      return;
    }
    if (_useBusiness && !_businessOk) {
      _log('⚠️ WhatsApp Business مش مثبّت');
      return;
    }
    if (!_useBusiness && !_whatsappOk) {
      _log('⚠️ WhatsApp مش مثبّت');
      return;
    }

    _count = int.tryParse(_countCtrl.text.trim()) ?? 1;
    _delaySeconds = int.tryParse(_delayCtrl.text.trim()) ?? 5;
    if (_count < 1) _count = 1;
    if (_delaySeconds < 1) _delaySeconds = 1;

    setState(() {
      _running = true;
      _stopRequested = false;
      _currentIndex = 0;
    });
    _logs.value = [];

    _log('═══ بدء الإرسال ═══');
    _log('رقم: $phone');
    _log('عدد: $_count رسالة');
    _log('فاصل: $_delaySeconds ثانية');

    bool allOk = true;

    for (int i = 1; i <= _count; i++) {
      if (_stopRequested) {
        _log('⏹ تم الإيقاف');
        allOk = false;
        break;
      }

      _currentIndex = i;
      if (mounted) setState(() {});

      _log('▶️ رسالة $i/$_count');

      try {
        // 1) افتح واتساب مع الرقم والرسالة
        final opened = await WhatsAppBridge.openWhatsApp(
          phone: phone,
          message: message,
          useBusiness: _useBusiness,
        );
        if (!opened) {
          _log('❌ فشل فتح واتساب');
          allOk = false;
          break;
        }
        _log('📱 اتفتح الواتساب');

        // 2) استنى شويّة لحد ما الصفحة تحمّل
        await Future.delayed(const Duration(milliseconds: 2500));
        if (_stopRequested) break;

        // 3) اضغط إرسال
        _log('⏳ بدور على زر الإرسال…');
        final sent = await WhatsAppBridge.clickSend(timeoutMs: 6000);
        if (sent) {
          _log('✅ اتبعتت $i');
        } else {
          _log('⚠️ مش لاقي زر الإرسال ($i)');
          allOk = false;
        }

        // 4) ارجع للشات ليست عشان الرسالة تتجدد
        await Future.delayed(const Duration(milliseconds: 700));
        await WhatsAppBridge.goBack();
        await Future.delayed(const Duration(milliseconds: 500));

        // 5) الفاصل بين الرسائل (مش بعد الأخير)
        if (i < _count && !_stopRequested) {
          _log('⏸ فاصل $_delaySeconds ثانية…');
          final step = 500;
          final total = _delaySeconds * 1000;
          var elapsed = 0;
          while (elapsed < total && !_stopRequested) {
            await Future.delayed(const Duration(milliseconds: step));
            elapsed += step;
          }
        }
      } catch (e) {
        _log('❌ خطأ: $e');
        allOk = false;
        break;
      }
    }

    if (mounted) {
      setState(() => _running = false);
    }

    _log(allOk
        ? '🎉 خلصت كل الرسائل ($_count)'
        : '⚠️ توقفنا في رسالة $_currentIndex من $_count');
  }

  void _stop() {
    setState(() => _stopRequested = true);
    _log('⏹ بطلب إيقاف…');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ═══ Header ═══
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.chat_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'wats',
                          style: kNoDeco.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          'إرسال رسائل واتساب متكررة',
                          style: kNoDeco.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconBtn(
                    icon: widget.isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    onTap: widget.onToggleTheme,
                  ),
                  const SizedBox(width: 6),
                  IconBtn(
                    icon: Icons.refresh_rounded,
                    onTap: _refreshPermissions,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ═══ Body ═══
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Accessibility status
                      if (!_accessibilityOn)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: WarnBox(
                            icon: Icons.warning_amber_rounded,
                            color: const Color(0xFFFF6B6B),
                            text: 'Accessibility Service مش مفعّل',
                            actionLabel: 'تفعيل',
                            onAction: () async {
                              await WhatsAppBridge.openAccessibilitySettings();
                              await Future.delayed(
                                  const Duration(seconds: 1));
                              _refreshPermissions();
                            },
                          ),
                        ),
                      if (!_whatsappOk && !_businessOk)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: WarnBox(
                            icon: Icons.warning_amber_rounded,
                            color: const Color(0xFFFFB84D),
                            text: 'الواتساب مش مثبّت',
                            actionLabel: 'تحديث',
                            onAction: _refreshPermissions,
                          ),
                        ),

                      _buildFormCard(theme),
                      const SizedBox(height: 12),
                      _buildSendCard(theme),
                      const SizedBox(height: 12),
                      LogPanel(logs: _logs),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(ThemeData theme) {
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(theme, Icons.person_rounded, 'رقم المستلم'),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: kNoDeco.copyWith(fontSize: 15),
            decoration: const InputDecoration(
              hintText: '201234567890',
              prefixIcon: Icon(Icons.phone_rounded),
              helperText: 'اكتب الرقم بكود الدولة (بدون +)',
              helperStyle: TextStyle(fontSize: 10),
            ),
          ),
          const SizedBox(height: 14),
          _label(theme, Icons.message_rounded, 'الرسالة'),
          const SizedBox(height: 10),
          TextField(
            controller: _msgCtrl,
            maxLines: 4,
            minLines: 3,
            style: kNoDeco.copyWith(fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'اكتب رسالتك هنا…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),

          // WhatsApp type
          Row(
            children: [
              Expanded(
                child: _typeChoice(
                  theme,
                  label: 'WhatsApp',
                  icon: Icons.chat_rounded,
                  selected: !_useBusiness,
                  color: const Color(0xFF25D366),
                  enabled: _whatsappOk,
                  onTap: () => setState(() => _useBusiness = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _typeChoice(
                  theme,
                  label: 'Business',
                  icon: Icons.business_center_rounded,
                  selected: _useBusiness,
                  color: const Color(0xFF128C7E),
                  enabled: _businessOk,
                  onTap: () => setState(() => _useBusiness = true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeChoice(
    ThemeData theme, {
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final opacity = enabled ? 1.0 : 0.4;
    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: selected
                  ? color.withOpacity(0.2)
                  : theme.colorScheme.surface.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? color
                    : theme.colorScheme.primary.withOpacity(0.15),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: selected
                        ? color
                        : theme.colorScheme.onSurface.withOpacity(0.6)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: kNoDeco.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? color
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSendCard(ThemeData theme) {
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(theme, Icons.repeat_rounded, 'عدد المرات'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _countCtrl,
                      keyboardType: TextInputType.number,
                      enabled: !_running,
                      textAlign: TextAlign.center,
                      style: kNoDeco.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(theme, Icons.timer_rounded, 'فاصل (ثانية)'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _delayCtrl,
                      keyboardType: TextInputType.number,
                      enabled: !_running,
                      textAlign: TextAlign.center,
                      style: kNoDeco.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryBtn(
            label: _running
                ? 'جاري الإرسال ($_currentIndex/$_count)'
                : 'ابدأ الإرسال',
            icon: _running
                ? Icons.hourglass_top_rounded
                : Icons.send_rounded,
            gradient: const [Color(0xFF25D366), Color(0xFF128C7E)],
            busy: _running,
            onTap: _running ? null : _start,
          ),
          if (_running) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _stop,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFFF6B6B).withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.stop_rounded,
                            color: Color(0xFFFF6B6B), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'إيقاف',
                          style: kNoDeco.copyWith(
                            color: const Color(0xFFFF6B6B),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
      ),
      child: child,
    );
  }

  Widget _label(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: kNoDeco.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}