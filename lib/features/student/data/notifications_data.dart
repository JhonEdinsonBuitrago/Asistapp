import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NotificationCategory { alert, academic, system }

enum NotificationKind {
  critical,
  sessionOpen,
  attendanceOk,
  classReminder,
  justifyDeadline,
  offlineSynced,
}

enum NotificationGroup { pinned, today, earlier }

enum ChipTone { green, blue }

class NotificationChip {
  const NotificationChip(this.label, this.tone);

  final String label;
  final ChipTone tone;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.category,
    required this.group,
    required this.title,
    required this.body,
    required this.timeLabel,
    this.courseId,
    this.unread = false,
    this.chips = const [],
  });

  final String id;
  final NotificationKind kind;
  final NotificationCategory category;
  final NotificationGroup group;
  final String title;

  /// El texto entre ** ** se muestra en negrita.
  final String body;
  final String timeLabel;
  final String? courseId;
  final bool unread;
  final List<NotificationChip> chips;

  AppNotification copyWith({bool? unread}) => AppNotification(
    id: id,
    kind: kind,
    category: category,
    group: group,
    title: title,
    body: body,
    timeLabel: timeLabel,
    courseId: courseId,
    unread: unread ?? this.unread,
    chips: chips,
  );
}

// ---------------------------------------------------------------------------
// DATOS DE EJEMPLO tomados del mockup.
// Se reemplazarán por avisos reales (resultado de registros, clases iniciadas,
// plazos de justificación) cuando existan cursos y asistencias en Firestore.
// ---------------------------------------------------------------------------
const sampleNotifications = <AppNotification>[
  AppNotification(
    id: 'n1',
    kind: NotificationKind.critical,
    category: NotificationCategory.alert,
    group: NotificationGroup.pinned,
    title: 'Alerta crítica',
    body: '',
    timeLabel: 'Hace 15 min',
    courseId: 'arq',
    unread: true,
  ),
  AppNotification(
    id: 'n2',
    kind: NotificationKind.sessionOpen,
    category: NotificationCategory.academic,
    group: NotificationGroup.today,
    title: '¡Sesión de asistencia abierta!',
    body: 'El Prof. Gómez ha iniciado el registro para **Arquitectura de Software** en Aula Magna B. Tienes 12 minutos para registrarte.',
    timeLabel: 'Hace 25 min',
    courseId: 'arq',
    unread: true,
  ),
  AppNotification(
    id: 'n3',
    kind: NotificationKind.attendanceOk,
    category: NotificationCategory.academic,
    group: NotificationGroup.today,
    title: 'Asistencia registrada con éxito',
    body: 'Se verificó tu presencia en **Estructuras de Datos y Algoritmos** (Lab 3). Tu porcentaje subió a 96%.',
    timeLabel: '10:04 AM',
    courseId: 'eda',
    chips: [
      NotificationChip('Presencial', ChipTone.green),
      NotificationChip('Récord: 96%', ChipTone.blue),
    ],
  ),
  AppNotification(
    id: 'n4',
    kind: NotificationKind.classReminder,
    category: NotificationCategory.academic,
    group: NotificationGroup.earlier,
    title: 'Recordatorio de clase próxima',
    body: 'Mañana tienes **Cálculo Multivariable** a las 14:00 en Edificio C - 201. Recuerda llegar puntual.',
    timeLabel: 'Ayer, 6:30 PM',
    courseId: 'calc',
  ),
  AppNotification(
    id: 'n5',
    kind: NotificationKind.justifyDeadline,
    category: NotificationCategory.alert,
    group: NotificationGroup.earlier,
    title: 'Plazo de justificación por vencer',
    body: 'Tienes 24h restantes para subir soporte médico de la falta del 20 de Feb en **Clean Architecture & Repositorios**.',
    timeLabel: 'Ayer, 11:20 AM',
    courseId: 'arq',
    unread: true,
  ),
  AppNotification(
    id: 'n6',
    kind: NotificationKind.offlineSynced,
    category: NotificationCategory.system,
    group: NotificationGroup.earlier,
    title: 'Registro offline sincronizado',
    body: 'La asistencia guardada sin conexión en Aula Magna B se validó correctamente.',
    timeLabel: '26 Feb, 15:40',
    courseId: 'arq',
  ),
];

class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => sampleNotifications;

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

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );

int unreadCount(List<AppNotification> list) =>
    list.where((n) => n.unread).length;
