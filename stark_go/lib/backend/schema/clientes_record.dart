import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ClientesRecord extends FirestoreRecord {
  ClientesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "nombre" field.
  String? _nombre;
  String get nombre => _nombre ?? '';
  bool hasNombre() => _nombre != null;

  // "apellido" field.
  String? _apellido;
  String get apellido => _apellido ?? '';
  bool hasApellido() => _apellido != null;

  // "numero" field.
  int? _numero;
  int get numero => _numero ?? 0;
  bool hasNumero() => _numero != null;

  // "vereda" field.
  String? _vereda;
  String get vereda => _vereda ?? '';
  bool hasVereda() => _vereda != null;

  // "nombrefinca" field.
  String? _nombrefinca;
  String get nombrefinca => _nombrefinca ?? '';
  bool hasNombrefinca() => _nombrefinca != null;

  // "claveatn" field.
  String? _claveatn;
  String get claveatn => _claveatn ?? '';
  bool hasClaveatn() => _claveatn != null;

  // "usuarioatn" field.
  String? _usuarioatn;
  String get usuarioatn => _usuarioatn ?? '';
  bool hasUsuarioatn() => _usuarioatn != null;

  // "ipatn" field.
  String? _ipatn;
  String get ipatn => _ipatn ?? '';
  bool hasIpatn() => _ipatn != null;

  // "usuariorouter" field.
  String? _usuariorouter;
  String get usuariorouter => _usuariorouter ?? '';
  bool hasUsuariorouter() => _usuariorouter != null;

  // "claverouter" field.
  String? _claverouter;
  String get claverouter => _claverouter ?? '';
  bool hasClaverouter() => _claverouter != null;

  // "iprouter" field.
  String? _iprouter;
  String get iprouter => _iprouter ?? '';
  bool hasIprouter() => _iprouter != null;

  // "fecha" field.
  DateTime? _fecha;
  DateTime? get fecha => _fecha;
  bool hasFecha() => _fecha != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "cc" field.
  int? _cc;
  int get cc => _cc ?? 0;
  bool hasCc() => _cc != null;

  // "starlinkId" field.
  String? _starlinkId;
  String get starlinkId => _starlinkId ?? '';
  bool hasStarlinkId() => _starlinkId != null;

  // "starlinkNombre" field.
  String? _starlinkNombre;
  String get starlinkNombre => _starlinkNombre ?? '';
  bool hasStarlinkNombre() => _starlinkNombre != null;

  // "antenaId" field.
  String? _antenaId;
  String get antenaId => _antenaId ?? '';
  bool hasAntenaId() => _antenaId != null;

  // "antenaMarca" field.
  String? _antenaMarca;
  String get antenaMarca => _antenaMarca ?? '';
  bool hasAntenaMarca() => _antenaMarca != null;

  // "antenaModelo" field.
  String? _antenaModelo;
  String get antenaModelo => _antenaModelo ?? '';
  bool hasAntenaModelo() => _antenaModelo != null;

  // "antenaIp" field.
  String? _antenaIp;
  String get antenaIp => _antenaIp ?? '';
  bool hasAntenaIp() => _antenaIp != null;

  // "routerId" field.
  String? _routerId;
  String get routerId => _routerId ?? '';
  bool hasRouterId() => _routerId != null;

  // "routerMarca" field.
  String? _routerMarca;
  String get routerMarca => _routerMarca ?? '';
  bool hasRouterMarca() => _routerMarca != null;

  // "routerModelo" field.
  String? _routerModelo;
  String get routerModelo => _routerModelo ?? '';
  bool hasRouterModelo() => _routerModelo != null;

  // "routerIp" field.
  String? _routerIp;
  String get routerIp => _routerIp ?? '';
  bool hasRouterIp() => _routerIp != null;

  // "planCliente" field.
  String? _planCliente;
  String get planCliente => _planCliente ?? '';
  bool hasPlanCliente() => _planCliente != null;

  // "planValor" field.  ← NUEVO
  double? _planValor;
  double get planValor => _planValor ?? 0.0;
  bool hasPlanValor() => _planValor != null;

  // "tipoServicio" field.
  String? _tipoServicio;
  String get tipoServicio => _tipoServicio ?? '';
  bool hasTipoServicio() => _tipoServicio != null;

  // "velocidadPlan" field.
  String? _velocidadPlan;
  String get velocidadPlan => _velocidadPlan ?? '';
  bool hasVelocidadPlan() => _velocidadPlan != null;

  void _initializeFields() {
    _nombre = snapshotData['nombre'] as String?;
    _apellido = snapshotData['apellido'] as String?;
    _numero = castToType<int>(snapshotData['numero']);
    _vereda = snapshotData['vereda'] as String?;
    _nombrefinca = snapshotData['nombrefinca'] as String?;
    _claveatn = snapshotData['claveatn'] as String?;
    _usuarioatn = snapshotData['usuarioatn'] as String?;
    _ipatn = snapshotData['ipatn'] as String?;
    _usuariorouter = snapshotData['usuariorouter'] as String?;
    _claverouter = snapshotData['claverouter'] as String?;
    _iprouter = snapshotData['iprouter'] as String?;
    _fecha = snapshotData['fecha'] as DateTime?;
    _status = snapshotData['status'] as String?;
    _cc = castToType<int>(snapshotData['cc']);
    _starlinkId = snapshotData['starlinkId'] as String?;
    _starlinkNombre = snapshotData['starlinkNombre'] as String?;
    _antenaId = snapshotData['antenaId'] as String?;
    _antenaMarca = snapshotData['antenaMarca'] as String?;
    _antenaModelo = snapshotData['antenaModelo'] as String?;
    _antenaIp = snapshotData['antenaIp'] as String?;
    _routerId = snapshotData['routerId'] as String?;
    _routerMarca = snapshotData['routerMarca'] as String?;
    _routerModelo = snapshotData['routerModelo'] as String?;
    _routerIp = snapshotData['routerIp'] as String?;
    _planCliente = snapshotData['planCliente'] as String?;
    _planValor = castToType<double>(snapshotData['planValor']); // ← NUEVO
    _tipoServicio = snapshotData['tipoServicio'] as String?;
    _velocidadPlan = snapshotData['velocidadPlan'] as String?;
  }

  static CollectionReference get collection => FirebaseFirestore.instance.collection('clientes');

  static Stream<ClientesRecord> getDocument(DocumentReference ref) => ref.snapshots().map((s) => ClientesRecord.fromSnapshot(s));

  static Future<ClientesRecord> getDocumentOnce(DocumentReference ref) => ref.get().then((s) => ClientesRecord.fromSnapshot(s));

  static ClientesRecord fromSnapshot(DocumentSnapshot snapshot) => ClientesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ClientesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ClientesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() => 'ClientesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) => other is ClientesRecord && reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createClientesRecordData({
  String? nombre,
  String? apellido,
  int? numero,
  String? vereda,
  String? nombrefinca,
  String? claveatn,
  String? usuarioatn,
  String? ipatn,
  String? usuariorouter,
  String? claverouter,
  String? iprouter,
  DateTime? fecha,
  String? status,
  int? cc,
  String? starlinkId,
  String? starlinkNombre,
  String? antenaId,
  String? antenaMarca,
  String? antenaModelo,
  String? antenaIp,
  String? routerId,
  String? routerMarca,
  String? routerModelo,
  String? routerIp,
  String? planCliente,
  double? planValor, // ← NUEVO
  String? tipoServicio,
  String? velocidadPlan,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'nombre': nombre,
      'apellido': apellido,
      'numero': numero,
      'vereda': vereda,
      'nombrefinca': nombrefinca,
      'claveatn': claveatn,
      'usuarioatn': usuarioatn,
      'ipatn': ipatn,
      'usuariorouter': usuariorouter,
      'claverouter': claverouter,
      'iprouter': iprouter,
      'fecha': fecha,
      'status': status,
      'cc': cc,
      'starlinkId': starlinkId,
      'starlinkNombre': starlinkNombre,
      'antenaId': antenaId,
      'antenaMarca': antenaMarca,
      'antenaModelo': antenaModelo,
      'antenaIp': antenaIp,
      'routerId': routerId,
      'routerMarca': routerMarca,
      'routerModelo': routerModelo,
      'routerIp': routerIp,
      'planCliente': planCliente,
      'planValor': planValor, // ← NUEVO
      'tipoServicio': tipoServicio,
      'velocidadPlan': velocidadPlan,
    }.withoutNulls,
  );

  return firestoreData;
}

class ClientesRecordDocumentEquality implements Equality<ClientesRecord> {
  const ClientesRecordDocumentEquality();

  @override
  bool equals(ClientesRecord? e1, ClientesRecord? e2) {
    return e1?.nombre == e2?.nombre &&
        e1?.apellido == e2?.apellido &&
        e1?.numero == e2?.numero &&
        e1?.vereda == e2?.vereda &&
        e1?.nombrefinca == e2?.nombrefinca &&
        e1?.claveatn == e2?.claveatn &&
        e1?.usuarioatn == e2?.usuarioatn &&
        e1?.ipatn == e2?.ipatn &&
        e1?.usuariorouter == e2?.usuariorouter &&
        e1?.claverouter == e2?.claverouter &&
        e1?.iprouter == e2?.iprouter &&
        e1?.fecha == e2?.fecha &&
        e1?.status == e2?.status &&
        e1?.cc == e2?.cc &&
        e1?.starlinkId == e2?.starlinkId &&
        e1?.starlinkNombre == e2?.starlinkNombre &&
        e1?.antenaId == e2?.antenaId &&
        e1?.antenaMarca == e2?.antenaMarca &&
        e1?.antenaModelo == e2?.antenaModelo &&
        e1?.antenaIp == e2?.antenaIp &&
        e1?.routerId == e2?.routerId &&
        e1?.routerMarca == e2?.routerMarca &&
        e1?.routerModelo == e2?.routerModelo &&
        e1?.routerIp == e2?.routerIp &&
        e1?.planCliente == e2?.planCliente &&
        e1?.planValor == e2?.planValor && // ← NUEVO
        e1?.tipoServicio == e2?.tipoServicio &&
        e1?.velocidadPlan == e2?.velocidadPlan;
  }

  @override
  int hash(ClientesRecord? e) => const ListEquality().hash([
        e?.nombre,
        e?.apellido,
        e?.numero,
        e?.vereda,
        e?.nombrefinca,
        e?.claveatn,
        e?.usuarioatn,
        e?.ipatn,
        e?.usuariorouter,
        e?.claverouter,
        e?.iprouter,
        e?.fecha,
        e?.status,
        e?.cc,
        e?.starlinkId,
        e?.starlinkNombre,
        e?.antenaId,
        e?.antenaMarca,
        e?.antenaModelo,
        e?.antenaIp,
        e?.routerId,
        e?.routerMarca,
        e?.routerModelo,
        e?.routerIp,
        e?.planCliente,
        e?.planValor, // ← NUEVO
        e?.tipoServicio,
        e?.velocidadPlan,
      ]);

  @override
  bool isValidKey(Object? o) => o is ClientesRecord;
}
