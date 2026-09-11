// lib/admin_dashboard.dart
// Admin Dashboard — Zero One Academy Experience & Survey Management
// Privacy-First Analytics, Non-Competitive Instructor Analysis, and Dynamic Engine

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_service.dart';
import 'web_utils.dart';

class _AC {
  static const bg = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const card = Color(0xFF263044);
  static const cardBorder = Color(0xFF334155);

  static const primary = Color(0xFF7C3AED);
  static const primaryLight = Color(0xFF9333EA);

  static const text = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);

  static const amber = Color(0xFFF59E0B);
  static const emerald = Color(0xFF10B981);
  static const red = Color(0xFFEF4444);
  static const blue = Color(0xFF3B82F6);
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  bool _unlocked = false;
  final _pinCtrl = TextEditingController();
  bool _pinError = false;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  static const _pin = '0101';

  // Active Tab: 0 = Overall Academy, 1 = Instructor Feedback, 2 = Dynamic Engine, 3 = Responses & Export
  int _currentTab = 0;

  List<Map<String, dynamic>> _responses = [];
  List<Map<String, dynamic>> _instructors = [];
  List<Map<String, dynamic>> _questions = [];

  StreamSubscription? _respSub;
  StreamSubscription? _instSub;
  StreamSubscription? _questSub;

  // Selected Instructor in Tab 1
  String? _selectedInstructorId;
  bool _instructorViewMode = false;

  // Monthly Filter — null means "All Time"
  String? _selectedMonth; // format: 'yyyy-MM'

  // Available months derived from responses (sorted descending)
  List<String> get _availableMonths {
    final months = <String>{};
    for (final r in _responses) {
      final ts = r['submittedAt'] as String? ?? '';
      if (ts.length >= 7) months.add(ts.substring(0, 7)); // 'yyyy-MM'
    }
    final list = months.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  // Filtered responses based on selected month
  List<Map<String, dynamic>> get _filteredResponses {
    if (_selectedMonth == null) return _responses;
    return _responses.where((r) {
      final ts = r['submittedAt'] as String? ?? '';
      return ts.startsWith(_selectedMonth!);
    }).toList();
  }

  // Arabic month label, e.g. '2025-09' → 'سبتمبر 2025'
  static String _monthLabel(String ym) {
    final parts = ym.split('-');
    if (parts.length < 2) return ym;
    final year = parts[0];
    const arabicMonths = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    final monthNum = int.tryParse(parts[1]) ?? 0;
    final name = (monthNum >= 1 && monthNum <= 12) ? arabicMonths[monthNum] : ym;
    return '$name $year';
  }

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  void _startStreams() {
    _respSub = FirebaseService.surveyResponsesStream().listen((list) {
      if (mounted) setState(() => _responses = list);
    });
    _instSub = FirebaseService.instructorsStream().listen((list) {
      if (mounted) {
        setState(() {
          _instructors = list;
          if (_selectedInstructorId == null && list.isNotEmpty) {
            _selectedInstructorId = list.first['id'];
          }
        });
      }
    });
    _questSub = FirebaseService.questionsStream().listen((list) {
      if (mounted) setState(() => _questions = list);
    });
  }

  @override
  void dispose() {
    _respSub?.cancel();
    _instSub?.cancel();
    _questSub?.cancel();
    _pinCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _tryPin() {
    if (_pinCtrl.text.trim() == _pin) {
      setState(() => _unlocked = true);
      _startStreams();
    } else {
      setState(() => _pinError = true);
      _shakeCtrl.forward(from: 0);
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _pinError = false);
      });
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Export CSV (Anonymous & Arabic UTF-8)
  // ───────────────────────────────────────────────────────────────────────────
  void _exportCSV() {
    final buffer = StringBuffer();
    // UTF-8 BOM so Excel opens Arabic correctly
    buffer.write('\uFEFF');
    buffer.writeln(
      'وقت الإرسال,تقييم المكان,تقييم المحتوى والشرح,اسم المدرب,وضوح الشرح,تبسيط المعلومات,التفاعل مع الطلاب,الإجابة عن الأسئلة,استخدام الأمثلة,المزايا المعجب بها,الاقتراحات,التوصية',
    );

    // Export only the currently filtered responses (respects month filter)
    for (final r in _filteredResponses) {
      final evals = r['evaluatedInstructors'] as List<dynamic>?;
      final liked = (r['likedFeatures'] as List<dynamic>? ?? []).join(' - ');
      final cleanText = (r['improvementFeedback'] ?? '').toString().replaceAll(',', ' ').replaceAll('\n', ' ');

      if (evals != null && evals.isNotEmpty) {
        for (final item in evals) {
          final instName = item['instructorName'] ?? '';
          final exp = item['teachingExperience'] as Map<String, dynamic>? ?? {};
          buffer.writeln(
            '${r['submittedAt'] ?? ''},'
            '${r['placeRating'] ?? ''},'
            '${r['contentRating'] ?? ''},'
            '"$instName",'
            '${exp['clarity'] ?? ''},'
            '${exp['simplification'] ?? ''},'
            '${exp['interaction'] ?? ''},'
            '${exp['answering'] ?? ''},'
            '${exp['examples'] ?? ''},'
            '"$liked",'
            '"$cleanText",'
            '"${r['recommendation'] ?? ''}"',
          );
        }
      } else {
        final exp = r['teachingExperience'] as Map<String, dynamic>? ?? {};
        buffer.writeln(
          '${r['submittedAt'] ?? ''},'
          '${r['placeRating'] ?? ''},'
          '${r['contentRating'] ?? ''},'
          '"${r['instructorName'] ?? ''}",'
          '${exp['clarity'] ?? ''},'
          '${exp['simplification'] ?? ''},'
          '${exp['interaction'] ?? ''},'
          '${exp['answering'] ?? ''},'
          '${exp['examples'] ?? ''},'
          '"$liked",'
          '"$cleanText",'
          '"${r['recommendation'] ?? ''}"',
        );
      }
    }

    final suffix = _selectedMonth != null
        ? '_${_selectedMonth!}'
        : '_${DateTime.now().millisecondsSinceEpoch}';
    final filename = 'zero_one_survey$suffix.csv';
    downloadCsvFile(filename, buffer.toString());
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _AC.bg,
        body: !_unlocked ? _buildPinGate() : _buildDashboardBody(),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PIN Gate
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPinGate() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: AnimatedBuilder(
            animation: _shakeAnim,
            builder: (context, child) => Transform.translate(
              offset: Offset(_shakeAnim.value, 0),
              child: child,
            ),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _AC.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _AC.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _AC.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, size: 48, color: _AC.primaryLight),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'لوحة تحكم الإدارة',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _AC.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Zero One Academy — استطلاع رأي الطلاب',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      color: _AC.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pinCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 24,
                      letterSpacing: 10,
                      fontWeight: FontWeight.bold,
                      color: _AC.text,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••',
                      hintStyle: TextStyle(color: _AC.textMuted, letterSpacing: 8),
                      filled: true,
                      fillColor: _AC.card,
                      errorText: _pinError ? 'الرمز السري غير صحيح' : null,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: _AC.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: _AC.primaryLight, width: 2),
                      ),
                    ),
                    onSubmitted: (_) => _tryPin(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _tryPin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _AC.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'دخول',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Dashboard Body
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDashboardBody() {
    return Column(
      children: [
        // App Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _AC.surface,
            border: Border(bottom: BorderSide(color: _AC.cardBorder)),
          ),
          child: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/logo.jpg',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, color: _AC.primaryLight),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'لوحة تحكم الأكاديمية',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _AC.text,
                    ),
                  ),
                  Text(
                    'تحليل تجربة الطلاب واستطلاعات الرأي',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      color: _AC.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Month filter chip row
              if (_availableMonths.isNotEmpty) ...
                [
                  _buildMonthChip(null, 'الكل'),
                  ..._availableMonths.map((m) => _buildMonthChip(m, _monthLabel(m))),
                  const SizedBox(width: 10),
                ],
              ElevatedButton.icon(
                onPressed: _exportCSV,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: Text(
                  _selectedMonth == null
                      ? 'تصدير CSV'
                      : 'تصدير ${_monthLabel(_selectedMonth!)}',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AC.card,
                  foregroundColor: _AC.text,
                  elevation: 0,
                  side: BorderSide(color: _AC.cardBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: _AC.textMuted, size: 20),
                tooltip: 'قفل اللوحة',
                onPressed: () => setState(() => _unlocked = false),
              ),
            ],
          ),
        ),

        // Navigation Tabs Bar
        Container(
          color: _AC.surface,
          child: Row(
            children: [
              _buildTabButton(0, 'إحصائيات الأكاديمية', Icons.insights_rounded),
              _buildTabButton(1, 'واجهة المدرب (Instructor View)', Icons.person_rounded),
              _buildTabButton(2, 'المدربين والأسئلة', Icons.tune_rounded),
              _buildTabButton(3, 'الردود المجهولة (${_filteredResponses.length})', Icons.list_alt_rounded),
            ],
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: _buildTabContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? _AC.primaryLight : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? _AC.primaryLight : _AC.textMuted),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? _AC.text : _AC.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Month Filter Chip Helper
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMonthChip(String? month, String label) {
    final isSelected = _selectedMonth == month;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _selectedMonth = month),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? _AC.primary : _AC.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? _AC.primaryLight : _AC.cardBorder,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : _AC.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0:
        return _buildOverallAcademyTab();
      case 1:
        return _buildInstructorFeedbackTab();
      case 2:
        return _buildDynamicEngineTab();
      case 3:
        return _buildResponsesTab();
      default:
        return const SizedBox();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 0: Overall Academy Statistics (Requirement 16)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildOverallAcademyTab() {
    final responses = _filteredResponses;
    final count = responses.length;

    double totalPlace = 0;
    double totalContent = 0;
    int recommendYes = 0;
    int recommendMaybe = 0;
    int recommendNo = 0;

    final placeDist = [0, 0, 0, 0, 0]; // 1 to 5 stars

    final List<String> suggestions = [];

    for (final r in responses) {
      final p = (r['placeRating'] as num? ?? 0).toInt();
      final c = (r['contentRating'] as num? ?? 0).toDouble();
      totalPlace += p;
      totalContent += c;

      if (p >= 1 && p <= 5) {
        placeDist[p - 1]++;
      }

      final rec = r['recommendation'] as String? ?? '';
      if (rec == 'أكيد') recommendYes++;
      if (rec == 'ممكن') recommendMaybe++;
      if (rec == 'مش حاليًا') recommendNo++;

      final sug = (r['improvementFeedback'] as String? ?? '').trim();
      if (sug.isNotEmpty) suggestions.add(sug);
    }

    final avgPlace = count > 0 ? totalPlace / count : 0.0;
    final avgContent = count > 0 ? totalContent / count : 0.0;
    final recRate = count > 0 ? ((recommendYes + recommendMaybe) / count) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active month banner
        if (_selectedMonth != null) ...
          [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _AC.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _AC.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: _AC.primaryLight, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'عرض نتائج شهر: ${_monthLabel(_selectedMonth!)} — $count استطلاع',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      color: _AC.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => setState(() => _selectedMonth = null),
                    child: Text(
                      'عرض الكل',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        color: _AC.primaryLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        // Metric KPI Cards
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                title: 'إجمالي التقييمات',
                value: '$count',
                icon: Icons.people_alt_rounded,
                color: _AC.blue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildKPICard(
                title: 'متوسط تقييم المكان',
                value: '${avgPlace.toStringAsFixed(1)} ⭐',
                icon: Icons.location_on_rounded,
                color: _AC.emerald,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildKPICard(
                title: 'متوسط المحتوى والشرح',
                value: '${avgContent.toStringAsFixed(1)} ⭐',
                icon: Icons.menu_book_rounded,
                color: _AC.primaryLight,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildKPICard(
                title: 'نسبة التوصية',
                value: '${recRate.toStringAsFixed(0)}%',
                icon: Icons.thumb_up_alt_rounded,
                color: _AC.amber,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Distribution & Recommendations
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rating Distribution
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _AC.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _AC.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'توزيع تقييمات المكان',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _AC.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (int star = 5; star >= 1; star--) ...[
                      _buildDistRow(star, placeDist[star - 1], count),
                      if (star > 1) const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(width: 18),

            // Recommendation breakdown
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _AC.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _AC.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تفاصيل التوصية بالأكاديمية',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _AC.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildRecRow('👍 أكيد', recommendYes, count, _AC.emerald),
                    const SizedBox(height: 12),
                    _buildRecRow('😐 ممكن', recommendMaybe, count, _AC.amber),
                    const SizedBox(height: 12),
                    _buildRecRow('👎 مش حاليًا', recommendNo, count, _AC.red),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Student Suggestions Wall
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _AC.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _AC.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('💡', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'حائط اقتراحات وملاحظات الطلاب',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _AC.text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${suggestions.length} اقتراح مجهول',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      color: _AC.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (suggestions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _AC.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'لا توجد مقترحات مسجلة حتى الآن.',
                    style: GoogleFonts.ibmPlexSansArabic(color: _AC.textMuted),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: suggestions.length.clamp(0, 10),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _AC.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _AC.cardBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✍️', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            suggestions[i],
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              height: 1.6,
                              color: _AC.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 1: Instructor Feedback (Strictly No-Comparison - Requirement 13 & 16)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildInstructorFeedbackTab() {
    if (_instructors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Text(
          'لم يتم إضافة مدربين بعد.',
          style: GoogleFonts.ibmPlexSansArabic(color: _AC.textMuted),
        ),
      );
    }

    final selectedInst = _instructors.firstWhere(
      (i) => i['id'] == _selectedInstructorId,
      orElse: () => _instructors.first,
    );

    final instResponses = _filteredResponses.where((r) {
      final evals = r['evaluatedInstructors'] as List<dynamic>?;
      if (evals != null && evals.isNotEmpty) {
        return evals.any((e) =>
            e['instructorId'] == selectedInst['id'] ||
            e['instructorName'] == selectedInst['name']);
      }
      return r['instructorId'] == selectedInst['id'] ||
          r['instructorName'] == selectedInst['name'];
    }).toList();

    double claritySum = 0;
    double simplSum = 0;
    double interSum = 0;
    double ansSum = 0;
    double exSum = 0;
    final List<String> instSuggestions = [];

    for (final r in instResponses) {
      Map<String, dynamic> exp = {};
      final evals = r['evaluatedInstructors'] as List<dynamic>?;
      if (evals != null && evals.isNotEmpty) {
        final match = evals.firstWhere(
          (e) =>
              e['instructorId'] == selectedInst['id'] ||
              e['instructorName'] == selectedInst['name'],
          orElse: () => null,
        );
        if (match != null && match['teachingExperience'] is Map) {
          exp = Map<String, dynamic>.from(match['teachingExperience']);
        }
      }
      if (exp.isEmpty) {
        exp = r['teachingExperience'] as Map<String, dynamic>? ?? {};
      }

      claritySum += (exp['clarity'] as num? ?? 0).toDouble();
      simplSum += (exp['simplification'] as num? ?? 0).toDouble();
      interSum += (exp['interaction'] as num? ?? 0).toDouble();
      ansSum += (exp['answering'] as num? ?? 0).toDouble();
      exSum += (exp['examples'] as num? ?? 0).toDouble();

      final sug = (r['improvementFeedback'] as String? ?? '').trim();
      if (sug.isNotEmpty) instSuggestions.add(sug);
    }

    final count = instResponses.length;
    final avgClarity = count > 0 ? claritySum / count : 0.0;
    final avgSimpl = count > 0 ? simplSum / count : 0.0;
    final avgInter = count > 0 ? interSum / count : 0.0;
    final avgAns = count > 0 ? ansSum / count : 0.0;
    final avgEx = count > 0 ? exSum / count : 0.0;

    final overall = (avgClarity + avgSimpl + avgInter + avgAns + avgEx) / 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Notice enforcing non-competitive design principle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _AC.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _AC.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: _AC.primaryLight, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'نظام تقييم تجربة التعلم يركز على تطوير تجربة الشرح لكل مدرب بشكل منفصل ومحايد، وبدون عمل مقارنات أو ترتيب تنافسي.',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    color: _AC.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Instructor Picker & Mode Switcher
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'اختر المدرب:',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _AC.text,
                  ),
                ),
                const SizedBox(width: 14),
                Wrap(
                  spacing: 8,
                  children: _instructors.map((inst) {
                    final isSelected = inst['id'] == _selectedInstructorId;
                    return ChoiceChip(
                      label: Text(inst['name'] ?? ''),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedInstructorId = inst['id']),
                      selectedColor: _AC.primary,
                      backgroundColor: _AC.surface,
                      labelStyle: GoogleFonts.ibmPlexSansArabic(
                        color: isSelected ? Colors.white : _AC.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      side: BorderSide(color: isSelected ? _AC.primary : _AC.cardBorder),
                    );
                  }).toList(),
                ),
              ],
            ),

            // Mode switcher: Full Admin vs Instructor View
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _AC.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _AC.cardBorder),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => setState(() => _instructorViewMode = false),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: !_instructorViewMode ? _AC.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'عرض الإدارة الكامل',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          fontWeight: !_instructorViewMode ? FontWeight.w700 : FontWeight.w500,
                          color: !_instructorViewMode ? Colors.white : _AC.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _instructorViewMode = true),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _instructorViewMode ? _AC.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.remove_red_eye_outlined, size: 14, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            'معاينة شاشة المدرب',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              fontWeight: _instructorViewMode ? FontWeight.w700 : FontWeight.w500,
                              color: _instructorViewMode ? Colors.white : _AC.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        if (_instructorViewMode && count < 3)
          // Threshold view as seen by instructor
          Container(
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: _AC.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _AC.cardBorder),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _AC.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_clock_rounded, size: 48, color: _AC.primaryLight),
                ),
                const SizedBox(height: 18),
                Text(
                  'حماية خصوصية الطلاب (Instructor Threshold View)',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _AC.text,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'سيتم عرض النتائج بعد وصول عدد كافٍ من التقييمات لضمان خصوصية الطلاب.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    height: 1.6,
                    color: _AC.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _AC.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _AC.cardBorder),
                  ),
                  child: Text(
                    'التقييمات الحالية: $count / 3 كحد أدنى لفك الحجب عن المدرب',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      color: _AC.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          // Selected Instructor Report
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _AC.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _AC.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('👨‍🏫', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedInst['name'] ?? '',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _AC.text,
                            ),
                          ),
                          Text(
                            'إجمالي التقييمات: $count تقييم مجهول',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              color: _AC.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _AC.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _AC.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Text(
                          overall.toStringAsFixed(1),
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _AC.text,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('⭐ / 5', style: TextStyle(color: _AC.amber, fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(color: _AC.cardBorder),
              const SizedBox(height: 20),

              // 5 Teaching Dimensions
              Text(
                'عناصر تجربة الشرح',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _AC.text,
                ),
              ),
              const SizedBox(height: 16),
              _buildMetricBarDetailed('وضوح الشرح', avgClarity),
              const SizedBox(height: 14),
              _buildMetricBarDetailed('تبسيط المعلومات', avgSimpl),
              const SizedBox(height: 14),
              _buildMetricBarDetailed('التفاعل مع الطلاب', avgInter),
              const SizedBox(height: 14),
              _buildMetricBarDetailed('الإجابة عن الأسئلة', avgAns),
              const SizedBox(height: 14),
              _buildMetricBarDetailed('استخدام الأمثلة والتطبيقات', avgEx),

              const SizedBox(height: 28),

              // Specific Suggestions for this instructor
              Text(
                'ملاحظات واقتراحات الطلاب الخاصة بالمدرب',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _AC.text,
                ),
              ),
              const SizedBox(height: 12),
              if (instSuggestions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _AC.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'لا توجد تعليقات نصية مكتوبة لهذا المدرب.',
                    style: GoogleFonts.ibmPlexSansArabic(color: _AC.textMuted),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: instSuggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _AC.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _AC.cardBorder),
                    ),
                    child: Text(
                      instSuggestions[idx],
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        color: _AC.text,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 2: Dynamic Engine Management (Requirement 17 & 18)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDynamicEngineTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Instructors Management Section
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _AC.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _AC.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('👨‍🏫', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Text(
                        'إدارة قائمة الـInstructors',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _AC.text,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddInstructorDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      'إضافة مدرب',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AC.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_instructors.isEmpty)
                Text('لا يوجد مدربين مسجلين.', style: GoogleFonts.ibmPlexSansArabic(color: _AC.textMuted))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _instructors.length,
                  separatorBuilder: (_, __) => const Divider(color: _AC.cardBorder, height: 16),
                  itemBuilder: (_, idx) {
                    final inst = _instructors[idx];
                    final isActive = inst['isActive'] ?? true;
                    return Row(
                      children: [
                        const Icon(Icons.drag_indicator_rounded, color: _AC.textMuted, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            inst['name'] ?? '',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isActive ? _AC.text : _AC.textMuted,
                            ),
                          ),
                        ),
                        // Toggle Active
                        Switch(
                          value: isActive,
                          activeThumbColor: _AC.primaryLight,
                          onChanged: (val) {
                            FirebaseService.updateInstructor(inst['id'], isActive: val);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: _AC.textSecondary, size: 18),
                          tooltip: 'تعديل الاسم',
                          onPressed: () => _showEditInstructorDialog(inst),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: _AC.red, size: 18),
                          tooltip: 'حذف',
                          onPressed: () => _confirmDeleteInstructor(inst),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Custom Questions Engine (Item 17 & 18)
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _AC.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _AC.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('⚙️', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Text(
                        'إدارة وتخصيص أسئلة الاستبيان (Survey Engine)',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _AC.text,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddQuestionDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      'إضافة سؤال ديناميكي',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AC.card,
                      foregroundColor: _AC.text,
                      side: BorderSide(color: _AC.cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'الأسئلة الأساسية (المكان، المحتوى، تجربة الشرح، التوصية) تعمل بشكل افتراضي. يمكنك إضافة أسئلة فرعية ديناميكية حسب الحاجة.',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  color: _AC.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (_questions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _AC.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'الأسئلة الأساسية مفعلة. لا توجد أسئلة ديناميكية إضافية مضافة حاليًا.',
                    style: GoogleFonts.ibmPlexSansArabic(color: _AC.textMuted),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _questions.length,
                  separatorBuilder: (_, __) => const Divider(color: _AC.cardBorder, height: 16),
                  itemBuilder: (_, idx) {
                    final q = _questions[idx];
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _AC.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            q['type'] ?? 'Rating 1-5',
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: _AC.primaryLight),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            q['title'] ?? '',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _AC.text,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: _AC.red, size: 18),
                          onPressed: () => FirebaseService.deleteQuestion(q['id']),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 3: Anonymous Responses List (Requirement 1 & 16)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildResponsesTab() {
    final responses = _filteredResponses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedMonth == null
                  ? 'سجل الاستطلاعات المجهولة (بدون أي بيانات تعريفية)'
                  : 'استطلاعات ${_monthLabel(_selectedMonth!)} — ${responses.length} رد مجهول',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _AC.text,
              ),
            ),
            TextButton.icon(
              onPressed: _confirmClearAll,
              icon: const Icon(Icons.delete_sweep_rounded, color: _AC.red, size: 18),
              label: Text(
                'تفريغ الردود (للاختبار)',
                style: GoogleFonts.ibmPlexSansArabic(color: _AC.red, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (responses.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _AC.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _selectedMonth == null
                  ? 'لا توجد ردود مسجلة بعد.'
                  : 'لا توجد ردود لشهر ${_monthLabel(_selectedMonth!)}.',
              style: GoogleFonts.ibmPlexSansArabic(color: _AC.textMuted),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: responses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, idx) {
              final r = responses[idx];
              final exp = r['teachingExperience'] as Map<String, dynamic>? ?? {};
              final liked = (r['likedFeatures'] as List<dynamic>? ?? []).join('، ');

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _AC.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _AC.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🔒', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              'رد مجهول #${responses.length - idx}',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _AC.text,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          r['submittedAt'] != null
                              ? r['submittedAt'].toString().split('T').first
                              : '',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            color: _AC.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildTag('المكان', '${r['placeRating'] ?? 0} ⭐'),
                        _buildTag('المحتوى', '${r['contentRating'] ?? 0} ⭐'),
                        _buildTag('المدرب', r['instructorName'] ?? '—'),
                        _buildTag('التوصية', r['recommendation'] ?? '—'),
                        if (exp.isNotEmpty)
                          _buildTag('الوضوح', '${exp['clarity'] ?? 0} ⭐'),
                      ],
                    ),
                    if (liked.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'عجبه: $liked',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          color: _AC.textSecondary,
                        ),
                      ),
                    ],
                    if ((r['improvementFeedback'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _AC.card,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'اقتراح: ${r['improvementFeedback']}',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            color: _AC.emerald,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Helper Widgets & Dialogs
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _AC.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _AC.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: _AC.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _AC.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistRow(int star, int count, int total) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        Text(
          '$star ⭐',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13,
            color: _AC.amber,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: _AC.card,
              valueColor: const AlwaysStoppedAnimation<Color>(_AC.amber),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$count (${(pct * 100).toStringAsFixed(0)}%)',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: _AC.textMuted),
        ),
      ],
    );
  }

  Widget _buildRecRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: _AC.text),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: _AC.card,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$count (${(pct * 100).toStringAsFixed(0)}%)',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: _AC.textMuted),
        ),
      ],
    );
  }

  Widget _buildMetricBarDetailed(String label, double val) {
    final pct = (val / 5.0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14,
                color: _AC.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 15, color: _AC.amber),
                const SizedBox(width: 4),
                Text(
                  '${val.toStringAsFixed(1)} / 5',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    color: _AC.amber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: _AC.card,
            valueColor: const AlwaysStoppedAnimation<Color>(_AC.primaryLight),
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String title, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _AC.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$title: $val',
        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: _AC.textSecondary),
      ),
    );
  }

  // Dialogs
  void _showAddInstructorDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _AC.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('إضافة مدرب جديد', style: GoogleFonts.ibmPlexSansArabic(color: _AC.text)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: GoogleFonts.ibmPlexSansArabic(color: _AC.text),
            decoration: InputDecoration(
              hintText: 'مثال: المهندس محمد',
              hintStyle: TextStyle(color: _AC.textMuted),
              filled: true,
              fillColor: _AC.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: _AC.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = ctrl.text.trim();
                if (name.isNotEmpty) {
                  await FirebaseService.addInstructor(name);
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _AC.primary),
              child: Text('إضافة', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditInstructorDialog(Map<String, dynamic> inst) {
    final ctrl = TextEditingController(text: inst['name'] ?? '');
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _AC.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('تعديل اسم المدرب', style: GoogleFonts.ibmPlexSansArabic(color: _AC.text)),
          content: TextField(
            controller: ctrl,
            style: GoogleFonts.ibmPlexSansArabic(color: _AC.text),
            decoration: InputDecoration(
              filled: true,
              fillColor: _AC.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: _AC.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = ctrl.text.trim();
                if (name.isNotEmpty) {
                  await FirebaseService.updateInstructor(inst['id'], name: name);
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _AC.primary),
              child: Text('حفظ', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteInstructor(Map<String, dynamic> inst) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _AC.surface,
          title: Text('حذف المدرب', style: GoogleFonts.ibmPlexSansArabic(color: _AC.red)),
          content: Text(
            'هل أنت متأكد من حذف "${inst['name']}" من قائمة الاستطلاع؟',
            style: GoogleFonts.ibmPlexSansArabic(color: _AC.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: _AC.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseService.deleteInstructor(inst['id']);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _AC.red),
              child: Text('حذف', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddQuestionDialog() {
    final titleCtrl = TextEditingController();
    String selectedType = 'Rating 1-5';
    bool isReq = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _AC.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('إضافة سؤال استبيان جديد', style: GoogleFonts.ibmPlexSansArabic(color: _AC.text)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('عنوان السؤال:', style: GoogleFonts.ibmPlexSansArabic(color: _AC.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    style: GoogleFonts.ibmPlexSansArabic(color: _AC.text),
                    decoration: InputDecoration(
                      hintText: 'اكتب نص السؤال هنا...',
                      hintStyle: TextStyle(color: _AC.textMuted),
                      filled: true,
                      fillColor: _AC.card,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('نوع السؤال:', style: GoogleFonts.ibmPlexSansArabic(color: _AC.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    dropdownColor: _AC.card,
                    style: GoogleFonts.ibmPlexSansArabic(color: _AC.text),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _AC.card,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Rating 1-5', child: Text('تقييم 1 إلى 5 ⭐')),
                      DropdownMenuItem(value: 'Single Choice', child: Text('اختيار مفرد')),
                      DropdownMenuItem(value: 'Multiple Choice', child: Text('اختيار متعدد')),
                      DropdownMenuItem(value: 'Text Area', child: Text('مساحة نصية')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isReq,
                        activeColor: _AC.primary,
                        onChanged: (val) => setDialogState(() => isReq = val ?? false),
                      ),
                      Text('سؤال إجباري', style: GoogleFonts.ibmPlexSansArabic(color: _AC.text, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: _AC.textMuted)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  if (title.isNotEmpty) {
                    await FirebaseService.saveQuestion({
                      'title': title,
                      'type': selectedType,
                      'isRequired': isReq,
                      'createdAt': DateTime.now().toIso8601String(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _AC.primary),
                child: Text('إضافة', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _AC.surface,
          title: Text('تفريغ كافة الردود', style: GoogleFonts.ibmPlexSansArabic(color: _AC.red)),
          content: Text(
            'هل أنت متأكد من حذف جميع استطلاعات الطلاب؟ هذا الإجراء لا يمكن التراجع عنه ويستخدم للاختبار.',
            style: GoogleFonts.ibmPlexSansArabic(color: _AC.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: _AC.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseService.clearAllResponses();
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _AC.red),
              child: Text('مسح الكل', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
