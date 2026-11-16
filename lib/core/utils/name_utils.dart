String capitalize(String w) =>
    w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase();

/// Nombre a mostrar: el de la cuenta o, si no existe, el inicio del correo.
String displayNameOf(String? displayName, String? email) {
  final name = displayName?.trim() ?? '';
  if (name.isNotEmpty) return name;
  final prefix = (email ?? '').split('@').first.trim();
  return prefix.isNotEmpty ? prefix : 'Estudiante';
}

String firstNameOf(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  return capitalize(parts.first);
}

/// Primera letra del primer nombre y de la última palabra.
String initialsOf(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
