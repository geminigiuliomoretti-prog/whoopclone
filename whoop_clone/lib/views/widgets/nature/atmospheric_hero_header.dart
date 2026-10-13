import 'package:flutter/material.dart';
import '../../../core/theme/nature_theme.dart';

/// AtmosphericHeroHeader — Visual Header per RECOVERY e SLEEP
///
/// Integra gli asset visuali atmosferici (sunrise per Recovery, nighttime/moon per Sleep)
/// creando una finestra naturale e raccolta nella parte superiore dello schermo.
///
/// L'immagine NON si comporta come uno sfondo/wallpaper:
/// - Occupa un'area visiva compatta nella parte superiore (~330px)
/// - Sfuma gradualmente e in modo organico nel background dark navy dell'applicazione
/// - Zero bordi rettangolari, zero stacchi netti
/// - Sopra l'atmosfera si adagia l'indicatore circolare principale (Recovery Dial / Sleep Dial)
class AtmosphericHeroHeader extends StatelessWidget {
  final String imageAsset;
  final Color backgroundColor;
  final Color glowColor;
  final Alignment imageAlignment;
  final double height;
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onInfo;
  final Widget? trailingAction;
  final Widget child;

  const AtmosphericHeroHeader({
    super.key,
    required this.imageAsset,
    this.backgroundColor = NatureColors.background,
    this.glowColor = const Color(0x2838B27E),
    this.imageAlignment = const Alignment(0.0, 0.18),
    this.height = 340.0,
    this.title = 'OGGI',
    this.onBack,
    this.onInfo,
    this.trailingAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Fondazione solida del canvas
          Positioned.fill(
            child: Container(color: backgroundColor),
          ),

          // 2. Asset Visivo Stilizzato con Fade Atmosferico Continuo
          Positioned.fill(
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    alignment: imageAlignment,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback elegante se l'asset non è ancora caricato in runtime
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              backgroundColor.withValues(alpha: 0.8),
                              backgroundColor,
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Sfumatura Superiore per la leggibilità della Top Bar / Status Bar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 90,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            backgroundColor.withValues(alpha: 0.70),
                            backgroundColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Diffusione Luminosa Ambientale (Sunrise Glow o Moonlight Aura)
                  Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            glowColor,
                            glowColor.withValues(alpha: 0.0),
                          ],
                          radius: 0.75,
                        ),
                      ),
                    ),
                  ),

                  // Sfumatura Inferiore a multi-fase: dissolve l'immagine nel Dark UI senza stacchi
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 180,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.40, 0.72, 1.0],
                          colors: [
                            backgroundColor.withValues(alpha: 0.0),
                            backgroundColor.withValues(alpha: 0.42),
                            backgroundColor.withValues(alpha: 0.88),
                            backgroundColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Top Navigation Bar (Back, Data, Info/Actions)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Pulsante Torna Indietro
                    GestureDetector(
                      onTap: onBack ?? () => Navigator.of(context).maybePop(),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: backgroundColor.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: NatureColors.borderSubtle.withValues(alpha: 0.6),
                            width: 0.8,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: NatureColors.primaryText,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                    // Titolo Schermata / Data (Es. "OGGI")
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: backgroundColor.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(NatureRadius.pill),
                        border: Border.all(
                          color: NatureColors.borderSubtle.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        title.toUpperCase(),
                        style: const TextStyle(
                          color: NatureColors.primaryText,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),

                    // Azione destra (Info o custom action)
                    trailingAction ??
                        GestureDetector(
                          onTap: onInfo,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: backgroundColor.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: NatureColors.borderSubtle.withValues(alpha: 0.6),
                                width: 0.8,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: NatureColors.secondaryText,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Hero Content (Indicatore circolare con punteggio e badge)
          Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}
