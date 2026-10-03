import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:client/models/ArticlesModel.dart';
import 'package:client/providers/likedArticleProvider.dart';
import 'package:client/screens/LoginPageScreen.dart';
import 'package:client/widgets/theme.dart';

void main() {
  group('Article.fromJson', () {
    test('tolerates missing and malformed fields', () {
      final a = Article.fromJson({'title': ' Hello ', 'source': null, 'publishedAt': 'not-a-date'});
      expect(a.title, 'Hello');
      expect(a.sourceName, 'Unknown');
      expect(a.publishedAt, isNull);
      expect(a.timeAgo, '');
    });

    test('reads recommendation metadata', () {
      final a = Article.fromJson({
        'title': 'T',
        'source': {'name': 'TOI'},
        'publishedAt': DateTime.now().subtract(const Duration(hours: 3)).toUtc().toIso8601String(),
        'interest': 'Space',
        'reason': 'Because you liked X',
      });
      expect(a.sourceName, 'TOI');
      expect(a.timeAgo, '3h ago');
      expect(a.interest, 'Space');
      expect(a.reason, 'Because you liked X');
    });
  });

  testWidgets('login form validates before calling the server', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => LikedArticlesProvider(),
      child: MaterialApp(theme: AppTheme.lightTheme, home: const LoginPage()),
    ));

    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });
}
