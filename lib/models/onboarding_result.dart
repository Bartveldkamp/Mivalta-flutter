// Onboarding result type — extracted from onboarding_screen.dart.
//
// This type is needed by main.dart's onboarding flow. The UI screen is
// deleted; only the result type remains.

/// Result of the onboarding flow.
///
/// FL-16: carries the RAW onboarding inputs (not a built profile). The engine
/// completes them into a full AthleteProfile downstream — the client computes
/// nothing.
class OnboardingResult {
  const OnboardingResult({required this.inputsJson});
  final String inputsJson;
}
