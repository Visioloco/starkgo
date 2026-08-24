import 'package:flutter_test/flutter_test.dart';

import 'package:stark_go/services/wireguard_keygen.dart';

void main() {
  test('genera un par de claves WireGuard válido', () async {
    final par = await WireGuardKeygen.generarParClaves();

    expect(WireGuardKeygen.esClaveValida(par.privateKey), isTrue,
        reason: 'privateKey debe ser base64 de 32 bytes');
    expect(WireGuardKeygen.esClaveValida(par.publicKey), isTrue,
        reason: 'publicKey debe ser base64 de 32 bytes');
    expect(par.privateKey.length, 44);
    expect(par.publicKey.length, 44);
  });

  test('deriva la clave pública correcta a partir de la privada', () async {
    final par = await WireGuardKeygen.generarParClaves();

    final publica = await WireGuardKeygen.derivarPublica(par.privateKey);

    expect(publica, par.publicKey,
        reason: 'X25519(privada) debe coincidir con la pública generada');
  });

  test('rechaza claves inválidas', () async {
    expect(WireGuardKeygen.esClaveValida('clave-invalida'), isFalse);
    expect(WireGuardKeygen.esClaveValida(''), isFalse);
    expect(WireGuardKeygen.esClaveValida('a' * 44), isFalse,
        reason: 'la base64 debe terminar en =');

    final publica = await WireGuardKeygen.derivarPublica('clave-invalida');
    expect(publica, isNull);
  });
}
