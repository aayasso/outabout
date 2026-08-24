// The three calls that reach the home-screen widget, behind an interface.
//
// `home_widget` talks over a platform channel, which cannot run in a Flutter
// unit test and would make every test in `widget_providers_test.dart` require
// a simulator. The interface is the seam: production wires the real one, tests
// record what would have crossed.
//
// It is also where the App Group id lives, which is the one piece of this
// feature that cannot work until the Apple Developer account clears. Keeping
// it behind one type means the failure has exactly one place to surface.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

/// The App Group shared by the app and the widget extension.
///
/// Must match `com.apple.security.application-groups` in both
/// `ios/Runner/Runner.entitlements` and
/// `ios/OutaboutWidget/OutaboutWidget.entitlements`, and the group registered
/// on the Apple Developer portal. A mismatch is silent: the write succeeds
/// into a container the widget cannot see, and the widget shows its empty
/// state forever.
const String widgetAppGroupId = 'group.com.outabout.outabout';

/// The key the payload is stored under, read by `WidgetPayload.load()` in Swift.
const String widgetPayloadKey = 'outabout_widget_payload';

/// The WidgetKit widget's `kind`, matching `OutaboutWidget.kind` in Swift.
const String widgetKind = 'OutaboutWidget';

abstract interface class HomeWidgetGateway {
  /// Writes [payload] into the shared store.
  Future<void> save(String payload);

  /// Asks WidgetKit to re-render. Always after [save].
  Future<void> reload();
}

class RealHomeWidgetGateway implements HomeWidgetGateway {
  const RealHomeWidgetGateway();

  @override
  Future<void> save(String payload) async {
    await HomeWidget.saveWidgetData<String>(widgetPayloadKey, payload);
  }

  @override
  Future<void> reload() async {
    await HomeWidget.updateWidget(iOSName: widgetKind);
  }
}

final homeWidgetGatewayProvider = Provider<HomeWidgetGateway>(
  (ref) => const RealHomeWidgetGateway(),
);

/// Points `home_widget` at the App Group. Call once, before any save.
///
/// Failure is swallowed and logged: on a build with no App Group entitlement —
/// every simulator build until the developer account clears — this throws, and
/// a widget that cannot be fed is not a reason to stop the app launching.
Future<void> initialiseHomeWidget() async {
  try {
    await HomeWidget.setAppGroupId(widgetAppGroupId);
  } catch (e) {
    debugPrint('initialiseHomeWidget: app group unavailable — $e');
  }
}
