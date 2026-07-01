// Today Screen — the home.
//
// Per Today-Modular.html: glow hero → Josi line → decision chip → module cards.
// Engine DECIDES, Flutter DISPLAYS. Wires to real engine data via HomeData.
//
// DR-001 corrections applied:
// - "Today" left-aligned in app bar
// - Hero number in Inter (not Zen Dots)
// - Josi line from state_recommendation
// - Recovered = #7FE3B0

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/home_data.dart';
import '../rust_engine.dart';
import '../services/profile_service.dart';
import '../theme/tokens.dart';
import '../widgets/today/glow_hero.dart';
import '../widgets/today/josi_card.dart';
import '../widgets/today/module_card.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  HomeData _data = HomeData();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  Future<void> _initEngine() async {
    try {
      // Bootstrap FRB
      final binding = await RustEngineBinding.bootstrap();

      // Load profile
      final profileJson = await ProfileService.loadProfile();
      if (profileJson == null) {
        // No profile — show honest absence
        setState(() {
          _data.insufficientData = true;
          _loading = false;
        });
        return;
      }

      // Load tables
      final tablesJson = await rootBundle.loadString('assets/compiled_tables.json');
      final vaultPath = await ProfileService.getVaultPath();

      // Check for persisted state
      final hasState = await binding.hasPersistedState(
        athleteProfileJson: profileJson,
        vaultPath: vaultPath,
      );

      EnginesHandle handle;
      if (hasState) {
        final stateJson = await binding.readPersistedState(
          athleteProfileJson: profileJson,
          vaultPath: vaultPath,
        );
        if (stateJson != null) {
          handle = await binding.constructEnginesFromState(
            athleteProfileJson: profileJson,
            tablesJson: tablesJson,
            vaultPath: vaultPath,
            viterbiStateJson: stateJson,
          );
        } else {
          handle = await binding.constructEnginesFresh(
            athleteProfileJson: profileJson,
            tablesJson: tablesJson,
            vaultPath: vaultPath,
          );
        }
      } else {
        handle = await binding.constructEnginesFresh(
          athleteProfileJson: profileJson,
          tablesJson: tablesJson,
          vaultPath: vaultPath,
        );
      }

      // Load home data
      await _loadHomeData(binding, handle);
    } catch (e) {
      setState(() {
        _data.error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadHomeData(RustEngineBinding binding, EnginesHandle handle) async {
    final data = HomeData();

    try {
      // Zone 1 — Readiness indicator (headline)
      final indicatorJson = await binding.readinessIndicator(handle);
      final indicator = jsonDecode(indicatorJson) as Map<String, dynamic>;
      data.readinessScore = (indicator['score'] as num?)?.toInt();
      data.confidence = (indicator['confidence'] as num?)?.toDouble();
      data.level = indicator['level'] as String?;
      data.contributions = (indicator['contributions'] as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [];

      // Check insufficient data gate
      data.insufficientData = insufficientDataFromConfidence(data.confidence);

      // State advisory (for Josi)
      final stateJson = await binding.stateAdvisory(handle);
      final stateMap = jsonDecode(stateJson) as Map<String, dynamic>;
      data.stateRecommendation = stateMap['state_recommendation'] as String?;
      data.confidenceAdvisory = stateMap['confidence_advisory'] as String?;

      // Fatigue state (for glow color + state word)
      // Engine returns {"state":"Recovered",...} — key is "state", not "fatigue_state"
      final fatigueJson = await binding.viterbiFatigueState(handle);
      final fatigueMap = jsonDecode(fatigueJson) as Map<String, dynamic>;
      data.fatigueState = fatigueMap['state'] as String?;

      // Zone 2 — Today load (for module card)
      try {
        final loadsJson = await binding.readDailyLoads(handle, days: 1);
        final loads = jsonDecode(loadsJson) as List;
        if (loads.isNotEmpty) {
          final todayLoad = loads.last;
          if (todayLoad is List && todayLoad.length >= 2) {
            data.todayLoad = (todayLoad[1] as num?)?.toDouble();
          }
        }
      } catch (_) {
        // Honest absence
      }

      // Sleep (for module card)
      try {
        final bioJson = await binding.readBiometricHistory(handle, days: 1);
        final bio = jsonDecode(bioJson) as List;
        if (bio.isNotEmpty) {
          final lastBio = bio.last as Map<String, dynamic>;
          data.lastNightSleepHours = (lastBio['sleep_hours'] as num?)?.toDouble();
        }
      } catch (_) {
        // Honest absence
      }

      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _data.error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: MivaltaColors.stateProductive,
                ),
              )
            : _buildContent(),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: MivaltaColors.surfaceBackground,
        border: Border(
          top: BorderSide(
            color: MivaltaColors.textPrimary.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.wb_sunny_outlined,
                activeIcon: Icons.wb_sunny,
                label: 'Today',
                isActive: true,
              ),
              _NavItem(
                icon: Icons.route_outlined,
                activeIcon: Icons.route,
                label: 'Journey',
                isActive: false,
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'You',
                isActive: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_data.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(MivaltaSpace.x4),
          child: Text(
            'Unable to load: ${_data.error}',
            style: const TextStyle(color: MivaltaColors.levelRed),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // App bar — "Today" left-aligned (DR-001)
        SliverAppBar(
          backgroundColor: MivaltaColors.surfaceBackground,
          pinned: true,
          title: const Text(
            'Today',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 24,
              letterSpacing: -0.02 * 24,
              color: MivaltaColors.textPrimary,
            ),
          ),
          centerTitle: false, // DR-001: left-aligned
        ),

        // Content
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: MivaltaSpace.x2),

              // Glow hero
              GlowHero(
                score: _data.readinessScore,
                fatigueState: _data.fatigueState,
                insufficientData: _data.insufficientData,
              ),

              // Josi card — from state_recommendation (I1 fix: engine state, not realizer)
              // BS-001 Step 6: collapse hero void when absent
              if (_data.stateRecommendation != null && _data.stateRecommendation!.isNotEmpty) ...[
                const SizedBox(height: MivaltaSpace.x3),
                JosiCard(line: _data.stateRecommendation),
              ],

              // Decision chip — BS-001 Step 7: honest-absent (hidden, collapse)
              // Not wired: zoneCap and sessionZone are null, so chip collapses
              if ((_data.zoneCap != null && _data.zoneCap!.isNotEmpty) ||
                  (_data.sessionZone != null && _data.sessionZone!.isNotEmpty)) ...[
                const SizedBox(height: MivaltaSpace.x3),
                _DecisionChip(
                  zoneCap: _data.zoneCap,
                  sessionZone: _data.sessionZone,
                ),
              ],

              // Spacing before cards: reduced when Josi + chip both absent
              SizedBox(
                height: (_data.stateRecommendation == null || _data.stateRecommendation!.isEmpty) &&
                        (_data.zoneCap == null || _data.zoneCap!.isEmpty) &&
                        (_data.sessionZone == null || _data.sessionZone!.isEmpty)
                    ? MivaltaSpace.x2 // ~8px collapsed
                    : MivaltaSpace.x4,
              ),

              // "Your day" section eyebrow
              Padding(
                padding: const EdgeInsets.only(bottom: MivaltaSpace.x3),
                child: Text(
                  'YOUR DAY',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.1,
                    color: const Color(0xFFF4F5F4).withValues(alpha: 0.45),
                  ),
                ),
              ),

              // Module cards (I2 fix: honest-absence pattern, never blank)
              ModuleCard(
                title: 'Load today',
                icon: Icons.trending_up,
                child: _data.todayLoad != null
                    ? MetricRow(
                        label: 'Training load',
                        value: _data.todayLoad!.round().toString(),
                        unit: ' UL',
                      )
                    : const _HonestAbsence(
                        label: 'No activity recorded',
                        unlock: 'Log a workout to see your load',
                      ),
              ),

              const SizedBox(height: MivaltaSpace.x3),

              // Daily activity card
              ModuleCard(
                title: 'Daily activity',
                icon: Icons.directions_walk,
                child: const _HonestAbsence(
                  label: 'No activity data',
                  unlock: 'Connect a health source for steps & movement',
                ),
              ),

              const SizedBox(height: MivaltaSpace.x3),

              ModuleCard(
                title: 'Sleep',
                icon: Icons.bedtime,
                child: _data.lastNightSleepHours != null
                    ? MetricRow(
                        label: 'Last night',
                        value: _formatSleep(_data.lastNightSleepHours!),
                      )
                    : const _HonestAbsence(
                        label: 'No sleep data',
                        unlock: 'Connect a health source',
                      ),
              ),

              const SizedBox(height: MivaltaSpace.x3),

              // Suggested workout card
              ModuleCard(
                title: 'Suggested workout',
                icon: Icons.fitness_center,
                child: _data.workoutTitle != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _data.workoutTitle!,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: MivaltaColors.textPrimary,
                            ),
                          ),
                          if (_data.durationMin != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${_data.durationMin} min',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: MivaltaColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      )
                    : const _HonestAbsence(
                        label: 'No suggestion yet',
                        unlock: 'Complete more workouts to unlock AI suggestions',
                      ),
              ),

              const SizedBox(height: MivaltaSpace.x6),
            ]),
          ),
        ),
      ],
    );
  }

  String _formatSleep(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

/// Honest-absence pattern for module cards (I2): named state + actionable unlock.
class _HonestAbsence extends StatelessWidget {
  const _HonestAbsence({required this.label, required this.unlock});

  final String label;
  final String unlock;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: MivaltaColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          unlock,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: MivaltaColors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// Bottom nav item for Today/Journey/You.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? MivaltaColors.stateProductive
        : MivaltaColors.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isActive ? activeIcon : icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Decision chip — shows the zone cap or primary action for today.
class _DecisionChip extends StatelessWidget {
  const _DecisionChip({
    required this.zoneCap,
    required this.sessionZone,
  });

  final String? zoneCap;
  final String? sessionZone;

  @override
  Widget build(BuildContext context) {
    // Show zone cap if available, otherwise session zone, otherwise honest absence
    final chipText = zoneCap ?? sessionZone;

    if (chipText == null || chipText.isEmpty) {
      // No chip to show — honest absence
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: MivaltaColors.stateProductive.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: MivaltaColors.stateProductive.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt,
              color: MivaltaColors.stateProductive,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              chipText,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MivaltaColors.stateProductive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
