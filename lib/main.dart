// lib/main.dart
// Zero One Academy — Student Experience Survey System
// Privacy-First, Anonymous Feedback Architecture

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'web_utils.dart';
import 'firebase_service.dart';
import 'student_survey.dart';
import 'admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;
  await FirebaseService.init();
  runApp(const AcademySurveyApp());
}

class AcademySurveyApp extends StatelessWidget {
  const AcademySurveyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Only URL containing ?admin unlocks Admin Dashboard (PIN protected)
    // Default URL is strictly the student survey
    final isAdmin = getUrlSearch().contains('admin');

    final baseTextTheme = ThemeData.light().textTheme;
    final ibmTextTheme = GoogleFonts.ibmPlexSansArabicTextTheme(baseTextTheme).apply(
      bodyColor: const Color(0xFF0F172A),
      displayColor: const Color(0xFF0F172A),
    );

    return MaterialApp(
      title: 'Zero One Academy — استطلاع رأي الطلاب',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: const ColorScheme.light(
          surface: Color(0xFFFFFFFF),
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFF9333EA),
        ),
        textTheme: ibmTextTheme,
      ),
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: isAdmin ? const AdminDashboard() : const StudentSurvey(),
      ),
    );
  }
}
