import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/receipt_template.dart';

class ReceiptTemplateNotifier extends StateNotifier<List<ReceiptTemplate>> {
  ReceiptTemplateNotifier() : super([]);

  Future<void> loadTemplates() async {
    try {
      // This would typically load from database
      // For now, we'll start with a default template
      state = [ReceiptTemplate.getDefault()];
    } catch (e) {
      // Handle error
      state = [ReceiptTemplate.getDefault()];
    }
  }

  Future<void> addTemplate(ReceiptTemplate template) async {
    try {
      final newTemplate = template.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      state = [...state, newTemplate];
    } catch (e) {
      // Handle error
    }
  }

  Future<void> updateTemplate(ReceiptTemplate template) async {
    try {
      final updatedTemplate = template.copyWith(updatedAt: DateTime.now());
      state =
          state.map((t) => t.id == template.id ? updatedTemplate : t).toList();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    try {
      state = state.where((t) => t.id != templateId).toList();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> setDefaultTemplate(String templateId) async {
    try {
      state = state
          .map((t) => t.copyWith(
                isDefault: t.id == templateId,
              ))
          .toList();
    } catch (e) {
      // Handle error
    }
  }
}

final receiptTemplateProvider =
    StateNotifierProvider<ReceiptTemplateNotifier, List<ReceiptTemplate>>(
        (ref) {
  final notifier = ReceiptTemplateNotifier();
  notifier.loadTemplates();
  return notifier;
});

final currentReceiptTemplateProvider = Provider<ReceiptTemplate>((ref) {
  final templates = ref.watch(receiptTemplateProvider);
  final defaultTemplate = templates.firstWhere(
    (t) => t.isDefault,
    orElse: () =>
        templates.isNotEmpty ? templates.first : ReceiptTemplate.getDefault(),
  );
  return defaultTemplate;
});
