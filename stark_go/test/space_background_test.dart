import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stark_go/widgets/space_background.dart';

// Test TEMPORAL: el fondo espacial tiene que dibujarse sin excepciones.
void main() {
  testWidgets('SpaceBackground se dibuja sin errores', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SpaceBackground(),
        ),
      ),
    );
    // Avanzamos varios segundos de animación (estrellas, fugaces, agujeros…)
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('SpaceBackground con intensidad baja', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SpaceBackground(intensidad: 0.4),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
