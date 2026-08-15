import '../providers/language_provider.dart';
import '../../features/pos/models/modifier_models.dart';
import '../../features/pos/models/product_models.dart';
import '../../features/pos/models/receipt_models.dart';

/// Ported from `frontend-flutter-pos/lib/core/utils/bilingual.dart` —
/// PARTIAL PORT. `ReceiptLineBilingualName` added Day 12, now that
/// `receipt_models.dart` exists and `receipt_view_model.dart` needs it.
/// Source's `CustomerBilingualName` is still not ported — `customer_models
/// .dart` exists (Day 9), but nothing in this port calls `Customer.
/// localizedName`; `customer_picker_screen.dart` uses `resolvedDisplayName`
/// directly instead. Add it when/if something actually needs it — never
/// speculatively. `ModifierGroupResponse`/`ModifierOptionResponse` were
/// added Day 7 for `product_modifier_sheet.dart`.
///
/// `resolveBilingual` itself is COPY/ADAPT NEARLY EXACTLY (byte-identical
/// logic, no platform dependency).
String resolveBilingual({
  required String en,
  String? km,
  required AppLanguage language,
}) {
  if (language == AppLanguage.km && km != null && km.trim().isNotEmpty) {
    return km;
  }
  return en;
}

extension ProductBilingualName on Product {
  String localizedName(AppLanguage language) =>
      resolveBilingual(en: nameEn, km: nameKm, language: language);

  String? localizedCategoryName(AppLanguage language) => categoryNameEn == null
      ? null
      : resolveBilingual(
          en: categoryNameEn!,
          km: categoryNameKm,
          language: language,
        );
}

extension CategoryBilingualName on Category {
  String localizedName(AppLanguage language) =>
      resolveBilingual(en: nameEn, km: nameKm, language: language);
}

extension ReceiptLineBilingualName on ReceiptLine {
  String localizedName(AppLanguage language) =>
      resolveBilingual(en: nameEn ?? '', km: nameKm, language: language);
}

extension ModifierGroupBilingualName on ModifierGroupResponse {
  String localizedName(AppLanguage language) =>
      resolveBilingual(en: nameEn, km: nameKm, language: language);
}

extension ModifierOptionBilingualName on ModifierOptionResponse {
  String localizedName(AppLanguage language) =>
      resolveBilingual(en: nameEn, km: nameKm, language: language);
}
