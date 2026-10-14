import 'package:flutter/material.dart';
import 'package:client/screens/HomeScreen.dart';
import 'package:client/screens/RecommendScreen.dart';
import 'package:client/screens/SummarizeScreen.dart';
import 'package:client/screens/FakeNewsScreen.dart';
import 'package:client/screens/CategoryScreen.dart';
import 'package:client/screens/ProfileScreen.dart';

/// Tab shell. Mobile navigation bar with separated Summarize and Fake News sections.
/// Tabs are built lazily on first access and preserved using IndexedStack.
class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _index = 0;
  final Set<int> _opened = {0};

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.auto_awesome_outlined),
      selectedIcon: Icon(Icons.auto_awesome_rounded),
      label: 'For You',
    ),
    NavigationDestination(
      icon: Icon(Icons.short_text_rounded),
      selectedIcon: Icon(Icons.short_text_rounded),
      label: 'Summarize',
    ),
    NavigationDestination(
      icon: Icon(Icons.fact_check_outlined),
      selectedIcon: Icon(Icons.fact_check_rounded),
      label: 'Fake News',
    ),
    NavigationDestination(
      icon: Icon(Icons.explore_outlined),
      selectedIcon: Icon(Icons.explore_rounded),
      label: 'Discover',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  Widget _tab(int i) {
    if (!_opened.contains(i)) return const SizedBox.shrink();
    switch (i) {
      case 0:
        return const HomeScreen();
      case 1:
        return RecommendationScreen(active: _index == 1);
      case 2:
        return const SummarizeScreen();
      case 3:
        return const FakeNewsScreen();
      case 4:
        return const CategoryScreen();
      default:
        return const Profile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: List.generate(_destinations.length, _tab),
      ),
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
