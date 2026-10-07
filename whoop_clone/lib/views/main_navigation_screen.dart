import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/nature_theme.dart';
import 'home_screen.dart';
import 'screens/health_screen.dart';
import 'screens/more_menu_screen.dart';
import 'screens/coach_screen.dart';
import 'widgets/nature/coach_emblem.dart';

/// Navigation Screen Principale WHOOP 5.0
/// Floating Frosted Glass Capsule Bar: Home | Salute | Altro | Coach AI
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
    CoachScreen(),       // 3 — Coach AI (Pulsante Orb)
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NatureColors.darkCanvas : NatureColors.offWhite,

      // IndexedStack preserva lo stato di tutte le schermate
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      // Floating Frosted Glass Navigation Bar (Bright Nature Capsule)
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 68,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? NatureColors.darkSurface.withValues(alpha: 0.88)
                      : Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: isDark ? NatureColors.darkBorderSubtle : NatureColors.sandBorder,
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.40)
                          : const Color(0xFF2C3E50).withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
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
                        isDark: isDark,
                      ),
                    ),
                    // 2. Salute
                    Expanded(
                      child: _buildNavItem(
                        index: 1,
                        icon: Icons.favorite_border_rounded,
                        activeIcon: Icons.favorite_rounded,
                        label: 'Salute',
                        isDark: isDark,
                      ),
                    ),
                    // 3. Altro (Hub di Navigazione)
                    Expanded(
                      child: _buildNavItem(
                        index: 2,
                        icon: Icons.menu_rounded,
                        activeIcon: Icons.menu_open_rounded,
                        label: 'Altro',
                        isDark: isDark,
                      ),
                    ),

                    const SizedBox(width: 4),

                    // 4. Coach AI — Pulsante Circolare Orb con Simbolo Originale CoachEmblem
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentIndex = 3; // Coach AI screen
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentIndex == 3
                              ? (isDark ? NatureColors.darkSurfaceRaised : NatureColors.creamLight)
                              : (isDark ? NatureColors.darkSurface : Colors.white),
                          border: Border.all(
                            color: _currentIndex == 3
                                ? (isDark ? NatureColors.tealLight : NatureColors.sage)
                                : (isDark ? NatureColors.darkBorderSubtle : NatureColors.sandBorder),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_currentIndex == 3
                                      ? (isDark ? NatureColors.tealLight : NatureColors.sage)
                                      : (isDark ? Colors.black : const Color(0xFF2C3E50)))
                                  .withValues(alpha: _currentIndex == 3 ? 0.35 : 0.06),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: CoachEmblem(
                            size: 22,
                            color: _currentIndex == 3
                                ? (isDark ? NatureColors.tealLight : NatureColors.sageDark)
                                : (isDark ? NatureColors.textDarkMuted : NatureColors.textLightMuted),
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
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    final activeColor = isDark ? NatureColors.tealLight : NatureColors.sageDark;
    final itemColor = isSelected
        ? activeColor
        : (isDark ? NatureColors.textDarkMuted : NatureColors.textLightMuted);

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Morbida Pill attiva retroilluminata
          if (isSelected)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: (isDark ? NatureColors.tealLight : NatureColors.sage)
                    .withValues(alpha: isDark ? 0.16 : 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: itemColor,
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: itemColor,
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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
