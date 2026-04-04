import '/flutter_flow/flutter_flow_util.dart';
import 'crear_starlink_widget.dart' show CrearStarlinkWidget;
import 'package:flutter/material.dart';

class CrearStarlinkModel extends FlutterFlowModel<CrearStarlinkWidget> {
  final formKey = GlobalKey<FormState>();

  // Nombre / identificador
  FocusNode? textFieldFocusNode1;
  TextEditingController? textController1;
  String? Function(BuildContext, String?)? textController1Validator;
  String? _textController1Validator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) return 'Nombre es requerido';
    return null;
  }

  // Ubicación / caserío
  FocusNode? textFieldFocusNode2;
  TextEditingController? textController2;
  String? Function(BuildContext, String?)? textController2Validator;
  String? _textController2Validator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) return 'Ubicación es requerida';
    return null;
  }

  // Plan que se paga a Starlink
  FocusNode? textFieldFocusNode3;
  TextEditingController? textController3;
  String? Function(BuildContext, String?)? textController3Validator;
  String? _textController3Validator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) return 'Plan es requerido';
    return null;
  }

  // Notas (opcional)
  FocusNode? textFieldFocusNode4;
  TextEditingController? textController4;

  // Fecha de instalación seleccionada
  DateTime? fechaInstalacion;

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
