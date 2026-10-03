import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:client/constants/config.dart';
import 'package:client/models/ArticlesModel.dart';

/// An error with a message that is safe to show to the user.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class Summary {
  final String title;
  final String text;
  final List<String> keyPoints;

  /// "article" (full text), "snippet" (NewsAPI preview only) or "text" (pasted/scanned).
  final String source;

  const Summary({required this.title, required this.text, required this.keyPoints, required this.source});
}

class Signal {
  final String label, detail, impact; // impact: positive | negative | neutral
  const Signal(this.label, this.detail, this.impact);
}

class CheckedClaim {
  final String claim, status, note; // status: supported | unsupported | contradicted | unverifiable
  const CheckedClaim(this.claim, this.status, this.note);
}

class Coverage {
  final String title, source, url;
  final bool supports;
  const Coverage(this.title, this.source, this.url, this.supports);
}

/// Result of the fake news check.
class Verification {
  final String verdict; // likely_real | unverified | misleading | likely_fake
  final String label;
  final int score;
  final String confidence;
  final String summary;
  final List<Signal> signals;
  final List<CheckedClaim> claims;
  final List<Coverage> coverage;

  const Verification({
    required this.verdict,
    required this.label,
    required this.score,
    required this.confidence,
    required this.summary,
    required this.signals,
    required this.claims,
    required this.coverage,
  });

  factory Verification.fromJson(Map<String, dynamic> j) => Verification(
        verdict: (j['verdict'] ?? 'unverified').toString(),
        label: (j['label'] ?? 'Unverified').toString(),
        score: (j['credibility_score'] as num?)?.round() ?? 50,
        confidence: (j['confidence'] ?? 'low').toString(),
        summary: (j['summary'] ?? '').toString(),
        signals: [
          for (final s in (j['signals'] as List? ?? []))
            Signal('${s['label'] ?? ''}', '${s['detail'] ?? ''}', '${s['impact'] ?? 'neutral'}')
        ],
        claims: [
          for (final c in (j['claims'] as List? ?? []))
            CheckedClaim('${c['claim'] ?? ''}', '${c['status'] ?? 'unverifiable'}', '${c['note'] ?? ''}')
        ],
        coverage: [
          for (final c in (j['coverage'] as List? ?? []))
            Coverage('${c['title'] ?? ''}', '${c['source'] ?? ''}', '${c['url'] ?? ''}', c['supports'] == true)
        ],
      );
}

class Recommendations {
  final List<String> interests;
  final List<Article> articles;
  const Recommendations(this.interests, this.articles);
}

class LikedItem {
  final String title;
  final String category;
  const LikedItem(this.title, this.category);
}

/// Single place for every backend call, with consistent error handling.
class Api {
  static final http.Client _client = http.Client();
  static const _json = {'Content-Type': 'application/json'};

  static Future<dynamic> _send(Future<http.Response> Function() request,
      {Duration timeout = const Duration(seconds: 30)}) async {
    final http.Response res;
    try {
      res = await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException('The server took too long to respond. Please try again.');
    } catch (_) {
      throw const ApiException("Can't reach the server. Check that the backend is running.");
    }

    dynamic body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      body = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    // FastAPI errors look like {"detail": "..."} or {"detail": [{"msg": "..."}]}.
    var message = 'Something went wrong (${res.statusCode}).';
    final detail = body is Map ? body['detail'] : null;
    if (detail is String) message = detail;
    if (detail is List && detail.isNotEmpty && detail.first is Map) {
      message = detail.first['msg']?.toString() ?? message;
    }
    throw ApiException(message, res.statusCode);
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body, {Duration? timeout}) =>
      _send(() => _client.post(Uri.parse('${Config.apiBase}$path'), headers: _json, body: jsonEncode(body)),
          timeout: timeout ?? const Duration(seconds: 30));

  static Future<dynamic> _get(String path, Map<String, String> query) =>
      _send(() => _client.get(Uri.parse('${Config.apiBase}$path').replace(queryParameters: query)));

  // ---- Auth ----
  static Future<String> login(String email, String password) async {
    final res = await _post('login', {'email': email, 'password': password});
    return (res['token'] ?? '').toString();
  }

  static Future<void> register({
    required String email,
    required String password,
    required String username,
    required String phone,
  }) =>
      _post('registration', {'email': email, 'password': password, 'username': username, 'phone': phone});

  static Future<Map<String, dynamic>> userDetails(String email) async {
    final res = await _post('getUserDetails', {'email': email});
    return Map<String, dynamic>.from(res['data'] ?? {});
  }

  // ---- News ----
  static Future<List<Article>> news({String? category, String? query}) async {
    final params = <String, String>{
      if (category != null) 'category': category,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    };
    final res = await _get('news', params);
    return (res['articles'] as List)
        .map((e) => Article.fromJson(Map<String, dynamic>.from(e), category: category))
        .where((a) => a.title.isNotEmpty)
        .toList();
  }

  static Future<Summary> summarize({String text = '', Article? article}) async {
    final res = await _post(
      'summarize',
      {
        'text': text,
        if (article != null) ...{
          'url': article.url,
          'title': article.title,
          'description': article.description,
          'content': article.content,
        },
      },
      timeout: const Duration(seconds: 90),
    );
    final r = res['result'] as Map;
    return Summary(
      title: (r['title'] ?? '').toString(),
      text: (r['summary_text'] ?? '').toString(),
      keyPoints: List<String>.from((r['key_points'] ?? []).map((e) => e.toString())),
      source: (res['source'] ?? 'text').toString(),
    );
  }

  /// Fake news detection for an article or pasted/scanned text.
  static Future<Verification> verify({String text = '', Article? article}) async {
    final res = await _post(
      'verify',
      {
        'text': text,
        if (article != null) ...{
          'url': article.url,
          'title': article.title,
          'description': article.description,
          'source': article.sourceName,
        },
      },
      timeout: const Duration(seconds: 90),
    );
    return Verification.fromJson(Map<String, dynamic>.from(res));
  }

  // ---- Likes & personalisation ----
  static Future<List<LikedItem>> likedArticles(String email) async {
    final res = await _post('getLikedArticles', {'email': email});
    if (res['status'] != true) throw ApiException(res['error']?.toString() ?? 'Could not load your likes.');
    return (res['data']['likedArticles'] as List)
        .map((e) => LikedItem((e['title'] ?? '').toString(), (e['category'] ?? 'general').toString()))
        .where((e) => e.title.isNotEmpty)
        .toList();
  }

  static Future<void> like(String email, Article a) =>
      _post('likeArticle', {'email': email, 'articleTitle': a.title, 'articleCategory': a.category});

  static Future<void> unlike(String email, String title) =>
      _post('unlikeArticle', {'email': email, 'articleTitle': title});

  static Future<Recommendations> recommend(List<LikedItem> liked) async {
    final res = await _post(
      'recommend',
      {
        'liked_articles': liked.map((l) => {'title': l.title, 'category': l.category}).toList(),
      },
      timeout: const Duration(seconds: 60),
    );
    return Recommendations(
      List<String>.from((res['interests'] ?? []).map((e) => e.toString())),
      (res['articles'] as List).map((e) => Article.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }
}
