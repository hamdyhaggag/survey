// lib/features/registration/registration_wizard.dart
// Premium Arabic RTL Bottom Sheet Registration Wizard
// زيرو وان أكاديمي — 4-Step Guided Registration Flow

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_service.dart';

// ─── Brand Colors ─────────────────────────────────────────────────────────────
class _RegColors {
  static const Color primary = Color(0xFF7C3AED);
  static const Color primarySurface = Color(0xFFF3E8FF);
  static const Color primaryBorder = Color(0xFFDDD6FE);

  static const Color surface = Color(0xFFFFFFFF);

  static const Color text = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const Color border = Color(0xFFE5E7EB);

  static const Color inputBg = Color(0xFFF9FAFB);
  static const Color inputBorder = Color(0xFFE5E7EB);
}

// ─── Text Styles ─────────────────────────────────────────────────────────────
class _RegTextStyles {
  static TextStyle heading(
    double size, {
    FontWeight weight = FontWeight.w800,
  }) => GoogleFonts.ibmPlexSansArabic(
    fontSize: size,
    fontWeight: weight,
    color: _RegColors.text,
    height: 1.35,
  );

  static TextStyle body(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w500,
  }) => GoogleFonts.ibmPlexSansArabic(
    fontSize: size,
    fontWeight: weight,
    color: color ?? _RegColors.textSecondary,
    height: 1.6,
  );

  static TextStyle label(double size, {Color? color}) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? _RegColors.text,
        height: 1.4,
      );
}

// ─── Registration Data Model ──────────────────────────────────────────────────
class RegistrationData {
  String fullName = '';
  String phone = '';
  String grade = '';
  String preferredDays = '';
  String preferredTime = '';
  bool hasSmartphone = false;
  String submittedAt = '';

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'phone': phone,
    'grade': grade,
    'preferredDays': preferredDays,
    'preferredTime': preferredTime,
    'hasSmartphone': hasSmartphone,
    'submittedAt': submittedAt,
  };
}

// ─── Firestore Save ───────────────────────────────────────────────────────────
Future<void> _saveRegistration(RegistrationData data) async {
  await FirebaseService.saveRegistration(data.toJson());
}

// ─── Entry Point ─────────────────────────────────────────────────────────────
class RegistrationWizard extends StatefulWidget {
  const RegistrationWizard({super.key});

  /// Launch the registration wizard as a full-screen modal
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => const RegistrationWizard(),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<RegistrationWizard> createState() => _RegistrationWizardState();
}

class _RegistrationWizardState extends State<RegistrationWizard>
    with TickerProviderStateMixin {
  // ── Wizard State ────────────────────────────────────────────────────────────
  int _screen = 0; // 0=welcome, 1-4=steps, 5=success
  final RegistrationData _data = RegistrationData();

  // ── Animation Controllers ────────────────────────────────────────────────────
  late AnimationController _slideController;
  late AnimationController _progressController;
  late AnimationController _successController;

  late Animation<double> _contentSlide;
  late Animation<double> _contentFade;
  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;
  late Animation<double> _successBounce;

  bool _isForward = true;

  @override
  void initState() {
    super.initState();

    // Content transition — slides content in/out between steps
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _contentSlide = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );
    _contentFade = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeIn,
    );

    // Progress bar animation
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Success animation controller
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _checkScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 60),
          TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 20),
        ]).animate(
          CurvedAnimation(parent: _successController, curve: Curves.easeOut),
        );
    _checkOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _successController,
        curve: const Interval(0.0, 0.4),
      ),
    );
    _successBounce = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _progressController.dispose();
    _successController.dispose();
    super.dispose();
  }

  // ── Navigation ───────────────────────────────────────────────────────────────
  double get _targetProgress {
    if (_screen <= 0) return 0.0;
    if (_screen > 4) return 1.0;
    return _screen / 4.0;
  }

  Future<void> _goToScreen(int target) async {
    if (target == _screen) return;
    _isForward = target > _screen;

    // Start progress animation
    _progressController.animateTo(_targetProgress == 0 ? 0 : target / 4.0);

    // Slide out
    await _slideController.reverse();

    setState(() => _screen = target);

    if (target == 5) {
      // ── Save to localStorage ─────────────────────────────────
      _data.submittedAt = DateTime.now().toIso8601String();
      _saveRegistration(_data);
      // ─────────────────────────────────────────────────────────
      await _slideController.forward();
      await _successController.forward();
      return;
    }
    // Slide in
    await _slideController.forward();
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_screen == 0) {
      _goToScreen(1);
    } else if (_screen < 4) {
      _goToScreen(_screen + 1);
    } else {
      _goToScreen(5); // success
    }
  }

  void _prevStep() {
    HapticFeedback.lightImpact();
    if (_screen > 1) {
      _goToScreen(_screen - 1);
    }
  }

  void _close() {
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        _goToScreen(0);
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPad = mq.viewInsets.bottom + mq.padding.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onTap: () {
          // dismiss keyboard on tap outside
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          backgroundColor: _RegColors.surface,
          body: SafeArea(
            child: Column(
              children: [
                // ── Header (logo + progress) ───────────────────────────────────────
                const SizedBox(height: 16),
                if (_screen != 5) _buildHeader(),

                // ── Content ───────────────────────────────────────────────────────
                Expanded(
                  child: AnimatedBuilder(
                    animation: _slideController,
                    builder: (context, child) {
                      final slideOffset = _isForward
                          ? Tween<Offset>(
                              begin: const Offset(-0.08, 0),
                              end: Offset.zero,
                            ).evaluate(_contentSlide)
                          : Tween<Offset>(
                              begin: const Offset(0.08, 0),
                              end: Offset.zero,
                            ).evaluate(_contentSlide);
                      return FadeTransition(
                        opacity: _contentFade,
                        child: Transform.translate(
                          offset: Offset(
                            slideOffset.dx * MediaQuery.of(context).size.width,
                            0,
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(bottom: bottomPad + 12),
                      child: _buildCurrentScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final stepProgress = _screen == 0 ? 0.0 : _screen / 4.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        children: [
          // Logo row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LogoWidget(size: 38),
              const SizedBox(width: 10),
              Text('زيرو وان أكاديمي', style: _RegTextStyles.heading(15)),
            ],
          ),

          if (_screen > 0) ...[
            const SizedBox(height: 16),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: stepProgress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutCubic,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation(
                      _RegColors.primary,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // Step indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الخطوة $_screen من 4',
                  style: _RegTextStyles.body(12, color: _RegColors.textMuted),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _RegColors.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(_screen / 4 * 100).round()}%',
                    style: _RegTextStyles.label(12, color: _RegColors.primary),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          const Divider(color: Color(0xFFF3F4F6), thickness: 1, height: 1),
        ],
      ),
    );
  }

  // ── Screen Router ─────────────────────────────────────────────────────────────
  Widget _buildCurrentScreen() {
    switch (_screen) {
      case 0:
        return _WelcomeScreen(onStart: _nextStep);
      case 1:
        return _Step1Screen(
          initialName: _data.fullName,
          initialPhone: _data.phone,
          onNext: (name, phone) {
            _data.fullName = name;
            _data.phone = phone;
            _nextStep();
          },
        );
      case 2:
        return _Step2Screen(
          selectedGrade: _data.grade,
          onNext: (grade) {
            _data.grade = grade;
            _nextStep();
          },
          onBack: _prevStep,
        );
      case 3:
        return _Step3Screen(
          selectedDays: _data.preferredDays,
          selectedTime: _data.preferredTime,
          onNext: (days, time) {
            _data.preferredDays = days;
            _data.preferredTime = time;
            _nextStep();
          },
          onBack: _prevStep,
        );
      case 4:
        return _Step4Screen(
          hasSmartphone: _data.hasSmartphone,
          onSubmit: (val) {
            _data.hasSmartphone = val;
            _nextStep();
          },
          onBack: _prevStep,
        );
      case 5:
        return _SuccessScreen(
          onDone: _close,
          checkScale: _checkScale,
          checkOpacity: _checkOpacity,
          successBounce: _successBounce,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Logo Widget ──────────────────────────────────────────────────────────────
class _LogoWidget extends StatelessWidget {
  final double size;
  const _LogoWidget({required this.size});

  @override
  Widget build(BuildContext context) {
    final padding = size * 0.06;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
            blurRadius: size * 0.35,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.20),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Image.asset(
            'assets/images/logo.jpg',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF9333EA), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  '01',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.35,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Primary Button ───────────────────────────────────────────────────────────
class _PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final IconData? icon;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.icon,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _pressCtrl.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              _pressCtrl.reverse();
              widget.onTap();
            }
          : null,
      onTapCancel: widget.enabled ? () => _pressCtrl.reverse() : null,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.enabled ? 1.0 : 0.55,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: widget.enabled
                  ? const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    )
                  : null,
              color: widget.enabled ? null : const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(18),
              boxShadow: widget.enabled
                  ? [
                      BoxShadow(
                        color: _RegColors.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.label,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                if (widget.icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(widget.icon, color: Colors.white, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Secondary Button ─────────────────────────────────────────────────────────
class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  const _SecondaryButton({required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: _RegColors.textSecondary, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _RegColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SCREEN 0: Welcome ────────────────────────────────────────────────────────
class _WelcomeScreen extends StatelessWidget {
  final VoidCallback onStart;
  const _WelcomeScreen({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Column(
        children: [
          // Hero Logo
          _WelcomeLogoHero(),

          const SizedBox(height: 24),

          // Title
          Text(
            'زيرو وان أكاديمي',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: _RegColors.text,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 6),

          // Description card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أهلًا بيك 👋', style: _RegTextStyles.heading(18)),
                const SizedBox(height: 10),
                Text(
                  'سجل بياناتك في أقل من دقيقة، وبعد ما التسجيل يكتمل هنرتب المجموعات ونعلن المواعيد النهائية.',
                  style: _RegTextStyles.body(14),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Time badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⏱️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'المدة المتوقعة للتسجيل : أقل من دقيقة',
                      style: _RegTextStyles.label(
                        12,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // CTA
          _PrimaryButton(
            label: 'ابدأ التسجيل',
            onTap: onStart,
            icon: Icons.arrow_back_rounded,
          ),
        ],
      ),
    );
  }
}

class _WelcomeLogoHero extends StatefulWidget {
  @override
  State<_WelcomeLogoHero> createState() => _WelcomeLogoHeroState();
}

class _WelcomeLogoHeroState extends State<_WelcomeLogoHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.94,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOutCubic));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _pulseAnim, child: _LogoWidget(size: 160));
  }
}

// ─── SCREEN 1: Name & WhatsApp Input ─────────────────────────────────────────
class _Step1Screen extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final void Function(String name, String phone) onNext;

  const _Step1Screen({
    required this.initialName,
    required this.initialPhone,
    required this.onNext,
  });

  @override
  State<_Step1Screen> createState() => _Step1ScreenState();
}

class _Step1ScreenState extends State<_Step1Screen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  bool _hasNameError = false;
  bool _hasPhoneError = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    bool error = false;
    if (name.length < 4) {
      setState(() => _hasNameError = true);
      error = true;
    }
    if (phone.length < 8) {
      setState(() => _hasPhoneError = true);
      error = true;
    }

    if (error) {
      HapticFeedback.mediumImpact();
      return;
    }

    widget.onNext(name, phone);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading
          Text('👋 البيانات الأساسية', style: _RegTextStyles.heading(22)),
          const SizedBox(height: 6),
          Text(
            'اكتب اسمك ورقم الواتساب للتواصل معاك.',
            style: _RegTextStyles.body(14),
          ),

          const SizedBox(height: 24),

          // Name Input Field
          _ArabicInputField(
            controller: _nameCtrl,
            label: 'الاسم الثلاثي',
            hint: 'اكتب اسمك بالكامل',
            icon: Icons.person_rounded,
            hasError: _hasNameError,
            errorText: 'يرجى كتابة الاسم الكامل (٤ حروف على الأقل)',
            onChanged: (_) {
              if (_hasNameError) setState(() => _hasNameError = false);
            },
          ),

          const SizedBox(height: 18),

          // WhatsApp Phone Field
          _ArabicInputField(
            controller: _phoneCtrl,
            label: 'رقم الواتساب للتواصل 💬',
            hint: '01xxxxxxxxx',
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            hasError: _hasPhoneError,
            errorText: 'يرجى كتابة رقم الواتساب الصحيح',
            onChanged: (_) {
              if (_hasPhoneError) setState(() => _hasPhoneError = false);
            },
          ),

          const SizedBox(height: 28),

          // Next Button
          _PrimaryButton(label: 'يلا بينا →', onTap: _submit),

          const SizedBox(height: 12),
          _ProgressDots(total: 4, current: 1),
        ],
      ),
    );
  }
}

// ─── SCREEN 2: Grade Selection ────────────────────────────────────────────────
class _Step2Screen extends StatefulWidget {
  final String selectedGrade;
  final void Function(String grade) onNext;
  final VoidCallback onBack;

  const _Step2Screen({
    required this.selectedGrade,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_Step2Screen> createState() => _Step2ScreenState();
}

class _Step2ScreenState extends State<_Step2Screen> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedGrade;
  }

  static const _grades = [
    ('الصف الأول الثانوي', '🏫'),
    ('الصف الثاني الثانوي', '📚'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📚 إنت في سنة كام؟', style: _RegTextStyles.heading(22)),
          const SizedBox(height: 6),
          Text('اختار الصف الدراسي الحالي.', style: _RegTextStyles.body(14)),

          const SizedBox(height: 28),

          // Grade cards
          for (final (grade, emoji) in _grades) ...[
            _SelectableCard(
              label: grade,
              emoji: emoji,
              isSelected: _selected == grade,
              onTap: () => setState(() => _selected = grade),
            ),
            const SizedBox(height: 14),
          ],

          const SizedBox(height: 32),

          // Navigation
          Row(
            children: [
              Expanded(
                child: _SecondaryButton(
                  label: '← رجوع',
                  onTap: widget.onBack,
                  icon: Icons.arrow_forward_rounded,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: _PrimaryButton(
                  label: 'يلا بينا →',
                  onTap: _selected.isEmpty
                      ? () {}
                      : () => widget.onNext(_selected),
                  enabled: _selected.isNotEmpty,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          _ProgressDots(total: 4, current: 2),
        ],
      ),
    );
  }
}

// ─── SCREEN 3: Group Preferences ─────────────────────────────────────────────
class _Step3Screen extends StatefulWidget {
  final String selectedDays;
  final String selectedTime;
  final void Function(String days, String time) onNext;
  final VoidCallback onBack;

  const _Step3Screen({
    required this.selectedDays,
    required this.selectedTime,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_Step3Screen> createState() => _Step3ScreenState();
}

class _Step3ScreenState extends State<_Step3Screen> {
  late String _days;
  late String _time;

  @override
  void initState() {
    super.initState();
    _days = widget.selectedDays;
    _time = widget.selectedTime;
  }

  static const _dayOptions = ['السبت والثلاثاء', 'الاثنين والخميس'];

  static const _timeOptions = [
    '9:00 ص - 10:30 ص',
    '11:00 ص - 12:30 م',
    '1:00 م - 2:30 م',
    '3:00 م - 4:30 م',
    '5:00 م - 6:30 م',
  ];

  bool get _canProceed => _days.isNotEmpty && _time.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🗓️ اختار المجموعة المناسبة ليك',
            style: _RegTextStyles.heading(20),
          ),
          const SizedBox(height: 6),
          Text(
            'اختار الأيام والوقت المناسب ليك.',
            style: _RegTextStyles.body(14),
          ),

          const SizedBox(height: 24),

          // ── Days Section ──────────────────────────────────────────────────
          _SectionLabel(label: 'الأيام', icon: Icons.calendar_today_rounded),
          const SizedBox(height: 12),

          for (final day in _dayOptions) ...[
            _CompactSelectableCard(
              label: day,
              isSelected: _days == day,
              onTap: () => setState(() => _days = day),
            ),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 20),

          // ── Time Section ──────────────────────────────────────────────────
          _SectionLabel(
            label: 'الفترة المناسبة',
            icon: Icons.access_time_rounded,
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _timeOptions
                .map(
                  (t) => _TimeChip(
                    label: t,
                    isSelected: _time == t,
                    onTap: () => setState(() => _time = t),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 20),

          // ── Info Note ─────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'المواعيد النهائية هتتحدد بعد اكتمال التسجيل.',
                    style: _RegTextStyles.body(
                      13,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Navigation
          Row(
            children: [
              Expanded(
                child: _SecondaryButton(
                  label: '← رجوع',
                  onTap: widget.onBack,
                  icon: Icons.arrow_forward_rounded,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: _PrimaryButton(
                  label: 'يلا بينا →',
                  onTap: _canProceed
                      ? () => widget.onNext(_days, _time)
                      : () {},
                  enabled: _canProceed,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          _ProgressDots(total: 4, current: 3),
        ],
      ),
    );
  }
}

// ─── SCREEN 4: Smartphone Question ───────────────────────────────────────────
class _Step4Screen extends StatefulWidget {
  final bool hasSmartphone;
  final void Function(bool val) onSubmit;
  final VoidCallback onBack;

  const _Step4Screen({
    required this.hasSmartphone,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  State<_Step4Screen> createState() => _Step4ScreenState();
}

class _Step4ScreenState extends State<_Step4Screen> {
  int _selected = -1; // -1=none, 0=yes, 1=no

  @override
  void initState() {
    super.initState();
    // no pre-selection to force conscious choice
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('✅ سؤال أخير', style: _RegTextStyles.heading(22)),
          const SizedBox(height: 6),
          Text(
            'هل معاك موبايل ذكي (Smart Phone)؟',
            style: _RegTextStyles.body(14),
          ),

          const SizedBox(height: 32),

          // Yes Card
          _BigChoiceCard(
            label: 'نعم',
            emoji: '📱',
            subtitle: 'معايا موبايل ذكي',
            isSelected: _selected == 0,
            accentColor: _RegColors.primary,
            onTap: () => setState(() => _selected = 0),
          ),

          const SizedBox(height: 14),

          // No Card
          _BigChoiceCard(
            label: 'لا',
            emoji: '📵',
            subtitle: 'مش معايا موبايل ذكي',
            isSelected: _selected == 1,
            accentColor: const Color(0xFF6366F1),
            onTap: () => setState(() => _selected = 1),
          ),

          const SizedBox(height: 40),

          // Navigation
          Row(
            children: [
              Expanded(
                child: _SecondaryButton(
                  label: '← رجوع',
                  onTap: widget.onBack,
                  icon: Icons.arrow_forward_rounded,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: _PrimaryButton(
                  label: 'إرسال التسجيل',
                  onTap: _selected >= 0
                      ? () => widget.onSubmit(_selected == 0)
                      : () {},
                  enabled: _selected >= 0,
                  icon: Icons.send_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          _ProgressDots(total: 4, current: 4),
        ],
      ),
    );
  }
}

// ─── SUCCESS SCREEN ───────────────────────────────────────────────────────────
class _SuccessScreen extends StatelessWidget {
  final VoidCallback onDone;
  final Animation<double> checkScale;
  final Animation<double> checkOpacity;
  final Animation<double> successBounce;

  const _SuccessScreen({
    required this.onDone,
    required this.checkScale,
    required this.checkOpacity,
    required this.successBounce,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 40),
      child: Column(
        children: [
          // Animated Checkmark
          AnimatedBuilder(
            animation: checkScale,
            builder: (context, _) {
              return Opacity(
                opacity: checkOpacity.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: checkScale.value.clamp(0.0, 2.0),
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _RegColors.primary.withValues(alpha: 0.4),
                          blurRadius: 40,
                          spreadRadius: 5,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 58,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          // Confetti emoji row
          AnimatedBuilder(
            animation: successBounce,
            builder: (context, _) {
              return Opacity(
                opacity: successBounce.value.clamp(0.0, 1.0),
                child: Text(
                  '🎉 تم استلام طلب التسجيل',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _RegColors.text,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          AnimatedBuilder(
            animation: successBounce,
            builder: (context, _) {
              return Opacity(
                opacity: successBounce.value.clamp(0.0, 1.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _RegColors.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _RegColors.primaryBorder),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'شكرًا ليك ❤️',
                        style: _RegTextStyles.heading(18),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'تم استلام طلب التسجيل بنجاح.\n\nنتمنى نشوفك قريب ضمن طلاب زيرو وان أكاديمي 💚',
                        style: _RegTextStyles.body(
                          14,
                          color: const Color(0xFF5B21B6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          AnimatedBuilder(
            animation: successBounce,
            builder: (context, _) {
              return Opacity(
                opacity: successBounce.value.clamp(0.0, 1.0),
                child: _PrimaryButton(label: 'تم ✓', onTap: onDone),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── SHARED UI COMPONENTS ─────────────────────────────────────────────────────

/// Arabic Input Field with floating label
class _ArabicInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool hasError;
  final String? errorText;
  final void Function(String)? onChanged;

  const _ArabicInputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.hasError = false,
    this.errorText,
    this.onChanged,
  });

  @override
  State<_ArabicInputField> createState() => _ArabicInputFieldState();
}

class _ArabicInputFieldState extends State<_ArabicInputField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.hasError
        ? const Color(0xFFEF4444)
        : _isFocused
        ? _RegColors.primary
        : _RegColors.inputBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: _RegTextStyles.label(13)),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _RegColors.inputBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: _isFocused ? 2 : 1.5),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: _RegColors.primary.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Focus(
            onFocusChange: (v) => setState(() => _isFocused = v),
            child: TextField(
              controller: widget.controller,
              keyboardType: widget.keyboardType,
              onChanged: widget.onChanged,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _RegColors.text,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 15,
                  color: _RegColors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  widget.icon,
                  color: _isFocused ? _RegColors.primary : _RegColors.textMuted,
                  size: 22,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),
        if (widget.hasError && widget.errorText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 16,
              ),
              const SizedBox(width: 5),
              Text(
                widget.errorText!,
                style: _RegTextStyles.body(12, color: const Color(0xFFEF4444)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Large selectable card for grade/answer selection
class _SelectableCard extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableCard({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = _RegColors.primary;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accent : _RegColors.border,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.15),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Emoji
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            // Label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? accent : _RegColors.text,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accent : _RegColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 15,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact selectable card for days
class _CompactSelectableCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompactSelectableCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? _RegColors.primary.withValues(alpha: 0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _RegColors.primary : _RegColors.border,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _RegColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _RegColors.primary : _RegColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 13,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _RegColors.primary : _RegColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Time chip (small selectable pill)
class _TimeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TimeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _RegColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _RegColors.primary : _RegColors.border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _RegColors.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : _RegColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Big choice card for yes/no question
class _BigChoiceCard extends StatelessWidget {
  final String label;
  final String emoji;
  final String subtitle;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _BigChoiceCard({
    required this.label,
    required this.emoji,
    required this.subtitle,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? accentColor : _RegColors.border,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Emoji in circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.15)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? accentColor : _RegColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: _RegTextStyles.body(12)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accentColor : _RegColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Section label with icon
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _RegColors.primarySurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _RegColors.primary, size: 17),
        ),
        const SizedBox(width: 10),
        Text(label, style: _RegTextStyles.label(15, color: _RegColors.text)),
      ],
    );
  }
}

/// Progress dots at the bottom
class _ProgressDots extends StatelessWidget {
  final int total;
  final int current;

  const _ProgressDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i + 1 == current;
        final done = i + 1 < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: done || active
                ? _RegColors.primary
                : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}
