// ══════════════════════════════════════════════════════════════
//  IPs locales del teléfono — STUB para web / plataformas sin `dart:io`.
//
//  En la web no se puede leer la red local, así que devolvemos vacío: el
//  blindaje se puede igual hacer por MAC o escribiendo la IP a mano.
// ══════════════════════════════════════════════════════════════

Future<List<String>> ipsLocalesDelTelefono() async => const [];
