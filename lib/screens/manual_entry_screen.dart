// PR-D: Manual entry form for daily biometrics.
//
// Display only for labels; user INPUT for the form fields themselves.
// On submit: processManualObservation → saveState → writeViterbiState
//            → writeMinimalBiometric → pop back.
//
// TOKENS ONLY — no inline Colors/hex/TextStyle.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../rust_engine.dart';
import '../theme/tokens.dart';

/// Manual entry screen for logging daily biometrics.
///
/// Receives the engine binding and handle from the parent screen
/// so we don't re-bootstrap. On submit, processes the observation
/// through the HMM and persists state.
class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({
    super.key,
    required this.binding,
    required this.handle,
  });

  final RustEngineBinding binding;
  final EnginesHandle handle;

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form state
  late DateTime _selectedDate;
  final _restingHrController = TextEditingController();
  final _hrvRmssdController = TextEditingController();
  final _sleepHoursController = TextEditingController();
  final _rpeController = TextEditingController();

  // UI state
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _restingHrController.dispose();
    _hrvRmssdController.dispose();
    _sleepHoursController.dispose();
    _rpeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        // Apply dark theme to date picker
        return Theme(
          data: mivaltaDarkTheme().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: MivaltaColors.primaryGreen,
              surface: MivaltaColors.surface1,
              onSurface: MivaltaColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final isoDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Parse optional fields (null if empty)
      final restingHr = _restingHrController.text.isNotEmpty
          ? double.tryParse(_restingHrController.text)
          : null;
      final hrvRmssd = _hrvRmssdController.text.isNotEmpty
          ? double.tryParse(_hrvRmssdController.text)
          : null;
      final sleepHours = _sleepHoursController.text.isNotEmpty
          ? double.tryParse(_sleepHoursController.text)
          : null;
      final rpe = _rpeController.text.isNotEmpty
          ? int.tryParse(_rpeController.text)
          : null;

      // Process through HMM
      await widget.binding.processManualObservation(
        widget.handle,
        isoDate: isoDate,
        restingHr: restingHr,
        hrvRmssd: hrvRmssd,
        sleepHours: sleepHours,
        rpe: rpe,
      );

      // Save state and persist
      final stateJson = await widget.binding.saveState(widget.handle);
      await widget.binding.writeViterbiState(widget.handle, stateJson: stateJson);

      // Write minimal biometric for source tier tracking
      if (restingHr != null) {
        await widget.binding.writeMinimalBiometric(
          handle: widget.handle,
          source: 'manual',
          isoDate: isoDate,
          restingHr: restingHr.round(),
        );
      }

      // Pop back to refresh the readiness screen
      if (mounted) {
        Navigator.of(context).pop(true); // true = data was entered
      }
    } on BridgeError catch (e) {
      setState(() {
        _error = 'Engine error: $e';
        _submitting = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        foregroundColor: MivaltaColors.textPrimary,
        title: Text(
          'Log Today',
          style: textTheme.titleLarge?.copyWith(
            color: MivaltaColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MivaltaSpace.x4),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Error banner
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(MivaltaSpace.x3),
                    decoration: BoxDecoration(
                      color: MivaltaColors.levelRed.withAlpha(40),
                      borderRadius: BorderRadius.circular(MivaltaRadii.sm),
                    ),
                    child: Text(
                      _error!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: MivaltaColors.levelRed,
                      ),
                    ),
                  ),
                  const SizedBox(height: MivaltaSpace.x4),
                ],

                // Date picker
                _SectionCard(
                  title: 'DATE',
                  child: InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: MivaltaSpace.x3,
                        horizontal: MivaltaSpace.x4,
                      ),
                      decoration: BoxDecoration(
                        color: MivaltaColors.surface2,
                        borderRadius: BorderRadius.circular(MivaltaRadii.sm),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                            style: textTheme.bodyLarge?.copyWith(
                              color: MivaltaColors.textPrimary,
                            ),
                          ),
                          const Icon(
                            Icons.calendar_today,
                            color: MivaltaColors.textMuted,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MivaltaSpace.x4),

                // Resting HR
                _SectionCard(
                  title: 'RESTING HEART RATE',
                  subtitle: 'bpm',
                  child: _NumberField(
                    controller: _restingHrController,
                    hint: 'e.g. 52',
                    validator: (v) {
                      if (v == null || v.isEmpty) return null; // Optional
                      final n = double.tryParse(v);
                      if (n == null || n < 30 || n > 200) {
                        return 'Enter 30-200 bpm';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: MivaltaSpace.x4),

                // HRV RMSSD
                _SectionCard(
                  title: 'HRV (RMSSD)',
                  subtitle: 'ms',
                  child: _NumberField(
                    controller: _hrvRmssdController,
                    hint: 'e.g. 45',
                    validator: (v) {
                      if (v == null || v.isEmpty) return null; // Optional
                      final n = double.tryParse(v);
                      if (n == null || n < 5 || n > 300) {
                        return 'Enter 5-300 ms';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: MivaltaSpace.x4),

                // Sleep hours
                _SectionCard(
                  title: 'SLEEP',
                  subtitle: 'hours',
                  child: _NumberField(
                    controller: _sleepHoursController,
                    hint: 'e.g. 7.5',
                    allowDecimal: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null; // Optional
                      final n = double.tryParse(v);
                      if (n == null || n < 0 || n > 24) {
                        return 'Enter 0-24 hours';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: MivaltaSpace.x4),

                // RPE (yesterday's session)
                _SectionCard(
                  title: 'YESTERDAY\'S SESSION RPE',
                  subtitle: '1-10 scale',
                  child: _NumberField(
                    controller: _rpeController,
                    hint: 'e.g. 6',
                    validator: (v) {
                      if (v == null || v.isEmpty) return null; // Optional
                      final n = int.tryParse(v);
                      if (n == null || n < 1 || n > 10) {
                        return 'Enter 1-10';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: MivaltaSpace.x6),

                // Submit button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MivaltaColors.primaryGreen,
                      foregroundColor: MivaltaColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MivaltaRadii.md),
                      ),
                      disabledBackgroundColor: MivaltaColors.surface2,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: MivaltaColors.textPrimary,
                            ),
                          )
                        : Text(
                            'Log Entry',
                            style: textTheme.labelLarge?.copyWith(
                              color: MivaltaColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: MivaltaSpace.x4),

                // Help text
                Text(
                  'All fields are optional. Enter what you have available.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: MivaltaColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section card with title and content.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: MivaltaColors.textMuted,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: MivaltaSpace.x2),
                Text(
                  subtitle!,
                  style: textTheme.labelSmall?.copyWith(
                    color: MivaltaColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: MivaltaSpace.x3),
          child,
        ],
      ),
    );
  }
}

/// Number input field with tokens styling.
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.hint,
    this.validator,
    this.allowDecimal = false,
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      style: textTheme.headlineSmall?.copyWith(
        color: MivaltaColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: textTheme.headlineSmall?.copyWith(
          color: MivaltaColors.textMuted,
        ),
        filled: true,
        fillColor: MivaltaColors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MivaltaRadii.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MivaltaRadii.sm),
          borderSide: const BorderSide(
            color: MivaltaColors.primaryGreen,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MivaltaRadii.sm),
          borderSide: const BorderSide(
            color: MivaltaColors.levelRed,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MivaltaRadii.sm),
          borderSide: const BorderSide(
            color: MivaltaColors.levelRed,
            width: 2,
          ),
        ),
        errorStyle: textTheme.bodySmall?.copyWith(
          color: MivaltaColors.levelRed,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: MivaltaSpace.x3,
          horizontal: MivaltaSpace.x4,
        ),
      ),
    );
  }
}
