import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'medications_screen.dart';
import 'today_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const TodayScreen(),
      const MedicationsScreen(),
      const HistoryScreen(),
    ];
    final compact = isCompactWidth(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: compact
          ? Container(
              decoration: BoxDecoration(
                gradient: AppDecorations.pageGradient(),
              ),
              child: pages[_selectedIndex],
            )
          : Row(
              children: [
                _Sidebar(
                  selectedIndex: _selectedIndex,
                  onSelect: (i) => setState(() => _selectedIndex = i),
                ),
                Container(width: 1, color: AppColors.borderGlass),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppDecorations.pageGradient(),
                    ),
                    child: pages[_selectedIndex],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: compact
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                decoration: AppDecorations.glassCard(elevated: true),
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  indicatorColor: AppColors.accent.withValues(alpha: 0.26),
                  shadowColor: Colors.transparent,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _selectedIndex = i),
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.check_circle_outline_rounded),
                      label: 'Habits',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.medication_rounded),
                      label: 'Medications',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.insights_rounded),
                      label: 'History',
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.sidebar.withValues(alpha: 0.96),
            AppColors.sidebar.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: AppDecorations.glassCard(elevated: true),
              child: const Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    color: AppColors.accentSoft,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'HabTrack',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: selectedIndex == 0,
                  onTap: () => onSelect(0),
                ),
                const SizedBox(height: 4),
                _NavItem(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Habits',
                  selected: selectedIndex == 1,
                  onTap: () => onSelect(1),
                ),
                const SizedBox(height: 4),
                _NavItem(
                  icon: Icons.medication_rounded,
                  label: 'Meds',
                  selected: selectedIndex == 2,
                  onTap: () => onSelect(2),
                ),
                const SizedBox(height: 4),
                _NavItem(
                  icon: Icons.insights_rounded,
                  label: 'History',
                  selected: selectedIndex == 3,
                  onTap: () => onSelect(3),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'v0.1.0',
              style: TextStyle(
                color: AppColors.textPrimary.withValues(alpha: 0.18),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: AppDecorations.glassChip(selected: selected),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.accentSoft : AppColors.textSubtle,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.textPrimary : AppColors.textSubtle,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
