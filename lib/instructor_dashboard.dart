// lib/instructor_dashboard.dart
// Zero One Academy — Instructor Feedback View
// Private, isolated teaching experience metrics with privacy threshold protection

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_service.dart';

class _IC {
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
}

class InstructorDashboard extends StatefulWidget {
  final String? initialInstructorId;

  const InstructorDashboard({super.key, this.initialInstructorId});

  @override
  State<InstructorDashboard> createState() => _InstructorDashboardState();
}

class _InstructorDashboardState extends State<InstructorDashboard> {
  List<Map<String, dynamic>> _instructors = [];
  List<Map<String, dynamic>> _allResponses = [];
  String? _selectedInstructorId;
  String? _selectedInstructorName;

  StreamSubscription? _instSub;
  StreamSubscription? _respSub;

  // Minimum Response Threshold to protect student anonymity (Item 15)
  static const int minThreshold = 3;

  @override
  void initState() {
    super.initState();
    _startStreams();
  }

  void _startStreams() {
    _instSub = FirebaseService.instructorsStream().listen((list) {
      if (mounted) {
        setState(() {
          _instructors = list;
          if (_selectedInstructorId == null && list.isNotEmpty) {
            final target = widget.initialInstructorId != null
                ? list.firstWhere(
                    (i) => i['id'] == widget.initialInstructorId,
                    orElse: () => list.first,
                  )
                : list.first;
            _selectedInstructorId = target['id'];
            _selectedInstructorName = target['name'];
          }
        });
      }
    });

    _respSub = FirebaseService.surveyResponsesStream().listen((responses) {
      if (mounted) {
        setState(() => _allResponses = responses);
      }
    });
  }

  @override
  void dispose() {
    _instSub?.cancel();
    _respSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter responses for selected instructor ONLY
    final instructorResponses = _allResponses.where((r) {
      final idMatch = r['instructorId'] == _selectedInstructorId;
      final nameMatch = _selectedInstructorName != null &&
          (r['instructorName'] ?? '') == _selectedInstructorName;
      return idMatch || nameMatch;
    }).toList();

    final responseCount = instructorResponses.length;
    final meetsThreshold = responseCount >= minThreshold;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _IC.bg,
        appBar: AppBar(
          backgroundColor: _IC.surface,
          elevation: 0,
          title: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/logo.jpg',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.school_rounded,
                    color: _IC.primaryLight,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'تقرير تجربة الشرح للمدرب',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _IC.text,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _IC.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _IC.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: _IC.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'بيانات مجمعة وسرية',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      color: _IC.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instructor Selector
                  _buildInstructorSelector(),
                  const SizedBox(height: 24),

                  if (!meetsThreshold)
                    // Privacy Threshold Protection Card (Requirement 15)
                    _buildThresholdProtectedView(responseCount)
                  else
                    // Full Anonymous Aggregated Report (Requirement 14)
                    _buildFullReport(instructorResponses),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructorSelector() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _IC.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _IC.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اختر حساب المدرب:',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14,
              color: _IC.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _selectedInstructorId,
            dropdownColor: _IC.surface,
            decoration: InputDecoration(
              filled: true,
              fillColor: _IC.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _IC.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _IC.primaryLight),
              ),
            ),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _IC.text,
            ),
            items: _instructors.map((inst) {
              return DropdownMenuItem<String>(
                value: inst['id'] as String,
                child: Row(
                  children: [
                    const Text('👨‍🏫', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(inst['name'] ?? ''),
                  ],
                ),
              );
            }).toList(),
            onChanged: (newId) {
              if (newId != null) {
                final match = _instructors.firstWhere((i) => i['id'] == newId);
                setState(() {
                  _selectedInstructorId = newId;
                  _selectedInstructorName = match['name'];
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Threshold View (When responses < 3 to ensure anonymity)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildThresholdProtectedView(int currentCount) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _IC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _IC.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _IC.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_clock_rounded,
              size: 48,
              color: _IC.primaryLight,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'حماية خصوصية الطلاب',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _IC.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'سيتم عرض النتائج بعد وصول عدد كافٍ من التقييمات لضمان خصوصية الطلاب.',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 15,
              height: 1.6,
              color: _IC.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _IC.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _IC.cardBorder),
            ),
            child: Text(
              'التقييمات الحالية: $currentCount / $minThreshold كحد أدنى',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                color: _IC.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Full Report (When threshold met)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFullReport(List<Map<String, dynamic>> responses) {
    double totalClarity = 0;
    double totalSimplification = 0;
    double totalInteraction = 0;
    double totalAnswering = 0;
    double totalExamples = 0;
    int count = responses.length;

    final List<String> suggestions = [];

    for (final r in responses) {
      final exp = r['teachingExperience'] as Map<String, dynamic>? ?? {};
      totalClarity += (exp['clarity'] as num? ?? 0).toDouble();
      totalSimplification += (exp['simplification'] as num? ?? 0).toDouble();
      totalInteraction += (exp['interaction'] as num? ?? 0).toDouble();
      totalAnswering += (exp['answering'] as num? ?? 0).toDouble();
      totalExamples += (exp['examples'] as num? ?? 0).toDouble();

      final sug = (r['improvementFeedback'] as String? ?? '').trim();
      if (sug.isNotEmpty) suggestions.add(sug);
    }

    final avgClarity = count > 0 ? totalClarity / count : 0.0;
    final avgSimplification = count > 0 ? totalSimplification / count : 0.0;
    final avgInteraction = count > 0 ? totalInteraction / count : 0.0;
    final avgAnswering = count > 0 ? totalAnswering / count : 0.0;
    final avgExamples = count > 0 ? totalExamples / count : 0.0;

    final overallExp = (avgClarity + avgSimplification + avgInteraction + avgAnswering + avgExamples) / 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Overview Banner
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4C1D95), Color(0xFF6D28D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _IC.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تجربة الشرح الإجمالية',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        overallExp.toStringAsFixed(1),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '⭐ / 5',
                        style: TextStyle(
                          fontSize: 18,
                          color: _IC.amber,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      '$count',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'تقييم مجهول',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 5 Teaching Dimensions Cards
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _IC.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _IC.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تفاصيل تجربة الشرح',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _IC.text,
                ),
              ),
              const SizedBox(height: 18),
              _buildMetricBar('وضوح الشرح', avgClarity),
              const SizedBox(height: 14),
              _buildMetricBar('تبسيط المعلومات', avgSimplification),
              const SizedBox(height: 14),
              _buildMetricBar('التفاعل مع الطلاب', avgInteraction),
              const SizedBox(height: 14),
              _buildMetricBar('الإجابة عن الأسئلة', avgAnswering),
              const SizedBox(height: 14),
              _buildMetricBar('استخدام الأمثلة والتطبيقات', avgExamples),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Anonymous Suggestions Section
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _IC.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _IC.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('💡', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'اقتراحات الطلاب',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _IC.text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'تعليقات مجهولة ومجمعة',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      color: _IC.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (suggestions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _IC.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'لا توجد اقتراحات مكتوبة بعد.',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14,
                      color: _IC.textMuted,
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, idx) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _IC.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _IC.cardBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💬', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              suggestions[idx],
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 14,
                                height: 1.6,
                                color: _IC.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBar(String label, double value) {
    final pct = (value / 5.0).clamp(0.0, 1.0);
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
                color: _IC.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 16, color: _IC.amber),
                const SizedBox(width: 4),
                Text(
                  '${value.toStringAsFixed(1)} / 5',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    color: _IC.amber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: _IC.card,
            valueColor: const AlwaysStoppedAnimation<Color>(_IC.primaryLight),
          ),
        ),
      ],
    );
  }
}
