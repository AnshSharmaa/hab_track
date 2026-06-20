import '../repositories/medication_repository.dart';
import 'app_notification_service.dart';

class MedicationNotificationService {
  MedicationNotificationService._();

  static final instance = MedicationNotificationService._();

  Future<void> initialize() async {
    await AppNotificationService.instance.initialize();
  }

  Future<void> scheduleDailyMedication(MedicationWithTimes med) async {
    await AppNotificationService.instance.scheduleMedicationDaily(med);
  }

  Future<void> cancelMedicationSchedules(
    String medicationId,
    List<String> times,
  ) async {
    await AppNotificationService.instance.cancelMedicationSchedules(
      medicationId,
      times,
    );
  }
}
