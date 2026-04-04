import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ReportepagoRecord extends FirestoreRecord {
  ReportepagoRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "imagen" field.
  String? _imagen;
  String get imagen => _imagen ?? '';
  bool hasImagen() => _imagen != null;

  // "ref" field.
  String? _ref;
  String get ref => _ref ?? '';
  bool hasRef() => _ref != null;

  // "valor" field.
  int? _valor;
  int get valor => _valor ?? 0;
  bool hasValor() => _valor != null;

  // "fecha" field.
  DateTime? _fecha;
  DateTime? get fecha => _fecha;
  bool hasFecha() => _fecha != null;

  // "comentario" field.
  String? _comentario;
  String get comentario => _comentario ?? '';
  bool hasComentario() => _comentario != null;

  // "refcliente" field.
  DocumentReference? _refcliente;
  DocumentReference? get refcliente => _refcliente;
  bool hasRefcliente() => _refcliente != null;

  // "nombrecliente" field.
  String? _nombrecliente;
  String get nombrecliente => _nombrecliente ?? '';
  bool hasNombrecliente() => _nombrecliente != null;

  // "pagofoto" field.
  String? _pagofoto;
  String get pagofoto => _pagofoto ?? '';
  bool hasPagofoto() => _pagofoto != null;

  void _initializeFields() {
    _imagen = snapshotData['imagen'] as String?;
    _ref = snapshotData['ref'] as String?;
    _valor = castToType<int>(snapshotData['valor']);
    _fecha = snapshotData['fecha'] as DateTime?;
    _comentario = snapshotData['comentario'] as String?;
    _refcliente = snapshotData['refcliente'] as DocumentReference?;
    _nombrecliente = snapshotData['nombrecliente'] as String?;
    _pagofoto = snapshotData['pagofoto'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('reportepago');

  static Stream<ReportepagoRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ReportepagoRecord.fromSnapshot(s));

  static Future<ReportepagoRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ReportepagoRecord.fromSnapshot(s));

  static ReportepagoRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ReportepagoRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ReportepagoRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ReportepagoRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ReportepagoRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ReportepagoRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createReportepagoRecordData({
  String? imagen,
  String? ref,
  int? valor,
  DateTime? fecha,
  String? comentario,
  DocumentReference? refcliente,
  String? nombrecliente,
  String? pagofoto,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'imagen': imagen,
      'ref': ref,
      'valor': valor,
      'fecha': fecha,
      'comentario': comentario,
      'refcliente': refcliente,
      'nombrecliente': nombrecliente,
      'pagofoto': pagofoto,
    }.withoutNulls,
  );

  return firestoreData;
}

class ReportepagoRecordDocumentEquality implements Equality<ReportepagoRecord> {
  const ReportepagoRecordDocumentEquality();

  @override
  bool equals(ReportepagoRecord? e1, ReportepagoRecord? e2) {
    return e1?.imagen == e2?.imagen &&
        e1?.ref == e2?.ref &&
        e1?.valor == e2?.valor &&
        e1?.fecha == e2?.fecha &&
        e1?.comentario == e2?.comentario &&
        e1?.refcliente == e2?.refcliente &&
        e1?.nombrecliente == e2?.nombrecliente &&
        e1?.pagofoto == e2?.pagofoto;
  }

  @override
  int hash(ReportepagoRecord? e) => const ListEquality().hash([
        e?.imagen,
        e?.ref,
        e?.valor,
        e?.fecha,
        e?.comentario,
        e?.refcliente,
        e?.nombrecliente,
        e?.pagofoto
      ]);

  @override
  bool isValidKey(Object? o) => o is ReportepagoRecord;
}
