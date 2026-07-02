// Splash Screen — the calm cover over real work.
//
// BS-001-splash: Opens the encrypted vault and warms the on-device model.
// Not a marketing moment, not a loading spinner. The glow blooms once,
// the mark settles, the privacy promise is stated, and it hands straight off.
// Fast, quiet, honest.
//
// The glow here is the SAME readiness light that later carries the Today score —
// introduced before it ever carries a number.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../rust_engine.dart';
import '../services/profile_service.dart';
import '../theme/tokens.dart';
import 'auth_screen.dart';
import 'today_screen.dart';

/// The splash screen — vault open + model warm, then hand-off.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ─── Animation controllers ───
  late final AnimationController _entranceController;
  late final AnimationController _breatheOuterController;
  late final AnimationController _breatheMidController;

  // ─── Entrance animations ───
  late final Animation<double> _outerHaloScale;
  late final Animation<double> _outerHaloOpacity;
  late final Animation<double> _midHaloScale;
  late final Animation<double> _midHaloOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkOffset;
  late final Animation<double> _taglineOpacity;
  late final Animation<Offset> _taglineOffset;
  late final Animation<double> _privacyOpacity;

  // ─── Breathe animations ───
  late final Animation<double> _breatheOuterScale;
  late final Animation<double> _breatheOuterOpacity;
  late final Animation<double> _breatheMidScale;
  late final Animation<double> _breatheMidOpacity;

  // ─── State ───
  bool _warmUpComplete = false;
  bool _entranceComplete = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startWarmUp();
  }

  void _initAnimations() {
    // Total entrance duration: ~2.5s (last element starts at 1.7s + 0.8s fade)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Breathe controllers (6s loop, counter-phased)
    _breatheOuterController = AnimationController(
      vsync: this,
      duration: MivaltaGlow.splashBreatheDuration,
    );
    _breatheMidController = AnimationController(
      vsync: this,
      duration: MivaltaGlow.splashBreatheDuration,
    );

    // ─── Entrance timeline (normalized to 2500ms total) ───
    // 0.15s (60ms) outer halo bloom: scale .8→1, opacity 0→.9, 700ms
    _outerHaloScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.06, 0.34, curve: Curves.easeOutCubic), // 150-850ms
      ),
    );
    _outerHaloOpacity = Tween<double>(begin: 0.0, end: MivaltaGlow.splashRestingAlpha).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.06, 0.34, curve: Curves.easeOutCubic),
      ),
    );

    // 0.25s (100ms) mid halo bloom: same animation, starts later
    _midHaloScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.10, 0.38, curve: Curves.easeOutCubic), // 250-950ms
      ),
    );
    _midHaloOpacity = Tween<double>(begin: 0.0, end: MivaltaGlow.splashRestingAlpha).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.10, 0.38, curve: Curves.easeOutCubic),
      ),
    );

    // 0.45s logo mark: scale .86→1, opacity 0→1, 700ms
    _logoScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.18, 0.46, curve: Curves.easeOutCubic), // 450-1150ms
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.18, 0.46, curve: Curves.easeOutCubic),
      ),
    );

    // 0.95s wordmark: rise translateY 8→0, opacity 0→1, 600ms
    _wordmarkOffset = Tween<Offset>(
      begin: const Offset(0, 8),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.38, 0.62, curve: Curves.easeOutCubic), // 950-1550ms
      ),
    );
    _wordmarkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.38, 0.62, curve: Curves.easeOutCubic),
      ),
    );

    // 1.20s tagline: same rise animation, 600ms
    _taglineOffset = Tween<Offset>(
      begin: const Offset(0, 8),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.48, 0.72, curve: Curves.easeOutCubic), // 1200-1800ms
      ),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.48, 0.72, curve: Curves.easeOutCubic),
      ),
    );

    // 1.70s privacy line: fade 0→1, 800ms
    _privacyOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.68, 1.0, curve: Curves.ease), // 1700-2500ms
      ),
    );

    // ─── Breathe animations (opacity .78↔1, scale .97↔1.05) ───
    _breatheOuterScale = Tween<double>(begin: 0.97, end: 1.05).animate(
      CurvedAnimation(parent: _breatheOuterController, curve: Curves.ease),
    );
    _breatheOuterOpacity = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(parent: _breatheOuterController, curve: Curves.ease),
    );
    // Mid is counter-phased (reverse)
    _breatheMidScale = Tween<double>(begin: 1.05, end: 0.97).animate(
      CurvedAnimation(parent: _breatheMidController, curve: Curves.ease),
    );
    _breatheMidOpacity = Tween<double>(begin: 1.0, end: 0.78).animate(
      CurvedAnimation(parent: _breatheMidController, curve: Curves.ease),
    );

    // Listen for entrance completion
    _entranceController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _entranceComplete = true);
        _startBreathing();
        _tryHandOff();
      }
    });
  }

  void _startBreathing() {
    _breatheOuterController.repeat(reverse: true);
    _breatheMidController.repeat(reverse: true);
  }

  Future<void> _startWarmUp() async {
    // Check for reduced motion preference
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mediaQuery = MediaQuery.of(context);
      _reducedMotion = mediaQuery.disableAnimations;

      if (_reducedMotion) {
        // Skip entrance animation, show settled state immediately
        _entranceController.value = 1.0;
        setState(() => _entranceComplete = true);
        // Still do the warm-up, just no animation
      } else {
        // Start entrance animation
        _entranceController.forward();
      }
    });

    // Warm-up: bootstrap engine + open vault
    try {
      final binding = await RustEngineBinding.bootstrap();
      final profileJson = await ProfileService.loadProfile();

      if (profileJson != null) {
        final tablesJson = await rootBundle.loadString('assets/compiled_tables.json');
        final vaultPath = await ProfileService.getVaultPath();

        final hasState = await binding.hasPersistedState(
          athleteProfileJson: profileJson,
          vaultPath: vaultPath,
        );

        if (hasState) {
          final stateJson = await binding.readPersistedState(
            athleteProfileJson: profileJson,
            vaultPath: vaultPath,
          );
          if (stateJson != null) {
            await binding.constructEnginesFromState(
              athleteProfileJson: profileJson,
              tablesJson: tablesJson,
              vaultPath: vaultPath,
              viterbiStateJson: stateJson,
            );
          } else {
            await binding.constructEnginesFresh(
              athleteProfileJson: profileJson,
              tablesJson: tablesJson,
              vaultPath: vaultPath,
            );
          }
        } else {
          await binding.constructEnginesFresh(
            athleteProfileJson: profileJson,
            tablesJson: tablesJson,
            vaultPath: vaultPath,
          );
        }
      }
    } catch (e) {
      // Warm-up failed — still proceed to routing (profile check will handle)
      debugPrint('Splash warm-up error: $e');
    }

    setState(() => _warmUpComplete = true);
    _tryHandOff();
  }

  void _tryHandOff() {
    if (!mounted) return;

    // Hand-off when both: entrance floor reached AND warm-up complete
    if (_entranceComplete && _warmUpComplete) {
      _handOff();
    }
  }

  Future<void> _handOff() async {
    // Routing logic (Step 7 / BS-001-auth Step 8):
    // - No auth session → Auth
    // - Authed, no profile → Onboarding (stub — Onboarding screen not yet built)
    // - Authed + profile → Today

    final hasSession = await _checkAuthSession();
    final hasProfile = await ProfileService.hasPersistedProfile();

    if (!mounted) return;

    if (!hasSession) {
      // No session → Auth
      _navigateToAuth();
    } else if (!hasProfile) {
      // Session but no profile → Onboarding
      // STUB: Onboarding screen not yet built, route to Today
      debugPrint('Splash hand-off: hasSession=true, hasProfile=false (Onboarding stub → Today)');
      _navigateToToday();
    } else {
      // Session + profile → Today
      debugPrint('Splash hand-off: hasSession=true, hasProfile=true → Today');
      _navigateToToday();
    }
  }

  Future<bool> _checkAuthSession() async {
    // STUB: No real auth session storage yet.
    // When auth is implemented: check SharedPreferences/SecureStorage for session token.
    // For now, return false to always show Auth screen on first launch.
    // Return true if you want to skip Auth and go directly to Today.
    return ProfileService.hasPersistedProfile();
  }

  void _navigateToAuth() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const AuthScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _navigateToToday() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const TodayScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _breatheOuterController.dispose();
    _breatheMidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.appSurface,
      body: Stack(
        children: [
          // Soft centred wash (Step 1)
          _buildSurfaceWash(),

          // Center stack (Steps 2-4)
          SafeArea(
            child: Center(
              child: _buildCenterStack(),
            ),
          ),

          // Privacy line anchored at bottom (Step 4)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: _buildPrivacyLine(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurfaceWash() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.16), // 50% 42%
            radius: 0.8, // 80% width
            colors: [
              MivaltaColors.tertiaryTealSolid.withValues(alpha: 0.10),
              Colors.transparent,
            ],
            stops: const [0.0, 0.70],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterStack() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _entranceController,
        _breatheOuterController,
        _breatheMidController,
      ]),
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glow field with logo (Steps 2-3)
            _buildGlowWithLogo(),

            // 26px gap (Step 2)
            const SizedBox(height: 26),

            // Wordmark (Step 4)
            Transform.translate(
              offset: _wordmarkOffset.value,
              child: Opacity(
                opacity: _wordmarkOpacity.value,
                child: Text(
                  'MiValta',
                  style: GoogleFonts.zenDots(
                    fontSize: 25,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                    color: MivaltaColors.textPrimary,
                  ),
                ),
              ),
            ),

            // Tagline with negative margin (Step 4)
            Transform.translate(
              offset: Offset(0, _taglineOffset.value.dy - 14), // margin-top -14px
              child: Opacity(
                opacity: _taglineOpacity.value,
                child: Text(
                  'Your body, read honestly.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.3,
                    color: MivaltaColors.textPrimary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlowWithLogo() {
    // Determine if breathing is active (entrance complete)
    final isBreathing = _entranceComplete;

    // Compute current scales and opacities
    final outerScale = isBreathing
        ? _outerHaloScale.value * _breatheOuterScale.value
        : _outerHaloScale.value;
    final outerOpacity = isBreathing
        ? _outerHaloOpacity.value * _breatheOuterOpacity.value
        : _outerHaloOpacity.value;
    final midScale = isBreathing
        ? _midHaloScale.value * _breatheMidScale.value
        : _midHaloScale.value;
    final midOpacity = isBreathing
        ? _midHaloOpacity.value * _breatheMidOpacity.value
        : _midHaloOpacity.value;

    return SizedBox(
      width: MivaltaGlow.splashFieldSize,
      height: MivaltaGlow.splashFieldSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer halo (240×240)
          Transform.scale(
            scale: outerScale,
            child: Opacity(
              opacity: outerOpacity.clamp(0.0, 1.0),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: MivaltaGlow.splashOuterBlur,
                  sigmaY: MivaltaGlow.splashOuterBlur,
                ),
                child: Container(
                  width: MivaltaGlow.splashOuterSize,
                  height: MivaltaGlow.splashOuterSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        MivaltaColors.tertiaryTealSolid.withValues(
                          alpha: MivaltaGlow.splashOuterAlpha,
                        ),
                        Colors.transparent,
                      ],
                      stops: [0.0, MivaltaGlow.splashOuterStop],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Mid halo (172×172)
          Transform.scale(
            scale: midScale,
            child: Opacity(
              opacity: midOpacity.clamp(0.0, 1.0),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: MivaltaGlow.splashMidBlur,
                  sigmaY: MivaltaGlow.splashMidBlur,
                ),
                child: Container(
                  width: MivaltaGlow.splashMidSize,
                  height: MivaltaGlow.splashMidSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        MivaltaColors.tertiaryTealSolid.withValues(
                          alpha: MivaltaGlow.splashMidAlpha,
                        ),
                        Colors.transparent,
                      ],
                      stops: [0.0, MivaltaGlow.splashMidStop],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Logo mark (108×108, z-above halos)
          Transform.scale(
            scale: _logoScale.value,
            child: Opacity(
              opacity: _logoOpacity.value,
              child: SvgPicture.asset(
                'assets/mivalta-logo.svg',
                width: 108,
                height: 108,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyLine() {
    return Opacity(
      opacity: _privacyOpacity.value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock,
            size: 13,
            color: MivaltaColors.brandGreen,
          ),
          const SizedBox(width: 6),
          Text(
            'Computed on your phone · never on a server',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: MivaltaColors.textPrimary.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
