import '/flutter_flow/flutter_flow_util.dart';
import 'crear_cuenta_widget.dart';
import 'package:flutter/material.dart';

class CrearCuentaModel extends FlutterFlowModel<CrearCuentaWidget> {
  final formKey = GlobalKey<FormState>();

  // Nombre
  FocusNode? nombreFocusNode;
  TextEditingController? nombreController;
  String? Function(BuildContext, String?)? nombreValidator;

  // Apellido
  FocusNode? apellidoFocusNode;
  TextEditingController? apellidoController;
  String? Function(BuildContext, String?)? apellidoValidator;

  // Correo
  FocusNode? correoFocusNode;
  TextEditingController? correoController;
  String? Function(BuildContext, String?)? correoValidator;

  // Contraseña
  FocusNode? passwordFocusNode;
  TextEditingController? passwordController;
  late bool passwordVisibility;
  String? Function(BuildContext, String?)? passwordValidator;

  // Teléfono WhatsApp
  FocusNode? telefonoFocusNode;
  TextEditingController? telefonoController;
  String? Function(BuildContext, String?)? telefonoValidator;

  @override
  void initState(BuildContext context) {
    passwordVisibility = false;
  }

  @override
  void dispose() {
    nombreFocusNode?.dispose();
    nombreController?.dispose();

    apellidoFocusNode?.dispose();
    apellidoController?.dispose();

    correoFocusNode?.dispose();
    correoController?.dispose();

    passwordFocusNode?.dispose();
    passwordController?.dispose();

    telefonoFocusNode?.dispose();
    telefonoController?.dispose();
  }
}
