import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'course_stats_data.dart';
import 'teacher_mock_data.dart';

enum TeacherNotificationCategory { alert, classes, system }

enum TeacherNotificationKind {
  critical,
  classToday,
  classTomorrow,
  reviewPending,
  justifyPending,
  sessionClosed,
  offlineSynced,
  lateSync,
  weeklySummary,
}

enum TeacherNotificationGroup { pinned, today, earlier }

enum TeacherChipTone { green, blue }

class TeacherChip {
  const TeacherChip(this.label, this.tone);

  final String label;
  final TeacherChipTone tone;
}

class CriticalStudent {
  const CriticalStudent({
    required this.id,
    required this.name,
    required this.absences,
    required this.held,
    required this.exceeded,
  });

  final String id;
  final String name;
  final int absences;
  final int held;

  /// true = superó el máximo; false = está justo en el límite.
  final bool exceeded;
}

class CriticalInfo {
  const CriticalInfo({
    required this.courseName,
    required this.count,
    required this.total,
    required this.maxAbsences,
    required this.students,
  });

  final String courseName;
  final int count;
  final int total;
  final int maxAbsences;
  final List<CriticalStudent> students;
}

class TeacherNotification {
  const TeacherNotification({
    required this.id,
    required this.kind,
    required this.category,
    required this.group,
    required this.title,
    required this.body,
    required this.timeLabel,
    this.courseId,
    this.studentId,
    this.unread = false,
    this.chips = const [],
    this.critical,
  });

  final String id;
  final TeacherNotificationKind kind;
  final TeacherNotificationCategory category;
  final TeacherNotificationGroup group;
  final String title;

  /// El texto entre ** ** se muestra en negrita.
  final String body;
  final String timeLabel;
  final String? courseId;
  final String? studentId;
  final bool unread;
  final List<TeacherChip> chips;
  final CriticalInfo? critical;

  TeacherNotification copyWith({bool? unread}) => TeacherNotification(
    id: id,
    kind: kind,
    category: category,
    group: group,
    title: title,
    body: body,
    timeLabel: timeLabel,
    courseId: courseId,
    studentId: studentId,
    unread: unread ?? this.unread,
    chips: chips,
    critical: critical,
  );
}

String _two(int n) => n.toString().padLeft(2, '0');

String _nameOf(String courseId, String fallback) =>
    sampleTeacherCourses.where((c) => c.id == courseId).firstOrNull?.name ??
    fallback;

// ---------------------------------------------------------------------------
// DATOS DE EJEMPLO
// Los avisos de clase se calculan con el día real de la semana. La alerta
// crítica usa las estadísticas de ejemplo de Arquitectura de Software. El resto
// son cifras inventadas. Se reemplazarán por avisos reales (registros por
// revisar, justificaciones, sesiones cerradas) cuando existan en Firestore.
// ---------------------------------------------------------------------------
List<TeacherNotification> _buildSample(DateTime now) {
  final out = <TeacherNotification>[];

  // Alerta crítica fija.
  final stats = sampleCourseStats('arq', now);
  if (stats != null && stats.criticalCount > 0) {
    final critical = stats.students.where((s) => s.isCritical).toList()
      ..sort((a, b) => b.absences.compareTo(a.absences));
    out.add(
      TeacherNotification(
        id: 'critical-arq',
        kind: TeacherNotificationKind.critical,
        category: TeacherNotificationCategory.alert,
        group: TeacherNotificationGroup.pinned,
        title: 'Alerta crítica',
        body: '',
        timeLabel: 'Hace 15 min',
        courseId: 'arq',
        studentId: critical.first.id,
        unread: true,
        critical: CriticalInfo(
          courseName: stats.name,
          count: stats.criticalCount,
          total: stats.students.length,
          maxAbsences: stats.maxAbsences,
          students: [
            for (final s in critical.take(3))
              CriticalStudent(
                id: s.id,
                name: s.name,
                absences: s.absences,
                held: s.held,
                exceeded: s.absences > stats.maxAbsences,
              ),
          ],
        ),
      ),
    );
  }

  // Clases de hoy (según el día real de la semana).
  for (final c in sampleTeacherCourses) {
    if (!c.hasClassOn(now.weekday)) continue;
    out.add(
      TeacherNotification(
        id: 'today-${c.id}',
        kind: TeacherNotificationKind.classToday,
        category: TeacherNotificationCategory.classes,
        group: TeacherNotificationGroup.today,
        title: '¡Hoy tienes clase!',
        body:
            '**${c.name}** empieza a las **${c.startTime12}** en ${c.room}. Inicia la sesión de asistencia cuando comience la clase.',
        timeLabel: 'Hoy',
        courseId: c.id,
        unread: true,
      ),
    );
  }

  // Registros por revisar.
  out.add(
    TeacherNotification(
      id: 'review-arq',
      kind: TeacherNotificationKind.reviewPending,
      category: TeacherNotificationCategory.alert,
      group: TeacherNotificationGroup.today,
      title: 'Registros esperando tu revisión',
      body:
          '**5 registros** de **${_nameOf('arq', 'Arquitectura de Software')}** necesitan tu decisión: se hicieron sin conexión o desde un mismo dispositivo.',
      timeLabel: 'Hace 40 min',
      courseId: 'arq',
      unread: true,
    ),
  );

  // Recordatorios de mañana (según el día real de la semana).
  final tomorrow = now.add(const Duration(days: 1));
  for (final c in sampleTeacherCourses) {
    if (!c.hasClassOn(tomorrow.weekday)) continue;
    out.add(
      TeacherNotification(
        id: 'tomorrow-${c.id}',
        kind: TeacherNotificationKind.classTomorrow,
        category: TeacherNotificationCategory.classes,
        group: TeacherNotificationGroup.today,
        title: 'Recordatorio de clase próxima',
        body:
            'Mañana tienes **${c.name}** a las ${_two(c.startHour)}:${_two(c.startMinute)} en ${c.room}.',
        timeLabel: 'Para mañana',
        courseId: c.id,
      ),
    );
  }

  // Justificaciones pendientes (el número sale del curso de ejemplo).
  final sod = sampleTeacherCourses.where((c) => c.id == 'sod').firstOrNull;
  final pending = sod?.pendingJustifications ?? 0;
  if (sod != null && pending > 0) {
    out.add(
      TeacherNotification(
        id: 'justify-sod',
        kind: TeacherNotificationKind.justifyPending,
        category: TeacherNotificationCategory.alert,
        group: TeacherNotificationGroup.earlier,
        title: 'Justificaciones pendientes',
        body:
            'Tienes **$pending ${pending == 1 ? 'justificación médica' : 'justificaciones médicas'}** por revisar en **${sod.name}**. Los estudiantes esperan tu respuesta.',
        timeLabel: 'Ayer, 11:20 AM',
        courseId: 'sod',
        unread: true,
      ),
    );
  }

  out.addAll([
    TeacherNotification(
      id: 'late-eda',
      kind: TeacherNotificationKind.lateSync,
      category: TeacherNotificationCategory.alert,
      group: TeacherNotificationGroup.earlier,
      title: 'Registros tardíos en revisión',
      body:
          '**2 registros** de **${_nameOf('eda', 'Estructuras de Datos y Algoritmos')}** llegaron después de 24 horas y pasaron a revisión manual.',
      timeLabel: 'Ayer, 9:15 AM',
      courseId: 'eda',
      unread: true,
    ),
    TeacherNotification(
      id: 'closed-eda',
      kind: TeacherNotificationKind.sessionClosed,
      category: TeacherNotificationCategory.classes,
      group: TeacherNotificationGroup.earlier,
      title: 'Sesión finalizada',
      body:
          '**${_nameOf('eda', 'Estructuras de Datos y Algoritmos')}**: **31 de 34** estudiantes registraron asistencia.',
      timeLabel: 'Ayer, 10:05 AM',
      courseId: 'eda',
      chips: const [
        TeacherChip('91% asistencia', TeacherChipTone.green),
        TeacherChip('3 sin registro', TeacherChipTone.blue),
      ],
    ),
    TeacherNotification(
      id: 'offline-arq',
      kind: TeacherNotificationKind.offlineSynced,
      category: TeacherNotificationCategory.system,
      group: TeacherNotificationGroup.earlier,
      title: 'Registros sin conexión validados',
      body:
          'Se validaron automáticamente **12 registros** hechos sin conexión en **${_nameOf('arq', 'Arquitectura de Software')}**.',
      timeLabel: 'Hace 2 días',
      courseId: 'arq',
    ),
    TeacherNotification(
      id: 'weekly',
      kind: TeacherNotificationKind.weeklySummary,
      category: TeacherNotificationCategory.system,
      group: TeacherNotificationGroup.earlier,
      title: 'Resumen semanal',
      body:
          'Tu asistencia promedio fue de **${sampleTeacher.globalAttendance}%** en tus cursos (+1.2 puntos frente a la semana anterior).',
      timeLabel: 'Hace 3 días',
    ),
  ]);

  return out;
}

class TeacherNotificationsNotifier extends Notifier<List<TeacherNotification>> {
  @override
  List<TeacherNotification> build() => _buildSample(DateTime.now());

  void markRead(String id) {
    state = [
      for (final n in state)
        (n.id == id && n.unread) ? n.copyWith(unread: false) : n,
    ];
  }

  void markAllRead() {
    state = [for (final n in state) n.unread ? n.copyWith(unread: false) : n];
  }
}

final teacherNotificationsProvider =
    NotifierProvider<TeacherNotificationsNotifier, List<TeacherNotification>>(
      TeacherNotificationsNotifier.new,
    );

int teacherUnreadCount(List<TeacherNotification> list) =>
    list.where((n) => n.unread).length;
