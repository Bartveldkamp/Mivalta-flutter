// Auth Screen — identity boundary, not health.
//
// BS-001-auth: Apple + email passwordless authentication.
// The single honest boundary: identity in, health stays on device.
// Account stores email + tier only. Say it on-screen; keep the promise true.
//
// Three sub-states:
// - Root: Apple Sign In + Continue with email
// - Email: email field + send code
// - Code: 6-digit code entry, paste-aware
//
// One action = create OR sign in. No separate sign-up vs log-in screens.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/tokens.dart';
import 'today_screen.dart';

/// Auth sub-states.
enum _AuthState { root, email, code }

/// The auth screen — identity boundary, not health.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  // ─── Current sub-state ───
  _AuthState _currentState = _AuthState.root;

  // ─── Animation controllers ───
  late final AnimationController _entranceController;
  late final AnimationController _breatheOuterController;
  late final AnimationController _breatheMidController;

  // ─── Entrance animations ───
  late final Animation<double> _glowOpacity;
  late final Animation<double> _copyOpacity;
  late final Animation<Offset> _copyOffset;
  late final Animation<double> _actionsOpacity;
  late final Animation<Offset> _actionsOffset;

  // ─── Breathe animations ───
  late final Animation<double> _breatheOuterScale;
  late final Animation<double> _breatheOuterOpacity;
  late final Animation<double> _breatheMidScale;
  late final Animation<double> _breatheMidOpacity;

  // ─── State ───
  bool _entranceComplete = false;
  bool _reducedMotion = false;

  // ─── Email sub-state ───
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  bool _emailValid = false;

  // ─── Code sub-state ───
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _codeFocusNodes = List.generate(6, (_) => FocusNode());
  int _resendCountdown = 0;
  bool _codeError = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _emailController.addListener(_onEmailChanged);
  }

  void _initAnimations() {
    // Total entrance duration: ~1.4s (last element starts at 0.8s + 0.6s rise)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Breathe controllers (6s loop, counter-phased)
    _breatheOuterController = AnimationController(
      vsync: this,
      duration: MivaltaGlow.authBreatheDuration,
    );
    _breatheMidController = AnimationController(
      vsync: this,
      duration: MivaltaGlow.authBreatheDuration,
    );

    // ─── Entrance timeline (normalized to 1400ms) ───
    // 0.10s glow + wordmark: fade 0→1, .7s decelerate
    _glowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.07, 0.57, curve: Curves.easeOutCubic), // 100-800ms
      ),
    );

    // 0.50s copy block: riseIn translateY 9→0, opacity 0→1, .6s decelerate
    _copyOffset = Tween<Offset>(
      begin: const Offset(0, 9),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.36, 0.79, curve: Curves.easeOutCubic), // 500-1100ms
      ),
    );
    _copyOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.36, 0.79, curve: Curves.easeOutCubic),
      ),
    );

    // 0.80s actions: riseIn translateY 9→0, opacity 0→1, .6s decelerate
    _actionsOffset = Tween<Offset>(
      begin: const Offset(0, 9),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.57, 1.0, curve: Curves.easeOutCubic), // 800-1400ms
      ),
    );
    _actionsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.57, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // ─── Breathe animations (opacity .72↔.9, scale .98↔1.04) ───
    _breatheOuterScale = Tween<double>(begin: 0.98, end: 1.04).animate(
      CurvedAnimation(parent: _breatheOuterController, curve: Curves.ease),
    );
    _breatheOuterOpacity = Tween<double>(begin: 0.72, end: 0.9).animate(
      CurvedAnimation(parent: _breatheOuterController, curve: Curves.ease),
    );
    // Mid is counter-phased (reverse)
    _breatheMidScale = Tween<double>(begin: 1.04, end: 0.98).animate(
      CurvedAnimation(parent: _breatheMidController, curve: Curves.ease),
    );
    _breatheMidOpacity = Tween<double>(begin: 0.9, end: 0.72).animate(
      CurvedAnimation(parent: _breatheMidController, curve: Curves.ease),
    );

    // Listen for entrance completion
    _entranceController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _entranceComplete = true);
        _startBreathing();
      }
    });

    // Check for reduced motion after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mediaQuery = MediaQuery.of(context);
      _reducedMotion = mediaQuery.disableAnimations;

      if (_reducedMotion) {
        _entranceController.value = 1.0;
        setState(() => _entranceComplete = true);
      } else {
        _entranceController.forward();
      }
    });
  }

  void _startBreathing() {
    if (_reducedMotion) return;
    _breatheOuterController.repeat(reverse: true);
    _breatheMidController.repeat(reverse: true);
  }

  void _onEmailChanged() {
    final email = _emailController.text.trim();
    final valid = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
    if (valid != _emailValid) {
      setState(() => _emailValid = valid);
    }
  }

  void _onAppleSignIn() {
    // STUB: Apple Sign In not yet implemented
    // When implemented: create/authenticate via Apple → route to Onboarding or Today
    debugPrint('Apple Sign In tapped (stub)');
    _completeAuth(isNewAccount: true);
  }

  void _onContinueWithEmail() {
    setState(() => _currentState = _AuthState.email);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emailFocusNode.requestFocus();
    });
  }

  void _onSendCode() {
    if (!_emailValid) return;

    // STUB: Send email code not yet implemented
    debugPrint('Send code to: ${_emailController.text} (stub)');

    setState(() {
      _currentState = _AuthState.code;
      _resendCountdown = 30;
    });

    // Start countdown
    _startResendCountdown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _codeFocusNodes[0].requestFocus();
    });
  }

  void _startResendCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _currentState != _AuthState.code) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
        _startResendCountdown();
      }
    });
  }

  void _onCodeChanged(int index, String value) {
    // Clear error on any input
    if (_codeError) {
      setState(() => _codeError = false);
    }

    if (value.length == 1 && index < 5) {
      // Auto-advance to next cell
      _codeFocusNodes[index + 1].requestFocus();
    }

    // Check if all 6 digits entered
    final code = _codeControllers.map((c) => c.text).join();
    if (code.length == 6) {
      _verifyCode(code);
    }
  }

  void _onCodePaste(String pastedText) {
    // Handle paste of full code
    final digits = pastedText.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 6) {
      for (int i = 0; i < 6; i++) {
        _codeControllers[i].text = digits[i];
      }
      _codeFocusNodes[5].requestFocus();
      _verifyCode(digits.substring(0, 6));
    }
  }

  void _verifyCode(String code) {
    // STUB: Verify code not yet implemented
    debugPrint('Verifying code: $code (stub)');

    // Simulate verification — always succeed for now
    // In production: API call, handle wrong code with _codeError = true
    _completeAuth(isNewAccount: true);
  }

  void _completeAuth({required bool isNewAccount}) {
    // Route based on whether this is a new account
    // - New account (no profile) → Onboarding
    // - Returning account → Today
    //
    // STUB: Onboarding not yet built. Route to Today for both cases.
    // When Onboarding exists: if (isNewAccount) → OnboardingScreen
    debugPrint('Auth complete: isNewAccount=$isNewAccount (routing to Today)');

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          // STUB: Always Today until Onboarding exists
          // if (isNewAccount) return const OnboardingScreen();
          return const TodayScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _onBack() {
    setState(() {
      if (_currentState == _AuthState.code) {
        _currentState = _AuthState.email;
        // Clear code fields
        for (final c in _codeControllers) {
          c.clear();
        }
      } else if (_currentState == _AuthState.email) {
        _currentState = _AuthState.root;
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _breatheOuterController.dispose();
    _breatheMidController.dispose();
    _emailController.dispose();
    _emailFocusNode.dispose();
    for (final c in _codeControllers) {
      c.dispose();
    }
    for (final f in _codeFocusNodes) {
      f.dispose();
    }
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

          // Content based on current state
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _currentState == _AuthState.root
                  ? _buildRootState()
                  : _currentState == _AuthState.email
                      ? _buildEmailState()
                      : _buildCodeState(),
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
            center: const Alignment(0, -0.4), // 50% 30%
            radius: 0.78, // 78% width
            colors: [
              MivaltaColors.tertiaryTealSolid.withValues(alpha: 0.10),
              Colors.transparent,
            ],
            stops: const [0.0, 0.44], // 44% height
          ),
        ),
      ),
    );
  }

  // ─── ROOT STATE ───
  Widget _buildRootState() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _entranceController,
        _breatheOuterController,
        _breatheMidController,
      ]),
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.only(top: 74, left: 30, right: 30, bottom: 30),
          child: Column(
            children: [
              // Top cluster: glow + wordmark
              Opacity(
                opacity: _glowOpacity.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGlowWithLogo(),
                    const SizedBox(height: 18),
                    Text(
                      'MiValta',
                      style: GoogleFonts.zenDots(
                        fontSize: 19,
                        fontWeight: FontWeight.w400,
                        color: MivaltaColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              // Copy block
              Transform.translate(
                offset: _copyOffset.value,
                child: Opacity(
                  opacity: _copyOpacity.value,
                  child: _buildCopyBlock(),
                ),
              ),

              const Spacer(),

              // Actions pinned to bottom
              Transform.translate(
                offset: _actionsOffset.value,
                child: Opacity(
                  opacity: _actionsOpacity.value,
                  child: _buildActions(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlowWithLogo() {
    final isBreathing = _entranceComplete && !_reducedMotion;

    final outerScale = isBreathing ? _breatheOuterScale.value : 1.0;
    final outerOpacity = isBreathing
        ? MivaltaGlow.authRestingAlpha * _breatheOuterOpacity.value
        : MivaltaGlow.authRestingAlpha;
    final midScale = isBreathing ? _breatheMidScale.value : 1.0;
    final midOpacity = isBreathing
        ? MivaltaGlow.authRestingAlpha * _breatheMidOpacity.value
        : MivaltaGlow.authRestingAlpha;

    return SizedBox(
      width: MivaltaGlow.authFieldSize,
      height: MivaltaGlow.authFieldSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer halo (200×200)
          Transform.scale(
            scale: outerScale,
            child: Opacity(
              opacity: outerOpacity.clamp(0.0, 1.0),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: MivaltaGlow.authOuterBlur,
                  sigmaY: MivaltaGlow.authOuterBlur,
                ),
                child: Container(
                  width: MivaltaGlow.authOuterSize,
                  height: MivaltaGlow.authOuterSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        MivaltaColors.tertiaryTealSolid.withValues(
                          alpha: MivaltaGlow.authOuterAlpha,
                        ),
                        Colors.transparent,
                      ],
                      stops: [0.0, MivaltaGlow.authOuterStop],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Mid halo (132×132)
          Transform.scale(
            scale: midScale,
            child: Opacity(
              opacity: midOpacity.clamp(0.0, 1.0),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: MivaltaGlow.authMidBlur,
                  sigmaY: MivaltaGlow.authMidBlur,
                ),
                child: Container(
                  width: MivaltaGlow.authMidSize,
                  height: MivaltaGlow.authMidSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        MivaltaColors.tertiaryTealSolid.withValues(
                          alpha: MivaltaGlow.authMidAlpha,
                        ),
                        Colors.transparent,
                      ],
                      stops: [0.0, MivaltaGlow.authMidStop],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Logo mark (62×62)
          SvgPicture.asset(
            'assets/mivalta-logo.svg',
            width: MivaltaGlow.authLogoSize,
            height: MivaltaGlow.authLogoSize,
          ),
        ],
      ),
    );
  }

  Widget _buildCopyBlock() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Heading
        Text(
          'One quiet account.',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.48, // -0.02em
            color: MivaltaColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        // Sub — with bold clause
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.5,
              color: MivaltaColors.textPrimary.withValues(alpha: 0.55),
            ),
            children: [
              const TextSpan(text: 'It carries your program and tier between devices. '),
              TextSpan(
                text: 'Your health data never leaves this phone.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                  color: MivaltaColors.textPrimary.withValues(alpha: 0.84),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sign in with Apple (primary)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _onAppleSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: MivaltaColors.textPrimary,
              foregroundColor: MivaltaColors.appSurface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.apple, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Sign in with Apple',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 11),

        // Continue with email (ghost)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _onContinueWithEmail,
            style: OutlinedButton.styleFrom(
              foregroundColor: MivaltaColors.textPrimary,
              side: BorderSide(
                color: MivaltaColors.tertiaryTealSolid.withValues(alpha: 0.30),
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 19,
                  color: MivaltaColors.tertiaryTealSolid,
                ),
                const SizedBox(width: 8),
                Text(
                  'Continue with email',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Consent line
        _buildConsentLine(),
      ],
    );
  }

  Widget _buildConsentLine() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w400,
          color: MivaltaColors.textPrimary.withValues(alpha: 0.40),
        ),
        children: [
          const TextSpan(text: 'By continuing you agree to the '),
          TextSpan(
            text: 'Terms',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              color: MivaltaColors.textPrimary.withValues(alpha: 0.64),
              decoration: TextDecoration.underline,
            ),
          ),
          const TextSpan(text: ' & '),
          TextSpan(
            text: 'Privacy Policy',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              color: MivaltaColors.textPrimary.withValues(alpha: 0.64),
              decoration: TextDecoration.underline,
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }

  // ─── EMAIL STATE ───
  Widget _buildEmailState() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 30, right: 30, bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          IconButton(
            onPressed: _onBack,
            icon: const Icon(Icons.chevron_left),
            color: MivaltaColors.textPrimary,
            iconSize: 28,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),

          const SizedBox(height: 32),

          // Logo mark (40px)
          Center(
            child: SvgPicture.asset(
              'assets/mivalta-logo.svg',
              width: 40,
              height: 40,
            ),
          ),

          const SizedBox(height: 24),

          // Heading
          Center(
            child: Text(
              "What's your email?",
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: MivaltaColors.textPrimary,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Sub
          Center(
            child: Text(
              "We'll send a one-time code — no password to set.",
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: MivaltaColors.textPrimary.withValues(alpha: 0.50),
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 32),

          // Email field
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: MivaltaColors.codeCellBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: MivaltaColors.codeCellBorder,
                width: 1,
              ),
            ),
            child: TextField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: MivaltaColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'you@email.com',
                hintStyle: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: MivaltaColors.textPrimary.withValues(alpha: 0.30),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Send code button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _emailValid ? _onSendCode : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: MivaltaColors.tertiaryTealSolid,
                foregroundColor: MivaltaColors.authAppleButtonForeground,
                disabledBackgroundColor:
                    MivaltaColors.tertiaryTealSolid.withValues(alpha: 0.30),
                disabledForegroundColor:
                    MivaltaColors.authAppleButtonForeground.withValues(alpha: 0.50),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Send code',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const Spacer(),

          // Reassurance (binding boundary statement)
          Center(
            child: Text(
              'Used to sign you in and carry your tier. Never for health data.',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w400,
                color: MivaltaColors.textPrimary.withValues(alpha: 0.40),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ─── CODE STATE ───
  Widget _buildCodeState() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 30, right: 30, bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          IconButton(
            onPressed: _onBack,
            icon: const Icon(Icons.chevron_left),
            color: MivaltaColors.textPrimary,
            iconSize: 28,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),

          const SizedBox(height: 32),

          // Logo mark (40px)
          Center(
            child: SvgPicture.asset(
              'assets/mivalta-logo.svg',
              width: 40,
              height: 40,
            ),
          ),

          const SizedBox(height: 24),

          // Heading
          Center(
            child: Text(
              'Enter your code',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: MivaltaColors.textPrimary,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Sub — shows email
          Center(
            child: Text(
              'Sent to ${_emailController.text}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: MivaltaColors.textPrimary.withValues(alpha: 0.50),
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 32),

          // 6-cell code entry
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              return Padding(
                padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                child: _buildCodeCell(index),
              );
            }),
          ),

          // Error message
          if (_codeError) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                "That code didn't match — try again",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: MivaltaColors.levelRed,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Resend link
          Center(
            child: _resendCountdown > 0
                ? Text(
                    'Resend in ${_resendCountdown}s',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: MivaltaColors.textPrimary.withValues(alpha: 0.40),
                    ),
                  )
                : GestureDetector(
                    onTap: () {
                      setState(() => _resendCountdown = 30);
                      _startResendCountdown();
                      // STUB: Resend code
                      debugPrint('Resend code (stub)');
                    },
                    child: Text(
                      'Resend',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MivaltaColors.tertiaryTealSolid,
                      ),
                    ),
                  ),
          ),

          const Spacer(),

          // Reassurance (binding boundary statement)
          Center(
            child: Text(
              'Used to sign you in and carry your tier. Never for health data.',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w400,
                color: MivaltaColors.textPrimary.withValues(alpha: 0.40),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCell(int index) {
    return Container(
      width: 44,
      height: 52,
      decoration: BoxDecoration(
        color: MivaltaColors.codeCellBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _codeError
              ? MivaltaColors.levelRed.withValues(alpha: 0.50)
              : MivaltaColors.codeCellBorder,
          width: 1,
        ),
      ),
      child: TextField(
        controller: _codeControllers[index],
        focusNode: _codeFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: MivaltaColors.textPrimary,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) => _onCodeChanged(index, value),
        onTap: () {
          // Handle paste
          Clipboard.getData('text/plain').then((data) {
            if (data?.text != null && data!.text!.length >= 6) {
              _onCodePaste(data.text!);
            }
          });
        },
      ),
    );
  }
}
