import 'package:flutter/material.dart';

/// Shared navigator observer used by [RouteAware] screens that need a
/// "returned to me" hook. Wired into the [GoRouter] observers list in
/// `app_router.dart` so sub-screens (e.g. the order-create screen reloading
/// the draft when the item picker pops) can subscribe to it.
final RouteObserver<Route<dynamic>> routeObserver =
    RouteObserver<Route<dynamic>>();