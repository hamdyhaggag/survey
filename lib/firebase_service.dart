// lib/firebase_service.dart
// Firebase Core & Cloud Firestore — Zero One Academy
// Student Experience Survey & Anonymous Feedback Engine

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

class FirebaseService {
  static bool _initialized = false;

  // Local fallback caches in case Firestore is offline or not configured
  static final List<Map<String, dynamic>> _localResponses = [];
  static final List<Map<String, dynamic>> _localInstructors = [
    {
      'id': 'inst_ahmed',
      'name': 'المهندس أحمد',
      'isActive': true,
      'order': 1,
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'id': 'inst_hamdy',
      'name': 'المهندس حمدي',
      'isActive': true,
      'order': 2,
      'createdAt': DateTime.now().toIso8601String(),
    },
  ];
  static final List<Map<String, dynamic>> _localQuestions = [];

  /// Initialize Firebase using the auto-generated options
  static Future<void> init() async {
    if (_initialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _initialized = true;
      // Seed default instructors if collection is empty
      await _seedDefaultInstructorsIfNeeded();
    } catch (e) {
      debugPrint('Firebase init notice: $e (operating with safe local cache)');
      _initialized = false;
    }
  }

  static FirebaseFirestore? get _db {
    if (!_initialized) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Backwards Compatibility (Legacy Registration)
  // ───────────────────────────────────────────────────────────────────────────
  static Future<void> saveRegistration(Map<String, dynamic> data) async {
    final db = _db;
    if (db != null) {
      try {
        await db.collection('registrations').add(data);
      } catch (e) {
        debugPrint('Legacy registration save: $e');
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Default Instructors Seeding
  // ───────────────────────────────────────────────────────────────────────────
  static Future<void> _seedDefaultInstructorsIfNeeded() async {
    final db = _db;
    if (db == null) return;
    try {
      final snap = await db.collection('instructors').limit(1).get();
      if (snap.docs.isEmpty) {
        for (final inst in _localInstructors) {
          await db.collection('instructors').doc(inst['id']).set(inst);
        }
      }
    } catch (e) {
      debugPrint('Seed instructors notice: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Survey Responses (Strictly 100% Anonymous - No PII)
  // ───────────────────────────────────────────────────────────────────────────

  /// Save anonymous survey response
  static Future<bool> submitSurveyResponse(Map<String, dynamic> responseData) async {
    // Ensure absolutely NO personal identifier exists
    responseData.remove('fullName');
    responseData.remove('phone');
    responseData.remove('email');
    responseData.remove('studentId');
    responseData.remove('ip');

    // Add submission timestamp if missing
    responseData['submittedAt'] ??= DateTime.now().toIso8601String();

    _localResponses.insert(0, Map<String, dynamic>.from(responseData));

    final db = _db;
    if (db != null) {
      try {
        await db.collection('survey_responses').add(responseData);
        return true;
      } catch (e) {
        debugPrint('Firestore submitSurveyResponse error: $e');
      }
    }
    return true; // Succeeded in local fallback
  }

  /// Stream of real-time survey responses
  static Stream<List<Map<String, dynamic>>> surveyResponsesStream() {
    final db = _db;
    if (db != null) {
      try {
        return db
            .collection('survey_responses')
            .orderBy('submittedAt', descending: true)
            .snapshots()
            .map((snap) {
          return snap.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['_id'] = doc.id;
            return data;
          }).toList();
        });
      } catch (e) {
        debugPrint('Stream responses error: $e');
      }
    }
    // Fallback stream
    return Stream.value(_localResponses);
  }

  /// Fetch responses once
  static Future<List<Map<String, dynamic>>> fetchAllResponses() async {
    final db = _db;
    if (db != null) {
      try {
        final snap = await db
            .collection('survey_responses')
            .orderBy('submittedAt', descending: true)
            .get();
        return snap.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['_id'] = doc.id;
          return data;
        }).toList();
      } catch (e) {
        debugPrint('Fetch responses error: $e');
      }
    }
    return List.from(_localResponses);
  }

  /// Clear all survey responses (Batch delete for Admin test reset)
  static Future<void> clearAllResponses() async {
    _localResponses.clear();
    final db = _db;
    if (db != null) {
      try {
        final snap = await db.collection('survey_responses').get();
        final batch = db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } catch (e) {
        debugPrint('Clear survey responses error: $e');
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Instructors Dynamic Management
  // ───────────────────────────────────────────────────────────────────────────

  /// Stream of active or all instructors
  static Stream<List<Map<String, dynamic>>> instructorsStream() {
    final db = _db;
    if (db != null) {
      try {
        return db
            .collection('instructors')
            .snapshots()
            .map((snap) {
          final list = snap.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['_id'] = doc.id;
            return data;
          }).toList();
          list.sort((a, b) => (a['order'] ?? 99).compareTo(b['order'] ?? 99));
          return list;
        });
      } catch (e) {
        debugPrint('Stream instructors error: $e');
      }
    }
    return Stream.value(_localInstructors);
  }

  /// Add new instructor
  static Future<void> addInstructor(String name) async {
    final id = 'inst_${DateTime.now().millisecondsSinceEpoch}';
    final data = {
      'id': id,
      'name': name.trim(),
      'isActive': true,
      'order': _localInstructors.length + 1,
      'createdAt': DateTime.now().toIso8601String(),
    };
    _localInstructors.add(data);

    final db = _db;
    if (db != null) {
      try {
        await db.collection('instructors').doc(id).set(data);
      } catch (e) {
        debugPrint('Add instructor error: $e');
      }
    }
  }

  /// Update instructor name or active status
  static Future<void> updateInstructor(String id, {String? name, bool? isActive}) async {
    for (var inst in _localInstructors) {
      if (inst['id'] == id) {
        if (name != null) inst['name'] = name.trim();
        if (isActive != null) inst['isActive'] = isActive;
        break;
      }
    }

    final db = _db;
    if (db != null) {
      try {
        final updateData = <String, dynamic>{};
        if (name != null) updateData['name'] = name.trim();
        if (isActive != null) updateData['isActive'] = isActive;
        await db.collection('instructors').doc(id).update(updateData);
      } catch (e) {
        debugPrint('Update instructor error: $e');
      }
    }
  }

  /// Delete instructor
  static Future<void> deleteInstructor(String id) async {
    _localInstructors.removeWhere((item) => item['id'] == id);
    final db = _db;
    if (db != null) {
      try {
        await db.collection('instructors').doc(id).delete();
      } catch (e) {
        debugPrint('Delete instructor error: $e');
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Dynamic Survey Questions Management
  // ───────────────────────────────────────────────────────────────────────────

  /// Stream of dynamic custom questions
  static Stream<List<Map<String, dynamic>>> questionsStream() {
    final db = _db;
    if (db != null) {
      try {
        return db
            .collection('survey_questions')
            .snapshots()
            .map((snap) {
          final list = snap.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['_id'] = doc.id;
            return data;
          }).toList();
          list.sort((a, b) => (a['order'] ?? 99).compareTo(b['order'] ?? 99));
          return list;
        });
      } catch (e) {
        debugPrint('Stream questions error: $e');
      }
    }
    return Stream.value(_localQuestions);
  }

  /// Add or update dynamic question
  static Future<void> saveQuestion(Map<String, dynamic> question) async {
    final id = question['id'] ?? 'q_${DateTime.now().millisecondsSinceEpoch}';
    question['id'] = id;

    _localQuestions.removeWhere((q) => q['id'] == id);
    _localQuestions.add(question);

    final db = _db;
    if (db != null) {
      try {
        await db.collection('survey_questions').doc(id).set(question);
      } catch (e) {
        debugPrint('Save question error: $e');
      }
    }
  }

  /// Delete dynamic question
  static Future<void> deleteQuestion(String id) async {
    _localQuestions.removeWhere((q) => q['id'] == id);
    final db = _db;
    if (db != null) {
      try {
        await db.collection('survey_questions').doc(id).delete();
      } catch (e) {
        debugPrint('Delete question error: $e');
      }
    }
  }
}
