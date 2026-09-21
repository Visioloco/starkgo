// ════════════════════════════════════════════════════════════════════
//  HOTSPOT VOUCHERS — reglas de duración y caducidad de las fichas
//
//  Las fichas (pines/vouchers) se crean con un `limit-uptime` copiado de la
//  duración del perfil (1h, 1d, 1w, 30d…). Ese límite es el TIEMPO TOTAL
//  acumulado que puede navegar la ficha.
//
//  Regla de la limpieza automática:
//     ✅ se borran del MikroTik sólo las fichas USADAS **y** CADUCADAS
//        (ya se conectaron y el tiempo total ya se consumió por completo);
//     ⛔ NO se borran las que todavía no se han usado (para venderlas);
//     ⛔ NO se borran las que se usaron pero todavía tienen tiempo a favor.
// ════════════════════════════════════════════════════════════════════

/// Estado de una ficha según su uso y su tiempo restante.
enum EstadoFicha {
  /// Nunca se ha conectado: lista para vender.
  nueva,

  /// Ya se usó y todavía le queda tiempo (hay que dejarla).
  enUso,

  /// Ya se usó y agotó su tiempo total: se puede borrar del router.
  caducada,

  /// Se usó pero la ficha NO tiene `limit-uptime`: nunca caduca sola.
  sinLimite;

  /// Texto corto para mostrar en la tarjeta de la ficha.
  String get etiqueta {
    switch (this) {
      case EstadoFicha.nueva:
        return 'Nueva';
      case EstadoFicha.enUso:
        return 'En uso';
      case EstadoFicha.caducada:
        return 'Caducada';
      case EstadoFicha.sinLimite:
        return 'Sin límite';
    }
  }
}

/// Convierte una duración de RouterOS a [Duration].
///
/// Formatos aceptados:
///  * `1w2d3h4m5s` (formato de RouterOS: w=semana, d=día, h=hora, m=min, s=seg)
///  * `01:00:00` y `2d01:00:00` (HH:MM:SS, con días opcionales)
///  * `3600` (segundos "pelados", como los escribe el usuario en el perfil)
///
/// Devuelve `null` si el texto está vacío o no se puede interpretar.
Duration? parseDuracionRouteros(String? texto) {
  final t = (texto ?? '').trim().toLowerCase();
  if (t.isEmpty) return null;

  // ── Formato con ':' → HH:MM:SS (con días opcionales delante) ──
  if (t.contains(':')) {
    var dias = 0;
    var resto = t;
    final mDias = RegExp(r'^(\d+)d').firstMatch(resto);
    if (mDias != null) {
      dias = int.parse(mDias.group(1)!);
      resto = resto.substring(mDias.end);
    }
    final partes = resto.split(':');
    if (partes.length < 2 || partes.length > 3) return null;
    final horas = int.tryParse(partes[0]) ?? 0;
    final minutos = int.tryParse(partes[1]) ?? 0;
    final segundos = partes.length == 3 ? (int.tryParse(partes[2]) ?? 0) : 0;
    return Duration(days: dias, hours: horas, minutes: minutos, seconds: segundos);
  }

  // ── Formato RouterOS: 1w 2d 3h 4m 5s (puede venir en cualquier orden) ──
  const unidades = <String, int>{'w': 604800, 'd': 86400, 'h': 3600, 'm': 60, 's': 1};
  var totalSegundos = 0;
  var encontro = false;
  for (final u in unidades.entries) {
    final m = RegExp('(\\d+)${u.key}').firstMatch(t);
    if (m != null) {
      totalSegundos += int.parse(m.group(1)!) * u.value;
      encontro = true;
    }
  }
  if (encontro) return Duration(seconds: totalSegundos);

  // ── Segundos "pelados" (lo que se escribe en el campo del perfil) ──
  final segundos = int.tryParse(t);
  if (segundos != null && segundos >= 0) return Duration(seconds: segundos);

  return null;
}

/// Texto legible para una duración (ej. `1 h`, `1 día`, `30 días`).
String duracionLegible(Duration? d) {
  if (d == null) return '—';
  if (d.inSeconds <= 0) return '0 s';
  final dias = d.inDays;
  final horas = d.inHours % 24;
  final minutos = d.inMinutes % 60;
  final segundos = d.inSeconds % 60;
  final partes = <String>[];
  if (dias > 0) partes.add(dias == 1 ? '1 día' : '$dias días');
  if (horas > 0) partes.add(horas == 1 ? '1 h' : '$horas h');
  if (minutos > 0) partes.add('$minutos min');
  if (segundos > 0 && partes.length < 2) partes.add('$segundos s');
  return partes.join(' ');
}

// ── Accesos tolerantes a los nombres de campo del API de RouterOS ──

String _campo(Map<String, dynamic> ficha, List<String> claves) {
  for (final k in claves) {
    final v = ficha[k];
    if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
  }
  return '';
}

/// Tiempo ya consumido por la ficha (`uptime`).
Duration? duracionUptime(Map<String, dynamic> ficha) =>
    parseDuracionRouteros(_campo(ficha, const ['uptime', 'uptime-used']));

/// Tiempo TOTAL permitido de la ficha (`limit-uptime`). `null` = sin límite.
Duration? duracionLimite(Map<String, dynamic> ficha) =>
    parseDuracionRouteros(_campo(ficha, const ['limit-uptime', 'limitUptime']));

/// ¿La ficha ya se conectó alguna vez? (tiempo consumido o datos transferidos)
bool fichaUsada(Map<String, dynamic> ficha) {
  final uptime = duracionUptime(ficha);
  final bytesIn = int.tryParse(_campo(ficha, const ['bytes-in', 'bytesIn'])) ?? 0;
  final bytesOut = int.tryParse(_campo(ficha, const ['bytes-out', 'bytesOut'])) ?? 0;
  return (uptime != null && uptime.inSeconds > 0) || bytesIn > 0 || bytesOut > 0;
}

/// Tiempo que le queda a la ficha (`null` si no tiene límite).
/// Nunca es negativo: si se pasó del límite devuelve [Duration.zero].
Duration? tiempoRestante(Map<String, dynamic> ficha) {
  final limite = duracionLimite(ficha);
  if (limite == null) return null;
  final consumido = duracionUptime(ficha) ?? Duration.zero;
  final resta = limite - consumido;
  return resta.isNegative ? Duration.zero : resta;
}

/// Estado de la ficha (nueva / en uso / caducada / sin límite).
EstadoFicha estadoDeFicha(Map<String, dynamic> ficha) {
  if (!fichaUsada(ficha)) return EstadoFicha.nueva;
  final limite = duracionLimite(ficha);
  if (limite == null) return EstadoFicha.sinLimite;
  final consumido = duracionUptime(ficha) ?? Duration.zero;
  return consumido >= limite ? EstadoFicha.caducada : EstadoFicha.enUso;
}

/// ¿Esta ficha se debe borrar en la limpieza automática?
/// Sí sólo si YA SE USÓ y YA CADUCÓ (agotó su tiempo total).
bool fichaListaParaBorrar(Map<String, dynamic> ficha) =>
    estadoDeFicha(ficha) == EstadoFicha.caducada;

/// Duración total del voucher: su `limit-uptime` y, si no lo tiene, el
/// `session-timeout` de su perfil (sirve para fichas viejas).
Duration? duracionVoucher(
  Map<String, dynamic> ficha,
  List<Map<String, dynamic>> perfiles,
) {
  final propio = duracionLimite(ficha);
  if (propio != null) return propio;
  final perfil = _campo(ficha, const ['profile']);
  if (perfil.isEmpty) return null;
  for (final p in perfiles) {
    if (_campo(p, const ['name']) == perfil) {
      return parseDuracionRouteros(_campo(p, const ['session-timeout']));
    }
  }
  return null;
}

