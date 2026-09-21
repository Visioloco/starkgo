import 'package:flutter_test/flutter_test.dart';

import 'package:stark_go/services/precios_service.dart';

// Reglas de negocio de las pasarelas por país:
//   · Mercado Pago → solo Colombia (la cuenta es CO y solo cobra allá)
//   · ePayco       → por defecto en TODOS los países (incluida Colombia)
// Estas reglas se ajustan desde Firestore/VPS sin recompilar la app.
void main() {
  group('PreciosService.paisPermitido', () {
    test('lista blanca: solo los países listados', () {
      expect(PreciosService.paisPermitido(pais: 'CO', paises: ['CO']), isTrue);
      expect(PreciosService.paisPermitido(pais: 'US', paises: ['CO']), isFalse);
    });

    test('lista negra: todos menos los excluidos', () {
      expect(PreciosService.paisPermitido(pais: 'US', excluir: ['CO']), isTrue);
      expect(PreciosService.paisPermitido(pais: 'CO', excluir: ['CO']), isFalse);
    });

    test('la lista negra gana sobre la blanca', () {
      expect(
        PreciosService.paisPermitido(pais: 'CO', paises: ['CO'], excluir: ['CO']),
        isFalse,
      );
    });

    test('forzar se muestra en todo el mundo', () {
      expect(
        PreciosService.paisPermitido(pais: 'CO', excluir: ['CO'], forzar: true),
        isTrue,
      );
    });

    test('país desconocido (null) no bloquea la venta', () {
      expect(PreciosService.paisPermitido(pais: null, paises: ['CO']), isTrue);
    });
  });

  group('Reglas reales de las pasarelas', () {
    test('Mercado Pago solo en Colombia', () {
      expect(PreciosService.mercadoPagoDisponible('CO'), isTrue);
      expect(PreciosService.mercadoPagoDisponible('US'), isFalse);
      expect(PreciosService.mercadoPagoDisponible(null), isTrue,
          reason: 'sin país detectado no le quitamos el botón al cliente');
    });

    test('ePayco en TODOS los países (incluida Colombia)', () {
      expect(PreciosService.epaycoDisponible('CO'), isTrue,
          reason: 'en Colombia además de Mercado Pago también está ePayco');
      expect(PreciosService.epaycoDisponible('US'), isTrue);
      expect(PreciosService.epaycoDisponible('MX'), isTrue);
      expect(PreciosService.epaycoDisponible(null), isTrue);
    });

    test('si se excluye un país, ePayco no se muestra ahí', () {
      expect(
        PreciosService.paisPermitido(pais: 'CO', excluir: ['CO']),
        isFalse,
        reason: 'con excluirPaises ["CO"] se oculta en Colombia',
      );
    });
  });
}
