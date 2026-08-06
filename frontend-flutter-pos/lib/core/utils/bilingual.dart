import '../providers/language_provider.dart';
import '../../features/pos/models/customer_models.dart';
import '../../features/pos/models/modifier_models.dart';
import '../../features/pos/models/product_models.dart';
import '../../features/pos/models/receipt_models.dart';

/// Picks the right display string for a bilingual DB field.
///
/// Reusable across every model that carries separate English/Khmer values
/// (products, categories, customers, receipt lines) and any single-language
/// value that doesn't have a Khmer field yet (payment methods, unit codes) —
/// pass `km: null` for those and it falls back to [en] regardless of
/// [language], so callers never special-case the "no translation" case.
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

extension CustomerBilingualName on Customer {
  /// Prefers the free-text [displayName] (matches existing
  /// [Customer.resolvedDisplayName] fallback order), then localizes between
  /// [nameEn]/[nameKm] when no display name was set.
  String localizedName(AppLanguage language) => displayName.isNotEmpty
      ? displayName
      : resolveBilingual(en: nameEn, km: nameKm, language: language);
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
