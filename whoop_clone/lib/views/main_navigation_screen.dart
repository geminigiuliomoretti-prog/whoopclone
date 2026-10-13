import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/nature_theme.dart';
import 'home_screen.dart';
import 'screens/health_screen.dart';
import 'screens/more_menu_screen.dart';
import 'screens/coach_screen.dart';
import 'widgets/nature/coach_emblem.dart';

/// Navigation Screen Principale — Floating Frosted Capsule Bar
/// Destinazioni: Home (0) | Salute (1) | Altro (2) | Coach AI (3)
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),        // 0 — Dashboard Principale
    HealthScreen(),      // 1 — Monitoraggio Salute & Parametri Vitali
    MoreMenuScreen(),    // 2 — Hub Menu Completo
    CoachScreen(),       // 3 — Coach AI Guida
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NatureColors.background,
      extendBody: true, // Permette alla barra floating di sovrapporsi con sfocatura

      // IndexedStack preserva lo stato di tutte le schermate
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      // Floating Frosted Glass Capsule Navigation Bar
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 66,
          margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: NatureColors.surfaceTranslucent,
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: NatureColors.border,
                    width: 0.85,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.40),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    // 1. Home
                    Expanded(
                      child: _buildNavItem(
                        index: 0,
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                        label: 'Home',
                      ),
                    ),
                    // 2. Salute
                    Expanded(
                      child: _buildNavItem(
                        index: 1,
                        icon: Icons.favorite_border_rounded,
                        activeIcon: Icons.favorite_rounded,
                        label: 'Salute',
                      ),
                    ),
                    // 3. Altro (Hub Menu)
                    Expanded(
                      child: _buildNavItem(
                        index: 2,
                        icon: Icons.grid_view_outlined,
                        activeIcon: Icons.grid_view_rounded,
                        label: 'Altro',
                      ),
                    ),

                    const SizedBox(width: 6),

                    // 4. Coach AI — Orb Circolare con Simbolo Originale CoachEmblem
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentIndex = 3;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentIndex == 3
                              ? NatureColors.surfaceElevated
                              : NatureColors.surface,
                          border: Border.all(
                            color: _currentIndex == 3
                                ? NatureColors.teal
                                : NatureColors.border,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_currentIndex == 3
                                      ? NatureColors.teal
                                      : Colors.black)
                                  .withValues(alpha: _currentIndex == 3 ? 0.35 : 0.15),
                              blurRadius: _currentIndex == 3 ? 12 : 6,
                              spreadRadius: _currentIndex == 3 ? 1 : 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: CoachEmblem(
                            size: 20,
                            color: _currentIndex == 3
                                ? NatureColors.tealLight
                                : NatureColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    final itemColor = isSelected ? NatureColors.tealLight : NatureColors.textMuted;

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isSelected)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: NatureColors.teal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: itemColor,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? NatureColors.textPrimary : NatureColors.textMuted,
                  fontSize: 10.0,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
