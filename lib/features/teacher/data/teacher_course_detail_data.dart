import 'course_repository.dart';
import 'teacher_mock_data.dart';
import 'enrollment_repository.dart';

enum RosterStatus {
  perfect,
  excellent,
  ok,
  regular,
  attention,
  risk,
  lost,
  none,
}

enum RosterGroup { ok, regular, risk, none }

class RosterStudent {
  const RosterStudent({
    required this.id,
    required this.name,
    required this.code,
    required this.absences,
    required this.attendance,
    this.starred = false,
    this.noData = false,
  });

  final String id;
  final String name;
  final String code;
  final int absences;
  final bool noData;

  /// Porcentaje de asistencia.
  final int attendance;
  final bool starred;

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  RosterStatus status(int maxAbsences) {
    if (noData) return RosterStatus.none;
    if (absences > maxAbsences) return RosterStatus.lost;
    if (attendance < 80) return RosterStatus.risk;
    if (attendance < 85) return RosterStatus.attention;
    if (attendance < 90) return RosterStatus.regular;
    if (attendance >= 100) return RosterStatus.perfect;
    if (attendance >= 95) return RosterStatus.excellent;
    return RosterStatus.ok;
  }

  RosterGroup group(int maxAbsences) {
    if (noData) return RosterGroup.none;
    if (absences > maxAbsences || attendance < 80) return RosterGroup.risk;
    if (attendance < 90) return RosterGroup.regular;
    return RosterGroup.ok;
  }

  String faultsText(int maxAbsences) {
    if (noData) return 'Sin registros aún';
    final base = '$absences ${absences == 1 ? 'falta' : 'faltas'}';
    if (absences > maxAbsences) return '$base (Límite excedido)';
    if (absences > 0 && absences == maxAbsences) return '$base (Al límite)';
    if (absences > 0 && absences == maxAbsences - 1)
      return '$base (1 del límite)';
    return base;
  }
}

class CourseDetailVm {
  const CourseDetailVm({
    required this.id,
    required this.name,
    required this.code,
    required this.cycle,
    required this.heldSessions,
    required this.totalSessions,
    required this.maxAbsences,
    required this.hasClassToday,
    required this.students,
    required this.isSample,
    this.section,
    this.scheduleLabel,
    this.room,
    this.attendance,
    this.facultyDelta,
    this.tone,
  });

  final String id;
  final String name;
  final String code;
  final String? section;
  final String cycle;
  final String? scheduleLabel;
  final String? room;
  final int heldSessions;
  final int totalSessions;

  /// Promedio de asistencia del curso; null si aún no hay sesiones.
  final double? attendance;

  /// Diferencia con el promedio de la facultad, en puntos porcentuales.
  final double? facultyDelta;
  final CourseTone? tone;
  final int maxAbsences;
  final bool hasClassToday;
  final List<RosterStudent> students;
  final bool isSample;

  double get progress => totalSessions == 0 ? 0 : heldSessions / totalSessions;
  int get progressPercent => (progress * 100).round();

  int countOf(RosterGroup g) =>
      students.where((s) => s.group(maxAbsences) == g).length;
}

// ---------------------------------------------------------------------------
// DATOS DE EJEMPLO
// Los 8 primeros estudiantes de Arquitectura de Software salen del mockup; el
// resto se genera. Se reemplazará por la matrícula real de Firestore.
// ---------------------------------------------------------------------------
const _firstNames = [
  'Andrea',
  'Bruno',
  'Daniela',
  'Fernando',
  'Gabriela',
  'Héctor',
  'Isabel',
  'Javier',
  'Karen',
  'Leonardo',
  'Mariana',
  'Nicolás',
  'Olga',
  'Pablo',
  'Rodrigo',
  'Silvana',
  'Tomás',
  'Úrsula',
  'Víctor',
  'Ximena',
];

const _lastNames = [
  'Quispe',
  'Castillo',
  'Rojas',
  'Huamán',
  'Soto',
  'Vargas',
  'Córdova',
  'Ponce',
  'Medina',
  'Cárdenas',
  'Delgado',
  'Ibáñez',
  'Paredes',
  'Zevallos',
  'Arce',
  'Palomino',
  'Herrera',
  'Aguirre',
  'Benítez',
  'Salazar',
];

const _okPcts = [100, 96, 94, 98, 92, 95, 97, 91, 100, 93];
const _regularPcts = [88, 87, 85, 89, 86, 82];
const _riskPcts = [78, 74, 76, 72, 79];

int _faultsFor(int pct) {
  if (pct >= 100) return 0;
  if (pct >= 95) return 1;
  if (pct >= 90) return 2;
  if (pct >= 85) return 3;
  if (pct >= 80) return 4;
  if (pct >= 75) return 5;
  return 6;
}

/// Genera estudiantes de ejemplo: [regular] entre 80 y 89 %, [risk] por debajo
/// de 80 % y el resto al día, repartidos por la lista.
List<RosterStudent> generateRoster({
  required int count,
  required int regular,
  required int risk,
  required int seed,
}) {
  if (count <= 0) return const [];

  final slots = List<int>.filled(count, 0); // 0 al día, 1 regular, 2 riesgo
  void place(int wanted, int type) {
    var i = wanted % count;
    var guard = 0;
    while (slots[i] != 0 && guard < count) {
      i = (i + 1) % count;
      guard++;
    }
    slots[i] = type;
  }

  for (var k = 1; k <= regular; k++) {
    place(k * count ~/ (regular + 1), 1);
  }
  for (var k = 1; k <= risk; k++) {
    place(k * count ~/ (risk + 1) + 2, 2);
  }

  final out = <RosterStudent>[];
  var ok = 0;
  var reg = 0;
  var rk = 0;
  for (var i = 0; i < count; i++) {
    final int pct;
    switch (slots[i]) {
      case 1:
        pct = _regularPcts[reg++ % _regularPcts.length];
      case 2:
        pct = _riskPcts[rk++ % _riskPcts.length];
      default:
        pct = _okPcts[ok++ % _okPcts.length];
    }

    final first = _firstNames[(i * 7 + seed * 3) % _firstNames.length];
    final l1 = _lastNames[(i * 3 + seed) % _lastNames.length];
    final l2 = _lastNames[(i * 5 + seed * 7 + 3) % _lastNames.length];
    final number = (1000 + (i * 389 + seed * 97) % 9000).toString().padLeft(
      4,
      '0',
    );

    out.add(
      RosterStudent(
        id: 's$seed-$i',
        name: '$first $l1 $l2',
        code: '20${21 + i % 3}-$number',
        absences: _faultsFor(pct),
        attendance: pct,
      ),
    );
  }
  return out;
}

const _arqCore = <RosterStudent>[
  RosterStudent(
    id: 'a1',
    name: 'Carlos Mendoza Vega',
    code: '2021-0842',
    absences: 1,
    attendance: 96,
  ),
  RosterStudent(
    id: 'a2',
    name: 'Sofía Benavides Ruiz',
    code: '2022-1104',
    absences: 0,
    attendance: 100,
  ),
  RosterStudent(
    id: 'a3',
    name: 'Alejandro Morales Rivera',
    code: '2021-10492',
    absences: 2,
    attendance: 92,
    starred: true,
  ),
  RosterStudent(
    id: 'a4',
    name: 'Mateo Flores Quispe',
    code: '2020-7712',
    absences: 6,
    attendance: 74,
  ),
  RosterStudent(
    id: 'a5',
    name: 'Diego Palacios Silva',
    code: '2020-4491',
    absences: 4,
    attendance: 84,
  ),
  RosterStudent(
    id: 'a6',
    name: 'Valeria Ramos Castro',
    code: '2021-3920',
    absences: 1,
    attendance: 94,
  ),
  RosterStudent(
    id: 'a7',
    name: 'Luciana Prado Herrera',
    code: '2021-5034',
    absences: 5,
    attendance: 78,
  ),
  RosterStudent(
    id: 'a8',
    name: 'Camila Torres León',
    code: '2022-0912',
    absences: 3,
    attendance: 86,
  ),
];

const _facultyAverage = 88.8;

const _sampleExtras =
    <String, ({int held, int total, double attendance, int maxAbsences})>{
      'arq': (held: 18, total: 32, attendance: 91.2, maxAbsences: 5),
      'eda': (held: 20, total: 32, attendance: 88.0, maxAbsences: 6),
      'sod': (held: 19, total: 32, attendance: 76.0, maxAbsences: 6),
      'req': (held: 9, total: 16, attendance: 94.0, maxAbsences: 3),
    };

/// Detalle de uno de los cursos de ejemplo del home.
CourseDetailVm? sampleCourseDetail(String id, DateTime now) {
  final course = sampleTeacherCourses.where((c) => c.id == id).firstOrNull;
  final extra = _sampleExtras[id];
  if (course == null || extra == null) return null;

  final List<RosterStudent> students = switch (id) {
    'arq' => [
      ..._arqCore,
      ...generateRoster(count: 30, regular: 3, risk: 0, seed: 1),
    ],
    'eda' => generateRoster(
      count: course.students,
      regular: 4,
      risk: 0,
      seed: 2,
    ),
    'sod' => generateRoster(
      count: course.students,
      regular: 7,
      risk: course.atRisk,
      seed: 3,
    ),
    _ => generateRoster(count: course.students, regular: 1, risk: 0, seed: 4),
  };

  return CourseDetailVm(
    id: course.id,
    name: course.name,
    code: course.code,
    section: course.section,
    cycle: sampleTeacher.cycle,
    scheduleLabel: course.scheduleLabel,
    room: course.room,
    heldSessions: extra.held,
    totalSessions: extra.total,
    attendance: extra.attendance,
    facultyDelta: extra.attendance - _facultyAverage,
    tone: course.tone,
    maxAbsences: extra.maxAbsences,
    hasClassToday: course.hasClassOn(now.weekday),
    students: students,
    isSample: true,
  );
}

/// Detalle de un curso real creado por el docente (aún sin matrícula).
RosterStudent rosterFromEnrolled(EnrolledStudent e) => RosterStudent(
  id: e.id,
  name: e.name,
  code: e.code,
  absences: 0,
  attendance: 0,
  noData: true,
);

/// Detalle de un curso real creado por el docente.
CourseDetailVm courseDetailFromCreated(
  CreatedCourse c, {
  List<EnrolledStudent> enrolled = const [],
}) => CourseDetailVm(
  id: c.id,
  name: c.name,
  code: c.code,
  cycle: c.period,
  heldSessions: 0,
  totalSessions: c.totalSessions,
  maxAbsences: c.maxAbsences,
  hasClassToday: false,
  students: enrolled.map(rosterFromEnrolled).toList(),
  isSample: false,
);
