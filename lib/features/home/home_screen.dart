import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/weather_theme_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(
              Icons.calendar_today_outlined,
              color: colors.textSecondary,
            ),
            selectedIcon: Icon(
              Icons.calendar_today_outlined,
              color: colors.primary,
            ),
            label: 'Schedule',
            tooltip: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.directions_run_outlined,
              color: colors.textSecondary,
            ),
            selectedIcon: Icon(
              Icons.directions_run_outlined,
              color: colors.primary,
            ),
            label: 'Activities',
            tooltip: 'Activities',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: colors.textSecondary),
            selectedIcon: Icon(Icons.settings_outlined, color: colors.primary),
            label: 'Settings',
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}
