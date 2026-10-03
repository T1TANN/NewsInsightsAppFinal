import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:client/models/ArticlesModel.dart';
import 'package:client/services/api_client.dart';

/// Holds the signed-in user and their liked articles, keyed by title.
class LikedArticlesProvider extends ChangeNotifier {
  String? _email;
  final Map<String, String> _liked = {}; // title -> category, insertion ordered
  Future<void>? _init;

  String? get userEmail => _email;
  bool get isLoggedIn => _email != null;
  List<LikedItem> get liked => _liked.entries.map((e) => LikedItem(e.key, e.value)).toList();
  int get likedCount => _liked.length;

  /// Changes whenever the liked set changes; lets screens detect stale data.
  String get likedSignature => _liked.keys.join('|');

  bool isLiked(String title) => _liked.containsKey(title);

  /// Loads the saved session and syncs likes from the backend. Safe to call repeatedly.
  Future<void> ensureInitialized() => _init ??= _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _email = (prefs.getBool('isLoggedIn') ?? false) ? prefs.getString('email') : null;
    await refreshLikes();
  }

  Future<void> refreshLikes() async {
    final email = _email;
    if (email == null) return;
    try {
      final items = await Api.likedArticles(email);
      _liked
        ..clear()
        ..addEntries(items.map((i) => MapEntry(i.title, i.category)));
      notifyListeners();
    } catch (e) {
      debugPrint('Could not sync likes: $e');
    }
  }

  Future<void> startSession(String email, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('email', email);
    await prefs.setString('token', token);
    _email = email;
    _liked.clear();
    _init = Future.value();
    notifyListeners();
    await refreshLikes();
  }

  Future<void> endSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('email');
    await prefs.remove('token');
    _email = null;
    _liked.clear();
    _init = Future.value();
    notifyListeners();
  }

  /// Optimistically toggles a like, rolling back if the backend call fails.
  /// Returns an error message, or null on success.
  Future<String?> toggle(Article article) async {
    final email = _email;
    if (email == null) return 'Please sign in to like articles.';
    final wasLiked = isLiked(article.title);
    if (wasLiked) {
      _liked.remove(article.title);
    } else {
      _liked[article.title] = article.category;
    }
    notifyListeners();
    try {
      if (wasLiked) {
        await Api.unlike(email, article.title);
      } else {
        await Api.like(email, article);
      }
      return null;
    } on ApiException catch (e) {
      if (wasLiked) {
        _liked[article.title] = article.category;
      } else {
        _liked.remove(article.title);
      }
      notifyListeners();
      return e.message;
    }
  }

  Future<String?> unlikeTitle(String title) async {
    final category = _liked[title];
    if (category == null) return null;
    return toggle(Article(
      title: title, description: '', url: '', author: '', publishedAt: null,
      sourceName: '', urlToImage: '', content: '', category: category,
    ));
  }
}
