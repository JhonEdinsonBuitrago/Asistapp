enum CourseTone { excellent, normal, risk, optimal }

const _dayShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

String _two(int n) => n.toString().padLeft(2, '0');

class TeacherCourse {
  const TeacherCourse({
    required this.id,
    required this.code,
    required this.section,
    required this.name,
    required this.weekdays,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.room,
    required this.students,
    required this.attendance,
    required this.tone,
    this.atRisk = 0,
    this.pendingJustifications = 0,
    this.syncedPercent,
  });

  final String id;
  final String code;
  final String section;
  final String name;

  /// Días de clase: 1 = lunes ... 7 = domingo.
  final List<int> weekdays;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String room;
  final int students;

  /// Asistencia del curso, en porcentaje.
  final int attendance;
  final CourseTone tone;

  /// Estudiantes en riesgo de perder el curso por inasistencia.
  final int atRisk;
  final int pendingJustifications;
  final int? syncedPercent;

  String get scheduleLabel {
    final days = weekdays.length == 1
        ? _dayShort[weekdays.first - 1]
        : '${_dayShort[weekdays.first - 1]} - ${_dayShort[weekdays.last - 1]}';
    return '$days (${_two(startHour)}:${_two(startMinute)} - ${_two(endHour)}:${_two(endMinute)})';
  }

  bool hasClassOn(int weekday) => weekdays.contains(weekday);

  /// Hora de inicio en formato de 12 horas, por ejemplo 10:00 AM.
  String get startTime12 {
    final h = startHour % 12 == 0 ? 12 : startHour % 12;
    return '${_two(h)}:${_two(startMinute)} ${startHour < 12 ? 'AM' : 'PM'}';
  }

  /// Próxima clase a partir de mañana, por ejemplo "Mañana 08:00" o "Mié 14:00".
  String nextClassLabel(DateTime now) {
    final time = '${_two(startHour)}:${_two(startMinute)}';
    for (var i = 1; i <= 7; i++) {
      final d = now.add(Duration(days: i));
      if (weekdays.contains(d.weekday)) {
        return i == 1 ? 'Mañana $time' : '${_dayShort[d.weekday - 1]} $time';
      }
    }
    return '';
  }
}

class TeacherSummary {
  const TeacherSummary({
    required this.department,
    required this.faculty,
    required this.cycle,
    required this.globalAttendance,
  });

  final String department;
  final String faculty;
  final String cycle;
  final double globalAttendance;
}

// ---------------------------------------------------------------------------
// DATOS DE EJEMPLO tomados del mockup.
// Se reemplazarán por los cursos reales del docente cuando exista el módulo de
// cursos en Firestore.
// ---------------------------------------------------------------------------
const sampleTeacher = TeacherSummary(
  department: 'Dpto. Ing. de Software',
  faculty: 'Facultad de Ingeniería',
  cycle: '2025-I',
  globalAttendance: 89.4,
);

const sampleTeacherCourses = <TeacherCourse>[
  TeacherCourse(
    id: 'arq',
    code: 'INF-302',
    section: '04',
    name: 'Arquitectura de Software',
    weekdays: [2, 4],
    startHour: 10,
    startMinute: 0,
    endHour: 12,
    endMinute: 0,
    room: 'Aula Magna B',
    students: 38,
    attendance: 91,
    tone: CourseTone.excellent,
  ),
  TeacherCourse(
    id: 'eda',
    code: 'CC-201',
    section: '02',
    name: 'Estructuras de Datos y Algoritmos',
    weekdays: [1, 3],
    startHour: 8,
    startMinute: 0,
    endHour: 10,
    endMinute: 0,
    room: 'Laboratorio de Cómputo 2',
    students: 34,
    attendance: 88,
    tone: CourseTone.normal,
  ),
  TeacherCourse(
    id: 'sod',
    code: 'INF-405',
    section: '01',
    name: 'Sistemas Operativos Distribuidos',
    weekdays: [3, 5],
    startHour: 14,
    startMinute: 0,
    endHour: 16,
    endMinute: 0,
    room: 'Aula TIC-210',
    students: 42,
    attendance: 76,
    tone: CourseTone.risk,
    atRisk: 5,
    pendingJustifications: 3,
  ),
  TeacherCourse(
    id: 'req',
    code: 'GES-104',
    section: '03',
    name: 'Ingeniería de Requerimientos',
    weekdays: [6],
    startHour: 9,
    startMinute: 0,
    endHour: 13,
    endMinute: 0,
    room: 'Pabellón C - 102',
    students: 28,
    attendance: 94,
    tone: CourseTone.optimal,
    syncedPercent: 100,
  ),
];
