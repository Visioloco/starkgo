import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'planes_widget.dart' show PlanesWidget;
import 'package:flutter/material.dart';

class PlanesModel extends FlutterFlowModel<PlanesWidget> {
  // ─── Form key ───
  final formKey = GlobalKey<FormState>();

  // ─── Controllers y FocusNodes ───
  late TextEditingController tcNombre;
  late FocusNode fnNombre;

  late TextEditingController tcValor;
  late FocusNode fnValor;

  late TextEditingController tcDescripcion;
  late FocusNode fnDescripcion;

  /// Llamar en initState del widget
  void initControllers() {
    tcNombre = TextEditingController();
    fnNombre = FocusNode();
    tcValor = TextEditingController();
    fnValor = FocusNode();
    tcDescripcion = TextEditingController();
    fnDescripcion = FocusNode();
  }

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    fnNombre.dispose();
    tcNombre.dispose();
    fnValor.dispose();
    tcValor.dispose();
    fnDescripcion.dispose();
    tcDescripcion.dispose();
  }
}
