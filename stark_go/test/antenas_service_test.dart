import 'package:flutter_test/flutter_test.dart';

import 'package:stark_go/services/antenas_service.dart';

void main() {
  group('AntenasService.ipEnSubred', () {
    test('acepta IPs dentro de la subred', () {
      expect(AntenasService.ipEnSubred('10.10.15.10', '10.10.15.0/24'), isTrue);
      expect(AntenasService.ipEnSubred('10.10.15.1', '10.10.15.0/24'), isTrue);
      expect(AntenasService.ipEnSubred('10.10.15.254', '10.10.15.0/24'), isTrue);
      expect(AntenasService.ipEnSubred('10.10.16.200', '10.10.16.0/24'), isTrue);
    });

    test('rechaza IPs fuera de la subred', () {
      expect(AntenasService.ipEnSubred('10.10.16.10', '10.10.15.0/24'), isFalse);
      expect(AntenasService.ipEnSubred('10.10.14.10', '10.10.15.0/24'), isFalse);
      expect(AntenasService.ipEnSubred('10.11.15.10', '10.10.15.0/24'), isFalse);
      expect(AntenasService.ipEnSubred('192.168.1.1', '10.10.15.0/24'), isFalse);
    });

    test('rechaza entradas inválidas', () {
      expect(AntenasService.ipEnSubred('10.10.15.10', '10.10.15.0/24'), isTrue);
      expect(AntenasService.ipEnSubred('10.10.15.10', 'no-es-cidr'), isFalse);
      expect(AntenasService.ipEnSubred('999.1.1.1', '10.10.15.0/24'), isFalse);
      expect(AntenasService.ipEnSubred('10.10.15', '10.10.15.0/24'), isFalse);
    });

    test('cada empresa tiene una subred distinta (no chocan)', () {
      // Empresa A → 10.10.15.0/24, Empresa B → 10.10.16.0/24
      const ipA = '10.10.15.8';
      const ipB = '10.10.16.8';
      expect(AntenasService.ipEnSubred(ipA, '10.10.15.0/24'), isTrue);
      expect(AntenasService.ipEnSubred(ipB, '10.10.16.0/24'), isTrue);
      // La antena de A no pertenece a la subred de B y viceversa.
      expect(AntenasService.ipEnSubred(ipA, '10.10.16.0/24'), isFalse);
      expect(AntenasService.ipEnSubred(ipB, '10.10.15.0/24'), isFalse);
    });
  });
}
