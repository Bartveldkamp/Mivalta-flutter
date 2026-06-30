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

      // Fatigue state (for glow color)
      final fatigueJson = await binding.viterbiFatigueState(handle);
      final fatigueMap = jsonDecode(fatigueJson) as Map<String, dynamic>;
      data.fatigueState = fatigueMap['fatigue_state'] as String?;

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

              const SizedBox(height: MivaltaSpace.x3),

              // Josi card — from state_recommendation (I1 fix: engine state, not realizer)
              JosiCard(
                line: _data.stateRecommendation,
              ),

              const SizedBox(height: MivaltaSpace.x3),

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
