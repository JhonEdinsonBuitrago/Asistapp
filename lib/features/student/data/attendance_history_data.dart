import 'dart:math' as math;

import 'student_mock_data.dart';

enum AttendanceKind { present, absent, justified }

enum RecordMethod { qr, manual, synced }

class HistoryRecord {
  const HistoryRecord({
    required this.number,
    required this.date,
    required this.title,
    required this.kind,
    this.method,
    this.deadlinePassed = false,
    this.approvedBy,
    this.expediente,
    this.reason,
  });

  final int number;
  final DateTime date;
  final String title;
  final AttendanceKind kind;
  final RecordMethod? method; // solo en sesiones con asistencia
  final bool deadlinePassed; // falta cuyo plazo para justificar ya venció
  final String? approvedBy;
  final String? expediente;
  final String? reason;
}

class CourseHistory {
  const CourseHistory({required this.detail, required this.records});

  final CourseDetail detail;

  /// De la sesión más reciente a la más antigua.
  final List<HistoryRecord> records;

  int get presentCount =>
      records.where((r) => r.kind == AttendanceKind.present).length;
  int get absentCount =>
      records.where((r) => r.kind != AttendanceKind.present).length;
  int get justifiedCount =>
      records.where((r) => r.kind == AttendanceKind.justified).length;
  int get unjustifiedCount =>
      records.where((r) => r.kind == AttendanceKind.absent).length;
}

// ---------------------------------------------------------------------------
// DATOS DE EJEMPLO tomados del mockup.
// Se reemplazarán por las sesiones y registros reales de Firestore.
// ---------------------------------------------------------------------------
const _arqTitles = <int, String>{
  25: 'Patrones de Microservicios',
  24: 'Arquitectura Hexagonal',
  23: 'Clean Architecture & Repositorios',
  22: 'Control de Concurrencia',
  21: 'Introducción a Event-Driven',
  20: 'Domain-Driven Design (DDD)',
  19: 'Patrón CQRS & Event Sourcing',
  18: 'Resiliencia y Tolerancia a Fallos',
  17: 'Escalabilidad y Balanceo de Carga',
  16: 'Arquitectura Cliente-Servidor',
  15: 'Persistencia y Repositorios',
  14: 'Seguridad en Arquitecturas Distribuidas',
  13: 'Mensajería y Colas',
  12: 'Arquitectura Orientada a Servicios',
  11: 'Modelado con UML y C4',
  10: 'Diseño de APIs REST',
  9: 'Patrones de Diseño de Comportamiento',
  8: 'Patrones de Diseño Estructurales',
  7: 'Patrones de Diseño Creacionales',
  6: 'Principios SOLID',
  5: 'Patrón MVC y MVVM',
  4: 'Arquitectura en Capas',
  3: 'Estilos Arquitectónicos',
  2: 'Atributos de Calidad',
  1: 'Introducción a la Arquitectura de Software',
};

const _arqMethods = <int, RecordMethod>{
  25: RecordMethod.qr,
  24: RecordMethod.qr,
  22: RecordMethod.synced,
  20: RecordMethod.manual,
};

const _arqMinutes = <int, int>{25: 4, 24: 1, 22: 12, 20: 2};

/// Fecha de la sesión [number]: martes y jueves, hacia atrás desde el jueves
/// 27 de febrero de 2025.
DateTime _dateFor(int number, int total, int minute) {
  var d = DateTime(2025, 2, 27);
  for (var i = 0; i < total - number; i++) {
    d = d.subtract(Duration(days: i.isEven ? 2 : 5));
  }
  return DateTime(d.year, d.month, d.day, 10, minute);
}

CourseHistory? historyFor(String courseId) {
  final d = courseDetailById(courseId);
  if (d == null) return null;

  final total = d.scheduled;
  final justified = math.max(
    0,
    math.min(d.absences, d.absences - d.unjustified),
  );

  // Sesiones con falta (de la más reciente a la más antigua).
  final List<int> absentNumbers;
  final Set<int> justifiedNumbers;
  final Set<int> expiredNumbers;

  if (d.id == 'arq') {
    absentNumbers = [23, 21, 19, 12];
    justifiedNumbers = {21};
    expiredNumbers = {19, 12};
  } else {
    final step = d.absences == 0 ? 1 : (total - 4) ~/ d.absences;
    absentNumbers = [for (var k = 0; k < d.absences; k++) total - 2 - k * step];
    justifiedNumbers = absentNumbers.skip(d.absences - justified).toSet();
    expiredNumbers = absentNumbers.skip(1).toSet();
  }

  RecordMethod methodFor(int n) {
    final fixed = d.id == 'arq' ? _arqMethods[n] : null;
    if (fixed != null) return fixed;
    if (n % 7 == 0) return RecordMethod.manual;
    if (n % 5 == 0) return RecordMethod.synced;
    return RecordMethod.qr;
  }

  final records = <HistoryRecord>[];
  for (var n = total; n >= 1; n--) {
    final minute =
        (d.id == 'arq' ? _arqMinutes[n] : null) ?? ((n * 7) % 14 + 1);
    final date = _dateFor(n, total, minute);
    final title = d.id == 'arq' ? (_arqTitles[n] ?? 'Tema $n') : 'Tema $n';

    if (absentNumbers.contains(n)) {
      final isJustified = justifiedNumbers.contains(n);
      records.add(
        HistoryRecord(
          number: n,
          date: date,
          title: title,
          kind: isJustified ? AttendanceKind.justified : AttendanceKind.absent,
          deadlinePassed: expiredNumbers.contains(n),
          approvedBy: isJustified ? 'Bienestar Estudiantil' : null,
          expediente: isJustified ? '#JST-${8900 + n}' : null,
          reason: isJustified
              ? 'Motivo médico acreditado mediante certificado oficial.'
              : null,
        ),
      );
    } else {
      records.add(
        HistoryRecord(
          number: n,
          date: date,
          title: title,
          kind: AttendanceKind.present,
          method: methodFor(n),
        ),
      );
    }
  }

  return CourseHistory(detail: d, records: records);
}
