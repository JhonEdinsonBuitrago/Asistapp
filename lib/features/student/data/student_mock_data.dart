enum CourseStatus { safe, warning, risk }

enum SessionType { theory, practice, exam }

class StudentCourse {
  const StudentCourse({
    required this.id,
    required this.name,
    required this.percentage,
    required this.status,
  });

  final String id;
  final String name;
  final int percentage;
  final CourseStatus status;
}

class StudentSummary {
  const StudentSummary({
    required this.program,
    required this.attendance,
    required this.weeksOptimal,
    required this.totalWeeks,
    required this.topPercent,
    required this.justifyHours,
    required this.courses,
  });

  final String program;
  final double attendance;
  final int weeksOptimal;
  final int totalWeeks;
  final int topPercent;
  final int justifyHours;
  final List<StudentCourse> courses;

  int get riskCount =>
      courses.where((c) => c.status != CourseStatus.safe).length;
}

class UpcomingSession {
  const UpcomingSession({
    required this.month,
    required this.day,
    required this.title,
    required this.time,
    required this.place,
    required this.type,
  });

  final String month;
  final String day;
  final String title;
  final String time;
  final String place;
  final SessionType type;
}

class ActiveSession {
  const ActiveSession({
    required this.number,
    required this.secondsLeft,
    required this.detectedRoom,
  });

  final int number;
  final int secondsLeft;
  final String detectedRoom;
}

class CourseDetail {
  const CourseDetail({
    required this.id,
    required this.code,
    required this.group,
    required this.level,
    required this.name,
    required this.status,
    required this.teacherName,
    required this.teacherRole,
    required this.schedule,
    required this.room,
    required this.period,
    required this.cutoff,
    required this.scheduled,
    required this.attended,
    required this.absences,
    required this.unjustified,
    required this.week,
    required this.totalWeeks,
    required this.nextSession,
    required this.upcoming,
    this.active,
    this.limitPercent = 20,
    this.justifyHours = 48,
  });

  final String id;
  final String code;
  final String group;
  final String level;
  final String name;
  final CourseStatus status;
  final String teacherName;
  final String teacherRole;
  final String schedule;
  final String room;
  final String period;
  final String cutoff;
  final int scheduled;
  final int attended;
  final int absences;
  final int unjustified;
  final int week;
  final int totalWeeks;
  final String nextSession;
  final List<UpcomingSession> upcoming;
  final ActiveSession? active;
  final int limitPercent;
  final int justifyHours;

  int get maxAbsences => scheduled * limitPercent ~/ 100;
  int get remainingAbsences => maxAbsences - absences;
  int get percentage =>
      scheduled == 0 ? 0 : (attended * 100 / scheduled).round();
  int get nextClassNumber => attended + absences + 1;
}

// ---------------------------------------------------------------------------
// DATOS DE EJEMPLO tomados del mockup.
// Se reemplazarán por datos reales de Firestore cuando existan los módulos
// de cursos y asistencias.
// ---------------------------------------------------------------------------
const sampleSummary = StudentSummary(
  program: 'Ingeniería de Software · Semestre 2025-1',
  attendance: 92.4,
  weeksOptimal: 13,
  totalWeeks: 14,
  topPercent: 5,
  justifyHours: 72,
  courses: [
    StudentCourse(
      id: 'eda',
      name: 'Estructuras de Datos y Algoritmos',
      percentage: 96,
      status: CourseStatus.safe,
    ),
    StudentCourse(
      id: 'arq',
      name: 'Arquitectura de Software',
      percentage: 84,
      status: CourseStatus.warning,
    ),
    StudentCourse(
      id: 'calc',
      name: 'Cálculo Multivariable',
      percentage: 76,
      status: CourseStatus.risk,
    ),
    StudentCourse(
      id: 'bda',
      name: 'Bases de Datos Avanzadas',
      percentage: 92,
      status: CourseStatus.safe,
    ),
    StudentCourse(
      id: 'ireq',
      name: 'Ingeniería de Requisitos',
      percentage: 94,
      status: CourseStatus.safe,
    ),
  ],
);

List<UpcomingSession> _defaultSessions(String time, String room) => [
  UpcomingSession(
    month: 'FEB',
    day: '27',
    title: 'Clase teórica',
    time: time,
    place: room,
    type: SessionType.theory,
  ),
  UpcomingSession(
    month: 'MAR',
    day: '04',
    title: 'Taller práctico',
    time: time,
    place: room,
    type: SessionType.practice,
  ),
];

final Map<String, CourseDetail> courseDetails = {
  'arq': const CourseDetail(
    id: 'arq',
    code: 'INF-302',
    group: 'G01',
    level: 'Pregrado de Ingeniería',
    name: 'Arquitectura de Software',
    status: CourseStatus.warning,
    teacherName: 'Ing. Roberto M. Gómez',
    teacherRole: 'Docente Titular • Dpto. Sistemas',
    schedule: 'Mar y Jue 10:00 - 12:00',
    room: 'Aula Magna B (Central)',
    period: '2025-I',
    cutoff: 'Sem. 11',
    scheduled: 25,
    attended: 21,
    absences: 4,
    unjustified: 3,
    week: 11,
    totalWeeks: 16,
    nextSession: 'Jue 27 Feb, 10:00 AM',
    active: ActiveSession(
      number: 22,
      secondsLeft: 14 * 60 + 28,
      detectedRoom: 'Aula Magna B',
    ),
    upcoming: [
      UpcomingSession(
        month: 'FEB',
        day: '27',
        title: 'Patrones de Arquitectura Microservicios',
        time: '10:00 - 12:00',
        place: 'Laboratorio de Redes 3',
        type: SessionType.theory,
      ),
      UpcomingSession(
        month: 'MAR',
        day: '04',
        title: 'Evaluación Práctica de Integración',
        time: '10:00 - 12:00',
        place: 'Aula Magna B',
        type: SessionType.exam,
      ),
    ],
  ),
  'eda': CourseDetail(
    id: 'eda',
    code: 'INF-201',
    group: 'G02',
    level: 'Pregrado de Ingeniería',
    name: 'Estructuras de Datos y Algoritmos',
    status: CourseStatus.safe,
    teacherName: 'Dra. Marcela Ortiz R.',
    teacherRole: 'Docente Titular • Dpto. Sistemas',
    schedule: 'Lun y Mié 08:00 - 10:00',
    room: 'Laboratorio de Cómputo 2',
    period: '2025-I',
    cutoff: 'Sem. 11',
    scheduled: 25,
    attended: 24,
    absences: 1,
    unjustified: 0,
    week: 11,
    totalWeeks: 16,
    nextSession: 'Lun 03 Mar, 08:00 AM',
    upcoming: _defaultSessions('08:00 - 10:00', 'Laboratorio de Cómputo 2'),
  ),
  'calc': CourseDetail(
    id: 'calc',
    code: 'MAT-210',
    group: 'G03',
    level: 'Ciencias Básicas',
    name: 'Cálculo Multivariable',
    status: CourseStatus.risk,
    teacherName: 'Mg. Andrés F. Cruz',
    teacherRole: 'Docente de Cátedra • Dpto. Matemáticas',
    schedule: 'Lun y Vie 14:00 - 16:00',
    room: 'Aula 204 (Bloque C)',
    period: '2025-I',
    cutoff: 'Sem. 11',
    scheduled: 25,
    attended: 19,
    absences: 6,
    unjustified: 5,
    week: 11,
    totalWeeks: 16,
    nextSession: 'Vie 28 Feb, 02:00 PM',
    upcoming: _defaultSessions('14:00 - 16:00', 'Aula 204 (Bloque C)'),
  ),
  'bda': CourseDetail(
    id: 'bda',
    code: 'INF-305',
    group: 'G01',
    level: 'Pregrado de Ingeniería',
    name: 'Bases de Datos Avanzadas',
    status: CourseStatus.safe,
    teacherName: 'Ing. Laura Beltrán P.',
    teacherRole: 'Docente Titular • Dpto. Sistemas',
    schedule: 'Mié y Vie 10:00 - 12:00',
    room: 'Laboratorio de Bases de Datos',
    period: '2025-I',
    cutoff: 'Sem. 11',
    scheduled: 25,
    attended: 23,
    absences: 2,
    unjustified: 1,
    week: 11,
    totalWeeks: 16,
    nextSession: 'Vie 28 Feb, 10:00 AM',
    upcoming: _defaultSessions(
      '10:00 - 12:00',
      'Laboratorio de Bases de Datos',
    ),
  ),
  'ireq': CourseDetail(
    id: 'ireq',
    code: 'INF-250',
    group: 'G02',
    level: 'Pregrado de Ingeniería',
    name: 'Ingeniería de Requisitos',
    status: CourseStatus.safe,
    teacherName: 'Mg. Camilo Restrepo V.',
    teacherRole: 'Docente Titular • Dpto. Sistemas',
    schedule: 'Mar y Jue 08:00 - 10:00',
    room: 'Aula 301 (Bloque B)',
    period: '2025-I',
    cutoff: 'Sem. 11',
    scheduled: 32,
    attended: 30,
    absences: 2,
    unjustified: 1,
    week: 11,
    totalWeeks: 16,
    nextSession: 'Jue 27 Feb, 08:00 AM',
    upcoming: _defaultSessions('08:00 - 10:00', 'Aula 301 (Bloque B)'),
  ),
};

CourseDetail? courseDetailById(String id) => courseDetails[id];
