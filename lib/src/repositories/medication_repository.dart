import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_db.dart';
import '../utils/date_utils.dart';

class MedicationWithTimes {
  final Medication medication;
  final List<String> times;

  MedicationWithTimes({required this.medication, required this.times});
}

class MedicationRepository {
  MedicationRepository(this.db);

  final AppDb db;
  final _uuid = const Uuid();

  Future<List<MedicationWithTimes>> getAllMedications(String userId) async {
    final medications = await db.getAllMedications(userId);
    return medications
        .map(
          (m) => MedicationWithTimes(
            medication: m,
            times: (jsonDecode(m.timesJson) as List<dynamic>).cast<String>(),
          ),
        )
        .toList();
  }

  Future<Medication> addMedication({
    required String userId,
    required String name,
    String? dosage,
    String? notes,
    required List<String> times,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextSortOrder = await db.getNextMedicationSortOrder();
    final med = MedicationsCompanion.insert(
      id: _uuid.v4(),
      userId: userId,
      name: name,
      dosage: Value(dosage),
      notes: Value(notes),
      timesJson: jsonEncode(times),
      createdAt: now,
      updatedAt: now,
      sortOrder: Value(nextSortOrder),
    );
    await db.insertMedication(med);
    final all = await db.getAllMedications(userId);
    return all.firstWhere((m) => m.id == med.id.value);
  }

  Future<void> updateMedication({
    required Medication medication,
    required String name,
    String? dosage,
    String? notes,
    required List<String> times,
  }) async {
    final updated = medication.copyWith(
      name: name,
      dosage: Value(dosage),
      notes: Value(notes),
      timesJson: jsonEncode(times),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await db.updateMedicationEntry(updated);
  }

  Future<void> deleteMedication(String medicationId) async {
    await db.archiveMedication(medicationId);
  }

  Future<void> reorderMedications(List<String> orderedIds) async {
    await db.reorderMedications(orderedIds);
  }

  Future<void> markDose({
    required String medicationId,
    required String time,
    required String status,
    String? date,
  }) async {
    final doseDate = date ?? todayIso();
    final existing = await db.getMedicationLogFor(medicationId, doseDate, time);
    final now = DateTime.now().millisecondsSinceEpoch;
    final log = MedicationLogsCompanion(
      id: Value(existing?.id ?? _uuid.v4()),
      medicationId: Value(medicationId),
      date: Value(doseDate),
      time: Value(time),
      status: Value(status),
      updatedAt: Value(now),
    );
    await db.upsertMedicationLog(log);
  }

  Future<Map<String, Map<String, String>>> getDoseStatusForDate(
    String date,
  ) async {
    final logs = await db.getMedicationLogsForDate(date);
    final out = <String, Map<String, String>>{};
    for (final log in logs) {
      out.putIfAbsent(log.medicationId, () => <String, String>{})[log.time] =
          log.status;
    }
    return out;
  }

  Future<Map<String, double>> getAdherenceForRecentDays(
    String userId, {
    int days = 7,
  }) async {
    final medications = await getAllMedications(userId);
    final today = DateTime.now();
    final start = today.subtract(Duration(days: days - 1));
    final logs = await db.getMedicationLogsForRange(
      toIsoDate(start),
      toIsoDate(today),
    );
    final byMedication = <String, List<MedicationLog>>{};
    for (final log in logs) {
      byMedication
          .putIfAbsent(log.medicationId, () => <MedicationLog>[])
          .add(log);
    }

    final result = <String, double>{};
    for (final med in medications) {
      final medLogs =
          byMedication[med.medication.id] ?? const <MedicationLog>[];
      final taken = medLogs.where((l) => l.status == 'taken').length;
      final skipped = medLogs.where((l) => l.status == 'skipped').length;
      final denominator = taken + skipped;
      result[med.medication.id] = denominator == 0 ? 0 : taken / denominator;
    }
    return result;
  }
}
