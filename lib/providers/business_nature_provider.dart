import 'package:flutter_riverpod/flutter_riverpod.dart';

final businessNatureProvider =
    StateNotifierProvider<BusinessNatureNotifier, String>((ref) {
  return BusinessNatureNotifier();
});

class BusinessNatureNotifier extends StateNotifier<String> {
  BusinessNatureNotifier() : super('retail');

  bool get isRetail => true;
}
