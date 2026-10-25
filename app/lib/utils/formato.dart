String _dos(int n) => n.toString().padLeft(2, '0');

/// dd/mm/aaaa hh:mm en hora local.
String fechaHora(DateTime fecha) {
  final f = fecha.toLocal();
  return '${_dos(f.day)}/${_dos(f.month)}/${f.year} ${_dos(f.hour)}:${_dos(f.minute)}';
}

/// "1 aporte" / "3 aportes".
String plural(int n, String singular, String plural) =>
    '$n ${n == 1 ? singular : plural}';

const _sinTilde = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};

/// Clave de orden alfabético español: sin distinguir mayúsculas ni tildes, con la ñ después
/// de la n.
String _claveEs(String texto) => texto
    .toLowerCase()
    .split('')
    .map((c) => c == 'ñ' ? 'n~' : (_sinTilde[c] ?? c))
    .join();

/// Compara dos textos en orden alfabético español (sin tildes ni mayúsculas; ñ tras n).
int compararEs(String a, String b) {
  final r = _claveEs(a).compareTo(_claveEs(b));
  return r != 0 ? r : a.compareTo(b);
}
