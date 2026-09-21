import 'package:flutter_test/flutter_test.dart';

import 'package:stark_go/services/pdf_fichas_service.dart';

// Reglas del lote de vouchers (plan "Solo Vouchers"):
//   · se pueden crear hasta kMaxVouchersPorLote (1000) fichas de una vez;
//   · cada archivo PDF agrupa como máximo kMaxVouchersPorPdf (100) fichas.
// Por eso un lote de 1000 se reparte en 10 PDFs de 100.
void main() {
  group('Límites de vouchers', () {
    test('los topes son 1000 por lote y 100 por PDF', () {
      expect(kMaxVouchersPorLote, 1000);
      expect(kMaxVouchersPorPdf, 100);
    });
  });

  group('pdfsParaLote', () {
    test('sin fichas no hay PDFs', () {
      expect(pdfsParaLote(0), 0);
      expect(pdfsParaLote(-5), 0);
    });

    test('hasta 100 fichas cabe todo en 1 PDF', () {
      expect(pdfsParaLote(1), 1);
      expect(pdfsParaLote(100), 1);
    });

    test('101 fichas ya necesitan 2 PDFs', () {
      expect(pdfsParaLote(101), 2);
      expect(pdfsParaLote(200), 2);
    });

    test('el lote máximo (1000) sale en 10 PDFs de 100', () {
      expect(pdfsParaLote(1000), 10);
      expect(pdfsParaLote(kMaxVouchersPorLote), 10);
    });

    test('un tope por PDF inválido se rechaza', () {
      expect(() => pdfsParaLote(10, porPdf: 0), throwsArgumentError);
    });
  });

  group('dividirEnBloques', () {
    test('un lote vacío no genera bloques', () {
      expect(dividirEnBloques<String>([], 100), isEmpty);
    });

    test('1000 códigos → 10 bloques de 100', () {
      final codigos = List.generate(1000, (i) => 'cod$i');
      final bloques = dividirEnBloques(codigos, kMaxVouchersPorPdf);
      expect(bloques.length, 10);
      for (final b in bloques) {
        expect(b.length, kMaxVouchersPorPdf);
      }
      // No se pierde ni se repite ningún código.
      expect(bloques.expand((b) => b).toList(), codigos);
    });

    test('el último bloque queda corto cuando no es múltiplo', () {
      final bloques = dividirEnBloques(List.generate(250, (i) => i), 100);
      expect(bloques.map((b) => b.length).toList(), [100, 100, 50]);
      expect(bloques.last.last, 249);
    });

    test('un tamaño de bloque inválido se rechaza', () {
      expect(() => dividirEnBloques([1, 2, 3], 0), throwsArgumentError);
    });
  });
}
