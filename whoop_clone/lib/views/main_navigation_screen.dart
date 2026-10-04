import 'package:flutter/material.dart';
import '../core/constants/whoop_theme.dart';
import 'home_screen.dart';
import 'screens/health_screen.dart';
import 'screens/community_screen.dart';
import 'screens/more_menu_screen.dart';
import 'screens/coach_screen.dart';

/// Navigation Screen Principale WHOOP 5.0
/// Bottom Nav Pill: Home | Salute | Community | Altro | WHOOP Coach AI
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
    CommunityScreen(),   // 2 — Community & Classifiche Team
    MoreMenuScreen(),    // 3 — Hub Menu Completo
    CoachScreen(),       // 4 — Whoop Coach AI (Pulsante Orb)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhoopTheme.background,

      // IndexedStack preserva lo stato di tutte le schermate
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      // Floating Navigation Bar (Identica al 100% agli screenshot ufficiali di reference_UI)
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 66,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF14191E),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: const Color(0xFF222B32), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 18,
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
              // 3. Community (Ufficiale Whoop 5.0)
              Expanded(
                child: _buildNavItem(
                  index: 2,
                  icon: Icons.people_outline_rounded,
                  activeIcon: Icons.people_rounded,
                  label: 'Community',
                ),
              ),
              // 4. Altro (Hub di Navigazione)
              Expanded(
                child: _buildNavItem(
                  index: 3,
                  icon: Icons.menu_rounded,
                  activeIcon: Icons.menu_open_rounded,
                  label: 'Altro',
                ),
              ),

              const SizedBox(width: 4),

              // 5. WHOOP Coach AI — Pulsante Circolare Orb (\V/ icon)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _currentIndex = 4; // Coach AI screen
                  });
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF121A22),
                    border: Border.all(
                      color: _currentIndex == 4
                          ? WhoopTheme.brandTeal
                          : WhoopTheme.strainBlue,
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_currentIndex == 4
                                ? WhoopTheme.brandTeal
                                : WhoopTheme.strainBlue)
                            .withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      WhoopTheme.circleWhite,
                      height: 22,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Text(
                        '\\V/',
                        style: TextStyle(
                          color: _currentIndex == 4
                              ? WhoopTheme.brandTeal
                              : WhoopTheme.strainBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    final itemColor = isSelected ? Colors.white : const Color(0xFF8896A2);

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
          // Sfumatura di retroilluminazione soffusa per il tab attivo
          if (isSelected)
            Positioned(
              bottom: 2,
              child: Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: WhoopTheme.strainBlue,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: WhoopTheme.strainBlue.withOpacity(0.8),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ],
                ),
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
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
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
