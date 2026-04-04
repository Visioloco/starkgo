import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class EquiposRecord extends FirestoreRecord {
  EquiposRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "tipo" field. → 'antena' | 'router'
  String? _tipo;
  String get tipo => _tipo ?? '';
  bool hasTipo() => _tipo != null;

  // "marca" field.
  String? _marca;
  String get marca => _marca ?? '';
  bool hasMarca() => _marca != null;

  // "modelo" field.
  String? _modelo;
  String get modelo => _modelo ?? '';
  bool hasModelo() => _modelo != null;

  // "ip" field.
  String? _ip;
  String get ip => _ip ?? '';
  bool hasIp() => _ip != null;

  // "notas" field.
  String? _notas;
  String get notas => _notas ?? '';
  bool hasNotas() => _notas != null;

  // "fecha_registro" field.
  DateTime? _fechaRegistro;
  DateTime? get fechaRegistro => _fechaRegistro;
  bool hasFechaRegistro() => _fechaRegistro != null;

  // "disponible" field.
  bool? _disponible;
  bool get disponible => _disponible ?? false;
  bool hasDisponible() => _disponible != null;

  void _initializeFields() {
    _tipo = snapshotData['tipo'] as String?;
    _marca = snapshotData['marca'] as String?;
    _modelo = snapshotData['modelo'] as String?;
    _ip = snapshotData['ip'] as String?;
    _notas = snapshotData['notas'] as String?;
    _fechaRegistro = snapshotData['fecha_registro'] as DateTime?;
    _disponible = snapshotData['disponible'] as bool?;
  }

  static CollectionReference get collection => FirebaseFirestore.instance.collection('equipos');

  static Stream<EquiposRecord> getDocument(DocumentReference ref) => ref.snapshots().map((s) => EquiposRecord.fromSnapshot(s));

  static Future<EquiposRecord> getDocumentOnce(DocumentReference ref) => ref.get().then((s) => EquiposRecord.fromSnapshot(s));

  static EquiposRecord fromSnapshot(DocumentSnapshot snapshot) => EquiposRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static EquiposRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      EquiposRecord._(reference, mapFromFirestore(data));

  @override
  String toString() => 'EquiposRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) => other is EquiposRecord && reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createEquiposRecordData({
  String? tipo,
  String? marca,
  String? modelo,
  String? ip,
  String? notas,
  DateTime? fechaRegistro,
  bool? disponible,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'tipo': tipo,
      'marca': marca,
      'modelo': modelo,
      'ip': ip,
      'notas': notas,
      'fecha_registro': fechaRegistro,
      'disponible': disponible,
    }.withoutNulls,
  );

  return firestoreData;
}

class EquiposRecordDocumentEquality implements Equality<EquiposRecord> {
  const EquiposRecordDocumentEquality();

  @override
  bool equals(EquiposRecord? e1, EquiposRecord? e2) {
    return e1?.tipo == e2?.tipo &&
        e1?.marca == e2?.marca &&
        e1?.modelo == e2?.modelo &&
        e1?.ip == e2?.ip &&
        e1?.notas == e2?.notas &&
        e1?.fechaRegistro == e2?.fechaRegistro &&
        e1?.disponible == e2?.disponible;
  }

  @override
  int hash(EquiposRecord? e) => const ListEquality().hash([
        e?.tipo,
        e?.marca,
        e?.modelo,
        e?.ip,
        e?.notas,
        e?.fechaRegistro,
        e?.disponible,
      ]);

  @override
  bool isValidKey(Object? o) => o is EquiposRecord;
}
