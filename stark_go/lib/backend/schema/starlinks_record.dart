import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class StarlinksRecord extends FirestoreRecord {
  StarlinksRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "nombre" field.
  String? _nombre;
  String get nombre => _nombre ?? '';
  bool hasNombre() => _nombre != null;

  // "ubicacion" field.
  String? _ubicacion;
  String get ubicacion => _ubicacion ?? '';
  bool hasUbicacion() => _ubicacion != null;

  // "plan_pago" field.
  String? _planPago;
  String get planPago => _planPago ?? '';
  bool hasPlanPago() => _planPago != null;

  // "notas" field.
  String? _notas;
  String get notas => _notas ?? '';
  bool hasNotas() => _notas != null;

  // "fecha_instalacion" field.
  DateTime? _fechaInstalacion;
  DateTime? get fechaInstalacion => _fechaInstalacion;
  bool hasFechaInstalacion() => _fechaInstalacion != null;

  // "fecha_registro" field.
  DateTime? _fechaRegistro;
  DateTime? get fechaRegistro => _fechaRegistro;
  bool hasFechaRegistro() => _fechaRegistro != null;

  // "activo" field.
  bool? _activo;
  bool get activo => _activo ?? false;
  bool hasActivo() => _activo != null;

  // "clientes_count" field.
  int? _clientesCount;
  int get clientesCount => _clientesCount ?? 0;
  bool hasClientesCount() => _clientesCount != null;

  void _initializeFields() {
    _nombre = snapshotData['nombre'] as String?;
    _ubicacion = snapshotData['ubicacion'] as String?;
    _planPago = snapshotData['plan_pago'] as String?;
    _notas = snapshotData['notas'] as String?;
    _fechaInstalacion = snapshotData['fecha_instalacion'] as DateTime?;
    _fechaRegistro = snapshotData['fecha_registro'] as DateTime?;
    _activo = snapshotData['activo'] as bool?;
    _clientesCount = castToType<int>(snapshotData['clientes_count']);
  }

  static CollectionReference get collection => FirebaseFirestore.instance.collection('starlinks');

  static Stream<StarlinksRecord> getDocument(DocumentReference ref) => ref.snapshots().map((s) => StarlinksRecord.fromSnapshot(s));

  static Future<StarlinksRecord> getDocumentOnce(DocumentReference ref) => ref.get().then((s) => StarlinksRecord.fromSnapshot(s));

  static StarlinksRecord fromSnapshot(DocumentSnapshot snapshot) => StarlinksRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static StarlinksRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      StarlinksRecord._(reference, mapFromFirestore(data));

  @override
  String toString() => 'StarlinksRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) => other is StarlinksRecord && reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createStarlinksRecordData({
  String? nombre,
  String? ubicacion,
  String? planPago,
  String? notas,
  DateTime? fechaInstalacion,
  DateTime? fechaRegistro,
  bool? activo,
  int? clientesCount,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'nombre': nombre,
      'ubicacion': ubicacion,
      'plan_pago': planPago,
      'notas': notas,
      'fecha_instalacion': fechaInstalacion,
      'fecha_registro': fechaRegistro,
      'activo': activo,
      'clientes_count': clientesCount,
    }.withoutNulls,
  );

  return firestoreData;
}

class StarlinksRecordDocumentEquality implements Equality<StarlinksRecord> {
  const StarlinksRecordDocumentEquality();

  @override
  bool equals(StarlinksRecord? e1, StarlinksRecord? e2) {
    return e1?.nombre == e2?.nombre &&
        e1?.ubicacion == e2?.ubicacion &&
        e1?.planPago == e2?.planPago &&
        e1?.notas == e2?.notas &&
        e1?.fechaInstalacion == e2?.fechaInstalacion &&
        e1?.fechaRegistro == e2?.fechaRegistro &&
        e1?.activo == e2?.activo &&
        e1?.clientesCount == e2?.clientesCount;
  }

  @override
  int hash(StarlinksRecord? e) => const ListEquality().hash([
        e?.nombre,
        e?.ubicacion,
        e?.planPago,
        e?.notas,
        e?.fechaInstalacion,
        e?.fechaRegistro,
        e?.activo,
        e?.clientesCount,
      ]);

  @override
  bool isValidKey(Object? o) => o is StarlinksRecord;
}
