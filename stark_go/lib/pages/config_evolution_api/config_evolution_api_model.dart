import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_util.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODEL – ConfigEvolutionApiWidget
// ══════════════════════════════════════════════════════════════════════════════
// Este archivo sigue el patrón FlutterFlow: un ChangeNotifier por página que
// mantiene el estado local, los controladores de texto y el foco.
// La lógica real (llamadas HTTP, Firebase, polling) vive en el _State del Widget.
// ══════════════════════════════════════════════════════════════════════════════

class ConfigEvolutionApiModel extends FlutterFlowModel<ConfigEvolutionApiWidget> {
  // ── Controladores de texto ─────────────────────────────────────────────────
  /// Número de WhatsApp que ingresa el usuario (solo dígitos)
  FocusNode? phoneFocusNode;
  TextEditingController? phoneController;
  String? Function(BuildContext, String?)? phoneControllerValidator;

  // ── Campos de estado expuestos (opcionales, para bindings FF) ─────────────
  /// Nombre de la instancia activa en Evolution API
  String? instanceName;

  /// true cuando el estado de la instancia es 'open' (open = conectado)
  bool isConnected = false;

  static String? get routeName => null;

  // ══════════════════════════════════════════════════════════════════════════
  @override
  void initState(BuildContext context) {
    // Inicialización de controladores de texto
    phoneFocusNode = FocusNode();
    phoneController = TextEditingController();
  }

  @override
  void dispose() {
    phoneFocusNode?.dispose();
    phoneController?.dispose();
  }
}

// ── Placeholder del Widget (para que el modelo compile sin dependencias) ──────
// En tu proyecto real este placeholder NO va; el Widget ya está en
// config_evolution_api_widget.dart
// ─────────────────────────────────────────────────────────────────────────────
class ConfigEvolutionApiWidget extends StatefulWidget {
  const ConfigEvolutionApiWidget({super.key});
  static String routeName = 'ConfigEvolutionApi';
  static String routePath = 'configEvolutionApi';

  @override
  State<ConfigEvolutionApiWidget> createState() => _ConfigEvolutionApiWidgetState();
}

class _ConfigEvolutionApiWidgetState extends State<ConfigEvolutionApiWidget> {
  late ConfigEvolutionApiModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConfigEvolutionApiModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
