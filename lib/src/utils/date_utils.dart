import 'package:intl/intl.dart';

String toIsoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

String todayIso() => toIsoDate(DateTime.now());

String weekdayKey(DateTime date) {
  switch (date.weekday) {
    case DateTime.monday:
      return 'mon';
    case DateTime.tuesday:
      return 'tue';
    case DateTime.wednesday:
      return 'wed';
    case DateTime.thursday:
      return 'thu';
    case DateTime.friday:
      return 'fri';
    case DateTime.saturday:
      return 'sat';
    case DateTime.sunday:
      return 'sun';
    default:
      return 'mon';
  }
}
