// Turning a widget tap back into a screen.
//
// A tap on the widget opens `outabout://schedule`. iOS delivers that URL two
// different ways depending on whether the app was already running, and
// `home_widget` exposes both: `initiallyLaunchedFromHomeWidget()` for a cold
// start, and the `widgetClicked` stream for a warm one. On some cold starts
// the same tap arrives through *both*, which is the hazard this file exists
// to handle — a double-counted `app_opened_from_widget` would inflate the one
// number the widget is measured by.
//
// Pure and injected rather than reaching for the router directly, on the model
// of `NotificationOpenTracker`: the routing decision and the deduplication are
// the parts worth testing, and neither needs a platform channel.

import '../../core/router.dart';

/// The URL scheme the widget links to. Declared in `CFBundleURLTypes` in
/// `ios/Runner/Info.plist`, and used by `widgetURL` in `OutaboutWidget.swift`.
const String widgetUriScheme = 'outabout';

/// The one destination the widget offers.
const String widgetScheduleHost = 'schedule';

/// The event logged when a widget tap brought the app to the foreground.
const String widgetOpenEvent = 'app_opened_from_widget';

/// The route [uri] asks for, or null if it is not one of ours.
///
/// Null rather than a default route: a URI with our scheme but an unknown host
/// comes from a build that is not this one — a newer widget, or something else
/// entirely — and guessing that it meant the schedule would send the user
/// somewhere they did not ask for.
String? routeForWidgetUri(Uri? uri) {
  if (uri == null) return null;
  if (uri.scheme != widgetUriScheme) return null;
  if (uri.host != widgetScheduleHost) return null;
  return AppRoutes.home;
}

/// Routes widget taps, counting each one exactly once.
class WidgetLaunchCoordinator {
  WidgetLaunchCoordinator({required this.onRoute, required this.onOpened});

  /// Navigates. Separated from the coordinator so tests need no GoRouter.
  final void Function(String route) onRoute;

  /// Logs the open. Fires only for taps that actually routed.
  final void Function() onOpened;

  Uri? _launchUri;
  bool _sawFirstClick = false;

  /// Handles the URL the app was launched with, if any.
  bool handleLaunch(Uri? uri) {
    final route = routeForWidgetUri(uri);
    if (route == null) return false;
    _launchUri = uri;
    onRoute(route);
    onOpened();
    return true;
  }

  /// Handles a tap delivered while the app was already alive.
  ///
  /// The first stream event after a cold start is dropped when it repeats the
  /// launch URL, because that is the same physical tap arriving twice. Only
  /// the *first* is checked: a genuine second tap on the same widget produces
  /// an identical URL, and suppressing that would make the widget feel broken.
  bool handleClick(Uri? uri) {
    if (!_sawFirstClick) {
      _sawFirstClick = true;
      if (uri != null && uri == _launchUri) return false;
    }
    final route = routeForWidgetUri(uri);
    if (route == null) return false;
    onRoute(route);
    onOpened();
    return true;
  }
}
