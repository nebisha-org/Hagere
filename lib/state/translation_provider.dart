import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/translate_api.dart';

enum AppLanguage { english, amharic }

extension AppLanguageX on AppLanguage {
  String get code => this == AppLanguage.english ? 'en' : 'am';
  String get label => this == AppLanguage.english ? 'English' : 'አማርኛ';
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final translateApiProvider = Provider<TranslateApi>((ref) => TranslateApi());

final translationControllerProvider =
    ChangeNotifierProvider<TranslationController>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final api = ref.watch(translateApiProvider);
  return TranslationController(api, prefs);
});

class TranslationController extends ChangeNotifier {
  TranslationController(this._api, this._prefs) {
    _loadSavedLanguage();
  }

  final TranslateApi _api;
  final SharedPreferences _prefs;

  AppLanguage _language = AppLanguage.english;
  AppLanguage get language => _language;

  final Map<String, String> _cache = {};
  final Set<String> _queue = {};
  Timer? _debounce;
  bool _inFlight = false;
  static const Duration _debounceDuration = Duration(milliseconds: 400);
  static const int _maxBatch = 40;

  void setLanguage(AppLanguage lang) {
    if (_language == lang) return;
    _language = lang;
    _prefs.setString('ui_language', lang.code);
    if (_language == AppLanguage.english) {
      _queue.clear();
      _debounce?.cancel();
      _debounce = null;
    }
    notifyListeners();
  }

  Future<void> prefetch(List<String> texts) async {
    if (_language == AppLanguage.english) return;
    if (texts.isEmpty) return;
    final missing = <String>[];
    for (final raw in texts) {
      final text = raw.trim();
      if (text.isEmpty) continue;
      if (!_shouldTranslate(text)) continue;
      final key = _cacheKey(_language.code, text);
      if (_cache.containsKey(key) || _prefs.containsKey(key)) continue;
      missing.add(text);
    }
    if (missing.isEmpty) return;
    await _translateAndStore(missing);
  }

  String tr(String text) {
    if (_language == AppLanguage.english) return text;
    final cleaned = text.trim();
    if (cleaned.isEmpty) return text;
    if (!_shouldTranslate(cleaned)) return text;

    final key = _cacheKey(_language.code, text);
    final cached = _cache[key] ?? _prefs.getString(key);
    if (cached != null && cached.isNotEmpty) {
      _cache[key] = cached;
      return cached;
    }

    _queue.add(text);
    _scheduleFlush();
    return text;
  }

  void _loadSavedLanguage() {
    final saved = _prefs.getString('ui_language');
    if (saved == 'am') {
      _language = AppLanguage.amharic;
    }
  }

  void _scheduleFlush() {
    if (_debounce != null) return;
    _debounce = Timer(_debounceDuration, _flushQueue);
  }

  Future<void> _flushQueue() async {
    _debounce?.cancel();
    _debounce = null;
    if (_language == AppLanguage.english) return;
    if (_queue.isEmpty) return;
    if (_inFlight) {
      _scheduleFlush();
      return;
    }

    final texts = _queue.toList();
    _queue.clear();
    await _translateAndStore(texts);
  }

  Future<void> _translateAndStore(List<String> texts) async {
    if (texts.isEmpty) return;
    _inFlight = true;
    try {
      final unique = texts.map((t) => t.trim()).where((t) => t.isNotEmpty);
      final batch = <String>[];
      for (final text in unique.toSet()) {
        if (!_shouldTranslate(text)) continue;
        final key = _cacheKey(_language.code, text);
        if (_cache.containsKey(key) || _prefs.containsKey(key)) continue;
        batch.add(text);
        if (batch.length >= _maxBatch) {
          await _translateChunk(batch);
          batch.clear();
        }
      }
      if (batch.isNotEmpty) {
        await _translateChunk(batch);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Translation error: $e');
      }
    } finally {
      _inFlight = false;
      if (_queue.isNotEmpty) {
        _scheduleFlush();
      }
    }
  }

  Future<void> _translateChunk(List<String> texts) async {
    if (texts.isEmpty) return;
    final translations = await _api.translateBatch(
      texts,
      target: _language.code,
      source: 'en',
    );
    for (final entry in translations.entries) {
      final key = _cacheKey(_language.code, entry.key);
      _cache[key] = entry.value;
      _prefs.setString(key, entry.value);
    }
    notifyListeners();
  }

  static bool _looksNumeric(String text) {
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(text);
    if (hasLetter) return false;
    final hasDigit = RegExp(r'\d').hasMatch(text);
    return hasDigit;
  }

  static bool _looksLikeUrlOrEmail(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('http://') || lower.contains('https://')) return true;
    if (lower.contains('www.')) return true;
    final emailLike = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailLike.hasMatch(text);
  }

  static bool _shouldTranslate(String text) {
    if (_looksNumeric(text)) return false;
    if (_looksLikeUrlOrEmail(text)) return false;
    if (RegExp(r'[\u1200-\u137F]').hasMatch(text)) return false;
    return true;
  }

  static String _cacheKey(String lang, String text) {
    return 'tr_${lang}_${_fnv1a(text)}';
  }

  static String _fnv1a(String input) {
    var hash = 0x811C9DC5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }
}
