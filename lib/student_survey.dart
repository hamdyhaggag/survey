// lib/student_survey.dart
// Zero One Academy — Student Experience Survey
// 100% Anonymous Feedback Flow

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_service.dart';

// ─── Theme & Colors ──────────────────────────────────────────────────────────
class _SurveyColors {
  static const Color primary = Color(0xFF7C3AED);
  static const Color primarySurface = Color(0xFFF5F3FF);
  static const Color primaryBorder = Color(0xFFDDD6FE);

  static const Color amber = Color(0xFFF59E0B);

  static const Color bg = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE2E8F0);

  static const Color text = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
}

class StudentSurvey extends StatefulWidget {
  const StudentSurvey({super.key});

  @override
  State<StudentSurvey> createState() => _StudentSurveyState();
}

class _StudentSurveyState extends State<StudentSurvey> {
  // Survey State
  bool _hasStarted = false;
  bool _isSubmitted = false;
  bool _isSubmitting = false;

  // Answers State (Strictly Anonymous)
  int _placeRating = 0; // 1 - 5
  int _contentRating = 0; // 1 - 5

  // Multi-instructor Selection & Ratings State
  final Set<String> _selectedInstructorIds = {};
  final Map<String, Map<String, int>> _instructorRatings = {};

  // Multiple Choice - Liked Features
  final Set<String> _likedFeatures = {};
  static const List<Map<String, String>> _likedOptions = [
    {'icon': '🎓', 'label': 'الشرح'},
    {'icon': '📚', 'label': 'المحتوى'},
    {'icon': '💻', 'label': 'التطبيق العملي'},
    {'icon': '🏫', 'label': 'المكان'},
    {'icon': '👨‍🏫', 'label': 'أسلوب الشرح'},
    {'icon': '❤️', 'label': 'التجربة بشكل عام'},
  ];

  // Suggestions
  final TextEditingController _improvementController = TextEditingController();

  // Recommendation
  String? _recommendation; // 'مش حاليًا', 'ممكن', 'أكيد'

  // Dynamic Instructors List
  List<Map<String, dynamic>> _instructors = [];
  bool _loadingInstructors = true;

  @override
  void initState() {
    super.initState();
    _loadInstructors();
  }

  void _loadInstructors() {
    FirebaseService.instructorsStream().listen((list) {
      if (mounted) {
        setState(() {
          _instructors = list.where((inst) => inst['isActive'] == true).toList();
          _loadingInstructors = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _improvementController.dispose();
    super.dispose();
  }

  bool _areInstructorsValid() {
    if (_selectedInstructorIds.isEmpty) return false;
    for (final id in _selectedInstructorIds) {
      final r = _instructorRatings[id];
      if (r == null) return false;
      if ((r['clarity'] ?? 0) == 0 ||
          (r['simplification'] ?? 0) == 0 ||
          (r['interaction'] ?? 0) == 0 ||
          (r['answering'] ?? 0) == 0 ||
          (r['examples'] ?? 0) == 0) {
        return false;
      }
    }
    return true;
  }

  // Check how many required sections are answered
  double _calculateProgress() {
    int total = 4; // Place, Content, Instructors + Teaching, Recommendation
    int done = 0;
    if (_placeRating > 0) done++;
    if (_contentRating > 0) done++;
    if (_areInstructorsValid()) done++;
    if (_recommendation != null) done++;
    return done / total;
  }

  bool _isFormValid() {
    return _placeRating > 0 &&
        _contentRating > 0 &&
        _areInstructorsValid() &&
        _recommendation != null;
  }

  Future<void> _submitSurvey() async {
    if (!_isFormValid() || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    // Prepare evaluated instructors list
    final evaluatedInstructors = _selectedInstructorIds.map((id) {
      final inst = _instructors.firstWhere((i) => i['id'] == id, orElse: () => {'name': ''});
      return {
        'instructorId': id,
        'instructorName': inst['name'] ?? '',
        'teachingExperience': Map<String, int>.from(_instructorRatings[id] ?? {}),
      };
    }).toList();

    final firstEval = evaluatedInstructors.isNotEmpty ? evaluatedInstructors.first : null;

    // Prepare clean anonymous payload
    final responsePayload = {
      'placeRating': _placeRating,
      'contentRating': _contentRating,
      'evaluatedInstructors': evaluatedInstructors,
      // Backwards compatibility fields
      'instructorId': firstEval?['instructorId'] ?? '',
      'instructorName': evaluatedInstructors.map((e) => e['instructorName']).join('، '),
      'teachingExperience': firstEval?['teachingExperience'] ?? {},
      'likedFeatures': _likedFeatures.toList(),
      'improvementFeedback': _improvementController.text.trim(),
      'recommendation': _recommendation,
      'submittedAt': DateTime.now().toIso8601String(),
    };

    await FirebaseService.submitSurveyResponse(responsePayload);

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
      });
    }
  }

  void _resetSurvey() {
    setState(() {
      _hasStarted = false;
      _isSubmitted = false;
      _isSubmitting = false;
      _placeRating = 0;
      _contentRating = 0;
      _selectedInstructorIds.clear();
      _instructorRatings.clear();
      _likedFeatures.clear();
      _improvementController.clear();
      _recommendation = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _SurveyColors.bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: !_hasStarted
                    ? _buildWelcomeScreen()
                    : _isSubmitted
                        ? _buildSuccessScreen()
                        : _buildSurveyForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. Welcome & Privacy Screen
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildWelcomeScreen() {
    return SingleChildScrollView(
      key: const ValueKey('welcome_screen'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Academy Logo & Badge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _SurveyColors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _SurveyColors.primary.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.jpg',
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.school_rounded,
                  size: 56,
                  color: _SurveyColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Zero One Academy',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _SurveyColors.text,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'استطلاع رأي وتقييم تجربة الطلاب',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _SurveyColors.primary,
            ),
          ),
          const SizedBox(height: 24),

          // Privacy Assurance Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _SurveyColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _SurveyColors.primaryBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _SurveyColors.primary.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _SurveyColors.primarySurface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '🔒',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'رأيك سري ومجهول تمامًا',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _SurveyColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'الاستطلاع ده مش بيطلب اسمك أو رقم تليفونك أو أي بيانات تعرفنا بيك.\n\n'
                  'حتى لو اخترت تقييم 1 من 5، مش هنعرف مين صاحب التقييم.\n\n'
                  'قول رأيك بصراحة، لأن هدفنا نعرف إيه اللي محتاج يتحسن ونخلي تجربتك أفضل ❤️',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    height: 1.75,
                    fontWeight: FontWeight.w500,
                    color: _SurveyColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⏱️', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        'دقيقة واحدة بس هتقول فيها رأيك',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Start Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _hasStarted = true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _SurveyColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: _SurveyColors.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'ابدأ الاستطلاع',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_back_rounded, size: 22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. Active Survey Form
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSurveyForm() {
    final progress = _calculateProgress();

    return Column(
      key: const ValueKey('survey_form'),
      children: [
        // Sticky Header with Progress Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _SurveyColors.surface,
            border: Border(bottom: BorderSide(color: _SurveyColors.cardBorder)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ClipOval(
                        child: Image.asset(
                          'assets/images/logo.jpg',
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.school_rounded,
                            size: 24,
                            color: _SurveyColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Zero One Academy',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _SurveyColors.text,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _SurveyColors.primarySurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(progress * 100).toInt()}% مكتمل',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _SurveyColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: _SurveyColors.cardBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(_SurveyColors.primary),
                ),
              ),
            ],
          ),
        ),

        // Scrollable Questions Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // STEP 1: Place Rating
                _buildCardContainer(
                  stepNumber: '1',
                  title: 'إيه تقييمك للمكان؟',
                  isRequired: true,
                  child: Column(
                    children: [
                      _buildFiveStarSelector(
                        value: _placeRating,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _placeRating = val);
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '1 = غير راضي جدًا',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              color: _SurveyColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '5 = راضي جدًا',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              color: _SurveyColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // STEP 2: Content & Teaching Rating
                _buildCardContainer(
                  stepNumber: '2',
                  title: 'إيه تقييمك للمحتوى والشرح؟',
                  helperText: 'هل الشرح واضح؟ وهل المحتوى مناسب لمستواك؟',
                  isRequired: true,
                  child: Column(
                    children: [
                      _buildFiveStarSelector(
                        value: _contentRating,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _contentRating = val);
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '1 = غير راضي جدًا',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              color: _SurveyColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '5 = راضي جدًا',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              color: _SurveyColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // STEP 3: Instructor Selection & Teaching Experience
                _buildCardContainer(
                  stepNumber: '3',
                  title: 'مين الـInstructor اللي شرح لك؟',
                  helperText: 'تقدر تختار مدرب أو أكتر لو شرح لك أكتر من مدرب',
                  isRequired: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_loadingInstructors)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_instructors.isEmpty)
                        Text(
                          'لا يوجد مدربين متاحين حالياً',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 14,
                            color: _SurveyColors.textMuted,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _instructors.map((inst) {
                            final instId = inst['id'] as String;
                            final isSelected = _selectedInstructorIds.contains(instId);
                            return InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (isSelected) {
                                    _selectedInstructorIds.remove(instId);
                                    _instructorRatings.remove(instId);
                                  } else {
                                    _selectedInstructorIds.add(instId);
                                    _instructorRatings[instId] = {
                                      'clarity': 0,
                                      'simplification': 0,
                                      'interaction': 0,
                                      'answering': 0,
                                      'examples': 0,
                                    };
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? _SurveyColors.primarySurface : _SurveyColors.bg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? _SurveyColors.primary : _SurveyColors.cardBorder,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('👨‍🏫', style: TextStyle(fontSize: 18)),
                                    const SizedBox(width: 8),
                                    Text(
                                      inst['name'] ?? '',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? _SurveyColors.primary : _SurveyColors.text,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 18,
                                        color: _SurveyColors.primary,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                      // Teaching Experience Cards (One card per selected instructor)
                      if (_selectedInstructorIds.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        ..._selectedInstructorIds.map((instId) {
                          final inst = _instructors.firstWhere(
                            (i) => i['id'] == instId,
                            orElse: () => {'name': 'المدرب'},
                          );
                          final ratings = _instructorRatings[instId] ?? {};

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: _SurveyColors.bg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _SurveyColors.primaryBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('👨‍🏫', style: TextStyle(fontSize: 20)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'قيّم تجربة الشرح — ${inst['name']}',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: _SurveyColors.text,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Item 1: وضوح الشرح
                                _buildMiniRatingRow(
                                  title: 'وضوح الشرح',
                                  value: ratings['clarity'] ?? 0,
                                  onChanged: (v) => setState(() {
                                    _instructorRatings[instId]!['clarity'] = v;
                                  }),
                                ),
                                const Divider(height: 20, thickness: 0.8),

                                // Item 2: تبسيط المعلومات
                                _buildMiniRatingRow(
                                  title: 'تبسيط المعلومات',
                                  value: ratings['simplification'] ?? 0,
                                  onChanged: (v) => setState(() {
                                    _instructorRatings[instId]!['simplification'] = v;
                                  }),
                                ),
                                const Divider(height: 20, thickness: 0.8),

                                // Item 3: التفاعل مع الطلاب
                                _buildMiniRatingRow(
                                  title: 'التفاعل مع الطلاب',
                                  value: ratings['interaction'] ?? 0,
                                  onChanged: (v) => setState(() {
                                    _instructorRatings[instId]!['interaction'] = v;
                                  }),
                                ),
                                const Divider(height: 20, thickness: 0.8),

                                // Item 4: الإجابة عن الأسئلة
                                _buildMiniRatingRow(
                                  title: 'الإجابة عن الأسئلة',
                                  value: ratings['answering'] ?? 0,
                                  onChanged: (v) => setState(() {
                                    _instructorRatings[instId]!['answering'] = v;
                                  }),
                                ),
                                const Divider(height: 20, thickness: 0.8),

                                // Item 5: استخدام الأمثلة والتطبيقات
                                _buildMiniRatingRow(
                                  title: 'استخدام الأمثلة والتطبيقات',
                                  value: ratings['examples'] ?? 0,
                                  onChanged: (v) => setState(() {
                                    _instructorRatings[instId]!['examples'] = v;
                                  }),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // STEP 4: What did you like most? (Optional, Multiple Choice)
                _buildCardContainer(
                  stepNumber: '4',
                  title: 'إيه أكتر حاجة عجبتك؟',
                  helperText: 'تقدر تختار أكتر من حاجة (اختياري)',
                  isRequired: false,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _likedOptions.map((opt) {
                      final label = opt['label']!;
                      final icon = opt['icon']!;
                      final isSelected = _likedFeatures.contains(label);
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (isSelected) {
                              _likedFeatures.remove(label);
                            } else {
                              _likedFeatures.add(label);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? _SurveyColors.primarySurface : _SurveyColors.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? _SurveyColors.primary : _SurveyColors.cardBorder,
                              width: isSelected ? 1.8 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(icon, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(
                                label,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? _SurveyColors.primary : _SurveyColors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 18),

                // STEP 5: Improvements / Suggestions (Optional)
                _buildCardContainer(
                  stepNumber: '5',
                  title: 'هل في حاجة نفسك تتحسن؟',
                  helperText: 'اكتب براحتك، ومش لازم تكتب اسمك (اختياري)',
                  isRequired: false,
                  child: TextField(
                    controller: _improvementController,
                    maxLines: 4,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14,
                      color: _SurveyColors.text,
                    ),
                    decoration: InputDecoration(
                      hintText: '✍️ اكتب اقتراحك أو المشكلة اللي قابلتك...',
                      hintStyle: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        color: _SurveyColors.textMuted,
                      ),
                      filled: true,
                      fillColor: _SurveyColors.bg,
                      contentPadding: const EdgeInsets.all(16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _SurveyColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _SurveyColors.primary, width: 2),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // STEP 6: Recommendation Question
                _buildCardContainer(
                  stepNumber: '6',
                  title: 'هل تنصح صاحبك يجرب Zero One Academy؟',
                  isRequired: true,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildRecommendationOption(
                          emoji: '👎',
                          text: 'مش حاليًا',
                          valueKey: 'مش حاليًا',
                          activeColor: const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildRecommendationOption(
                          emoji: '😐',
                          text: 'ممكن',
                          valueKey: 'ممكن',
                          activeColor: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildRecommendationOption(
                          emoji: '👍',
                          text: 'أكيد',
                          valueKey: 'أكيد',
                          activeColor: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Pre-submit Privacy Reminder Notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🔒', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مهم تعرف',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'هدف التقييم هو تطوير تجربة التعلم، مش المقارنة بين الـInstructors. قيّم تجربتك بصراحة، سواء كانت ممتازة أو محتاجة تحسين.',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13,
                                height: 1.6,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isFormValid() && !_isSubmitting) ? _submitSurvey : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _SurveyColors.primary,
                      disabledBackgroundColor: _SurveyColors.cardBorder,
                      foregroundColor: Colors.white,
                      elevation: _isFormValid() ? 4 : 0,
                      shadowColor: _SurveyColors.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'إرسال الاستطلاع ✓',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                if (!_isFormValid()) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'يرجى إكمال الأسئلة الأساسية لتتمكن من الإرسال',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        color: _SurveyColors.textMuted,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Helper Components
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildCardContainer({
    required String stepNumber,
    required String title,
    String? helperText,
    required bool isRequired,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _SurveyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _SurveyColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _SurveyColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  stepNumber,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _SurveyColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _SurveyColors.text,
                  ),
                ),
              ),
              if (!isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _SurveyColors.bg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'اختياري',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      color: _SurveyColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          if (helperText != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 38),
              child: Text(
                helperText,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  color: _SurveyColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildFiveStarSelector({
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (index) {
        final starNum = index + 1;
        final isSelected = value == starNum;
        final isPassed = value >= starNum;

        return InkWell(
          onTap: () => onChanged(starNum),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? _SurveyColors.amber.withValues(alpha: 0.15)
                  : isPassed
                      ? const Color(0xFFFFFBEB)
                      : _SurveyColors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? _SurveyColors.amber
                    : isPassed
                        ? const Color(0xFFFDE68A)
                        : _SurveyColors.cardBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isPassed ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 28,
                  color: isPassed ? _SurveyColors.amber : _SurveyColors.textMuted,
                ),
                const SizedBox(height: 4),
                Text(
                  '$starNum',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isPassed ? _SurveyColors.text : _SurveyColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMiniRatingRow({
    required String title,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _SurveyColors.text,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
            final starNum = index + 1;
            final isSelected = value == starNum;
            final isPassed = value >= starNum;

            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(starNum);
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _SurveyColors.primarySurface
                      : isPassed
                          ? const Color(0xFFF5F3FF)
                          : _SurveyColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? _SurveyColors.primary
                        : isPassed
                            ? _SurveyColors.primaryBorder
                            : _SurveyColors.cardBorder,
                    width: isSelected ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPassed ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 18,
                      color: isPassed ? _SurveyColors.amber : _SurveyColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$starNum',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? _SurveyColors.primary : _SurveyColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRecommendationOption({
    required String emoji,
    required String text,
    required String valueKey,
    required Color activeColor,
  }) {
    final isSelected = _recommendation == valueKey;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _recommendation = valueKey);
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : _SurveyColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : _SurveyColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : _SurveyColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. Success Screen
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSuccessScreen() {
    return SingleChildScrollView(
      key: const ValueKey('success_screen'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Text(
              '🎉',
              style: TextStyle(fontSize: 54),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'شكرًا على رأيك!',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _SurveyColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'رأيك بيساعدنا نخلي Zero One Academy أفضل ليك ولزمايلك ❤️',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 16,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: _SurveyColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Privacy reminder card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _SurveyColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _SurveyColors.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔒', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'اطمّن — إجابتك مجهولة ومش مرتبطة بهويتك.',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _SurveyColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _resetSurvey,
              style: ElevatedButton.styleFrom(
                backgroundColor: _SurveyColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'تم ✓',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
