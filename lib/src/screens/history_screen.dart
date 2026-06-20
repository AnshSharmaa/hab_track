import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';

import '../db/app_db.dart';
import '../providers.dart';
import '../repositories/medication_repository.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _rangeDays = 30;
  int? _customDays;
  _HistoryChartMode _chartMode = _HistoryChartMode.summary;
  _HistoryScope _scope = _HistoryScope.all;
  String _selectedHabitId = 'all';
  String _selectedMedicationId = 'all';

  @override
  Widget build(BuildContext context) {
    final isPhone = isPhoneWidth(context);
    final habitsAsync = ref.watch(habitsListProvider);
    final historyAsync = ref.watch(habitHistoryProvider(_rangeDays));
    final statsAsync = ref.watch(habitStatsProvider);
    final medsAsync = ref.watch(medicationsProvider);
    final doseHistoryAsync = ref.watch(medicationDoseHistoryProvider);
    final adherenceAsync = ref.watch(medicationAdherenceProvider(_rangeDays));
    final medLogsAsync = ref.watch(medicationLogsHistoryProvider(_rangeDays));
    final hasActiveFilters =
        _chartMode != _HistoryChartMode.summary ||
        _scope != _HistoryScope.all ||
        _selectedHabitId != 'all' ||
        _selectedMedicationId != 'all';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(gradient: AppDecorations.pageGradient()),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isPhone ? 16 : 28,
              isPhone ? 18 : 36,
              isPhone ? 16 : 28,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HISTORY',
                  style: TextStyle(
                    color: AppColors.textSubtle,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Habit analytics',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: isPhone ? 22 : 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _RangeChip(
                        label: '7d',
                        selected: _rangeDays == 7 && _customDays == null,
                        onTap: () => setState(() {
                          _rangeDays = 7;
                          _customDays = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _RangeChip(
                        label: '30d',
                        selected: _rangeDays == 30 && _customDays == null,
                        onTap: () => setState(() {
                          _rangeDays = 30;
                          _customDays = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _RangeChip(
                        label: '90d',
                        selected: _rangeDays == 90 && _customDays == null,
                        onTap: () => setState(() {
                          _rangeDays = 90;
                          _customDays = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _RangeChip(
                        label: '365d',
                        selected: _rangeDays == 365 && _customDays == null,
                        onTap: () => setState(() {
                          _rangeDays = 365;
                          _customDays = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _RangeChip(
                        label: _customDays == null
                            ? 'Custom'
                            : '${_customDays}d',
                        selected: _customDays != null,
                        onTap: () async {
                          final controller = TextEditingController(
                            text: (_customDays ?? _rangeDays).toString(),
                          );
                          final days = await showDialog<int>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: AppColors.surface,
                              title: const Text(
                                'Custom time range',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Enter days (e.g. 45)',
                                  hintStyle: TextStyle(
                                    color: AppColors.textSubtle,
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    final parsed = int.tryParse(
                                      controller.text.trim(),
                                    );
                                    Navigator.pop(context, parsed);
                                  },
                                  child: const Text('Apply'),
                                ),
                              ],
                            ),
                          );
                          if (days != null && days > 0) {
                            setState(() {
                              _rangeDays = days;
                              _customDays = days;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppDecorations.glassCard(elevated: true),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Visualization',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _RangeChip(
                            label: 'Summary',
                            selected: _chartMode == _HistoryChartMode.summary,
                            onTap: () => setState(
                              () => _chartMode = _HistoryChartMode.summary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _RangeChip(
                            label: 'Heatmap',
                            selected: _chartMode == _HistoryChartMode.heatmap,
                            onTap: () => setState(
                              () => _chartMode = _HistoryChartMode.heatmap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Filters',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      habitsAsync.when(
                        data: (habits) => medsAsync.when(
                          data: (meds) => Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _DropdownFilter<_HistoryScope>(
                                label: 'Scope',
                                value: _scope,
                                items: const [
                                  DropdownMenuItem(
                                    value: _HistoryScope.all,
                                    child: Text('All'),
                                  ),
                                  DropdownMenuItem(
                                    value: _HistoryScope.habits,
                                    child: Text('Habits'),
                                  ),
                                  DropdownMenuItem(
                                    value: _HistoryScope.medications,
                                    child: Text('Medications'),
                                  ),
                                ],
                                onChanged: (v) => setState(
                                  () => _scope = v ?? _HistoryScope.all,
                                ),
                              ),
                              _DropdownFilter<String>(
                                label: 'Habit',
                                value: _selectedHabitId,
                                items: [
                                  const DropdownMenuItem(
                                    value: 'all',
                                    child: Text('All habits'),
                                  ),
                                  ...habits.map(
                                    (h) => DropdownMenuItem(
                                      value: h.id,
                                      child: Text(h.title),
                                    ),
                                  ),
                                ],
                                onChanged: (v) => setState(
                                  () => _selectedHabitId = v ?? 'all',
                                ),
                              ),
                              _DropdownFilter<String>(
                                label: 'Medication',
                                value: _selectedMedicationId,
                                items: [
                                  const DropdownMenuItem(
                                    value: 'all',
                                    child: Text('All meds'),
                                  ),
                                  ...meds.map(
                                    (m) => DropdownMenuItem(
                                      value: m.medication.id,
                                      child: Text(m.medication.name),
                                    ),
                                  ),
                                ],
                                onChanged: (v) => setState(
                                  () => _selectedMedicationId = v ?? 'all',
                                ),
                              ),
                            ],
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (e, stack) => const SizedBox.shrink(),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (e, stack) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                if (hasActiveFilters) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._activeFilterLabels().map(
                        (label) => _ActiveFilterPill(label: label),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _chartMode = _HistoryChartMode.summary;
                            _scope = _HistoryScope.all;
                            _selectedHabitId = 'all';
                            _selectedMedicationId = 'all';
                          });
                        },
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Expanded(
                  child: ListView(
                    children: [
                      if (_chartMode == _HistoryChartMode.summary) ...[
                        const Text(
                          'Trend',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        historyAsync.when(
                          data: (historyMap) => medLogsAsync.when(
                            data: (logs) => _TrendChartCard(
                              dates: _datesForRange(_rangeDays),
                              scores: _buildHeatmapScores(
                                historyMap: historyMap,
                                medLogs: logs,
                              ),
                            ),
                            loading: () => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            error: (_, _) => const Text(
                              'Could not load trend data.',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ),
                          loading: () => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, _) => const Text(
                            'Could not load trend data.',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_chartMode == _HistoryChartMode.heatmap) ...[
                        const Text(
                          'Heatmap',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        historyAsync.when(
                          data: (historyMap) => medLogsAsync.when(
                            data: (logs) => habitsAsync.when(
                              data: (habits) => medsAsync.when(
                                data: (meds) => _ContributionHeatmapCard(
                                  dates: _datesForRange(_rangeDays),
                                  scores: _buildHeatmapScores(
                                    historyMap: historyMap,
                                    medLogs: logs,
                                  ),
                                  onDayTap: (date) => _showDayActivityModal(
                                    date: date,
                                    historyMap: historyMap,
                                    medLogs: logs,
                                    habits: habits,
                                    meds: meds,
                                  ),
                                ),
                                loading: () => const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                error: (_, _) => const Text(
                                  'Could not load heatmap data.',
                                  style: TextStyle(color: AppColors.danger),
                                ),
                              ),
                              loading: () => const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              error: (_, _) => const Text(
                                'Could not load heatmap data.',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                            loading: () => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            error: (_, _) => const Text(
                              'Could not load heatmap data.',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ),
                          loading: () => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, _) => const Text(
                            'Could not load heatmap data.',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_scope != _HistoryScope.medications)
                        const Text(
                          'Habits',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (_scope != _HistoryScope.medications)
                        const SizedBox(height: 10),
                      if (_scope != _HistoryScope.medications)
                        habitsAsync.when(
                          data: (habits) => historyAsync.when(
                            data: (historyMap) => statsAsync.when(
                              data: (statsMap) {
                                final filteredHabits = _selectedHabitId == 'all'
                                    ? habits
                                    : habits
                                          .where(
                                            (h) => h.id == _selectedHabitId,
                                          )
                                          .toList();
                                if (filteredHabits.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Text(
                                      'No matching habits',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  );
                                }
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: filteredHabits.map((habit) {
                                    final instances =
                                        historyMap[habit.id] ?? const [];
                                    final completed = instances
                                        .where((e) => e.completed == 1)
                                        .length;
                                    final stats = statsMap[habit.id];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _HistoryCard(
                                        title: habit.title,
                                        completed: completed,
                                        total: _rangeDays,
                                        streak: stats?.currentStreak ?? 0,
                                        best: stats?.bestStreak ?? 0,
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                              loading: () => const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              error: (_, _) => const Text(
                                'Could not load habit history.',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                            loading: () => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            error: (_, _) => const Text(
                              'Could not load habit history.',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ),
                          loading: () => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, _) => const Text(
                            'Could not load habit history.',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      if (_scope != _HistoryScope.habits)
                        const SizedBox(height: 14),
                      if (_scope != _HistoryScope.habits)
                        const Text(
                          'Medications',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (_scope != _HistoryScope.habits)
                        const SizedBox(height: 10),
                      if (_scope != _HistoryScope.habits)
                        medsAsync.when(
                          data: (meds) => doseHistoryAsync.when(
                            data: (doseHistory) => adherenceAsync.when(
                              data: (adherence) {
                                final filteredMeds =
                                    _selectedMedicationId == 'all'
                                    ? meds
                                    : meds
                                          .where(
                                            (m) =>
                                                m.medication.id ==
                                                _selectedMedicationId,
                                          )
                                          .toList();
                                if (filteredMeds.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Text(
                                      'No matching medications',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  );
                                }
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: filteredMeds.map((med) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _MedicationHistoryCard(
                                        name: med.medication.name,
                                        times: med.times,
                                        statuses:
                                            doseHistory[med.medication.id] ??
                                            const {},
                                        adherenceRate:
                                            adherence[med.medication.id] ?? 0,
                                        adherenceWindowDays: _rangeDays,
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                              loading: () => const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              error: (_, _) => const Text(
                                'Could not load medication history.',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                            loading: () => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            error: (_, _) => const Text(
                              'Could not load medication history.',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ),
                          loading: () => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, _) => const Text(
                            'Could not load medication history.',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _datesForRange(int days) {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days - 1));
    final out = <String>[];
    for (var i = 0; i < days; i++) {
      out.add(toIsoDate(start.add(Duration(days: i))));
    }
    return out;
  }

  Map<String, int> _buildHeatmapScores({
    required Map<String, List<HabitInstance>> historyMap,
    required List<MedicationLog> medLogs,
  }) {
    final scores = <String, int>{};

    if (_scope != _HistoryScope.medications) {
      for (final entry in historyMap.entries) {
        if (_selectedHabitId != 'all' && entry.key != _selectedHabitId) {
          continue;
        }
        for (final instance in entry.value) {
          if (instance.completed == 1) {
            scores[instance.date] = (scores[instance.date] ?? 0) + 1;
          }
        }
      }
    }

    if (_scope != _HistoryScope.habits) {
      for (final log in medLogs) {
        if (_selectedMedicationId != 'all' &&
            log.medicationId != _selectedMedicationId) {
          continue;
        }
        if (log.status == 'taken') {
          scores[log.date] = (scores[log.date] ?? 0) + 1;
        }
      }
    }
    return scores;
  }

  List<String> _activeFilterLabels() {
    final labels = <String>[];
    if (_chartMode != _HistoryChartMode.summary) {
      labels.add('Chart: Heatmap');
    }
    if (_scope != _HistoryScope.all) {
      labels.add(
        'Scope: ${_scope == _HistoryScope.habits ? 'Habits' : 'Medications'}',
      );
    }
    if (_selectedHabitId != 'all') {
      labels.add('Habit selected');
    }
    if (_selectedMedicationId != 'all') {
      labels.add('Medication selected');
    }
    if (_customDays != null) {
      labels.add('Custom: ${_customDays}d');
    }
    return labels;
  }

  Future<void> _showDayActivityModal({
    required DateTime date,
    required Map<String, List<HabitInstance>> historyMap,
    required List<MedicationLog> medLogs,
    required List<Habit> habits,
    required List<MedicationWithTimes> meds,
  }) async {
    final iso = toIsoDate(date);
    final habitNameById = {for (final h in habits) h.id: h.title};
    final medNameById = {
      for (final m in meds) m.medication.id: m.medication.name,
    };

    final habitActivity = <String>[];
    for (final entry in historyMap.entries) {
      final instanceForDay = entry.value.where((i) => i.date == iso);
      for (final instance in instanceForDay) {
        habitActivity.add(
          '${habitNameById[entry.key] ?? 'Habit'}: ${instance.completed == 1 ? 'completed' : 'not completed'}',
        );
      }
    }

    final medActivity = medLogs
        .where((l) => l.date == iso)
        .map(
          (l) =>
              '${medNameById[l.medicationId] ?? 'Medication'} at ${l.time}: ${l.status}',
        )
        .toList();

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Activity • $iso',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width > 620
              ? 480
              : MediaQuery.sizeOf(context).width * 0.86,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Habits',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                if (habitActivity.isEmpty)
                  const Text(
                    'No habit activity',
                    style: TextStyle(color: Color(0xFF64748B)),
                  )
                else
                  ...habitActivity.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        a,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Medications',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                if (medActivity.isEmpty)
                  const Text(
                    'No medication activity',
                    style: TextStyle(color: Color(0xFF64748B)),
                  )
                else
                  ...medActivity.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        a,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

enum _HistoryChartMode { summary, heatmap }

enum _HistoryScope { all, habits, medications }

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.title,
    required this.completed,
    required this.total,
    required this.streak,
    required this.best,
  });

  final String title;
  final int completed;
  final int total;
  final int streak;
  final int best;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completed/$total complete  •  streak $streak  •  best $best',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: AppDecorations.glassChip(selected: selected),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.accentSoft : AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DropdownFilter<T> extends StatelessWidget {
  const _DropdownFilter({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: AppDecorations.glassCard(),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            dropdownColor: AppColors.surfaceAlt,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            iconEnabledColor: AppColors.textMuted,
            hint: Text(label),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _ContributionHeatmapCard extends StatelessWidget {
  const _ContributionHeatmapCard({
    required this.dates,
    required this.scores,
    required this.onDayTap,
  });

  final List<String> dates;
  final Map<String, int> scores;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final datasets = <DateTime, int>{};
    for (final isoDate in dates) {
      final score = scores[isoDate] ?? 0;
      if (score <= 0) continue;
      final date = DateTime.tryParse(isoDate);
      if (date != null) {
        datasets[DateTime(date.year, date.month, date.day)] = score;
      }
    }

    return _HoverableCard(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppDecorations.glassCard(elevated: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily completion intensity',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (datasets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'No completions in this period.',
                    style: TextStyle(color: AppColors.textSubtle, fontSize: 13),
                  ),
                ),
              )
            else
              HeatMap(
                startDate: _parseDate(dates.first),
                endDate: _parseDate(dates.last),
                datasets: datasets,
                colorMode: ColorMode.opacity,
                defaultColor: AppColors.surfaceAlt,
                textColor: AppColors.textSubtle,
                showText: false,
                scrollable: true,
                showColorTip: true,
                size: 18,
                borderRadius: 3,
                colorsets: const {1: Color(0xFF22C55E)},
                onClick: onDayTap,
              ),
            const SizedBox(height: 6),
            Text(
              datasets.isEmpty
                  ? 'Complete habits or log meds to see activity here.'
                  : 'Tap any day to view activity details.',
              style: const TextStyle(color: AppColors.textSubtle, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _parseDate(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return DateTime.now();
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}

class _HoverableCard extends StatefulWidget {
  const _HoverableCard({required this.child});
  final Widget child;

  @override
  State<_HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<_HoverableCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: _hovered
              ? const [
                  BoxShadow(
                    color: AppColors.accentGlow,
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

class _ActiveFilterPill extends StatelessWidget {
  const _ActiveFilterPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: AppDecorations.glassChip(selected: true),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.accentSoft,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  const _TrendChartCard({required this.dates, required this.scores});

  final List<String> dates;
  final Map<String, int> scores;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < dates.length; i++) {
      spots.add(FlSpot(i.toDouble(), (scores[dates[i]] ?? 0).toDouble()));
    }
    final maxY = spots.isEmpty
        ? 1.0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 1;

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      decoration: AppDecorations.glassCard(elevated: true),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) =>
                const FlLine(color: AppColors.surfaceAlt, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: AppColors.textSubtle,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: dates.length > 14 ? 7 : 2,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= dates.length) {
                    return const SizedBox.shrink();
                  }
                  final parts = dates[i].split('-');
                  final label = parts.length == 3
                      ? '${parts[1]}/${parts[2]}'
                      : dates[i];
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF22C55E),
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicationHistoryCard extends StatelessWidget {
  const _MedicationHistoryCard({
    required this.name,
    required this.times,
    required this.statuses,
    required this.adherenceRate,
    required this.adherenceWindowDays,
  });

  final String name;
  final List<String> times;
  final Map<String, String> statuses;
  final double adherenceRate;
  final int adherenceWindowDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: times
                .map((t) => _DoseStatusChip(time: t, status: statuses[t]))
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            '${adherenceWindowDays}d adherence: ${(adherenceRate * 100).round()}%',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DoseStatusChip extends StatelessWidget {
  const _DoseStatusChip({required this.time, required this.status});

  final String time;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final normalized = status ?? 'pending';
    final color = switch (normalized) {
      'taken' => const Color(0xFF22C55E),
      'skipped' => const Color(0xFFEF4444),
      'snoozed' => const Color(0xFFF59E0B),
      _ => const Color(0xFF64748B),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '${_formatTime(time)} · $normalized',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final hour = int.tryParse(parts[0]);
    if (hour == null) return hhmm;
    final minute = parts[1];
    final period = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    return '$displayHour:$minute $period';
  }
}
