import 'package:flutter/material.dart';

/// Disabled v1 payment compatibility service.
///
/// This class intentionally performs no checkout, simulation, entitlement
/// grant, or network call. It remains as a compile-safe seam for a future v2
/// Stripe/UPI implementation without leaving the previous provider active.
@Deprecated('Payments are disabled until the v2 payment redesign.')
class Payments {
  Payments._();

  static final Payments instance = Payments._();
  static const bool live = false;

  Future<void> buyPro(
    BuildContext context, {
    required int days,
    required int rupees,
    required void Function(bool ok, String msg) onDone,
  }) async {
    onDone(
      false,
      'Payments and subscriptions are not available in this version.',
    );
  }
}
