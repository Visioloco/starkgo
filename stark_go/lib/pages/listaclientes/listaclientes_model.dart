import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'listaclientes_widget.dart' show ListaclientesWidget;
import 'package:flutter/material.dart';

class ListaclientesModel extends FlutterFlowModel<ListaclientesWidget> {
  ///  State fields for stateful widgets in this page.

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
    // textController?.dispose();  // ← comentar o eliminar esta líne
  }
}
