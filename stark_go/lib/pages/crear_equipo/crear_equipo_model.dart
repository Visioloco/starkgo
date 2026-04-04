import '/flutter_flow/flutter_flow_util.dart';
import 'crear_equipos_widget.dart' show CrearEquipoWidget;
import 'package:flutter/material.dart';

class CrearEquipoModel extends FlutterFlowModel<CrearEquipoWidget> {
  final formKey = GlobalKey<FormState>();

  // Tipo de equipo: 'antena' o 'router'
  String tipoEquipo = 'antena';

  // Marca
  FocusNode? textFieldFocusNode1;
  TextEditingController? textController1;
  String? Function(BuildContext, String?)? textController1Validator;
  String? _textController1Validator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) return 'Marca es requerida';
    return null;
  }

  // Modelo
  FocusNode? textFieldFocusNode2;
  TextEditingController? textController2;
  String? Function(BuildContext, String?)? textController2Validator;
  String? _textController2Validator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) return 'Modelo es requerido';
    return null;
  }

  // IP asignada
  FocusNode? textFieldFocusNode3;
  TextEditingController? textController3;
  String? Function(BuildContext, String?)? textController3Validator;
  String? _textController3Validator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) return 'IP es requerida';
    return null;
  }

  // Notas (opcional)
  FocusNode? textFieldFocusNode4;
  TextEditingController? textController4;

  @override
  void initState(BuildContext context) {
    textController1Validator = _textController1Validator;
    textController2Validator = _textController2Validator;
    textController3Validator = _textController3Validator;
  }

  @override
  void dispose() {
    textFieldFocusNode1?.dispose();
    textController1?.dispose();

    textFieldFocusNode2?.dispose();
    textController2?.dispose();

    textFieldFocusNode3?.dispose();
    textController3?.dispose();

    textFieldFocusNode4?.dispose();
    textController4?.dispose();
  }
}
