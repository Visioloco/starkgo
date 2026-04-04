import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'home_widget.dart' show HomeWidget;
import 'package:flutter/material.dart';

class HomeModel extends FlutterFlowModel<HomeWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - actualizarMoraPorBoton] action in Container widget.
  String? resultado;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;
  List<ClientesRecord> simpleSearchResults = [];
  // Stores action output result for [Custom Action - generarMensajeWhatsapp] action in Container widget.
  String? mnsajs;
  // Stores action output result for [Custom Action - generarMensajeWhatsapp] action in Container widget.
  String? mnsajss;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}
