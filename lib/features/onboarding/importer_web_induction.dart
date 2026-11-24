import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/features/profile/importer_commercial_settings.dart';

/// Controles del panel mayorista que el recorrido de escritorio puede señalar.
enum ImporterTourTarget {
  homePriorities,
  navHome,
  inventoryAvailability,
  inventoryTools,
  navInventory,
  orderActions,
  orderAdvance,
  orderQty,
  pendingOrder,
  navOrders,
  orderChat,
  notifications,
  reputationSummary,
  navReputation,
  profileAlerts,
  profileData,
  commercialSettings,
  navProfile,
}

/// Inducción de primer ingreso del mayorista. Solo se ofrece en escritorio.
abstract final class ImporterWebInduction {
  static String _key(String profileId) =>
      'importer_web_induction_v5_${profileId.trim()}';

  static String _firstOrderKey(String profileId) =>
      'importer_web_first_order_v2_${profileId.trim()}';

  static _ImporterTourController get _tour => _ImporterTourController.instance;

  static Listenable get listenable => _tour;

  static bool get isActive => _tour.active;

  /// El panel de pedidos abre la primera ficha para mostrar los botones.
  static bool get wantsOrderDetail => _tour.wantsOrderDetail;

  /// El paso del pedido nuevo quiere la fila de la lista, no la ficha.
  static bool get highlightsPendingRow =>
      _tour.active &&
      _tour._script == _TourScript.orders &&
      _tour.index == 0;

  /// Subpestaña de Perfil que el paso activo necesita: 0 datos, 1 alertas.
  static int? get profileSubTab {
    if (!_tour.active || _tour._script != _TourScript.welcome) return null;
    return switch (_tour.index) {
      6 || 7 => 0,
      8 => 1,
      _ => null,
    };
  }

  static Future<bool> isDismissed(String profileId) async {
    if (profileId.trim().isEmpty) return true;
    return _isFlagDismissed(_key(profileId));
  }

  static Future<void> markDismissed(
    String profileId, {
    required bool skipped,
    bool firstOrder = false,
  }) async {
    if (profileId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      firstOrder ? _firstOrderKey(profileId) : _key(profileId),
      skipped ? 'skipped' : 'done',
    );
  }

  /// Primer ingreso en una ventana de escritorio. El panel estrecho no lo abre.
  static Future<void> showIfNeeded({
    required BuildContext context,
    required String profileId,
  }) async {
    if (!context.mounted) return;
    if (MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu) return;
    if (await isDismissed(profileId)) return;
    if (!context.mounted) return;
    await show(context: context, profileId: profileId);
  }

  static void rememberProfile(String profileId) {
    final id = profileId.trim();
    if (id.isEmpty) return;
    _tour.profileId = id;
  }

  static Future<void> show({
    required BuildContext context,
    required String profileId,
  }) {
    rememberProfile(profileId);
    return _tour.startWelcome(profileId);
  }

  /// Solo publicar, pausar y la carga masiva. No recorre el resto del panel.
  static Future<void> showInventory(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu) {
      return Future.value();
    }
    return _tour.startInventory();
  }

  /// Solo cómo gestionar un pedido. No recorre el resto del panel.
  static Future<void> showOrders(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu) {
      return Future.value();
    }
    return _tour.startOrders();
  }

  /// Recorrido de gestión la primera vez que hay un pedido. Solo escritorio.
  static Future<void> showFirstOrderIfNeeded(BuildContext context) async {
    if (!context.mounted) return;
    if (MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu) return;
    final id = _tour.profileId.trim();
    if (id.isEmpty) return;
    if (_tour.active) {
      _tour.queueFirstOrder = true;
      return;
    }
    if (await _isFlagDismissed(_firstOrderKey(id))) return;
    if (!context.mounted) return;
    await _tour.startFirstOrder(id);
  }

  static Future<bool> _isFlagDismissed(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);
    return value == 'done' || value == 'skipped';
  }

  static void registerTarget(
    ImporterTourTarget target,
    GlobalKey key, {
    int priority = 0,
  }) {
    _tour.register(target, key, priority: priority);
  }

  static void unregisterTarget(ImporterTourTarget target, GlobalKey key) {
    _tour.unregister(target, key);
  }

  static void notifyTargetUsed(ImporterTourTarget target) {
    _tour.advanceFromTarget(target);
  }
}

/// Botón de un recorrido corto. Solo se coloca en las vistas de escritorio.
class ImporterSectionInductionButton extends StatelessWidget {
  const ImporterSectionInductionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: theme.textSecondary,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      icon: LucideIcon(
        LucideGlyph.sparkles,
        size: 16,
        color: theme.brand,
      ),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Marca un control de escritorio. En el paso activo, tocarlo avanza el recorrido.
class ImporterTourAnchor extends StatefulWidget {
  const ImporterTourAnchor({
    super.key,
    required this.target,
    required this.child,
    this.priority = 0,
  });

  final ImporterTourTarget target;
  final Widget child;
  final int priority;

  @override
  State<ImporterTourAnchor> createState() => _ImporterTourAnchorState();
}

class _ImporterTourAnchorState extends State<ImporterTourAnchor> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    ImporterWebInduction.registerTarget(
      widget.target,
      _key,
      priority: widget.priority,
    );
  }

  @override
  void dispose() {
    ImporterWebInduction.unregisterTarget(widget.target, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: (_) => ImporterWebInduction.notifyTargetUsed(widget.target),
      child: KeyedSubtree(key: _key, child: widget.child),
    );
  }
}

/// Capa del shell de escritorio. No pinta nada mientras el recorrido está quieto.
class ImporterWebTourLayer extends StatelessWidget {
  const ImporterWebTourLayer({
    super.key,
    required this.child,
    this.viewToken = 0,
  });

  final Widget child;

  /// Cambia cuando el shell de escritorio muestra otra página.
  final int viewToken;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ImporterWebInduction.listenable,
      builder: (context, child) {
        final desktop =
            MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;
        if (!ImporterWebInduction.isActive || !desktop) return child!;
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification ||
                notification is ScrollEndNotification) {
              _ImporterTourController.instance._queueRefresh();
            }
            return false;
          },
          child: Stack(
            children: [
              child!,
              Positioned.fill(
                child: _ImporterTourOverlay(viewToken: viewToken),
              ),
            ],
          ),
        );
      },
      child: child,
    );
  }
}

class _TourStep {
  const _TourStep({
    required this.title,
    required this.body,
    required this.targets,
    this.advanceOnTarget = true,
  });

  final String title;
  final String body;
  final List<ImporterTourTarget> targets;

  /// Si es falso, el toque abre el control y el paso sigue hasta pulsar Siguiente.
  final bool advanceOnTarget;
}

class _AnchorRef {
  _AnchorRef(this.key, this.priority);

  final GlobalKey key;
  final int priority;
}

enum _TourScript { welcome, orders, inventory }

class _ImporterTourController extends ChangeNotifier {
  _ImporterTourController._();

  static final instance = _ImporterTourController._();

  static const _welcomeSteps = <_TourStep>[
    _TourStep(
      title: 'Opciones de inicio',
      targets: [
        ImporterTourTarget.homePriorities,
        ImporterTourTarget.navHome,
      ],
      body:
          'En Inicio está lo urgente: pedidos por confirmar, comisiones por pagar '
          'y la salud del inventario. Toca una tarjeta para abrir esa sección.',
    ),
    _TourStep(
      title: 'Disponibilidad del producto',
      targets: [
        ImporterTourTarget.inventoryAvailability,
        ImporterTourTarget.inventoryTools,
        ImporterTourTarget.navInventory,
      ],
      body:
          'Toca el interruptor Publicado o Pausado para decidir si la tienda ve ese producto. '
          'Si todavía no hay productos, abre Herramientas y elige Publicar o pausar varios.',
    ),
    _TourStep(
      title: 'Carga masiva',
      advanceOnTarget: false,
      targets: [
        ImporterTourTarget.inventoryTools,
        ImporterTourTarget.navInventory,
      ],
      body:
          'Abre Herramientas y elige Importar Excel, CSV o PDF. '
          'Ahí cargas el catálogo de una vez. Este paso espera a que pulses Siguiente.',
    ),
    _TourStep(
      title: 'Acciones del pedido',
      targets: [
        ImporterTourTarget.orderActions,
        ImporterTourTarget.navOrders,
      ],
      body:
          'En la ficha del pedido avanza el estado o usa Proponer ajuste de cantidad '
          'cuando el mínimo de tu producto no coincide con lo pedido.',
    ),
    _TourStep(
      title: 'Chat y notificaciones',
      targets: [
        ImporterTourTarget.orderChat,
        ImporterTourTarget.notifications,
      ],
      body:
          'Abre el chat del pedido: ahí se ve el nombre de tu negocio. '
          'La campana abre cada aviso en la vista que le corresponde.',
    ),
    _TourStep(
      title: 'Valoraciones',
      targets: [
        ImporterTourTarget.reputationSummary,
        ImporterTourTarget.navReputation,
      ],
      body:
          'En Reputación ves la nota que te dan las tiendas. '
          'Cuando un pedido se entrega, también puedes valorar a la tienda minorista desde la ficha.',
    ),
    _TourStep(
      title: 'Datos del perfil',
      advanceOnTarget: false,
      targets: [
        ImporterTourTarget.profileData,
        ImporterTourTarget.navProfile,
      ],
      body:
          'En Datos del perfil cambias el nombre comercial, el teléfono, el RIF y la dirección. '
          'Eso es lo que ven las tiendas. En Seguridad, al lado, cambias la contraseña.',
    ),
    _TourStep(
      title: 'Condiciones mínimas',
      advanceOnTarget: false,
      targets: [
        ImporterTourTarget.commercialSettings,
        ImporterTourTarget.navProfile,
      ],
      body:
          'En Perfil, Configuración comercial es donde defines el monto y las '
          'unidades mínimas de cada pedido.',
    ),
    _TourStep(
      title: 'Alertas y notificaciones',
      advanceOnTarget: false,
      targets: [
        ImporterTourTarget.profileAlerts,
      ],
      body:
          'En Alertas hay dos grupos. En la plataforma: pedidos de tiendas, '
          'recordatorios de documentos y mensajes en el chat. '
          'Fuera de la página: Activar en este navegador, para avisos aunque la pestaña esté atrás.',
    ),
  ];

  static const _firstOrderSteps = <_TourStep>[
    _TourStep(
      title: 'Pedido por confirmar',
      targets: [
        ImporterTourTarget.pendingOrder,
        ImporterTourTarget.navOrders,
      ],
      body:
          'Una tienda te hizo un pedido. La fila muestra el producto, la tienda y el total. '
          'Ábrela para gestionarlo.',
    ),
    _TourStep(
      title: 'Confirmar el pedido',
      advanceOnTarget: false,
      targets: [
        ImporterTourTarget.orderAdvance,
        ImporterTourTarget.orderActions,
        ImporterTourTarget.navOrders,
      ],
      body:
          'En la ficha, el botón de estado confirma el pedido y lo pasa a preparación o despacho. '
          'Revisa la tienda y el total antes de pulsarlo. Este paso sigue con Siguiente.',
    ),
    _TourStep(
      title: 'Ajustar la cantidad',
      advanceOnTarget: false,
      targets: [
        ImporterTourTarget.orderQty,
      ],
      body:
          'Si lo pedido no llega al mínimo de tu producto, usa Proponer ajuste de cantidad. '
          'La tienda acepta o rechaza el cambio antes del despacho. '
          'Si el botón no está, la cantidad ya es válida y puedes seguir.',
    ),
    _TourStep(
      title: 'Hablar con la tienda',
      advanceOnTarget: false,
      targets: [
        ImporterTourTarget.orderChat,
        ImporterTourTarget.notifications,
      ],
      body:
          'El chat del pedido muestra el nombre de tu negocio. '
          'Úsalo para acordar la entrega o resolver una duda de la tienda.',
    ),
  ];

  static const _inventorySteps = <_TourStep>[
    _TourStep(
      title: 'Disponibilidad del producto',
      targets: [
        ImporterTourTarget.inventoryAvailability,
        ImporterTourTarget.inventoryTools,
        ImporterTourTarget.navInventory,
      ],
      body:
          'Toca el interruptor Publicado o Pausado para decidir si la tienda ve ese producto. '
          'Si todavía no hay productos, abre Herramientas y elige Publicar o pausar varios.',
    ),
    _TourStep(
      title: 'Carga masiva',
      advanceOnTarget: false,
      targets: [
        ImporterTourTarget.inventoryTools,
        ImporterTourTarget.navInventory,
      ],
      body:
          'Abre Herramientas y elige Importar Excel, CSV o PDF. '
          'Ahí cargas el catálogo de una vez. Este paso espera a que pulses Siguiente.',
    ),
  ];

  final Map<ImporterTourTarget, List<_AnchorRef>> _anchors = {};
  Completer<void>? _session;
  String profileId = '';
  int index = 0;
  bool active = false;
  bool queueFirstOrder = false;
  _TourScript _script = _TourScript.welcome;

  /// El recorrido automático del primer pedido sí se recuerda. El botón no.
  bool _rememberOrders = false;
  DateTime? _lastAdvance;
  VoidCallback? layoutTick;
  int? _snappedIndex;
  bool _commercialKnown = false;
  bool _hasMinAmount = false;
  bool _hasMinUnits = false;
  int _commercialToken = 0;

  bool get commercialKnown => _commercialKnown;

  bool get commercialNeedsSetup =>
      _commercialKnown && (!_hasMinAmount || !_hasMinUnits);

  String get commercialBody {
    if (!_commercialKnown) {
      return 'En Perfil, Configuración comercial es donde defines el monto '
          'y las unidades mínimas de cada pedido.';
    }
    if (!_hasMinAmount && !_hasMinUnits) {
      return 'Aún no tienes montos ni cantidades mínimas. No se aplica ningún '
          'piso hasta que los guardes.';
    }
    if (!_hasMinAmount) {
      return 'Ya tienes cantidades mínimas, pero aún no un monto. '
          'No hay un monto por defecto hasta que lo registres.';
    }
    if (!_hasMinUnits) {
      return 'Ya tienes un monto mínimo, pero aún no cantidades. '
          'No hay un mínimo de unidades por defecto hasta que lo registres.';
    }
    return 'Tus condiciones ya están guardadas. En Configuración comercial '
        'puedes revisarlas o actualizarlas cuando quieras.';
  }

  Future<void> refreshCommercialState() async {
    final token = ++_commercialToken;
    try {
      final profile = await SupabaseService.fetchMyProfile();
      if (token != _commercialToken) return;
      final units = profile?.minOrderUnits;
      final amount = profile?.hasMinOrderAmount == true;
      final hasUnits = units != null && units >= 1;
      if (_commercialKnown &&
          _hasMinAmount == amount &&
          _hasMinUnits == hasUnits) {
        return;
      }
      _commercialKnown = true;
      _hasMinAmount = amount;
      _hasMinUnits = hasUnits;
      if (active) notifyListeners();
    } catch (_) {}
  }

  List<_TourStep> get steps => switch (_script) {
        _TourScript.welcome => _welcomeSteps,
        _TourScript.orders => _firstOrderSteps,
        _TourScript.inventory => _inventorySteps,
      };

  bool get wantsOrderDetail => active &&
      switch (_script) {
        _TourScript.orders => index > 0,
        _TourScript.welcome => index == 3 || index == 4,
        _TourScript.inventory => false,
      };

  _TourStep get step => steps[index];

  Future<void> startWelcome(String id) {
    _script = _TourScript.welcome;
    _rememberOrders = false;
    return _begin(id);
  }

  Future<void> startFirstOrder(String id) {
    _script = _TourScript.orders;
    _rememberOrders = true;
    queueFirstOrder = false;
    return _begin(id);
  }

  Future<void> startOrders() {
    _script = _TourScript.orders;
    _rememberOrders = false;
    return _begin(profileId);
  }

  Future<void> startInventory() {
    _script = _TourScript.inventory;
    _rememberOrders = false;
    return _begin(profileId);
  }

  Future<void> _begin(String id) {
    final trimmed = id.trim();
    if (trimmed.isNotEmpty) profileId = trimmed;
    final previous = _session;
    _session = Completer<void>();
    if (previous != null && !previous.isCompleted) previous.complete();
    active = true;
    index = 0;
    _snappedIndex = null;
    _openSection();
    notifyListeners();
    return _session!.future;
  }

  void register(ImporterTourTarget target, GlobalKey key, {int priority = 0}) {
    final list = _anchors.putIfAbsent(target, () => []);
    list.removeWhere((anchor) => anchor.key == key);
    list.add(_AnchorRef(key, priority));
    list.sort((a, b) => b.priority.compareTo(a.priority));
    if (active && step.targets.contains(target)) _queueRefresh();
  }

  void unregister(ImporterTourTarget target, GlobalKey key) {
    final list = _anchors[target];
    if (list == null) return;
    list.removeWhere((anchor) => anchor.key == key);
    if (list.isEmpty) _anchors.remove(target);
    if (active && step.targets.contains(target)) _queueRefresh();
  }

  /// initState de un ancla puede correr durante el layout. Solo pide
  /// otra medición; no anima el scroll ni rearma la tarjeta.
  void _queueRefresh() => layoutTick?.call();

  void advanceFromTarget(ImporterTourTarget target) {
    if (!active || !step.targets.contains(target) || !step.advanceOnTarget) {
      return;
    }
    final now = DateTime.now();
    if (_lastAdvance != null &&
        now.difference(_lastAdvance!) < const Duration(milliseconds: 400)) {
      return;
    }
    _lastAdvance = now;
    if (index >= steps.length - 1) {
      unawaited(_close(skipped: false));
    } else {
      _move(index + 1);
    }
  }

  void next() {
    if (index >= steps.length - 1) {
      unawaited(_close(skipped: false));
    } else {
      _move(index + 1);
    }
  }

  void previous() {
    if (index == 0) return;
    _move(index - 1);
  }

  void skip() => unawaited(_close(skipped: true));

  void _move(int nextIndex) {
    index = nextIndex;
    _snappedIndex = null;
    _openSection();
    notifyListeners();
  }

  /// Si el usuario cambió de pestaña, vuelve una vez a la vista de este paso.
  /// No insiste: si el control sigue sin pintarse, la tarjeta queda sola.
  void realignSection() {
    if (!active || _snappedIndex == index) return;
    final primary = step.targets.isEmpty ? null : step.targets.first;
    if (primary != null && _contextFor(primary) != null) return;
    _snappedIndex = index;
    _openSection();
  }

  void _openSection() {
    switch (_script) {
      case _TourScript.orders:
        MainShellTabController.navigateToPedidosTab();
        return;
      case _TourScript.inventory:
        MainShellTabController.navigateToImporterInventory();
        return;
      case _TourScript.welcome:
        break;
    }
    switch (index) {
      case 0:
        MainShellTabController.navigateToHomeTab();
      case 1:
      case 2:
        MainShellTabController.navigateToImporterInventory();
      case 5:
        MainShellTabController.navigateToReputationTab();
      case 6:
      case 7:
        MainShellTabController.navigateToAliadoProfileSubTab(0);
        if (index == 7) unawaited(refreshCommercialState());
      case 8:
        MainShellTabController.navigateToAliadoProfileSubTab(1);
      default:
        MainShellTabController.navigateToPedidosTab();
    }
  }

  Future<void> _close({required bool skipped}) async {
    if (!active) return;
    final script = _script;
    final rememberOrders = _rememberOrders;
    final queued = queueFirstOrder && script == _TourScript.welcome;
    active = false;
    queueFirstOrder = false;
    _script = _TourScript.welcome;
    _rememberOrders = false;
    notifyListeners();
    if (script == _TourScript.welcome ||
        (script == _TourScript.orders && rememberOrders)) {
      await ImporterWebInduction.markDismissed(
        profileId,
        skipped: skipped,
        firstOrder: script == _TourScript.orders,
      );
    }
    final session = _session;
    _session = null;
    if (session != null && !session.isCompleted) session.complete();
    if (!queued || profileId.isEmpty) return;
    if (await ImporterWebInduction._isFlagDismissed(
      ImporterWebInduction._firstOrderKey(profileId),
    )) {
      return;
    }
    await startFirstOrder(profileId);
  }

  ImporterTourTarget? focusedTarget() {
    for (final target in step.targets) {
      if (_contextFor(target) != null) return target;
    }
    return null;
  }

  BuildContext? _contextFor(ImporterTourTarget target) {
    for (final anchor in _anchors[target] ?? const <_AnchorRef>[]) {
      final ctx = anchor.key.currentContext;
      if (ctx != null && ctx.mounted && _isOnScreen(ctx)) return ctx;
    }
    return null;
  }

  bool _isOnScreen(BuildContext ctx) {
    final box = _boxOf(ctx);
    if (box == null) return false;
    try {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final screen = Offset.zero & MediaQuery.sizeOf(ctx);
      final visible = rect.intersect(screen);
      if (visible.width < 8 || visible.height < 8) return false;
      if (!_boxIsPainted(box)) return false;
      var hidden = false;
      ctx.visitAncestorElements((element) {
        final widget = element.widget;
        if (widget is Offstage && widget.offstage) {
          hidden = true;
          return false;
        }
        if (widget is Visibility && !widget.visible) {
          hidden = true;
          return false;
        }
        return true;
      });
      return !hidden;
    } catch (_) {
      return false;
    }
  }

  /// [IndexedStack] mantiene el tamaño de las páginas ocultas en el mismo
  /// sitio. Su rectángulo global pisa la vista visible y el recorte sale
  /// blanco. Solo vale el hijo que el stack está pintando.
  bool _boxIsPainted(RenderBox box) {
    RenderObject? node = box;
    while (node != null) {
      final parent = node.parent;
      if (parent is RenderOffstage && parent.offstage) return false;
      if (parent is RenderIndexedStack) {
        final shown = _indexedChild(parent);
        RenderObject? direct = node;
        while (direct != null && direct.parent != parent) {
          direct = direct.parent;
        }
        if (direct == null || !identical(direct, shown)) return false;
      }
      node = parent;
    }
    return true;
  }

  RenderBox? _indexedChild(RenderIndexedStack stack) {
    final index = stack.index;
    if (index == null || index < 0) return null;
    RenderBox? child = stack.firstChild;
    for (var i = 0; i < index; i++) {
      if (child == null) return null;
      child = stack.childAfter(child);
    }
    return child;
  }

  /// Un elemento desactivado sigue contando como mounted, pero
  /// findRenderObject lanza si se consulta durante el layout.
  RenderBox? _boxOf(BuildContext ctx) {
    if (!ctx.mounted) return null;
    try {
      final object = ctx.findRenderObject();
      if (object is! RenderBox || !object.attached || !object.hasSize) {
        return null;
      }
      if (object.size.isEmpty) return null;
      return object;
    } catch (_) {
      return null;
    }
  }

  Rect? targetRect() {
    final target = focusedTarget();
    if (target == null) return null;
    final ctx = _contextFor(target);
    if (ctx == null) return null;
    final box = _boxOf(ctx);
    if (box == null) return null;
    try {
      return box.localToGlobal(Offset.zero) & box.size;
    } catch (_) {
      return null;
    }
  }
}

class _ImporterTourOverlay extends StatefulWidget {
  const _ImporterTourOverlay({required this.viewToken});

  final int viewToken;

  @override
  State<_ImporterTourOverlay> createState() => _ImporterTourOverlayState();
}

class _ImporterTourOverlayState extends State<_ImporterTourOverlay>
    with WidgetsBindingObserver {
  Rect? _hole;
  int _step = -1;
  bool _measureQueued = false;
  bool _retried = false;

  Future<void> _openCommercialSettings() async {
    final profile = await SupabaseService.fetchMyProfile();
    if (!mounted || profile == null) return;
    await ImporterCommercialSettings.openDesktop(
      context,
      profile: profile,
      onChanged: () {
        _ImporterTourController.instance.refreshCommercialState();
      },
    );
    await _ImporterTourController.instance.refreshCommercialState();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _step = _ImporterTourController.instance.index;
    _ImporterTourController.instance.layoutTick = _measure;
    _measure();
  }

  @override
  void didUpdateWidget(covariant _ImporterTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tour = _ImporterTourController.instance;
    final step = tour.index;
    final viewChanged = widget.viewToken != oldWidget.viewToken;
    if (step != _step || viewChanged) {
      _step = step;
      _hole = null;
      _retried = false;
    }
    if (viewChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        tour.realignSection();
      });
    }
    _measure();
  }

  @override
  void dispose() {
    if (_ImporterTourController.instance.layoutTick == _measure) {
      _ImporterTourController.instance.layoutTick = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => _measure();

  /// Un frame después del layout. Si el ancla acaba de montarse, un
  /// segundo frame y nada más.
  void _measure() {
    if (_measureQueued) return;
    _measureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureQueued = false;
      if (!mounted) return;
      final next = _holeInOverlay();
      if (next == null && !_retried) {
        _retried = true;
        _measure();
        return;
      }
      _retried = false;
      if (next != _hole) setState(() => _hole = next);
    });
  }

  Rect? _holeInOverlay() {
    final overlay = context.findRenderObject();
    if (overlay is! RenderBox || !overlay.attached || !overlay.hasSize) {
      return null;
    }
    final global = _ImporterTourController.instance.targetRect();
    if (global == null) return null;
    final topLeft = overlay.globalToLocal(global.topLeft);
    final bottomRight = overlay.globalToLocal(global.bottomRight);
    final local = Rect.fromPoints(topLeft, bottomRight).inflate(6);
    const margin = 10.0;
    if (!local.width.isFinite ||
        !local.height.isFinite ||
        local.width < 20 ||
        local.height < 20) {
      return null;
    }
    // Un control no ocupa casi toda la ventana. Eso es una página oculta
    // cuyo rectángulo cayó encima de la vista actual.
    if (local.width > overlay.size.width * 0.72 &&
        local.height > overlay.size.height * 0.58) {
      return null;
    }
    if (overlay.size.width <= margin * 2 || overlay.size.height <= margin * 2) {
      return null;
    }
    final bounds = Rect.fromLTRB(
      margin,
      margin,
      overlay.size.width - margin,
      overlay.size.height - margin,
    );
    final visible = local.intersect(bounds);
    if (visible.width < 20 || visible.height < 20) return null;
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final tour = _ImporterTourController.instance;
    final theme = B2BThemeExtension.of(context);
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final hole = _hole;
        final card = _cardPosition(size, hole);
        final scrim = theme.textPrimary.withOpacity(0.46);
        final radius = hole == null
            ? 16.0
            : math.min(16.0, math.min(hole.width, hole.height) / 2);
        final last = tour.index == tour.steps.length - 1;
        final focused = tour.focusedTarget();
        return Stack(
          children: [
            Positioned.fill(
              child: _TourScrim(hole: hole, color: scrim, radius: radius),
            ),
            if (hole != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _TourArrowPainter(
                      from: _clampToSize(_edgeToward(card, hole.center), size),
                      to: _clampToSize(hole.center, size),
                      color: theme.brand,
                      halo: theme.dialogSurface,
                    ),
                  ),
                ),
              ),
            if (hole != null)
              Positioned(
                left: hole.left,
                top: hole.top,
                width: hole.width,
                height: hole.height,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(color: theme.brand, width: 2),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: card.left,
              top: card.top,
              width: card.width,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.max(160, size.height - card.top - 12),
                ),
                child: Material(
                color: theme.dialogSurface,
                elevation: 8,
                clipBehavior: Clip.antiAlias,
                shadowColor: theme.textPrimary.withOpacity(0.18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.border),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Paso ${tour.index + 1} de ${tour.steps.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.textSecondary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: tour.skip,
                            style: TextButton.styleFrom(
                              foregroundColor: theme.textSecondary,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text(
                              'Saltar',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          for (var i = 0;
                              i < tour.steps.length;
                              i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: i <= tour.index
                                      ? theme.brand
                                      : theme.borderSubtle,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tour.step.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (tour.step.targets
                          .contains(ImporterTourTarget.commercialSettings)) ...[
                        if (tour.commercialKnown)
                          Text(
                            tour.commercialNeedsSetup
                                ? 'Aún no están configuradas'
                                : 'Ya puedes revisarlas aquí',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: tour.commercialNeedsSetup
                                  ? theme.textPrimary
                                  : theme.successFg,
                            ),
                          ),
                        if (tour.commercialKnown) const SizedBox(height: 4),
                        Text(
                          tour.commercialBody,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: theme.textSecondary,
                          ),
                        ),
                        if (tour.commercialNeedsSetup)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _openCommercialSettings,
                              style: TextButton.styleFrom(
                                foregroundColor: theme.brand,
                                visualDensity: VisualDensity.compact,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 0),
                              ),
                              child: const Text(
                                'Registrar condiciones',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                      ] else
                        Text(
                          tour.step.body,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: theme.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        _cue(focused),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (tour.index > 0)
                            OutlinedButton(
                              onPressed: tour.previous,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.textPrimary,
                                side: BorderSide(color: theme.borderStrong),
                                minimumSize: const Size(0, 36),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('Anterior'),
                            ),
                          const Spacer(),
                          FilledButton(
                            onPressed: tour.next,
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.brand,
                              foregroundColor: onBrand,
                              minimumSize: const Size(108, 36),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(
                              last ? 'Listo' : 'Siguiente',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ],
        );
      },
    );
  }

  String _cue(ImporterTourTarget? target) {
    return switch (target) {
      ImporterTourTarget.navHome =>
        'La flecha señala Inicio en el menú. Ábrelo o pulsa Siguiente.',
      ImporterTourTarget.navInventory =>
        'La flecha señala Inventario en el menú. Ábrelo o pulsa Siguiente.',
      ImporterTourTarget.navOrders =>
        'La flecha señala Pedidos en el menú. Ábrelo o pulsa Siguiente.',
      ImporterTourTarget.navReputation =>
        'La flecha señala Reputación en el menú. Ábrela o pulsa Siguiente.',
      ImporterTourTarget.inventoryTools =>
        _ImporterTourController.instance.step.advanceOnTarget
            ? 'La flecha señala Herramientas. Ahí publicas o pausas varios productos.'
            : 'La flecha señala Herramientas. Ahí está Importar Excel, CSV o PDF.',
      ImporterTourTarget.profileData =>
        'Aquí están los datos que ven las tiendas. El paso sigue hasta Siguiente.',
      ImporterTourTarget.profileAlerts =>
        'Estas son las notificaciones: en el panel y en el navegador. El paso sigue hasta Siguiente.',
      ImporterTourTarget.navProfile =>
        'La flecha señala tu cuenta, abajo en el menú. Ábrela o pulsa Siguiente.',
      ImporterTourTarget.pendingOrder =>
        'La flecha señala el pedido por confirmar. Ábrelo o pulsa Siguiente.',
      ImporterTourTarget.orderAdvance =>
        'La flecha señala el botón que confirma el pedido. El paso sigue hasta Siguiente.',
      ImporterTourTarget.orderQty =>
        'La flecha señala Proponer ajuste de cantidad. El paso sigue hasta Siguiente.',
      ImporterTourTarget.notifications =>
        'La flecha señala la campana de notificaciones.',
      null => 'Puedes seguir con Siguiente si el acceso aún no está a la vista.',
      _ => 'La flecha señala el control. Tócalo o usa Siguiente.',
    };
  }

  Offset _clampToSize(Offset point, Size size) {
    return Offset(
      point.dx.clamp(8.0, math.max(8.0, size.width - 8)),
      point.dy.clamp(8.0, math.max(8.0, size.height - 8)),
    );
  }

  Offset _edgeToward(Rect card, Offset target) {
    final center = card.center;
    final delta = target - center;
    if (delta.distance < 1) return center;
    final scaleX = delta.dx == 0 ? double.infinity : (card.width / 2) / delta.dx.abs();
    final scaleY = delta.dy == 0 ? double.infinity : (card.height / 2) / delta.dy.abs();
    final scale = scaleX < scaleY ? scaleX : scaleY;
    return center + delta * scale;
  }

  Rect _cardPosition(Size size, Rect? hole) {
    const width = 320.0;
    const height = 360.0;
    final maxLeft = math.max(12.0, size.width - width - 12);
    final maxTop = math.max(12.0, size.height - height - 12);

    Rect place(double left, double top) {
      return Rect.fromLTWH(
        left.clamp(12.0, maxLeft),
        top.clamp(12.0, maxTop),
        width,
        height,
      );
    }

    if (hole == null) {
      return place(maxLeft, (size.height - height) / 2);
    }

    final candidates = <Rect>[
      place(hole.right + 16, hole.top),
      place(hole.left - width - 16, hole.top),
      place(12, maxTop),
      place(maxLeft, maxTop),
    ];
    for (final candidate in candidates) {
      final gap = candidate.inflate(8);
      if (!gap.overlaps(hole) &&
          candidate.right <= size.width - 8 &&
          candidate.bottom <= size.height - 8) {
        return candidate;
      }
    }
    return candidates.last;
  }

}

class _TourScrim extends LeafRenderObjectWidget {
  const _TourScrim({
    required this.hole,
    required this.color,
    required this.radius,
  });

  final Rect? hole;
  final Color color;
  final double radius;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderTourScrim(hole: hole, color: color, radius: radius);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderTourScrim renderObject) {
    renderObject
      ..hole = hole
      ..color = color
      ..radius = radius;
  }
}

class _RenderTourScrim extends RenderBox {
  _RenderTourScrim({
    required Rect? hole,
    required Color color,
    required double radius,
  })  : _hole = hole,
        _color = color,
        _radius = radius;

  Rect? _hole;
  Color _color;
  double _radius;

  set hole(Rect? value) {
    if (_hole == value) return;
    _hole = value;
    markNeedsPaint();
  }

  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  set radius(double value) {
    if (_radius == value) return;
    _radius = value;
    markNeedsPaint();
  }

  RRect? get _holeShape {
    final hole = _hole;
    if (hole == null || hole.isEmpty) return null;
    final cap = math.min(hole.width, hole.height) / 2;
    final radius = _radius < cap ? _radius : cap;
    return RRect.fromRectAndRadius(hole, Radius.circular(radius));
  }

  @override
  void performLayout() {
    size = constraints.biggest;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final shape = _holeShape;
    if (shape != null && shape.contains(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final path = Path()..addRect(offset & size);
    final shape = _holeShape?.shift(offset);
    if (shape != null) {
      path
        ..addRRect(shape)
        ..fillType = PathFillType.evenOdd;
    }
    context.canvas.drawPath(path, Paint()..color = _color);
  }
}

class _TourArrowPainter extends CustomPainter {
  const _TourArrowPainter({
    required this.from,
    required this.to,
    required this.color,
    required this.halo,
  });

  final Offset from;
  final Offset to;
  final Color color;
  final Color halo;

  @override
  void paint(Canvas canvas, Size size) {
    final delta = to - from;
    if (delta.distance < 8) return;
    final end = to - delta / delta.distance * 10;
    final haloPaint = Paint()
      ..color = halo
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(from, end, haloPaint);
    canvas.drawLine(from, end, line);
    final angle = delta.direction;
    final head = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - 12 * math.cos(angle - 0.45),
        to.dy - 12 * math.sin(angle - 0.45),
      )
      ..lineTo(
        to.dx - 12 * math.cos(angle + 0.45),
        to.dy - 12 * math.sin(angle + 0.45),
      )
      ..close();
    canvas.drawPath(head, Paint()..color = halo);
    canvas.drawPath(head, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TourArrowPainter oldDelegate) {
    return from != oldDelegate.from ||
        to != oldDelegate.to ||
        color != oldDelegate.color ||
        halo != oldDelegate.halo;
  }
}
