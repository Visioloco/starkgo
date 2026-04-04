import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'config_mikro_tik_widget.dart' show ConfigMikroTikWidget;
import 'package:flutter/material.dart';

class ConfigMikroTikModel extends FlutterFlowModel<ConfigMikroTikWidget> {
  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();

  // ── VPS ──
  // State field(s) for VpsUrl TextField widget.
  FocusNode? vpsUrlFocusNode;
  TextEditingController? vpsUrlController;
  String? Function(BuildContext, String?)? vpsUrlControllerValidator;
  String? _vpsUrlControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'URL del VPS is required';
    }
    return null;
  }

  // State field(s) for VpsApiKey TextField widget.
  FocusNode? vpsApiKeyFocusNode;
  TextEditingController? vpsApiKeyController;
  String? Function(BuildContext, String?)? vpsApiKeyControllerValidator;
  String? _vpsApiKeyControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'API Key del VPS is required';
    }
    return null;
  }

  // ── MikroTik ──
  // State field(s) for MikrotikIp TextField widget.
  FocusNode? mikrotikIpFocusNode;
  TextEditingController? mikrotikIpController;
  String? Function(BuildContext, String?)? mikrotikIpControllerValidator;
  String? _mikrotikIpControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'IP del MikroTik is required';
    }
    return null;
  }

  // State field(s) for MikrotikUser TextField widget.
  FocusNode? mikrotikUserFocusNode;
  TextEditingController? mikrotikUserController;
  String? Function(BuildContext, String?)? mikrotikUserControllerValidator;
  String? _mikrotikUserControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Usuario MikroTik is required';
    }
    return null;
  }

  // State field(s) for MikrotikPass TextField widget.
  FocusNode? mikrotikPassFocusNode;
  TextEditingController? mikrotikPassController;
  String? Function(BuildContext, String?)? mikrotikPassControllerValidator;
  String? _mikrotikPassControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Contraseña MikroTik is required';
    }
    return null;
  }

  // ── Scheduler ──
  // State field(s) for SchedulerDropdown widget.
  int? schedulerMinutos;

  // ── UI State ──
  bool cargando = false;
  bool guardando = false;
  bool scriptVisible = false;

  @override
  void initState(BuildContext context) {
    vpsUrlControllerValidator = _vpsUrlControllerValidator;
    vpsApiKeyControllerValidator = _vpsApiKeyControllerValidator;
    mikrotikIpControllerValidator = _mikrotikIpControllerValidator;
    mikrotikUserControllerValidator = _mikrotikUserControllerValidator;
    mikrotikPassControllerValidator = _mikrotikPassControllerValidator;
  }

  @override
  void dispose() {
    vpsUrlFocusNode?.dispose();
    vpsUrlController?.dispose();

    vpsApiKeyFocusNode?.dispose();
    vpsApiKeyController?.dispose();

    mikrotikIpFocusNode?.dispose();
    mikrotikIpController?.dispose();

    mikrotikUserFocusNode?.dispose();
    mikrotikUserController?.dispose();

    mikrotikPassFocusNode?.dispose();
    mikrotikPassController?.dispose();
  }
}
