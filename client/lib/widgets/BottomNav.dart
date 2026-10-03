import 'package:flutter/material.dart';
import 'package:client/screens/HomeScreen.dart';
import 'package:client/screens/RecommendScreen.dart';
import 'package:client/screens/OcrScreen.dart';
import 'package:client/screens/CategoryScreen.dart';
import 'package:client/screens/ProfileScreen.dart';

/// Tab shell. Tabs are built the first time they're opened and then kept alive
/// (IndexedStack), so switching tabs doesn't refetch data or lose scroll position.
class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _index = 0;
  final Set<int> _opened = {0};

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
    NavigationDestination(
        icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome_rounded), label: 'For You'),
    NavigationDestination(
        icon: Icon(Icons.document_scanner_outlined), selectedIcon: Icon(Icons.document_scanner_rounded), label: 'Scan'),
    NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_rounded), label: 'Discover'),
    NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
  ];

  Widget _tab(int i) {
    if (!_opened.contains(i)) return const SizedBox.shrink();
    switch (i) {
      case 0:
        return const HomeScreen();
      case 1:
        return RecommendationScreen(active: _index == 1);
      case 2:
        return const OcrScreen();
      case 3:
        return const CategoryScreen();
      default:
        return const Profile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: List.generate(_destinations.length, _tab)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: _destinations,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _opened.add(i);
        }),
      ),
    );
  }
}
