import 'package:flutter_test/flutter_test.dart';

import 'package:stark_go/services/hotspot_vouchers.dart';

// Reglas de los pines/vouchers (plan "Solo Vouchers"):
//   · se crean de 1 hora, 1 día, 1 semana o 1 mes (limit-uptime del perfil);
//   · la app los borra SOLO cuando ya se usaron Y su tiempo ya caducó;
//   · las fichas nuevas y las que todavía tienen tiempo a favor NO se borran.
void main() {
  group('parseDuracionRouteros', () {
    test('formatos de RouterOS (h, d, w)', () {
      expect(parseDuracionRouteros('1h'), const Duration(hours: 1));
      expect(parseDuracionRouteros('1d'), const Duration(days: 1));
      expect(parseDuracionRouteros('1w'), const Duration(days: 7));
      expect(parseDuracionRouteros('30d'), const Duration(days: 30));
      expect(parseDuracionRouteros('1w2d'), const Duration(days: 9));
      expect(parseDuracionRouteros('1h30m'), const Duration(hours: 1, minutes: 30));
      expect(parseDuracionRouteros('1h2m3s'), const Duration(hours: 1, minutes: 2, seconds: 3));
    });

    test('formato HH:MM:SS y segundos pelados', () {
      expect(parseDuracionRouteros('01:00:00'), const Duration(hours: 1));
      expect(parseDuracionRouteros('00:30:00'), const Duration(minutes: 30));
      expect(parseDuracionRouteros('2d01:00:00'), const Duration(days: 2, hours: 1));
      expect(parseDuracionRouteros('3600'), const Duration(hours: 1));
      expect(parseDuracionRouteros('18000'), const Duration(hours: 5));
      expect(parseDuracionRouteros('2592000'), const Duration(days: 30));
    });

    test('los atajos de duración dan las horas/días que promete la pantalla', () {
      // Los mismos valores que muestran los chips del perfil.
      expect(parseDuracionRouteros('3600'), const Duration(hours: 1));
      expect(parseDuracionRouteros('18000'), const Duration(hours: 5));
      expect(parseDuracionRouteros('86400'), const Duration(days: 1));
      expect(parseDuracionRouteros('604800'), const Duration(days: 7));
      expect(parseDuracionRouteros('2592000'), const Duration(days: 30));

      expect(duracionLegible(parseDuracionRouteros('3600')), '1 h');
      expect(duracionLegible(parseDuracionRouteros('18000')), '5 h');
      expect(duracionLegible(parseDuracionRouteros('86400')), '1 día');
      expect(duracionLegible(parseDuracionRouteros('604800')), '7 días');
      expect(duracionLegible(parseDuracionRouteros('2592000')), '30 días');
    });

    test('textos inválidos devuelven null', () {
      expect(parseDuracionRouteros(''), isNull);
      expect(parseDuracionRouteros(null), isNull);
      expect(parseDuracionRouteros('sin-limite'), isNull);
    });
  });

  group('estadoDeFicha', () {
    test('sin usar → Nueva (no se borra)', () {
      final f = {'name': 'abc123', 'limit-uptime': '1h'};
      expect(estadoDeFicha(f), EstadoFicha.nueva);
      expect(fichaListaParaBorrar(f), isFalse);
    });

    test('usada con tiempo a favor → En uso (no se borra)', () {
      final f = {'limit-uptime': '1h', 'uptime': '20m', 'bytes-in': '1500'};
      expect(estadoDeFicha(f), EstadoFicha.enUso);
      expect(fichaListaParaBorrar(f), isFalse);
      expect(tiempoRestante(f), const Duration(minutes: 40));
    });

    test('usada y tiempo agotado → Caducada (SÍ se borra)', () {
      final f = {'limit-uptime': '1h', 'uptime': '1h', 'bytes-in': '9000'};
      expect(estadoDeFicha(f), EstadoFicha.caducada);
      expect(fichaListaParaBorrar(f), isTrue);
      expect(tiempoRestante(f), Duration.zero);
    });

    test('usada de más (uptime > límite) sigue caducada', () {
      final f = {'limit-uptime': '1h', 'uptime': '1h05m'};
      expect(estadoDeFicha(f), EstadoFicha.caducada);
      expect(tiempoRestante(f), Duration.zero);
    });

    test('usada sin limit-uptime → Sin límite (no se borra sola)', () {
      final f = {'uptime': '5m', 'bytes-out': '2048'};
      expect(estadoDeFicha(f), EstadoFicha.sinLimite);
      expect(fichaListaParaBorrar(f), isFalse);
      expect(tiempoRestante(f), isNull);
    });

    test('acepta los nombres alternativos del API (uptime-used / bytesIn)', () {
      final f = {'limit-uptime': '30m', 'uptime-used': '30m', 'bytesIn': '10'};
      expect(estadoDeFicha(f), EstadoFicha.caducada);
    });
  });

  group('Pines reales del negocio', () {
    test('pin de 1 hora: se conserva hasta que se agoten los 60 minutos', () {
      final pin = <String, dynamic>{'name': 'h1', 'limit-uptime': '1h'};
      expect(fichaListaParaBorrar(pin), isFalse);

      pin['uptime'] = '15m';
      expect(fichaListaParaBorrar(pin), isFalse, reason: 'todavía le quedan 45 min');

      pin['uptime'] = '1h';
      expect(fichaListaParaBorrar(pin), isTrue, reason: 'ya caducó');
    });

    test('pin de 1 semana: no se borra a los 2 días de uso', () {
      final pin = <String, dynamic>{'limit-uptime': '1w', 'uptime': '2d'};
      expect(fichaListaParaBorrar(pin), isFalse);
      expect(tiempoRestante(pin), const Duration(days: 5));

      pin['uptime'] = '7d';
      expect(fichaListaParaBorrar(pin), isTrue);
    });

    test('pin de 1 mes (30 días): caduca recién a los 30 días usados', () {
      final pin = <String, dynamic>{'limit-uptime': '30d', 'uptime': '29d'};
      expect(fichaListaParaBorrar(pin), isFalse);

      pin['uptime'] = '30d';
      expect(fichaListaParaBorrar(pin), isTrue);
    });

    test('pin de 5 horas: sólo caduca al completar las 5 horas de uso', () {
      final pin = <String, dynamic>{'limit-uptime': '5h', 'uptime': '4h59m'};
      expect(fichaListaParaBorrar(pin), isFalse, reason: 'todavía tiene 1 minuto a favor');

      pin['uptime'] = '5h';
      expect(fichaListaParaBorrar(pin), isTrue);
    });

    test('duracionVoucher usa el session-timeout del perfil si la ficha no lo trae', () {
      final ficha = {'name': 'x', 'profile': 'Plan-1H', 'uptime': '10m'};
      final perfiles = [
        {'name': 'Plan-1H', 'session-timeout': '1h'},
        {'name': 'Plan-Mes', 'session-timeout': '30d'},
      ];
      expect(duracionVoucher(ficha, perfiles), const Duration(hours: 1));
    });
  });

  group('duracionLegible', () {
    test('muestra horas, días y meses en texto claro', () {
      expect(duracionLegible(const Duration(hours: 1)), '1 h');
      expect(duracionLegible(const Duration(days: 1)), '1 día');
      expect(duracionLegible(const Duration(days: 7)), '7 días');
      expect(duracionLegible(const Duration(days: 30)), '30 días');
      expect(duracionLegible(null), '—');
    });
  });
}
