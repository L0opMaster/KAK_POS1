import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_km.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('km')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'KAKNNEA'**
  String get appName;

  /// No description provided for @commonName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get commonPrint;

  /// No description provided for @commonSavePdf.
  ///
  /// In en, this message translates to:
  /// **'Save PDF'**
  String get commonSavePdf;

  /// No description provided for @commonGeneratingPdf.
  ///
  /// In en, this message translates to:
  /// **'Generating PDF...'**
  String get commonGeneratingPdf;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get commonSelect;

  /// No description provided for @commonSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get commonSelectAll;

  /// No description provided for @commonRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get commonRequired;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get commonOptional;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get commonActive;

  /// No description provided for @commonInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get commonInactive;

  /// No description provided for @commonEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get commonEnabled;

  /// No description provided for @commonDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get commonDisabled;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get commonWarning;

  /// No description provided for @commonInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get commonInfo;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get errorNetwork;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'You are not authorized'**
  String get errorUnauthorized;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get errorNotFound;

  /// No description provided for @errorValidation.
  ///
  /// In en, this message translates to:
  /// **'Please check the highlighted fields'**
  String get errorValidation;

  /// No description provided for @errorSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorSomethingWentWrong;

  /// No description provided for @errorTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again'**
  String get errorTryAgain;

  /// No description provided for @navPos.
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get navPos;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get navInventory;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get navCustomers;

  /// No description provided for @navItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get navItems;

  /// No description provided for @navCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get navCategories;

  /// No description provided for @navTables.
  ///
  /// In en, this message translates to:
  /// **'Tables'**
  String get navTables;

  /// No description provided for @navShifts.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get navShifts;

  /// No description provided for @navReceipts.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get navReceipts;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageKhmer.
  ///
  /// In en, this message translates to:
  /// **'Khmer'**
  String get languageKhmer;

  /// No description provided for @languageSwitchTo.
  ///
  /// In en, this message translates to:
  /// **'Switch to {language}'**
  String languageSwitchTo(String language);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsCompanyProfile.
  ///
  /// In en, this message translates to:
  /// **'Company Profile'**
  String get settingsCompanyProfile;

  /// No description provided for @settingsTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get settingsTax;

  /// No description provided for @settingsPrinters.
  ///
  /// In en, this message translates to:
  /// **'Printers'**
  String get settingsPrinters;

  /// No description provided for @settingsPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get settingsPaymentMethods;

  /// No description provided for @settingsPosSettings.
  ///
  /// In en, this message translates to:
  /// **'POS Settings'**
  String get settingsPosSettings;

  /// No description provided for @settingsCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Currencies'**
  String get settingsCurrencies;

  /// No description provided for @settingsCurrencySymbol.
  ///
  /// In en, this message translates to:
  /// **'Symbol'**
  String get settingsCurrencySymbol;

  /// No description provided for @settingsExchangeRatePerUsd.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate (per 1 USD)'**
  String get settingsExchangeRatePerUsd;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguage;

  /// No description provided for @settingsMainColor.
  ///
  /// In en, this message translates to:
  /// **'Main Color'**
  String get settingsMainColor;

  /// No description provided for @settingsMainColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get settingsMainColorGreen;

  /// No description provided for @settingsMainColorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get settingsMainColorBlue;

  /// No description provided for @settingsMainColorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get settingsMainColorPurple;

  /// No description provided for @settingsMainColorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get settingsMainColorOrange;

  /// No description provided for @settingsMainColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get settingsMainColorRed;

  /// No description provided for @settingsMainColorTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get settingsMainColorTeal;

  /// No description provided for @settingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSave;

  /// No description provided for @settingsSaveGeneral.
  ///
  /// In en, this message translates to:
  /// **'Save General'**
  String get settingsSaveGeneral;

  /// No description provided for @settingsSaveCompany.
  ///
  /// In en, this message translates to:
  /// **'Save Company'**
  String get settingsSaveCompany;

  /// No description provided for @settingsSaveTax.
  ///
  /// In en, this message translates to:
  /// **'Save Tax'**
  String get settingsSaveTax;

  /// No description provided for @settingsSavePrinters.
  ///
  /// In en, this message translates to:
  /// **'Save Printers'**
  String get settingsSavePrinters;

  /// No description provided for @settingsTaxRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax rate'**
  String get settingsTaxRateLabel;

  /// No description provided for @settingsDefaultLanguage.
  ///
  /// In en, this message translates to:
  /// **'Default language'**
  String get settingsDefaultLanguage;

  /// No description provided for @settingsReceiptFooter.
  ///
  /// In en, this message translates to:
  /// **'Receipt footer'**
  String get settingsReceiptFooter;

  /// No description provided for @settingsRequireShiftForSales.
  ///
  /// In en, this message translates to:
  /// **'Require shift for sales'**
  String get settingsRequireShiftForSales;

  /// No description provided for @settingsShowKhqrOnReceipts.
  ///
  /// In en, this message translates to:
  /// **'Show KHQR on receipts'**
  String get settingsShowKhqrOnReceipts;

  /// No description provided for @printerTransportType.
  ///
  /// In en, this message translates to:
  /// **'Connection type'**
  String get printerTransportType;

  /// No description provided for @printerPdfDriver.
  ///
  /// In en, this message translates to:
  /// **'PDF / Driver printer'**
  String get printerPdfDriver;

  /// No description provided for @printerBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get printerBluetooth;

  /// No description provided for @printerUsb.
  ///
  /// In en, this message translates to:
  /// **'USB'**
  String get printerUsb;

  /// No description provided for @printerNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get printerNetwork;

  /// No description provided for @printerPaperSize.
  ///
  /// In en, this message translates to:
  /// **'Paper size'**
  String get printerPaperSize;

  /// No description provided for @printerPaper58mm.
  ///
  /// In en, this message translates to:
  /// **'58mm'**
  String get printerPaper58mm;

  /// No description provided for @printerPaper80mm.
  ///
  /// In en, this message translates to:
  /// **'80mm'**
  String get printerPaper80mm;

  /// No description provided for @printerIpAddress.
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get printerIpAddress;

  /// No description provided for @printerPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get printerPort;

  /// No description provided for @printerSelectDevice.
  ///
  /// In en, this message translates to:
  /// **'Select device'**
  String get printerSelectDevice;

  /// No description provided for @printerTestPrint.
  ///
  /// In en, this message translates to:
  /// **'Test print'**
  String get printerTestPrint;

  /// No description provided for @printerConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get printerConnect;

  /// No description provided for @printerDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get printerDisconnect;

  /// No description provided for @printerConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get printerConnected;

  /// No description provided for @printerNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get printerNotConnected;

  /// No description provided for @printerScanDevices.
  ///
  /// In en, this message translates to:
  /// **'Scan devices'**
  String get printerScanDevices;

  /// No description provided for @printerPrintSuccess.
  ///
  /// In en, this message translates to:
  /// **'Print succeeded'**
  String get printerPrintSuccess;

  /// No description provided for @printerPrintFailed.
  ///
  /// In en, this message translates to:
  /// **'Print failed'**
  String get printerPrintFailed;

  /// No description provided for @posTitle.
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get posTitle;

  /// No description provided for @posSearchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get posSearchProducts;

  /// No description provided for @posSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or SKU'**
  String get posSearchHint;

  /// No description provided for @posBarcodeHint.
  ///
  /// In en, this message translates to:
  /// **'Scan or enter barcode'**
  String get posBarcodeHint;

  /// No description provided for @posCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get posCategories;

  /// No description provided for @posCart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get posCart;

  /// No description provided for @posEmptyCart.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty'**
  String get posEmptyCart;

  /// No description provided for @posCheckout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get posCheckout;

  /// No description provided for @posHoldTicket.
  ///
  /// In en, this message translates to:
  /// **'Hold ticket'**
  String get posHoldTicket;

  /// No description provided for @posOpenTickets.
  ///
  /// In en, this message translates to:
  /// **'Open tickets'**
  String get posOpenTickets;

  /// No description provided for @posCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get posCustomer;

  /// No description provided for @posTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get posTable;

  /// No description provided for @posNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get posNotifications;

  /// No description provided for @posScannerReady.
  ///
  /// In en, this message translates to:
  /// **'Scanner ready — scan a code or type it and press Enter'**
  String get posScannerReady;

  /// No description provided for @posConnectScanner.
  ///
  /// In en, this message translates to:
  /// **'Connect / focus barcode scanner'**
  String get posConnectScanner;

  /// No description provided for @posNotificationsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Notifications coming soon'**
  String get posNotificationsComingSoon;

  /// No description provided for @cartSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get cartSubtotal;

  /// No description provided for @cartDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get cartDiscount;

  /// No description provided for @cartTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get cartTax;

  /// No description provided for @cartTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get cartTotal;

  /// No description provided for @cartQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get cartQty;

  /// No description provided for @cartPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get cartPrice;

  /// No description provided for @cartRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get cartRemove;

  /// No description provided for @cartClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get cartClear;

  /// No description provided for @cartAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get cartAddNote;

  /// No description provided for @cartSelectCustomer.
  ///
  /// In en, this message translates to:
  /// **'Select customer'**
  String get cartSelectCustomer;

  /// No description provided for @cartSelectTable.
  ///
  /// In en, this message translates to:
  /// **'Select table'**
  String get cartSelectTable;

  /// No description provided for @cartPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get cartPayment;

  /// No description provided for @cartCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cartCash;

  /// No description provided for @cartCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get cartCard;

  /// No description provided for @cartKhqr.
  ///
  /// In en, this message translates to:
  /// **'KHQR'**
  String get cartKhqr;

  /// No description provided for @cartAmountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get cartAmountPaid;

  /// No description provided for @cartChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get cartChange;

  /// No description provided for @cartCompleteSale.
  ///
  /// In en, this message translates to:
  /// **'Complete sale'**
  String get cartCompleteSale;

  /// No description provided for @receiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receiptTitle;

  /// No description provided for @receiptSaleReceipt.
  ///
  /// In en, this message translates to:
  /// **'Sale Receipt'**
  String get receiptSaleReceipt;

  /// No description provided for @receiptInvoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Invoice No.'**
  String get receiptInvoiceNumber;

  /// No description provided for @receiptDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get receiptDate;

  /// No description provided for @receiptTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get receiptTime;

  /// No description provided for @receiptCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get receiptCashier;

  /// No description provided for @receiptCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get receiptCustomer;

  /// No description provided for @receiptTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get receiptTable;

  /// No description provided for @receiptItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get receiptItem;

  /// No description provided for @receiptQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get receiptQty;

  /// No description provided for @receiptPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get receiptPrice;

  /// No description provided for @receiptAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get receiptAmount;

  /// No description provided for @receiptSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get receiptSubtotal;

  /// No description provided for @receiptDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get receiptDiscount;

  /// No description provided for @receiptDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get receiptDelivery;

  /// No description provided for @receiptOtherCharge.
  ///
  /// In en, this message translates to:
  /// **'Other Charge'**
  String get receiptOtherCharge;

  /// No description provided for @receiptTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get receiptTax;

  /// No description provided for @receiptTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get receiptTotal;

  /// No description provided for @receiptPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get receiptPaid;

  /// No description provided for @receiptChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get receiptChange;

  /// No description provided for @receiptPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get receiptPaymentMethod;

  /// No description provided for @receiptThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your purchase!'**
  String get receiptThankYou;

  /// No description provided for @receiptPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get receiptPrint;

  /// No description provided for @receiptReprint.
  ///
  /// In en, this message translates to:
  /// **'Reprint'**
  String get receiptReprint;

  /// No description provided for @receiptExchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate'**
  String get receiptExchangeRate;

  /// No description provided for @dialogConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get dialogConfirmTitle;

  /// No description provided for @dialogConfirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get dialogConfirmDeleteTitle;

  /// No description provided for @dialogConfirmDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this item? This action cannot be undone.'**
  String get dialogConfirmDeleteMessage;

  /// No description provided for @dialogUnsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get dialogUnsavedChangesTitle;

  /// No description provided for @dialogUnsavedChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Discard them?'**
  String get dialogUnsavedChangesMessage;

  /// No description provided for @formName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get formName;

  /// No description provided for @formNameEn.
  ///
  /// In en, this message translates to:
  /// **'Name (English)'**
  String get formNameEn;

  /// No description provided for @formNameKm.
  ///
  /// In en, this message translates to:
  /// **'Name (Khmer)'**
  String get formNameKm;

  /// No description provided for @formPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get formPrice;

  /// No description provided for @formCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get formCost;

  /// No description provided for @formSku.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get formSku;

  /// No description provided for @formBarcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get formBarcode;

  /// No description provided for @formCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get formCategory;

  /// No description provided for @formPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get formPhone;

  /// No description provided for @formEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get formEmail;

  /// No description provided for @formAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get formAddress;

  /// No description provided for @formWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get formWebsite;

  /// No description provided for @formPleaseEnterValue.
  ///
  /// In en, this message translates to:
  /// **'Please enter a value'**
  String get formPleaseEnterValue;

  /// No description provided for @formInvalidValue.
  ///
  /// In en, this message translates to:
  /// **'Invalid value'**
  String get formInvalidValue;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @reportsSalesSummary.
  ///
  /// In en, this message translates to:
  /// **'Sales Summary'**
  String get reportsSalesSummary;

  /// No description provided for @reportsSalesByItem.
  ///
  /// In en, this message translates to:
  /// **'Sales by Item'**
  String get reportsSalesByItem;

  /// No description provided for @reportsSalesByCategory.
  ///
  /// In en, this message translates to:
  /// **'Sales by Category'**
  String get reportsSalesByCategory;

  /// No description provided for @reportsSalesByEmployee.
  ///
  /// In en, this message translates to:
  /// **'Sales by Employee'**
  String get reportsSalesByEmployee;

  /// No description provided for @reportsSalesByPaymentType.
  ///
  /// In en, this message translates to:
  /// **'Sales by Payment Type'**
  String get reportsSalesByPaymentType;

  /// No description provided for @reportsDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Discounts'**
  String get reportsDiscounts;

  /// No description provided for @reportsTaxes.
  ///
  /// In en, this message translates to:
  /// **'Taxes'**
  String get reportsTaxes;

  /// No description provided for @reportsDateRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get reportsDateRange;

  /// No description provided for @reportsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get reportsExport;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get authLogin;

  /// No description provided for @authUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get authUsername;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get authLoginFailed;

  /// No description provided for @authLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get authLogout;

  /// No description provided for @loginScreenBadge.
  ///
  /// In en, this message translates to:
  /// **'Smart Restaurant POS'**
  String get loginScreenBadge;

  /// No description provided for @loginScreenHeadline.
  ///
  /// In en, this message translates to:
  /// **'Modern POS\nFor Fast Business'**
  String get loginScreenHeadline;

  /// No description provided for @loginScreenDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage restaurant orders, inventory, kitchen workflow,\ncustomer management, payments, and business reports\nfrom one complete POS platform.'**
  String get loginScreenDescription;

  /// No description provided for @loginScreenFeatureRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get loginScreenFeatureRestaurant;

  /// No description provided for @loginScreenFeatureMultiBranch.
  ///
  /// In en, this message translates to:
  /// **'Multi Branch'**
  String get loginScreenFeatureMultiBranch;

  /// No description provided for @loginScreenCopyright.
  ///
  /// In en, this message translates to:
  /// **'© 2026 KAKNNEA Technologies'**
  String get loginScreenCopyright;

  /// No description provided for @loginScreenWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get loginScreenWelcomeBack;

  /// No description provided for @loginScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Login to access your dashboard and manage\nyour restaurant or retail business operations.'**
  String get loginScreenSubtitle;

  /// No description provided for @loginScreenEnterUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter username'**
  String get loginScreenEnterUsernameHint;

  /// No description provided for @loginScreenEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get loginScreenEmailRequired;

  /// No description provided for @loginScreenEnterPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get loginScreenEnterPasswordHint;

  /// No description provided for @loginScreenPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get loginScreenPasswordRequired;

  /// No description provided for @loginScreenPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Min 6 characters'**
  String get loginScreenPasswordMinLength;

  /// No description provided for @loginScreenRememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get loginScreenRememberMe;

  /// No description provided for @loginScreenForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get loginScreenForgotPassword;

  /// No description provided for @loginScreenNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get loginScreenNoAccount;

  /// No description provided for @loginScreenRegisterLink.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get loginScreenRegisterLink;

  /// No description provided for @createEmployeeSelectExistingAccountError.
  ///
  /// In en, this message translates to:
  /// **'Select an existing user account to link'**
  String get createEmployeeSelectExistingAccountError;

  /// No description provided for @createEmployeeAccountFieldsRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Email, password, and role are required to create a user account'**
  String get createEmployeeAccountFieldsRequiredError;

  /// No description provided for @createEmployeeUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Employee updated'**
  String get createEmployeeUpdatedMessage;

  /// No description provided for @createEmployeeCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Employee created'**
  String get createEmployeeCreatedMessage;

  /// No description provided for @createEmployeeSaveFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get createEmployeeSaveFailedPrefix;

  /// No description provided for @createEmployeeHasUserAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Has User Account'**
  String get createEmployeeHasUserAccountTitle;

  /// No description provided for @createEmployeeHasUserAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow this employee to log into the POS with a role'**
  String get createEmployeeHasUserAccountSubtitle;

  /// No description provided for @createEmployeeLinkedAccountPrefix.
  ///
  /// In en, this message translates to:
  /// **'Linked to user account:'**
  String get createEmployeeLinkedAccountPrefix;

  /// No description provided for @createEmployeeLinkedAccountManageHint.
  ///
  /// In en, this message translates to:
  /// **'Manage its role or password from User Accounts.'**
  String get createEmployeeLinkedAccountManageHint;

  /// No description provided for @createEmployeeCreateNewOption.
  ///
  /// In en, this message translates to:
  /// **'Create New'**
  String get createEmployeeCreateNewOption;

  /// No description provided for @createEmployeeLinkExistingOption.
  ///
  /// In en, this message translates to:
  /// **'Link Existing'**
  String get createEmployeeLinkExistingOption;

  /// No description provided for @createEmployeeLoginEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Login Email *'**
  String get createEmployeeLoginEmailLabel;

  /// No description provided for @createEmployeeAccountPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password *'**
  String get createEmployeeAccountPasswordLabel;

  /// No description provided for @createEmployeeSelectRoleHint.
  ///
  /// In en, this message translates to:
  /// **'Select role'**
  String get createEmployeeSelectRoleHint;

  /// No description provided for @createEmployeeRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role *'**
  String get createEmployeeRoleLabel;

  /// No description provided for @createEmployeeExistingUserAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Existing User Account *'**
  String get createEmployeeExistingUserAccountLabel;

  /// No description provided for @createEmployeeSelectUserHint.
  ///
  /// In en, this message translates to:
  /// **'Select user'**
  String get createEmployeeSelectUserHint;

  /// No description provided for @createEmployeeNoUnlinkedAccountsMessage.
  ///
  /// In en, this message translates to:
  /// **'No unlinked user accounts available. Create one instead.'**
  String get createEmployeeNoUnlinkedAccountsMessage;

  /// No description provided for @createEmployeeEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Employee'**
  String get createEmployeeEditTitle;

  /// No description provided for @createEmployeeNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Employee'**
  String get createEmployeeNewTitle;

  /// No description provided for @createEmployeeFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name *'**
  String get createEmployeeFullNameLabel;

  /// No description provided for @createEmployeeCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Employee Code'**
  String get createEmployeeCodeLabel;

  /// No description provided for @createEmployeeCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to auto-generate'**
  String get createEmployeeCodeHint;

  /// No description provided for @createEmployeePositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get createEmployeePositionLabel;

  /// No description provided for @createEmployeePositionHint.
  ///
  /// In en, this message translates to:
  /// **'Cashier, Chef, Manager...'**
  String get createEmployeePositionHint;

  /// No description provided for @createEmployeeDepartmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get createEmployeeDepartmentLabel;

  /// No description provided for @createEmployeeHireDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Hire Date'**
  String get createEmployeeHireDateLabel;

  /// No description provided for @createEmployeeNotSetLabel.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get createEmployeeNotSetLabel;

  /// No description provided for @createEmployeeBaseSalaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Base Salary *'**
  String get createEmployeeBaseSalaryLabel;

  /// No description provided for @createEmployeeInvalidAmountError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get createEmployeeInvalidAmountError;

  /// No description provided for @createEmployeeNegativeAmountError.
  ///
  /// In en, this message translates to:
  /// **'Cannot be negative'**
  String get createEmployeeNegativeAmountError;

  /// No description provided for @createEmployeePayTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Pay Type'**
  String get createEmployeePayTypeLabel;

  /// No description provided for @createEmployeeStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get createEmployeeStatusLabel;

  /// No description provided for @createEmployeeNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get createEmployeeNotesLabel;

  /// No description provided for @createEmployeeSavingLabel.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get createEmployeeSavingLabel;

  /// No description provided for @createEmployeeSaveChangesLabel.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get createEmployeeSaveChangesLabel;

  /// No description provided for @createEmployeeCreateButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Create Employee'**
  String get createEmployeeCreateButtonLabel;

  /// No description provided for @createModifierMinOneOptionError.
  ///
  /// In en, this message translates to:
  /// **'A modifier must have at least one option.'**
  String get createModifierMinOneOptionError;

  /// No description provided for @createModifierDiscardChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this page and discard changes?'**
  String get createModifierDiscardChangesMessage;

  /// No description provided for @createModifierContinueEditingButton.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE EDITING'**
  String get createModifierContinueEditingButton;

  /// No description provided for @createModifierDiscardChangesButton.
  ///
  /// In en, this message translates to:
  /// **'DISCARD CHANGES'**
  String get createModifierDiscardChangesButton;

  /// No description provided for @createModifierEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Modifier'**
  String get createModifierEditTitle;

  /// No description provided for @createModifierCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Modifier'**
  String get createModifierCreateTitle;

  /// No description provided for @createModifierAddOptionButton.
  ///
  /// In en, this message translates to:
  /// **'ADD OPTION'**
  String get createModifierAddOptionButton;

  /// No description provided for @createModifierRequiredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customer must select an option.'**
  String get createModifierRequiredSubtitle;

  /// No description provided for @createModifierMultiSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow multiple selections'**
  String get createModifierMultiSelectTitle;

  /// No description provided for @createModifierMultiSelectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customer can select more than one option.'**
  String get createModifierMultiSelectSubtitle;

  /// No description provided for @createModifierNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Modifier name'**
  String get createModifierNameLabel;

  /// No description provided for @createModifierNameRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Modifier name cannot be blank'**
  String get createModifierNameRequiredError;

  /// No description provided for @createModifierDeleteOptionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete option'**
  String get createModifierDeleteOptionTooltip;

  /// No description provided for @createModifierOptionNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Option name'**
  String get createModifierOptionNameLabel;

  /// No description provided for @createModifierOptionNameRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Option name is required'**
  String get createModifierOptionNameRequiredError;

  /// No description provided for @createModifierPriceRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Price is required'**
  String get createModifierPriceRequiredError;

  /// No description provided for @createModifierInvalidPriceError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price'**
  String get createModifierInvalidPriceError;

  /// No description provided for @createModifierNegativePriceError.
  ///
  /// In en, this message translates to:
  /// **'Price cannot be negative'**
  String get createModifierNegativePriceError;

  /// No description provided for @createModifierDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete modifier'**
  String get createModifierDeleteTitle;

  /// No description provided for @createModifierDeleteConfirmPrefix.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete'**
  String get createModifierDeleteConfirmPrefix;

  /// No description provided for @createModifierUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Modifier updated successfully.'**
  String get createModifierUpdatedMessage;

  /// No description provided for @createModifierCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Modifier created successfully.'**
  String get createModifierCreatedMessage;

  /// No description provided for @createModifierSaveFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Failed to save modifier.'**
  String get createModifierSaveFailedFallback;

  /// No description provided for @createModifierDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Modifier deleted successfully.'**
  String get createModifierDeletedMessage;

  /// No description provided for @createModifierDeleteFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete modifier.'**
  String get createModifierDeleteFailedFallback;

  /// No description provided for @createTableUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Table updated'**
  String get createTableUpdatedMessage;

  /// No description provided for @createTableCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Table created'**
  String get createTableCreatedMessage;

  /// No description provided for @createTableSaveFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get createTableSaveFailedPrefix;

  /// No description provided for @createTableEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Table'**
  String get createTableEditTitle;

  /// No description provided for @createTableNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Table'**
  String get createTableNewTitle;

  /// No description provided for @createTableNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Table Number *'**
  String get createTableNumberLabel;

  /// No description provided for @createTableNumberHint.
  ///
  /// In en, this message translates to:
  /// **'A1, B2, T-01...'**
  String get createTableNumberHint;

  /// No description provided for @createTableNumberLockedHint.
  ///
  /// In en, this message translates to:
  /// **'Table number cannot be changed'**
  String get createTableNumberLockedHint;

  /// No description provided for @createTableDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get createTableDisplayNameLabel;

  /// No description provided for @createTableDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to use the table number'**
  String get createTableDisplayNameHint;

  /// No description provided for @createTableCapacityLabel.
  ///
  /// In en, this message translates to:
  /// **'Capacity (seats) *'**
  String get createTableCapacityLabel;

  /// No description provided for @createTableInvalidNumberError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get createTableInvalidNumberError;

  /// No description provided for @createTableMinCapacityError.
  ///
  /// In en, this message translates to:
  /// **'Must be at least 1'**
  String get createTableMinCapacityError;

  /// No description provided for @createTableSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get createTableSectionLabel;

  /// No description provided for @createTableSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Main Hall, Patio, VIP...'**
  String get createTableSectionHint;

  /// No description provided for @createTableStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get createTableStatusLabel;

  /// No description provided for @createTableActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Table is available for use in the POS'**
  String get createTableActiveSubtitle;

  /// No description provided for @createTableNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get createTableNotesLabel;

  /// No description provided for @createTableSavingLabel.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get createTableSavingLabel;

  /// No description provided for @createTableSaveChangesLabel.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get createTableSaveChangesLabel;

  /// No description provided for @createTableCreateButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Create Table'**
  String get createTableCreateButtonLabel;

  /// No description provided for @categoryManagementUpdateFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Failed to update'**
  String get categoryManagementUpdateFailedPrefix;

  /// No description provided for @categoryManagementEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get categoryManagementEmptyTitle;

  /// No description provided for @categoryManagementEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add a category'**
  String get categoryManagementEmptyHint;

  /// No description provided for @categoryManagementAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get categoryManagementAddButton;

  /// No description provided for @categoryManagementEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get categoryManagementEditTitle;

  /// No description provided for @categoryManagementNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get categoryManagementNewTitle;

  /// No description provided for @categoryManagementColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get categoryManagementColorLabel;

  /// No description provided for @categoryManagementActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show in POS category filter'**
  String get categoryManagementActiveSubtitle;

  /// No description provided for @categoryManagementPreviewNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get categoryManagementPreviewNamePlaceholder;

  /// No description provided for @categoryManagementUpdatedSuffix.
  ///
  /// In en, this message translates to:
  /// **'updated'**
  String get categoryManagementUpdatedSuffix;

  /// No description provided for @categoryManagementCreatedSuffix.
  ///
  /// In en, this message translates to:
  /// **'created'**
  String get categoryManagementCreatedSuffix;

  /// No description provided for @categoryManagementSaveFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get categoryManagementSaveFailedPrefix;

  /// No description provided for @unitManagementUpdateFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Failed to update'**
  String get unitManagementUpdateFailedPrefix;

  /// No description provided for @unitManagementSaveFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get unitManagementSaveFailedPrefix;

  /// No description provided for @unitManagementEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No units yet'**
  String get unitManagementEmptyTitle;

  /// No description provided for @unitManagementEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add a unit'**
  String get unitManagementEmptyHint;

  /// No description provided for @unitManagementAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Unit'**
  String get unitManagementAddButton;

  /// No description provided for @unitManagementEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Unit'**
  String get unitManagementEditTitle;

  /// No description provided for @unitManagementNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Unit'**
  String get unitManagementNewTitle;

  /// No description provided for @unitManagementUpdatedSuffix.
  ///
  /// In en, this message translates to:
  /// **'updated'**
  String get unitManagementUpdatedSuffix;

  /// No description provided for @unitManagementCreatedSuffix.
  ///
  /// In en, this message translates to:
  /// **'created'**
  String get unitManagementCreatedSuffix;

  /// No description provided for @unitManagementCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get unitManagementCodeLabel;

  /// No description provided for @unitManagementSymbolLabel.
  ///
  /// In en, this message translates to:
  /// **'Symbol'**
  String get unitManagementSymbolLabel;

  /// No description provided for @unitManagementGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit group'**
  String get unitManagementGroupLabel;

  /// No description provided for @unitManagementGroupHelper.
  ///
  /// In en, this message translates to:
  /// **'Units that convert to each other share the same group, e.g. \"weight\"'**
  String get unitManagementGroupHelper;

  /// No description provided for @unitManagementBaseUnitGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get unitManagementBaseUnitGroupLabel;

  /// No description provided for @unitManagementBaseUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Base unit'**
  String get unitManagementBaseUnitLabel;

  /// No description provided for @unitManagementBaseUnitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The reference unit other units in this group convert against'**
  String get unitManagementBaseUnitSubtitle;

  /// No description provided for @unitManagementBaseUnitPickerLabel.
  ///
  /// In en, this message translates to:
  /// **'Convert to'**
  String get unitManagementBaseUnitPickerLabel;

  /// No description provided for @unitManagementNoCandidatesHelper.
  ///
  /// In en, this message translates to:
  /// **'No other units in this group yet — add the base unit first'**
  String get unitManagementNoCandidatesHelper;

  /// No description provided for @unitManagementConversionFactorLabel.
  ///
  /// In en, this message translates to:
  /// **'Conversion factor'**
  String get unitManagementConversionFactorLabel;

  /// No description provided for @unitManagementConversionFactorHelper.
  ///
  /// In en, this message translates to:
  /// **'How many {symbol} equal 1 of the base unit'**
  String unitManagementConversionFactorHelper(Object symbol);

  /// No description provided for @unitManagementPickBaseUnitError.
  ///
  /// In en, this message translates to:
  /// **'Choose which unit this converts to'**
  String get unitManagementPickBaseUnitError;

  /// No description provided for @customerManagementDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete customers'**
  String get customerManagementDeleteTitle;

  /// No description provided for @customerManagementDeleteConfirmPrefix.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete'**
  String get customerManagementDeleteConfirmPrefix;

  /// No description provided for @customerManagementDeleteConfirmSuffix.
  ///
  /// In en, this message translates to:
  /// **'selected customer(s)?'**
  String get customerManagementDeleteConfirmSuffix;

  /// No description provided for @customerManagementDeletedSuffix.
  ///
  /// In en, this message translates to:
  /// **'customer(s) deleted successfully.'**
  String get customerManagementDeletedSuffix;

  /// No description provided for @customerManagementDeleteFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete customers'**
  String get customerManagementDeleteFailedPrefix;

  /// No description provided for @customerManagementAddButton.
  ///
  /// In en, this message translates to:
  /// **'ADD CUSTOMER'**
  String get customerManagementAddButton;

  /// No description provided for @customerManagementDeleteSelectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete selected customers'**
  String get customerManagementDeleteSelectedTooltip;

  /// No description provided for @customerManagementSelectedSuffix.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get customerManagementSelectedSuffix;

  /// No description provided for @customerManagementSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, phone or email...'**
  String get customerManagementSearchHint;

  /// No description provided for @customerManagementShowingPrefix.
  ///
  /// In en, this message translates to:
  /// **'Showing'**
  String get customerManagementShowingPrefix;

  /// No description provided for @customerManagementOfLabel.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get customerManagementOfLabel;

  /// No description provided for @customerManagementNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No customers found'**
  String get customerManagementNoResultsTitle;

  /// No description provided for @customerManagementNoContactInfo.
  ///
  /// In en, this message translates to:
  /// **'No contact info'**
  String get customerManagementNoContactInfo;

  /// No description provided for @customerManagementPagePrefix.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get customerManagementPagePrefix;

  /// No description provided for @customerManagementFirstPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'First page'**
  String get customerManagementFirstPageTooltip;

  /// No description provided for @customerManagementPreviousPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get customerManagementPreviousPageTooltip;

  /// No description provided for @customerManagementNextPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get customerManagementNextPageTooltip;

  /// No description provided for @customerManagementLastPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Last page'**
  String get customerManagementLastPageTooltip;

  /// No description provided for @customerManagementEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep track of customers and their credit balances.'**
  String get customerManagementEmptyDescription;

  /// No description provided for @customerManagementEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Customer'**
  String get customerManagementEditTitle;

  /// No description provided for @customerManagementNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Customer'**
  String get customerManagementNewTitle;

  /// No description provided for @customerManagementNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer Name *'**
  String get customerManagementNameLabel;

  /// No description provided for @customerManagementCreditLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Credit Limit (\$)'**
  String get customerManagementCreditLimitLabel;

  /// No description provided for @customerManagementNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get customerManagementNotesLabel;

  /// No description provided for @customerManagementSavingLabel.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get customerManagementSavingLabel;

  /// No description provided for @customerManagementUpdateButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Update Customer'**
  String get customerManagementUpdateButtonLabel;

  /// No description provided for @customerManagementCreateButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Create Customer'**
  String get customerManagementCreateButtonLabel;

  /// No description provided for @customerManagementCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Customer created'**
  String get customerManagementCreatedMessage;

  /// No description provided for @customerManagementUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Customer updated'**
  String get customerManagementUpdatedMessage;

  /// No description provided for @customerManagementSaveFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get customerManagementSaveFailedPrefix;

  /// No description provided for @customerManagementDetailFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customerManagementDetailFallbackTitle;

  /// No description provided for @customerManagementCreditAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Credit Account'**
  String get customerManagementCreditAccountTitle;

  /// No description provided for @customerManagementBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get customerManagementBalanceLabel;

  /// No description provided for @customerManagementLimitPrefix.
  ///
  /// In en, this message translates to:
  /// **'Limit:'**
  String get customerManagementLimitPrefix;

  /// No description provided for @customerManagementUsedSuffix.
  ///
  /// In en, this message translates to:
  /// **'used'**
  String get customerManagementUsedSuffix;

  /// No description provided for @customerManagementNoPurchaseHistory.
  ///
  /// In en, this message translates to:
  /// **'No purchase history'**
  String get customerManagementNoPurchaseHistory;

  /// No description provided for @customerManagementPurchaseHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase History'**
  String get customerManagementPurchaseHistoryTitle;

  /// No description provided for @customerManagementSalePrefix.
  ///
  /// In en, this message translates to:
  /// **'Sale #'**
  String get customerManagementSalePrefix;

  /// No description provided for @debugSettingsUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Settings updated'**
  String get debugSettingsUpdatedMessage;

  /// No description provided for @debugSettingsUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Unavailable in release mode'**
  String get debugSettingsUnavailableMessage;

  /// No description provided for @debugSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug Settings'**
  String get debugSettingsTitle;

  /// No description provided for @debugSettingsUseApiCartLabel.
  ///
  /// In en, this message translates to:
  /// **'Use API cart service'**
  String get debugSettingsUseApiCartLabel;

  /// No description provided for @debugSettingsHeldTicketSyncLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable held-ticket sync'**
  String get debugSettingsHeldTicketSyncLabel;

  /// No description provided for @createPurchaseOrderSelectSupplier.
  ///
  /// In en, this message translates to:
  /// **'Select a supplier'**
  String get createPurchaseOrderSelectSupplier;

  /// No description provided for @inventoryLinesAddAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Add at least one line'**
  String get inventoryLinesAddAtLeastOne;

  /// No description provided for @createPurchaseOrderCreated.
  ///
  /// In en, this message translates to:
  /// **'Purchase order created'**
  String get createPurchaseOrderCreated;

  /// No description provided for @inventoryFailedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String inventoryFailedToSave(Object error);

  /// No description provided for @createPurchaseOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'New Purchase Order'**
  String get createPurchaseOrderTitle;

  /// No description provided for @createPurchaseOrderSupplierLabel.
  ///
  /// In en, this message translates to:
  /// **'Supplier *'**
  String get createPurchaseOrderSupplierLabel;

  /// No description provided for @createPurchaseOrderDeliverToStore.
  ///
  /// In en, this message translates to:
  /// **'Deliver to Store'**
  String get createPurchaseOrderDeliverToStore;

  /// No description provided for @inventoryNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get inventoryNotSet;

  /// No description provided for @createPurchaseOrderOrderDeadline.
  ///
  /// In en, this message translates to:
  /// **'Order Deadline'**
  String get createPurchaseOrderOrderDeadline;

  /// No description provided for @createPurchaseOrderExpectedArrival.
  ///
  /// In en, this message translates to:
  /// **'Expected Arrival'**
  String get createPurchaseOrderExpectedArrival;

  /// No description provided for @createPurchaseOrderTaxRate.
  ///
  /// In en, this message translates to:
  /// **'Tax Rate (%)'**
  String get createPurchaseOrderTaxRate;

  /// No description provided for @inventoryNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get inventoryNotesLabel;

  /// No description provided for @inventoryLinesLabel.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get inventoryLinesLabel;

  /// No description provided for @inventoryAddLine.
  ///
  /// In en, this message translates to:
  /// **'Add Line'**
  String get inventoryAddLine;

  /// No description provided for @inventoryProductLabel.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get inventoryProductLabel;

  /// No description provided for @createPurchaseOrderUnitCost.
  ///
  /// In en, this message translates to:
  /// **'Unit Cost'**
  String get createPurchaseOrderUnitCost;

  /// No description provided for @createRecipeEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a recipe name'**
  String get createRecipeEnterName;

  /// No description provided for @createRecipeSelectOutputProduct.
  ///
  /// In en, this message translates to:
  /// **'Select an output product'**
  String get createRecipeSelectOutputProduct;

  /// No description provided for @createRecipeEnterValidQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid output quantity'**
  String get createRecipeEnterValidQuantity;

  /// No description provided for @createRecipeAddAtLeastOneComponent.
  ///
  /// In en, this message translates to:
  /// **'Add at least one component'**
  String get createRecipeAddAtLeastOneComponent;

  /// No description provided for @createRecipeUpdated.
  ///
  /// In en, this message translates to:
  /// **'Recipe updated'**
  String get createRecipeUpdated;

  /// No description provided for @createRecipeCreated.
  ///
  /// In en, this message translates to:
  /// **'Recipe created'**
  String get createRecipeCreated;

  /// No description provided for @createRecipeEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Recipe'**
  String get createRecipeEditTitle;

  /// No description provided for @createRecipeNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Recipe'**
  String get createRecipeNewTitle;

  /// No description provided for @createRecipeNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipe Name *'**
  String get createRecipeNameLabel;

  /// No description provided for @createRecipeOutputProductLabel.
  ///
  /// In en, this message translates to:
  /// **'Output Product'**
  String get createRecipeOutputProductLabel;

  /// No description provided for @createRecipeProductNumber.
  ///
  /// In en, this message translates to:
  /// **'Product #{id}'**
  String createRecipeProductNumber(Object id);

  /// No description provided for @createRecipeOutputProductRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Output Product *'**
  String get createRecipeOutputProductRequiredLabel;

  /// No description provided for @createRecipeOutputQtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Output Quantity *'**
  String get createRecipeOutputQtyLabel;

  /// No description provided for @createRecipeComponentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Components'**
  String get createRecipeComponentsLabel;

  /// No description provided for @createRecipeAddComponent.
  ///
  /// In en, this message translates to:
  /// **'Add Component'**
  String get createRecipeAddComponent;

  /// No description provided for @createRecipeComponentLabel.
  ///
  /// In en, this message translates to:
  /// **'Component'**
  String get createRecipeComponentLabel;

  /// No description provided for @createSupplierUpdated.
  ///
  /// In en, this message translates to:
  /// **'Supplier updated'**
  String get createSupplierUpdated;

  /// No description provided for @createSupplierCreated.
  ///
  /// In en, this message translates to:
  /// **'Supplier created'**
  String get createSupplierCreated;

  /// No description provided for @createSupplierEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Supplier'**
  String get createSupplierEditTitle;

  /// No description provided for @createSupplierNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Supplier'**
  String get createSupplierNewTitle;

  /// No description provided for @createSupplierNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Supplier Name *'**
  String get createSupplierNameLabel;

  /// No description provided for @createSupplierContactPerson.
  ///
  /// In en, this message translates to:
  /// **'Contact Person'**
  String get createSupplierContactPerson;

  /// No description provided for @createSupplierPaymentTerms.
  ///
  /// In en, this message translates to:
  /// **'Payment Terms'**
  String get createSupplierPaymentTerms;

  /// No description provided for @createSupplierPaymentTermsHint.
  ///
  /// In en, this message translates to:
  /// **'Net 30, COD...'**
  String get createSupplierPaymentTermsHint;

  /// No description provided for @createSupplierLeadTime.
  ///
  /// In en, this message translates to:
  /// **'Lead Time (days)'**
  String get createSupplierLeadTime;

  /// No description provided for @createSupplierTaxId.
  ///
  /// In en, this message translates to:
  /// **'Tax ID'**
  String get createSupplierTaxId;

  /// No description provided for @createSupplierDefaultCurrency.
  ///
  /// In en, this message translates to:
  /// **'Default Currency'**
  String get createSupplierDefaultCurrency;

  /// No description provided for @createSupplierActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Available when creating purchase orders'**
  String get createSupplierActiveSubtitle;

  /// No description provided for @createSupplierSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get createSupplierSaving;

  /// No description provided for @createSupplierSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get createSupplierSaveChanges;

  /// No description provided for @createSupplierCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create Supplier'**
  String get createSupplierCreateButton;

  /// No description provided for @createTransferOrderSelectBothStores.
  ///
  /// In en, this message translates to:
  /// **'Select both stores'**
  String get createTransferOrderSelectBothStores;

  /// No description provided for @createTransferOrderStoresMustDiffer.
  ///
  /// In en, this message translates to:
  /// **'From and To store must be different'**
  String get createTransferOrderStoresMustDiffer;

  /// No description provided for @createTransferOrderCreated.
  ///
  /// In en, this message translates to:
  /// **'Transfer created'**
  String get createTransferOrderCreated;

  /// No description provided for @createTransferOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'New Transfer'**
  String get createTransferOrderTitle;

  /// No description provided for @createTransferOrderFromStore.
  ///
  /// In en, this message translates to:
  /// **'From Store *'**
  String get createTransferOrderFromStore;

  /// No description provided for @createTransferOrderToStore.
  ///
  /// In en, this message translates to:
  /// **'To Store *'**
  String get createTransferOrderToStore;

  /// No description provided for @inventoryCountsFailedToStart.
  ///
  /// In en, this message translates to:
  /// **'Failed to start count: {error}'**
  String inventoryCountsFailedToStart(Object error);

  /// No description provided for @inventoryCountsEnterValidQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid quantity'**
  String get inventoryCountsEnterValidQuantity;

  /// No description provided for @inventoryCountsExpectedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get inventoryCountsExpectedPrefix;

  /// No description provided for @inventoryCountsCountedQtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Counted quantity *'**
  String get inventoryCountsCountedQtyLabel;

  /// No description provided for @inventoryCountsPostDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Post count'**
  String get inventoryCountsPostDialogTitle;

  /// No description provided for @inventoryCountsPostDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'This applies every counted variance to stock on hand and cannot be undone. Continue?'**
  String get inventoryCountsPostDialogMessage;

  /// No description provided for @inventoryCountsPostAction.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get inventoryCountsPostAction;

  /// No description provided for @inventoryCountsPostedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Count posted successfully'**
  String get inventoryCountsPostedSuccess;

  /// No description provided for @inventoryCountsFailedToPost.
  ///
  /// In en, this message translates to:
  /// **'Failed to post count: {error}'**
  String inventoryCountsFailedToPost(Object error);

  /// No description provided for @inventoryCountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Inventory Counts'**
  String get inventoryCountsTitle;

  /// No description provided for @inventoryCountsForDate.
  ///
  /// In en, this message translates to:
  /// **'Count for {date}'**
  String inventoryCountsForDate(Object date);

  /// No description provided for @inventoryCountsStartCount.
  ///
  /// In en, this message translates to:
  /// **'Start Count'**
  String get inventoryCountsStartCount;

  /// No description provided for @inventoryCountsPostCountButton.
  ///
  /// In en, this message translates to:
  /// **'Post Count'**
  String get inventoryCountsPostCountButton;

  /// No description provided for @inventoryCountsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No count started for today'**
  String get inventoryCountsEmptyTitle;

  /// No description provided for @inventoryCountsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap Start Count to snapshot expected quantities'**
  String get inventoryCountsEmptySubtitle;

  /// No description provided for @inventoryCountsProductsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} products'**
  String inventoryCountsProductsCount(Object count);

  /// No description provided for @inventoryCountsUnitsOff.
  ///
  /// In en, this message translates to:
  /// **'{count} unit(s) off'**
  String inventoryCountsUnitsOff(Object count);

  /// No description provided for @inventoryCountsEnterCountTooltip.
  ///
  /// In en, this message translates to:
  /// **'Enter count'**
  String get inventoryCountsEnterCountTooltip;

  /// No description provided for @inventoryHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Inventory History'**
  String get inventoryHistoryTitle;

  /// No description provided for @inventoryHistoryFilterByProduct.
  ///
  /// In en, this message translates to:
  /// **'Filter by product'**
  String get inventoryHistoryFilterByProduct;

  /// No description provided for @inventoryHistoryAllProducts.
  ///
  /// In en, this message translates to:
  /// **'All products'**
  String get inventoryHistoryAllProducts;

  /// No description provided for @inventoryHistoryMovementsLabel.
  ///
  /// In en, this message translates to:
  /// **'Movements'**
  String get inventoryHistoryMovementsLabel;

  /// No description provided for @inventoryHistoryShowingCount.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total}'**
  String inventoryHistoryShowingCount(Object shown, Object total);

  /// No description provided for @inventoryHistoryNoMovements.
  ///
  /// In en, this message translates to:
  /// **'No movements found'**
  String get inventoryHistoryNoMovements;

  /// No description provided for @inventoryHistoryPaginationRange.
  ///
  /// In en, this message translates to:
  /// **'{first}–{last} of {total}'**
  String inventoryHistoryPaginationRange(
      Object first, Object last, Object total);

  /// No description provided for @inventoryHistoryFirstPage.
  ///
  /// In en, this message translates to:
  /// **'First page'**
  String get inventoryHistoryFirstPage;

  /// No description provided for @inventoryHistoryPrevPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get inventoryHistoryPrevPage;

  /// No description provided for @inventoryHistoryPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String inventoryHistoryPageOf(Object page, Object total);

  /// No description provided for @inventoryHistoryNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get inventoryHistoryNextPage;

  /// No description provided for @inventoryHistoryLastPage.
  ///
  /// In en, this message translates to:
  /// **'Last page'**
  String get inventoryHistoryLastPage;

  /// No description provided for @inventoryActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String inventoryActionFailed(Object error);

  /// No description provided for @inventoryCancelOrderButton.
  ///
  /// In en, this message translates to:
  /// **'CANCEL ORDER'**
  String get inventoryCancelOrderButton;

  /// No description provided for @inventoryFirstPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'First page'**
  String get inventoryFirstPageTooltip;

  /// No description provided for @inventoryHubLowStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get inventoryHubLowStockLabel;

  /// No description provided for @inventoryHubOutOfStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get inventoryHubOutOfStockLabel;

  /// No description provided for @inventoryHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock Lookup'**
  String get inventoryHubTitle;

  /// No description provided for @inventoryHubTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get inventoryHubTotalLabel;

  /// No description provided for @inventoryKeepButton.
  ///
  /// In en, this message translates to:
  /// **'KEEP'**
  String get inventoryKeepButton;

  /// No description provided for @inventoryLastPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Last page'**
  String get inventoryLastPageTooltip;

  /// No description provided for @inventoryLineCount.
  ///
  /// In en, this message translates to:
  /// **'{count} line(s)'**
  String inventoryLineCount(Object count);

  /// No description provided for @inventoryNextPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get inventoryNextPageTooltip;

  /// No description provided for @inventoryNoProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get inventoryNoProductsFound;

  /// No description provided for @inventoryOrderCount.
  ///
  /// In en, this message translates to:
  /// **'{count} order(s)'**
  String inventoryOrderCount(Object count);

  /// No description provided for @inventoryPaginationPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String inventoryPaginationPage(Object page, Object total);

  /// No description provided for @inventoryPaginationRange.
  ///
  /// In en, this message translates to:
  /// **'{start}–{end} of {total}'**
  String inventoryPaginationRange(Object start, Object end, Object total);

  /// No description provided for @inventoryPreviousPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get inventoryPreviousPageTooltip;

  /// No description provided for @inventoryShowingCount.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total}'**
  String inventoryShowingCount(Object shown, Object total);

  /// No description provided for @inventoryValuationAsOf.
  ///
  /// In en, this message translates to:
  /// **'As of {date}'**
  String inventoryValuationAsOf(Object date);

  /// No description provided for @inventoryValuationColProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get inventoryValuationColProduct;

  /// No description provided for @inventoryValuationColStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get inventoryValuationColStock;

  /// No description provided for @inventoryValuationColValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get inventoryValuationColValue;

  /// No description provided for @inventoryValuationProductsLabel.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get inventoryValuationProductsLabel;

  /// No description provided for @inventoryValuationStockByProduct.
  ///
  /// In en, this message translates to:
  /// **'Stock Value by Product'**
  String get inventoryValuationStockByProduct;

  /// No description provided for @inventoryValuationTitle.
  ///
  /// In en, this message translates to:
  /// **'Inventory Valuation'**
  String get inventoryValuationTitle;

  /// No description provided for @inventoryValuationTotalValue.
  ///
  /// In en, this message translates to:
  /// **'Total Inventory Value'**
  String get inventoryValuationTotalValue;

  /// No description provided for @productionsActionComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get productionsActionComplete;

  /// No description provided for @productionsActionStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get productionsActionStart;

  /// No description provided for @productionsAllComponentsAvailable.
  ///
  /// In en, this message translates to:
  /// **'All components available'**
  String get productionsAllComponentsAvailable;

  /// No description provided for @productionsCancelOrderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel {name}?'**
  String productionsCancelOrderConfirm(Object name);

  /// No description provided for @productionsCancelOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel production order'**
  String get productionsCancelOrderTitle;

  /// No description provided for @productionsCheckAvailabilityButton.
  ///
  /// In en, this message translates to:
  /// **'Check Component Availability'**
  String get productionsCheckAvailabilityButton;

  /// No description provided for @productionsCheckAvailabilityFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to check availability: {error}'**
  String productionsCheckAvailabilityFailed(Object error);

  /// No description provided for @productionsCompleteButton.
  ///
  /// In en, this message translates to:
  /// **'COMPLETE'**
  String get productionsCompleteButton;

  /// No description provided for @productionsCompleteOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete Production Order'**
  String get productionsCompleteOrderTitle;

  /// No description provided for @productionsComponentCount.
  ///
  /// In en, this message translates to:
  /// **'{count} component(s)'**
  String productionsComponentCount(Object count);

  /// No description provided for @productionsComponentNeedHave.
  ///
  /// In en, this message translates to:
  /// **'need {required}, have {onHand}'**
  String productionsComponentNeedHave(Object required, Object onHand);

  /// No description provided for @productionsCreateButton.
  ///
  /// In en, this message translates to:
  /// **'CREATE'**
  String get productionsCreateButton;

  /// No description provided for @productionsDeactivateButton.
  ///
  /// In en, this message translates to:
  /// **'DEACTIVATE'**
  String get productionsDeactivateButton;

  /// No description provided for @productionsDeactivateRecipeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Deactivate \"{name}\"? It will no longer be usable for new production orders.'**
  String productionsDeactivateRecipeConfirm(Object name);

  /// No description provided for @productionsDeactivateRecipeTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate recipe'**
  String get productionsDeactivateRecipeTitle;

  /// No description provided for @productionsDeactivateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get productionsDeactivateTooltip;

  /// No description provided for @productionsInsufficientStock.
  ///
  /// In en, this message translates to:
  /// **'Insufficient stock'**
  String get productionsInsufficientStock;

  /// No description provided for @productionsInvalidProducedQtyError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid produced quantity'**
  String get productionsInvalidProducedQtyError;

  /// No description provided for @productionsMakesLabel.
  ///
  /// In en, this message translates to:
  /// **'Makes'**
  String get productionsMakesLabel;

  /// No description provided for @productionsNewOrderButton.
  ///
  /// In en, this message translates to:
  /// **'NEW ORDER'**
  String get productionsNewOrderButton;

  /// No description provided for @productionsNewOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'New Production Order'**
  String get productionsNewOrderTitle;

  /// No description provided for @productionsNewRecipeButton.
  ///
  /// In en, this message translates to:
  /// **'NEW RECIPE'**
  String get productionsNewRecipeButton;

  /// No description provided for @productionsNoOrdersFound.
  ///
  /// In en, this message translates to:
  /// **'No production orders found'**
  String get productionsNoOrdersFound;

  /// No description provided for @productionsNoRecipesFound.
  ///
  /// In en, this message translates to:
  /// **'No recipes found'**
  String get productionsNoRecipesFound;

  /// No description provided for @productionsNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get productionsNotesLabel;

  /// No description provided for @productionsOrderFallback.
  ///
  /// In en, this message translates to:
  /// **'Order #{id}'**
  String productionsOrderFallback(Object id);

  /// No description provided for @productionsOrdersTab.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get productionsOrdersTab;

  /// No description provided for @productionsPickRecipeQtyError.
  ///
  /// In en, this message translates to:
  /// **'Pick a recipe and enter a valid quantity'**
  String get productionsPickRecipeQtyError;

  /// No description provided for @productionsPlannedLabel.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get productionsPlannedLabel;

  /// No description provided for @productionsPlannedQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Planned Quantity *'**
  String get productionsPlannedQuantityLabel;

  /// No description provided for @productionsProducedLabel.
  ///
  /// In en, this message translates to:
  /// **'Produced'**
  String get productionsProducedLabel;

  /// No description provided for @productionsProducedQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Produced Quantity *'**
  String get productionsProducedQuantityLabel;

  /// No description provided for @productionsProductFallback.
  ///
  /// In en, this message translates to:
  /// **'Product #{id}'**
  String productionsProductFallback(Object id);

  /// No description provided for @productionsRecipeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} recipe(s)'**
  String productionsRecipeCount(Object count);

  /// No description provided for @productionsRecipeFallback.
  ///
  /// In en, this message translates to:
  /// **'Recipe #{id}'**
  String productionsRecipeFallback(Object id);

  /// No description provided for @productionsRecipeLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipe *'**
  String get productionsRecipeLabel;

  /// No description provided for @productionsRecipesTab.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get productionsRecipesTab;

  /// No description provided for @productionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Productions'**
  String get productionsTitle;

  /// No description provided for @productionsWasteQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Waste Quantity'**
  String get productionsWasteQuantityLabel;

  /// No description provided for @purchaseOrdersActionApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get purchaseOrdersActionApprove;

  /// No description provided for @purchaseOrdersActionDoneSnackbar.
  ///
  /// In en, this message translates to:
  /// **'{action} done'**
  String purchaseOrdersActionDoneSnackbar(Object action);

  /// No description provided for @purchaseOrdersActionSendToSupplier.
  ///
  /// In en, this message translates to:
  /// **'Send to Supplier'**
  String get purchaseOrdersActionSendToSupplier;

  /// No description provided for @purchaseOrdersCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel {name}?'**
  String purchaseOrdersCancelConfirm(Object name);

  /// No description provided for @purchaseOrdersCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel purchase order'**
  String get purchaseOrdersCancelTitle;

  /// No description provided for @purchaseOrdersEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Order stock from your suppliers.'**
  String get purchaseOrdersEmptySubtitle;

  /// No description provided for @purchaseOrdersNewButton.
  ///
  /// In en, this message translates to:
  /// **'NEW PURCHASE ORDER'**
  String get purchaseOrdersNewButton;

  /// No description provided for @purchaseOrdersNoOrdersFound.
  ///
  /// In en, this message translates to:
  /// **'No purchase orders found'**
  String get purchaseOrdersNoOrdersFound;

  /// No description provided for @purchaseOrdersPoFallback.
  ///
  /// In en, this message translates to:
  /// **'PO #{id}'**
  String purchaseOrdersPoFallback(Object id);

  /// No description provided for @purchaseOrdersSupplierFallback.
  ///
  /// In en, this message translates to:
  /// **'Supplier #{id}'**
  String purchaseOrdersSupplierFallback(Object id);

  /// No description provided for @purchaseOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase Orders'**
  String get purchaseOrdersTitle;

  /// No description provided for @stockAdjustmentReasonDamaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get stockAdjustmentReasonDamaged;

  /// No description provided for @stockAdjustmentReasonFound.
  ///
  /// In en, this message translates to:
  /// **'Found'**
  String get stockAdjustmentReasonFound;

  /// No description provided for @stockAdjustmentReasonLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get stockAdjustmentReasonLost;

  /// No description provided for @stockAdjustmentReasonManualCount.
  ///
  /// In en, this message translates to:
  /// **'Manual Count'**
  String get stockAdjustmentReasonManualCount;

  /// No description provided for @stockAdjustmentReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get stockAdjustmentReasonOther;

  /// No description provided for @stockAdjustmentReasonReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get stockAdjustmentReasonReceived;

  /// No description provided for @stockAdjustmentReasonReturned.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get stockAdjustmentReasonReturned;

  /// No description provided for @stockAdjustmentsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record manual stock corrections — damaged, lost, found, or recounted items.'**
  String get stockAdjustmentsEmptySubtitle;

  /// No description provided for @stockAdjustmentsMovementsHeader.
  ///
  /// In en, this message translates to:
  /// **'Movements'**
  String get stockAdjustmentsMovementsHeader;

  /// No description provided for @stockAdjustmentsNewButton.
  ///
  /// In en, this message translates to:
  /// **'NEW ADJUSTMENT'**
  String get stockAdjustmentsNewButton;

  /// No description provided for @stockAdjustmentsNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Stock Adjustment'**
  String get stockAdjustmentsNewTitle;

  /// No description provided for @stockAdjustmentsNoMatchingMovements.
  ///
  /// In en, this message translates to:
  /// **'No matching movements found'**
  String get stockAdjustmentsNoMatchingMovements;

  /// No description provided for @stockAdjustmentsNoMovements.
  ///
  /// In en, this message translates to:
  /// **'No movements found'**
  String get stockAdjustmentsNoMovements;

  /// No description provided for @stockAdjustmentsPickProductError.
  ///
  /// In en, this message translates to:
  /// **'Pick a product and enter a non-zero quantity'**
  String get stockAdjustmentsPickProductError;

  /// No description provided for @stockAdjustmentsProductLabel.
  ///
  /// In en, this message translates to:
  /// **'Product *'**
  String get stockAdjustmentsProductLabel;

  /// No description provided for @stockAdjustmentsQuantityChangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity change *'**
  String get stockAdjustmentsQuantityChangeLabel;

  /// No description provided for @stockAdjustmentsQuantityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 10 or -5'**
  String get stockAdjustmentsQuantityHint;

  /// No description provided for @stockAdjustmentsReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get stockAdjustmentsReasonLabel;

  /// No description provided for @stockAdjustmentsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by product or reason...'**
  String get stockAdjustmentsSearchHint;

  /// No description provided for @stockAdjustmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock Adjustments'**
  String get stockAdjustmentsTitle;

  /// No description provided for @suppliersAddButton.
  ///
  /// In en, this message translates to:
  /// **'ADD SUPPLIER'**
  String get suppliersAddButton;

  /// No description provided for @suppliersDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} selected supplier(s)?'**
  String suppliersDeleteConfirm(Object count);

  /// No description provided for @suppliersDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete suppliers: {error}'**
  String suppliersDeleteFailed(Object error);

  /// No description provided for @suppliersDeleteSelectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete selected suppliers'**
  String get suppliersDeleteSelectedTooltip;

  /// No description provided for @suppliersDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'{count} supplier(s) deleted successfully.'**
  String suppliersDeleteSuccess(Object count);

  /// No description provided for @suppliersDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete suppliers'**
  String get suppliersDeleteTitle;

  /// No description provided for @suppliersEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep track of who you buy stock from.'**
  String get suppliersEmptySubtitle;

  /// No description provided for @suppliersNoContactSet.
  ///
  /// In en, this message translates to:
  /// **'No contact set'**
  String get suppliersNoContactSet;

  /// No description provided for @suppliersNoMatchingSuppliersFound.
  ///
  /// In en, this message translates to:
  /// **'No matching suppliers found'**
  String get suppliersNoMatchingSuppliersFound;

  /// No description provided for @suppliersNoSuppliersFound.
  ///
  /// In en, this message translates to:
  /// **'No suppliers found'**
  String get suppliersNoSuppliersFound;

  /// No description provided for @suppliersOwedAmount.
  ///
  /// In en, this message translates to:
  /// **'Owed {amount}'**
  String suppliersOwedAmount(Object amount);

  /// No description provided for @suppliersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search suppliers...'**
  String get suppliersSearchHint;

  /// No description provided for @suppliersSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String suppliersSelectedCount(Object count);

  /// No description provided for @suppliersTitle.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliersTitle;

  /// No description provided for @transferOrdersCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel transfer {name}?'**
  String transferOrdersCancelConfirm(Object name);

  /// No description provided for @transferOrdersCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel transfer'**
  String get transferOrdersCancelTitle;

  /// No description provided for @transferOrdersCancelTransferButton.
  ///
  /// In en, this message translates to:
  /// **'CANCEL TRANSFER'**
  String get transferOrdersCancelTransferButton;

  /// No description provided for @transferOrdersCompletedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Transfer completed'**
  String get transferOrdersCompletedSnackbar;

  /// No description provided for @transferOrdersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} transfer(s)'**
  String transferOrdersCount(Object count);

  /// No description provided for @transferOrdersEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Move stock between store locations.'**
  String get transferOrdersEmptySubtitle;

  /// No description provided for @transferOrdersFailedToCancel.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel: {error}'**
  String transferOrdersFailedToCancel(Object error);

  /// No description provided for @transferOrdersFailedToComplete.
  ///
  /// In en, this message translates to:
  /// **'Failed to complete: {error}'**
  String transferOrdersFailedToComplete(Object error);

  /// No description provided for @transferOrdersMarkComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark Complete'**
  String get transferOrdersMarkComplete;

  /// No description provided for @transferOrdersNewButton.
  ///
  /// In en, this message translates to:
  /// **'NEW TRANSFER'**
  String get transferOrdersNewButton;

  /// No description provided for @transferOrdersNoTransfersFound.
  ///
  /// In en, this message translates to:
  /// **'No transfers found'**
  String get transferOrdersNoTransfersFound;

  /// No description provided for @transferOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer Orders'**
  String get transferOrdersTitle;

  /// No description provided for @transferOrdersTransferFallback.
  ///
  /// In en, this message translates to:
  /// **'Transfer #{id}'**
  String transferOrdersTransferFallback(Object id);

  /// No description provided for @paymentScreenMethodAba.
  ///
  /// In en, this message translates to:
  /// **'ABA Pay'**
  String get paymentScreenMethodAba;

  /// No description provided for @paymentScreenMethodBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get paymentScreenMethodBankTransfer;

  /// No description provided for @paymentScreenMethodWing.
  ///
  /// In en, this message translates to:
  /// **'Wing'**
  String get paymentScreenMethodWing;

  /// No description provided for @paymentScreenMethodAcleda.
  ///
  /// In en, this message translates to:
  /// **'ACLEDA'**
  String get paymentScreenMethodAcleda;

  /// No description provided for @paymentScreenMethodCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get paymentScreenMethodCheck;

  /// No description provided for @paymentScreenMethodOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get paymentScreenMethodOther;

  /// No description provided for @paymentScreenSplitAmountTitle.
  ///
  /// In en, this message translates to:
  /// **'Split {number} Amount'**
  String paymentScreenSplitAmountTitle(Object number);

  /// No description provided for @paymentScreenSplitPayment.
  ///
  /// In en, this message translates to:
  /// **'Split Payment'**
  String get paymentScreenSplitPayment;

  /// No description provided for @paymentScreenPaymentComplete.
  ///
  /// In en, this message translates to:
  /// **'Payment Complete'**
  String get paymentScreenPaymentComplete;

  /// No description provided for @paymentScreenPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get paymentScreenPaymentFailed;

  /// No description provided for @paymentScreenCartCount.
  ///
  /// In en, this message translates to:
  /// **'Cart ({count})'**
  String paymentScreenCartCount(Object count);

  /// No description provided for @paymentScreenBaseModifierLine.
  ///
  /// In en, this message translates to:
  /// **'Base: {base} + Modifier: {modifier}'**
  String paymentScreenBaseModifierLine(Object base, Object modifier);

  /// No description provided for @paymentScreenTotalDue.
  ///
  /// In en, this message translates to:
  /// **'Total Due'**
  String get paymentScreenTotalDue;

  /// No description provided for @paymentScreenCashReceived.
  ///
  /// In en, this message translates to:
  /// **'Cash Received'**
  String get paymentScreenCashReceived;

  /// No description provided for @paymentScreenExact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get paymentScreenExact;

  /// No description provided for @paymentScreenShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get paymentScreenShort;

  /// No description provided for @paymentScreenChargeCash.
  ///
  /// In en, this message translates to:
  /// **'Charge Cash'**
  String get paymentScreenChargeCash;

  /// No description provided for @paymentScreenPayFullAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay Full Amount'**
  String get paymentScreenPayFullAmount;

  /// No description provided for @paymentScreenPayLater.
  ///
  /// In en, this message translates to:
  /// **'Pay Later / Credit'**
  String get paymentScreenPayLater;

  /// No description provided for @paymentScreenCreditRequiresCustomer.
  ///
  /// In en, this message translates to:
  /// **'Select a customer first to sell on credit'**
  String get paymentScreenCreditRequiresCustomer;

  /// No description provided for @paymentScreenCreditDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Credit Sale'**
  String get paymentScreenCreditDialogTitle;

  /// No description provided for @paymentScreenCreditDueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get paymentScreenCreditDueDateLabel;

  /// No description provided for @paymentScreenCreditExpiresLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiration Date (optional)'**
  String get paymentScreenCreditExpiresLabel;

  /// No description provided for @paymentScreenCreditNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get paymentScreenCreditNotesLabel;

  /// No description provided for @paymentScreenCreditConfirm.
  ///
  /// In en, this message translates to:
  /// **'Create Credit Sale'**
  String get paymentScreenCreditConfirm;

  /// No description provided for @paymentScreenCreditDueDateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Due date cannot be before today'**
  String get paymentScreenCreditDueDateInvalid;

  /// No description provided for @paymentScreenCreditExpiresInvalid.
  ///
  /// In en, this message translates to:
  /// **'Expiration date cannot be before the due date'**
  String get paymentScreenCreditExpiresInvalid;

  /// No description provided for @paymentScreenCreditSaleCreated.
  ///
  /// In en, this message translates to:
  /// **'Credit Sale Created'**
  String get paymentScreenCreditSaleCreated;

  /// No description provided for @paymentScreenCreditStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get paymentScreenCreditStatusLabel;

  /// No description provided for @paymentScreenCreditDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get paymentScreenCreditDueLabel;

  /// No description provided for @paymentScreenCreditSaleFailed.
  ///
  /// In en, this message translates to:
  /// **'Credit sale failed: {error}'**
  String paymentScreenCreditSaleFailed(Object error);

  /// No description provided for @creditRepaymentDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get creditRepaymentDialogTitle;

  /// No description provided for @creditPaymentReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'CREDIT PAYMENT'**
  String get creditPaymentReceiptTitle;

  /// No description provided for @creditPaymentReceiptCreditSaleLabel.
  ///
  /// In en, this message translates to:
  /// **'Credit Sale'**
  String get creditPaymentReceiptCreditSaleLabel;

  /// No description provided for @creditPaymentReceiptPreviousBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous Balance'**
  String get creditPaymentReceiptPreviousBalanceLabel;

  /// No description provided for @creditPaymentReceiptPaymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get creditPaymentReceiptPaymentLabel;

  /// No description provided for @creditRepaymentRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining Balance'**
  String get creditRepaymentRemainingLabel;

  /// No description provided for @creditRepaymentAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Amount'**
  String get creditRepaymentAmountLabel;

  /// No description provided for @creditRepaymentPayFullButton.
  ///
  /// In en, this message translates to:
  /// **'Pay Full Balance'**
  String get creditRepaymentPayFullButton;

  /// No description provided for @creditRepaymentMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get creditRepaymentMethodLabel;

  /// No description provided for @creditRepaymentNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get creditRepaymentNotesLabel;

  /// No description provided for @creditRepaymentConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String creditRepaymentConfirmButton(Object amount);

  /// No description provided for @creditRepaymentAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get creditRepaymentAmountInvalid;

  /// No description provided for @creditRepaymentExceedsBalance.
  ///
  /// In en, this message translates to:
  /// **'Amount exceeds remaining balance'**
  String get creditRepaymentExceedsBalance;

  /// No description provided for @creditRepaymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get creditRepaymentSuccess;

  /// No description provided for @creditRepaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed: {error}'**
  String creditRepaymentFailed(Object error);

  /// No description provided for @customerManagementCreditSalesTitle.
  ///
  /// In en, this message translates to:
  /// **'Credit Sales'**
  String get customerManagementCreditSalesTitle;

  /// No description provided for @customerManagementTotalCreditLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Credit'**
  String get customerManagementTotalCreditLabel;

  /// No description provided for @customerManagementTotalPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Paid'**
  String get customerManagementTotalPaidLabel;

  /// No description provided for @customerManagementOutstandingLabel.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get customerManagementOutstandingLabel;

  /// No description provided for @customerManagementRecordPaymentButton.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get customerManagementRecordPaymentButton;

  /// No description provided for @customerManagementPaymentHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get customerManagementPaymentHistoryTitle;

  /// No description provided for @customerManagementNoCreditSales.
  ///
  /// In en, this message translates to:
  /// **'No credit sales'**
  String get customerManagementNoCreditSales;

  /// No description provided for @customerManagementNoPaymentHistory.
  ///
  /// In en, this message translates to:
  /// **'No payments recorded yet'**
  String get customerManagementNoPaymentHistory;

  /// No description provided for @receiptsScreenRecordPaymentAction.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get receiptsScreenRecordPaymentAction;

  /// No description provided for @creditStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get creditStatusOpen;

  /// No description provided for @creditStatusPartiallyPaid.
  ///
  /// In en, this message translates to:
  /// **'Partially Paid'**
  String get creditStatusPartiallyPaid;

  /// No description provided for @creditStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get creditStatusPaid;

  /// No description provided for @creditStatusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get creditStatusOverdue;

  /// No description provided for @creditStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get creditStatusExpired;

  /// No description provided for @creditStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get creditStatusCancelled;

  /// No description provided for @paymentScreenTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total: {amount}'**
  String paymentScreenTotalLabel(Object amount);

  /// No description provided for @paymentScreenRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining: {amount}'**
  String paymentScreenRemainingLabel(Object amount);

  /// No description provided for @paymentScreenAllPaid.
  ///
  /// In en, this message translates to:
  /// **'All paid'**
  String get paymentScreenAllPaid;

  /// No description provided for @paymentScreenRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get paymentScreenRemaining;

  /// No description provided for @paymentScreenOfAmount.
  ///
  /// In en, this message translates to:
  /// **'of {amount}'**
  String paymentScreenOfAmount(Object amount);

  /// No description provided for @paymentScreenCharge.
  ///
  /// In en, this message translates to:
  /// **'Charge'**
  String get paymentScreenCharge;

  /// No description provided for @paymentScreenSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get paymentScreenSubmitting;

  /// No description provided for @paymentScreenInvoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Invoice #{number}'**
  String paymentScreenInvoiceNumber(Object number);

  /// No description provided for @paymentScreenWaitingNumber.
  ///
  /// In en, this message translates to:
  /// **'Waiting Number  #{number}'**
  String paymentScreenWaitingNumber(Object number);

  /// No description provided for @paymentScreenReceiptHeader.
  ///
  /// In en, this message translates to:
  /// **'KAKNNEA POS'**
  String get paymentScreenReceiptHeader;

  /// No description provided for @paymentScreenPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get paymentScreenPayments;

  /// No description provided for @paymentScreenPrintReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print Receipt'**
  String get paymentScreenPrintReceipt;

  /// No description provided for @paymentScreenEmailReceipt.
  ///
  /// In en, this message translates to:
  /// **'Email Receipt'**
  String get paymentScreenEmailReceipt;

  /// No description provided for @paymentScreenNewSale.
  ///
  /// In en, this message translates to:
  /// **'New Sale'**
  String get paymentScreenNewSale;

  /// No description provided for @paymentScreenTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get paymentScreenTryAgain;

  /// No description provided for @paymentScreenWaitingTicketSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment succeeded, but waiting ticket was not saved: {error}'**
  String paymentScreenWaitingTicketSaveFailed(Object error);

  /// No description provided for @paymentScreenSaleFailed.
  ///
  /// In en, this message translates to:
  /// **'Sale failed: {error}'**
  String paymentScreenSaleFailed(Object error);

  /// No description provided for @itemManagementDeleteItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete items'**
  String get itemManagementDeleteItemsTitle;

  /// No description provided for @itemManagementDeleteItemsMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} selected item(s)?'**
  String itemManagementDeleteItemsMessage(Object count);

  /// No description provided for @itemManagementItemsDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'{count} item(s) deleted successfully.'**
  String itemManagementItemsDeletedSuccess(Object count);

  /// No description provided for @itemManagementFailedToDeleteItems.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete items: {error}'**
  String itemManagementFailedToDeleteItems(Object error);

  /// No description provided for @itemManagementAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get itemManagementAddItem;

  /// No description provided for @itemManagementDeleteSelectedItemsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete selected items'**
  String get itemManagementDeleteSelectedItemsTooltip;

  /// No description provided for @itemManagementSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String itemManagementSelectedCount(Object count);

  /// No description provided for @itemManagementSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search items by name or SKU...'**
  String get itemManagementSearchHint;

  /// No description provided for @itemManagementShowingCount.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total}'**
  String itemManagementShowingCount(Object shown, Object total);

  /// No description provided for @itemManagementNoItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get itemManagementNoItemsFound;

  /// No description provided for @itemManagementNoCategorySet.
  ///
  /// In en, this message translates to:
  /// **'No category set'**
  String get itemManagementNoCategorySet;

  /// No description provided for @itemManagementFirstPage.
  ///
  /// In en, this message translates to:
  /// **'First page'**
  String get itemManagementFirstPage;

  /// No description provided for @itemManagementPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get itemManagementPreviousPage;

  /// No description provided for @itemManagementPageOfPages.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String itemManagementPageOfPages(Object current, Object total);

  /// No description provided for @itemManagementNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get itemManagementNextPage;

  /// No description provided for @itemManagementLastPage.
  ///
  /// In en, this message translates to:
  /// **'Last page'**
  String get itemManagementLastPage;

  /// No description provided for @itemManagementRangeOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{first}–{last} of {total}'**
  String itemManagementRangeOfTotal(Object first, Object last, Object total);

  /// No description provided for @itemManagementEmptyStateDescription.
  ///
  /// In en, this message translates to:
  /// **'Create and manage the items sold at the POS.'**
  String get itemManagementEmptyStateDescription;

  /// No description provided for @itemManagementProductImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Product Image'**
  String get itemManagementProductImageTitle;

  /// No description provided for @itemManagementImageUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get itemManagementImageUrlLabel;

  /// No description provided for @itemManagementUseUrl.
  ///
  /// In en, this message translates to:
  /// **'Use URL'**
  String get itemManagementUseUrl;

  /// No description provided for @itemManagementOrUploadFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Or upload from device'**
  String get itemManagementOrUploadFromDevice;

  /// No description provided for @itemManagementUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload Image'**
  String get itemManagementUploadImage;

  /// No description provided for @itemManagementSkuRequired.
  ///
  /// In en, this message translates to:
  /// **'SKU is required'**
  String get itemManagementSkuRequired;

  /// No description provided for @itemManagementBarcodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Barcode is required'**
  String get itemManagementBarcodeRequired;

  /// No description provided for @itemManagementKhmerNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Khmer name is required'**
  String get itemManagementKhmerNameRequired;

  /// No description provided for @itemManagementPleaseSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get itemManagementPleaseSelectCategory;

  /// No description provided for @itemManagementItemUpdated.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" updated'**
  String itemManagementItemUpdated(Object name);

  /// No description provided for @itemManagementItemCreated.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" created'**
  String itemManagementItemCreated(Object name);

  /// No description provided for @itemManagementFailedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String itemManagementFailedToSave(Object error);

  /// No description provided for @itemManagementModifiersNotUpdated.
  ///
  /// In en, this message translates to:
  /// **'Item saved, but modifiers were not updated: {error}'**
  String itemManagementModifiersNotUpdated(Object error);

  /// No description provided for @itemManagementEditItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get itemManagementEditItemTitle;

  /// No description provided for @itemManagementNewItemTitle.
  ///
  /// In en, this message translates to:
  /// **'New Item'**
  String get itemManagementNewItemTitle;

  /// No description provided for @itemManagementSectionBasicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Info'**
  String get itemManagementSectionBasicInfo;

  /// No description provided for @itemManagementSelectCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get itemManagementSelectCategoryHint;

  /// No description provided for @itemManagementSectionDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get itemManagementSectionDescriptionOptional;

  /// No description provided for @itemManagementDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Additional details visible in POS ticket'**
  String get itemManagementDescriptionHint;

  /// No description provided for @itemManagementSectionPricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get itemManagementSectionPricing;

  /// No description provided for @itemManagementSellPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Sell Price *'**
  String get itemManagementSellPriceLabel;

  /// No description provided for @itemManagementInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get itemManagementInvalidNumber;

  /// No description provided for @itemManagementSectionInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get itemManagementSectionInventory;

  /// No description provided for @itemManagementTrackInventoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Track inventory'**
  String get itemManagementTrackInventoryTitle;

  /// No description provided for @itemManagementManageStockQuantitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage stock quantity'**
  String get itemManagementManageStockQuantitySubtitle;

  /// No description provided for @itemManagementPurchasableTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow purchasing from supplier'**
  String get itemManagementPurchasableTitle;

  /// No description provided for @itemManagementPurchasableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Can be added to a Purchase Order'**
  String get itemManagementPurchasableSubtitle;

  /// No description provided for @itemManagementInitialStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Initial Stock'**
  String get itemManagementInitialStockLabel;

  /// No description provided for @itemManagementLowStockAlertLabel.
  ///
  /// In en, this message translates to:
  /// **'Low Stock Alert'**
  String get itemManagementLowStockAlertLabel;

  /// No description provided for @itemManagementSectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get itemManagementSectionStatus;

  /// No description provided for @itemManagementProductAvailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Product is available for sale'**
  String get itemManagementProductAvailableSubtitle;

  /// No description provided for @itemManagementSellableTitle.
  ///
  /// In en, this message translates to:
  /// **'Sellable'**
  String get itemManagementSellableTitle;

  /// No description provided for @itemManagementCanBeSoldInPosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Can be sold in POS'**
  String get itemManagementCanBeSoldInPosSubtitle;

  /// No description provided for @itemManagementSectionModifiers.
  ///
  /// In en, this message translates to:
  /// **'Modifiers'**
  String get itemManagementSectionModifiers;

  /// No description provided for @itemManagementNoModifiersYet.
  ///
  /// In en, this message translates to:
  /// **'No modifiers yet. Create one from Modifiers management first.'**
  String get itemManagementNoModifiersYet;

  /// No description provided for @itemManagementNoOptions.
  ///
  /// In en, this message translates to:
  /// **'No options'**
  String get itemManagementNoOptions;

  /// No description provided for @itemManagementSectionImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get itemManagementSectionImage;

  /// No description provided for @itemManagementSavingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get itemManagementSavingEllipsis;

  /// No description provided for @itemManagementUpdateItem.
  ///
  /// In en, this message translates to:
  /// **'Update Item'**
  String get itemManagementUpdateItem;

  /// No description provided for @itemManagementCreateItem.
  ///
  /// In en, this message translates to:
  /// **'Create Item'**
  String get itemManagementCreateItem;

  /// No description provided for @employeeManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Employee List'**
  String get employeeManagementTitle;

  /// No description provided for @employeeManagementDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete employees'**
  String get employeeManagementDeleteDialogTitle;

  /// No description provided for @employeeManagementDeleteDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} selected employee(s)?'**
  String employeeManagementDeleteDialogMessage(Object count);

  /// No description provided for @employeeManagementDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'{count} employee(s) deleted successfully.'**
  String employeeManagementDeleteSuccess(Object count);

  /// No description provided for @employeeManagementDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete employees: {error}'**
  String employeeManagementDeleteFailed(Object error);

  /// No description provided for @employeeManagementAddEmployee.
  ///
  /// In en, this message translates to:
  /// **'ADD EMPLOYEE'**
  String get employeeManagementAddEmployee;

  /// No description provided for @employeeManagementDeleteSelectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete selected employees'**
  String get employeeManagementDeleteSelectedTooltip;

  /// No description provided for @employeeManagementSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String employeeManagementSelectedCount(Object count);

  /// No description provided for @employeeManagementSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search employees...'**
  String get employeeManagementSearchHint;

  /// No description provided for @employeeManagementEmployeesHeader.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get employeeManagementEmployeesHeader;

  /// No description provided for @employeeManagementShowingCount.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total}'**
  String employeeManagementShowingCount(Object shown, Object total);

  /// No description provided for @employeeManagementNoEmployeesFound.
  ///
  /// In en, this message translates to:
  /// **'No employees found'**
  String get employeeManagementNoEmployeesFound;

  /// No description provided for @employeeManagementNoPositionSet.
  ///
  /// In en, this message translates to:
  /// **'No position set'**
  String get employeeManagementNoPositionSet;

  /// No description provided for @employeeManagementRangeOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{first}–{last} of {total}'**
  String employeeManagementRangeOfTotal(
      Object first, Object last, Object total);

  /// No description provided for @employeeManagementFirstPage.
  ///
  /// In en, this message translates to:
  /// **'First page'**
  String get employeeManagementFirstPage;

  /// No description provided for @employeeManagementPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get employeeManagementPreviousPage;

  /// No description provided for @employeeManagementPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String employeeManagementPageOf(Object current, Object total);

  /// No description provided for @employeeManagementNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get employeeManagementNextPage;

  /// No description provided for @employeeManagementLastPage.
  ///
  /// In en, this message translates to:
  /// **'Last page'**
  String get employeeManagementLastPage;

  /// No description provided for @employeeManagementEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get employeeManagementEmptyTitle;

  /// No description provided for @employeeManagementEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create sets of options that can be applied to employees.'**
  String get employeeManagementEmptyDescription;

  /// No description provided for @modifierManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Modifiers'**
  String get modifierManagementTitle;

  /// No description provided for @modifierManagementDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete modifiers'**
  String get modifierManagementDeleteDialogTitle;

  /// No description provided for @modifierManagementDeleteDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} selected modifier(s)?'**
  String modifierManagementDeleteDialogMessage(Object count);

  /// No description provided for @modifierManagementDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'{count} modifier(s) deleted successfully.'**
  String modifierManagementDeleteSuccess(Object count);

  /// No description provided for @modifierManagementDeleteFailedDefault.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete modifiers.'**
  String get modifierManagementDeleteFailedDefault;

  /// No description provided for @modifierManagementEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Item modifiers'**
  String get modifierManagementEmptyTitle;

  /// No description provided for @modifierManagementEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create sets of options that can be applied to items.'**
  String get modifierManagementEmptyDescription;

  /// No description provided for @modifierManagementAddModifier.
  ///
  /// In en, this message translates to:
  /// **'ADD MODIFIER'**
  String get modifierManagementAddModifier;

  /// No description provided for @modifierManagementDeleteSelectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete selected modifiers'**
  String get modifierManagementDeleteSelectedTooltip;

  /// No description provided for @modifierManagementSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String modifierManagementSelectedCount(Object count);

  /// No description provided for @modifierManagementSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search modifiers...'**
  String get modifierManagementSearchHint;

  /// No description provided for @modifierManagementSectionHeader.
  ///
  /// In en, this message translates to:
  /// **'Modifier'**
  String get modifierManagementSectionHeader;

  /// No description provided for @modifierManagementShowingCount.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total}'**
  String modifierManagementShowingCount(Object shown, Object total);

  /// No description provided for @modifierManagementNoModifiersFound.
  ///
  /// In en, this message translates to:
  /// **'No modifiers found'**
  String get modifierManagementNoModifiersFound;

  /// No description provided for @modifierManagementNoOptions.
  ///
  /// In en, this message translates to:
  /// **'No options'**
  String get modifierManagementNoOptions;

  /// No description provided for @modifierManagementApplyToProductsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Apply to products'**
  String get modifierManagementApplyToProductsTooltip;

  /// No description provided for @modifierManagementProductsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated products for \"{name}\".'**
  String modifierManagementProductsUpdated(Object name);

  /// No description provided for @modifierManagementRangeOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{first}–{last} of {total}'**
  String modifierManagementRangeOfTotal(
      Object first, Object last, Object total);

  /// No description provided for @modifierManagementFirstPage.
  ///
  /// In en, this message translates to:
  /// **'First page'**
  String get modifierManagementFirstPage;

  /// No description provided for @modifierManagementPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get modifierManagementPreviousPage;

  /// No description provided for @modifierManagementPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String modifierManagementPageOf(Object current, Object total);

  /// No description provided for @modifierManagementNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get modifierManagementNextPage;

  /// No description provided for @modifierManagementLastPage.
  ///
  /// In en, this message translates to:
  /// **'Last page'**
  String get modifierManagementLastPage;

  /// No description provided for @modifierProductAssignmentSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {error}'**
  String modifierProductAssignmentSearchFailed(Object error);

  /// No description provided for @modifierProductAssignmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply \"{groupName}\" to products'**
  String modifierProductAssignmentTitle(Object groupName);

  /// No description provided for @modifierProductAssignmentDescription.
  ///
  /// In en, this message translates to:
  /// **'Customers will be able to choose from this modifier whenever a checked product is added to the cart.'**
  String get modifierProductAssignmentDescription;

  /// No description provided for @modifierProductAssignmentSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} product(s) selected'**
  String modifierProductAssignmentSelectedCount(Object count);

  /// No description provided for @modifierProductAssignmentNoProducts.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get modifierProductAssignmentNoProducts;

  /// No description provided for @openTicketPageEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No held tickets'**
  String get openTicketPageEmptyTitle;

  /// No description provided for @openTicketPageEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Hold\" on the POS screen to save a sale here'**
  String get openTicketPageEmptySubtitle;

  /// No description provided for @openTicketPageTicketNumber.
  ///
  /// In en, this message translates to:
  /// **'Ticket #{number}'**
  String openTicketPageTicketNumber(Object number);

  /// No description provided for @openTicketPageItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String openTicketPageItemCount(Object count);

  /// No description provided for @openTicketPageJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get openTicketPageJustNow;

  /// No description provided for @openTicketPageMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String openTicketPageMinutesAgo(Object minutes);

  /// No description provided for @openTicketPageHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String openTicketPageHoursAgo(Object hours);

  /// No description provided for @openTicketPageDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String openTicketPageDaysAgo(Object days);

  /// No description provided for @openTicketPageRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get openTicketPageRestore;

  /// No description provided for @paginationFirstPage.
  ///
  /// In en, this message translates to:
  /// **'First page'**
  String get paginationFirstPage;

  /// No description provided for @paginationLastPage.
  ///
  /// In en, this message translates to:
  /// **'Last page'**
  String get paginationLastPage;

  /// No description provided for @paginationNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get paginationNextPage;

  /// No description provided for @paginationPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String paginationPageOf(Object current, Object total);

  /// No description provided for @paginationPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get paginationPreviousPage;

  /// No description provided for @paginationRangeOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{first}–{last} of {total}'**
  String paginationRangeOfTotal(Object first, Object last, Object total);

  /// No description provided for @paginationShowingOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total}'**
  String paginationShowingOfTotal(Object shown, Object total);

  /// No description provided for @permissionScreenEmpty.
  ///
  /// In en, this message translates to:
  /// **'No permissions found'**
  String get permissionScreenEmpty;

  /// No description provided for @permissionScreenListHeader.
  ///
  /// In en, this message translates to:
  /// **'Permission List'**
  String get permissionScreenListHeader;

  /// No description provided for @permissionScreenNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching permissions found'**
  String get permissionScreenNoMatch;

  /// No description provided for @permissionScreenSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search permissions...'**
  String get permissionScreenSearchHint;

  /// No description provided for @permissionScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissionScreenTitle;

  /// No description provided for @phoneScanScreenBarcodeSent.
  ///
  /// In en, this message translates to:
  /// **'{value} sent to POS'**
  String phoneScanScreenBarcodeSent(Object value);

  /// No description provided for @phoneScanScreenConnectButton.
  ///
  /// In en, this message translates to:
  /// **'Connect to POS'**
  String get phoneScanScreenConnectButton;

  /// No description provided for @phoneScanScreenConnectedReady.
  ///
  /// In en, this message translates to:
  /// **'Connected — point the camera at a 1D barcode'**
  String get phoneScanScreenConnectedReady;

  /// No description provided for @phoneScanScreenConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect. Check the server URL, Wi-Fi and code.'**
  String get phoneScanScreenConnectFailed;

  /// No description provided for @phoneScanScreenConnectHeadline.
  ///
  /// In en, this message translates to:
  /// **'Connect this phone to the active POS'**
  String get phoneScanScreenConnectHeadline;

  /// No description provided for @phoneScanScreenConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get phoneScanScreenConnecting;

  /// No description provided for @phoneScanScreenConnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The phone and POS must use the same Wi-Fi and backend server.'**
  String get phoneScanScreenConnectSubtitle;

  /// No description provided for @phoneScanScreenDetectedSending.
  ///
  /// In en, this message translates to:
  /// **'{value} detected — sending to POS'**
  String phoneScanScreenDetectedSending(Object value);

  /// No description provided for @phoneScanScreenDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get phoneScanScreenDisconnected;

  /// No description provided for @phoneScanScreenDisconnectTooltip.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get phoneScanScreenDisconnectTooltip;

  /// No description provided for @phoneScanScreenEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 8-character code shown on the POS'**
  String get phoneScanScreenEnterCode;

  /// No description provided for @phoneScanScreenFlashlight.
  ///
  /// In en, this message translates to:
  /// **'Flashlight'**
  String get phoneScanScreenFlashlight;

  /// No description provided for @phoneScanScreenLastBarcode.
  ///
  /// In en, this message translates to:
  /// **'Last barcode: {barcode}'**
  String phoneScanScreenLastBarcode(Object barcode);

  /// No description provided for @phoneScanScreenPosEndedSession.
  ///
  /// In en, this message translates to:
  /// **'The POS ended this scanner session'**
  String get phoneScanScreenPosEndedSession;

  /// No description provided for @phoneScanScreenReadyToScan.
  ///
  /// In en, this message translates to:
  /// **'Ready to scan'**
  String get phoneScanScreenReadyToScan;

  /// No description provided for @phoneScanScreenRelayError.
  ///
  /// In en, this message translates to:
  /// **'Scanner relay error'**
  String get phoneScanScreenRelayError;

  /// No description provided for @phoneScanScreenServerUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'POS server URL'**
  String get phoneScanScreenServerUrlLabel;

  /// No description provided for @phoneScanScreenSessionCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Example: 7KMX4P2R'**
  String get phoneScanScreenSessionCodeHint;

  /// No description provided for @phoneScanScreenSessionCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'POS session code'**
  String get phoneScanScreenSessionCodeLabel;

  /// No description provided for @phoneScanScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone 1D Scanner'**
  String get phoneScanScreenTitle;

  /// No description provided for @posDrawerAddCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add Customer'**
  String get posDrawerAddCustomer;

  /// No description provided for @posDrawerAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get posDrawerAddItem;

  /// No description provided for @posDrawerAddTable.
  ///
  /// In en, this message translates to:
  /// **'Add Table'**
  String get posDrawerAddTable;

  /// No description provided for @posDrawerCustomerList.
  ///
  /// In en, this message translates to:
  /// **'Customer List'**
  String get posDrawerCustomerList;

  /// No description provided for @posDrawerEmployees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get posDrawerEmployees;

  /// No description provided for @posDrawerEmployeesList.
  ///
  /// In en, this message translates to:
  /// **'Employees List'**
  String get posDrawerEmployeesList;

  /// No description provided for @posDrawerHeldTickets.
  ///
  /// In en, this message translates to:
  /// **'Held Tickets'**
  String get posDrawerHeldTickets;

  /// No description provided for @posDrawerInventoryCounts.
  ///
  /// In en, this message translates to:
  /// **'Inventory Counts'**
  String get posDrawerInventoryCounts;

  /// No description provided for @posDrawerInventoryHistory.
  ///
  /// In en, this message translates to:
  /// **'Inventory History'**
  String get posDrawerInventoryHistory;

  /// No description provided for @posDrawerInventoryManagement.
  ///
  /// In en, this message translates to:
  /// **'Inventory Management'**
  String get posDrawerInventoryManagement;

  /// No description provided for @posDrawerInventoryValuation.
  ///
  /// In en, this message translates to:
  /// **'Inventory Valuation'**
  String get posDrawerInventoryValuation;

  /// No description provided for @posDrawerItemList.
  ///
  /// In en, this message translates to:
  /// **'Item List'**
  String get posDrawerItemList;

  /// No description provided for @posDrawerLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get posDrawerLogoutConfirm;

  /// No description provided for @posDrawerModifiers.
  ///
  /// In en, this message translates to:
  /// **'Modifiers'**
  String get posDrawerModifiers;

  /// No description provided for @posDrawerOnlineStatus.
  ///
  /// In en, this message translates to:
  /// **'Online · Cashier'**
  String get posDrawerOnlineStatus;

  /// No description provided for @posDrawerPermission.
  ///
  /// In en, this message translates to:
  /// **'Permission'**
  String get posDrawerPermission;

  /// No description provided for @posDrawerProductions.
  ///
  /// In en, this message translates to:
  /// **'Productions'**
  String get posDrawerProductions;

  /// No description provided for @posDrawerPurchaseOrders.
  ///
  /// In en, this message translates to:
  /// **'Purchase Orders'**
  String get posDrawerPurchaseOrders;

  /// No description provided for @posDrawerRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get posDrawerRegister;

  /// No description provided for @posDrawerRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get posDrawerRole;

  /// No description provided for @posDrawerSalesByCashier.
  ///
  /// In en, this message translates to:
  /// **'Sales by Cashier'**
  String get posDrawerSalesByCashier;

  /// No description provided for @posDrawerSalesByModifier.
  ///
  /// In en, this message translates to:
  /// **'Sales by Modifier'**
  String get posDrawerSalesByModifier;

  /// No description provided for @posDrawerStockAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Stock Adjustments'**
  String get posDrawerStockAdjustments;

  /// No description provided for @posDrawerStockLookup.
  ///
  /// In en, this message translates to:
  /// **'Stock Lookup'**
  String get posDrawerStockLookup;

  /// No description provided for @posDrawerStoreName.
  ///
  /// In en, this message translates to:
  /// **'Kaknnea Store'**
  String get posDrawerStoreName;

  /// No description provided for @posDrawerSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get posDrawerSuppliers;

  /// No description provided for @posDrawerTableList.
  ///
  /// In en, this message translates to:
  /// **'Table List'**
  String get posDrawerTableList;

  /// No description provided for @posDrawerTransferOrders.
  ///
  /// In en, this message translates to:
  /// **'Transfer Orders'**
  String get posDrawerTransferOrders;

  /// No description provided for @posDrawerUnits.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get posDrawerUnits;

  /// No description provided for @posDrawerUserAccount.
  ///
  /// In en, this message translates to:
  /// **'User Account'**
  String get posDrawerUserAccount;

  /// No description provided for @posSettingsScreenAlertEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Alert email (optional)'**
  String get posSettingsScreenAlertEmailLabel;

  /// No description provided for @posSettingsScreenAutoPrint.
  ///
  /// In en, this message translates to:
  /// **'Auto-print after payment'**
  String get posSettingsScreenAutoPrint;

  /// No description provided for @posSettingsScreenCashRounding.
  ///
  /// In en, this message translates to:
  /// **'Cash Rounding'**
  String get posSettingsScreenCashRounding;

  /// No description provided for @posSettingsScreenColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get posSettingsScreenColumns;

  /// No description provided for @posSettingsScreenDefaultLayout.
  ///
  /// In en, this message translates to:
  /// **'Default layout'**
  String get posSettingsScreenDefaultLayout;

  /// No description provided for @posSettingsScreenDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get posSettingsScreenDiscount;

  /// No description provided for @posSettingsScreenEnableFavorites.
  ///
  /// In en, this message translates to:
  /// **'Enable favorites'**
  String get posSettingsScreenEnableFavorites;

  /// No description provided for @posSettingsScreenEnableKitchenDisplay.
  ///
  /// In en, this message translates to:
  /// **'Enable kitchen display'**
  String get posSettingsScreenEnableKitchenDisplay;

  /// No description provided for @posSettingsScreenKitchenDisplay.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Display'**
  String get posSettingsScreenKitchenDisplay;

  /// No description provided for @posSettingsScreenKitchenPrinterLabel.
  ///
  /// In en, this message translates to:
  /// **'Kitchen printer name/IP'**
  String get posSettingsScreenKitchenPrinterLabel;

  /// No description provided for @posSettingsScreenKitchenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send orders to kitchen printer'**
  String get posSettingsScreenKitchenSubtitle;

  /// No description provided for @posSettingsScreenLowStockAlert.
  ///
  /// In en, this message translates to:
  /// **'Low stock alert'**
  String get posSettingsScreenLowStockAlert;

  /// No description provided for @posSettingsScreenPaperWidth.
  ///
  /// In en, this message translates to:
  /// **'Paper width (mm)'**
  String get posSettingsScreenPaperWidth;

  /// No description provided for @posSettingsScreenPinFavoriteProducts.
  ///
  /// In en, this message translates to:
  /// **'Pin favourite products'**
  String get posSettingsScreenPinFavoriteProducts;

  /// No description provided for @posSettingsScreenPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cashier must enter PIN on launch'**
  String get posSettingsScreenPinSubtitle;

  /// No description provided for @posSettingsScreenQuickPresets.
  ///
  /// In en, this message translates to:
  /// **'Quick presets: {presets}'**
  String posSettingsScreenQuickPresets(Object presets);

  /// No description provided for @posSettingsScreenRequireDiscountReason.
  ///
  /// In en, this message translates to:
  /// **'Require reason for discount'**
  String get posSettingsScreenRequireDiscountReason;

  /// No description provided for @posSettingsScreenRequirePin.
  ///
  /// In en, this message translates to:
  /// **'Require PIN to open POS'**
  String get posSettingsScreenRequirePin;

  /// No description provided for @posSettingsScreenRoundingInterval.
  ///
  /// In en, this message translates to:
  /// **'Rounding interval'**
  String get posSettingsScreenRoundingInterval;

  /// No description provided for @posSettingsScreenRoundingMode.
  ///
  /// In en, this message translates to:
  /// **'Rounding mode'**
  String get posSettingsScreenRoundingMode;

  /// No description provided for @posSettingsScreenSaleScreen.
  ///
  /// In en, this message translates to:
  /// **'Sale Screen'**
  String get posSettingsScreenSaleScreen;

  /// No description provided for @posSettingsScreenSaveAll.
  ///
  /// In en, this message translates to:
  /// **'Save All Settings'**
  String get posSettingsScreenSaveAll;

  /// No description provided for @posSettingsScreenSaveAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save all settings'**
  String get posSettingsScreenSaveAllTooltip;

  /// No description provided for @posSettingsScreenSaved.
  ///
  /// In en, this message translates to:
  /// **'POS settings saved'**
  String get posSettingsScreenSaved;

  /// No description provided for @posSettingsScreenSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String posSettingsScreenSaveFailed(Object error);

  /// No description provided for @posSettingsScreenSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get posSettingsScreenSaving;

  /// No description provided for @posSettingsScreenSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get posSettingsScreenSecurity;

  /// No description provided for @posSettingsScreenShowBarcodes.
  ///
  /// In en, this message translates to:
  /// **'Show barcodes'**
  String get posSettingsScreenShowBarcodes;

  /// No description provided for @posSettingsScreenShowCustomerInfo.
  ///
  /// In en, this message translates to:
  /// **'Show customer info'**
  String get posSettingsScreenShowCustomerInfo;

  /// No description provided for @posSettingsScreenStockAlerts.
  ///
  /// In en, this message translates to:
  /// **'Stock Alerts'**
  String get posSettingsScreenStockAlerts;

  /// No description provided for @receiptsScreenBaseWithUnit.
  ///
  /// In en, this message translates to:
  /// **'Base: {amount}/{unit}'**
  String receiptsScreenBaseWithUnit(Object amount, Object unit);

  /// No description provided for @receiptsScreenConfirmRefundButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm Refund'**
  String get receiptsScreenConfirmRefundButton;

  /// No description provided for @receiptsScreenDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String receiptsScreenDaysAgo(Object days);

  /// No description provided for @receiptsScreenDeliveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get receiptsScreenDeliveryLabel;

  /// No description provided for @receiptsScreenDescriptionHeader.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get receiptsScreenDescriptionHeader;

  /// No description provided for @receiptsScreenEachUnitFallback.
  ///
  /// In en, this message translates to:
  /// **'ea'**
  String get receiptsScreenEachUnitFallback;

  /// No description provided for @receiptsScreenEmailDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the customer\'s email address:'**
  String get receiptsScreenEmailDialogBody;

  /// No description provided for @receiptsScreenEmailDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Email Receipt'**
  String get receiptsScreenEmailDialogTitle;

  /// No description provided for @receiptsScreenEmailHint.
  ///
  /// In en, this message translates to:
  /// **'customer@example.com'**
  String get receiptsScreenEmailHint;

  /// No description provided for @receiptsScreenEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Complete a sale to see it here'**
  String get receiptsScreenEmptySubtitle;

  /// No description provided for @receiptsScreenEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No receipts yet'**
  String get receiptsScreenEmptyTitle;

  /// No description provided for @receiptsScreenExchangeRateValue.
  ///
  /// In en, this message translates to:
  /// **'1 USD = {rate} KHR'**
  String receiptsScreenExchangeRateValue(Object rate);

  /// No description provided for @receiptsScreenHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String receiptsScreenHoursAgo(Object hours);

  /// No description provided for @receiptsScreenItemFallback.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get receiptsScreenItemFallback;

  /// No description provided for @receiptsScreenJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get receiptsScreenJustNow;

  /// No description provided for @receiptsScreenManagerEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Manager email'**
  String get receiptsScreenManagerEmailLabel;

  /// No description provided for @receiptsScreenManagerPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Manager password'**
  String get receiptsScreenManagerPasswordLabel;

  /// No description provided for @receiptsScreenMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String receiptsScreenMinutesAgo(Object minutes);

  /// No description provided for @receiptsScreenModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get receiptsScreenModeLabel;

  /// No description provided for @receiptsScreenModifiersWithUnit.
  ///
  /// In en, this message translates to:
  /// **'Modifiers: {amount}/{unit}'**
  String receiptsScreenModifiersWithUnit(Object amount, Object unit);

  /// No description provided for @receiptsScreenOtherLabel.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get receiptsScreenOtherLabel;

  /// No description provided for @receiptsScreenPaymentFallback.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get receiptsScreenPaymentFallback;

  /// No description provided for @receiptsScreenPoweredBy.
  ///
  /// In en, this message translates to:
  /// **'Powered by KAKNNEA'**
  String get receiptsScreenPoweredBy;

  /// No description provided for @receiptsScreenPrintNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Print receipt - connect a printer'**
  String get receiptsScreenPrintNotConnected;

  /// No description provided for @receiptsScreenPrintReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print Receipt'**
  String get receiptsScreenPrintReceipt;

  /// No description provided for @receiptsScreenPrintAll.
  ///
  /// In en, this message translates to:
  /// **'Print All'**
  String get receiptsScreenPrintAll;

  /// No description provided for @receiptsScreenPrintAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'Print all receipts'**
  String get receiptsScreenPrintAllTooltip;

  /// No description provided for @receiptsScreenPrintAllConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Print all receipts?'**
  String get receiptsScreenPrintAllConfirmTitle;

  /// No description provided for @receiptsScreenPrintAllConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Print all {count} receipts?'**
  String receiptsScreenPrintAllConfirmBody(Object count);

  /// No description provided for @receiptsScreenPreparingReceipts.
  ///
  /// In en, this message translates to:
  /// **'Preparing receipts...'**
  String get receiptsScreenPreparingReceipts;

  /// No description provided for @receiptsScreenPrintingReceipts.
  ///
  /// In en, this message translates to:
  /// **'Printing receipts...'**
  String get receiptsScreenPrintingReceipts;

  /// No description provided for @receiptsScreenPrintAllProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total}'**
  String receiptsScreenPrintAllProgress(Object done, Object total);

  /// No description provided for @receiptsScreenLoadReceiptFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load receipt {invoice}.'**
  String receiptsScreenLoadReceiptFailed(Object invoice);

  /// No description provided for @receiptsScreenPrintReceiptFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to print receipt.'**
  String get receiptsScreenPrintReceiptFailed;

  /// No description provided for @receiptsScreenPrintAllDone.
  ///
  /// In en, this message translates to:
  /// **'Printed {printed} of {total} receipts.'**
  String receiptsScreenPrintAllDone(Object printed, Object total);

  /// No description provided for @receiptsScreenPrintAllPartialFailure.
  ///
  /// In en, this message translates to:
  /// **'{count} receipt(s) could not be printed.'**
  String receiptsScreenPrintAllPartialFailure(Object count);

  /// No description provided for @receiptsScreenSavePdf.
  ///
  /// In en, this message translates to:
  /// **'Save PDF'**
  String get receiptsScreenSavePdf;

  /// No description provided for @receiptsScreenReasonOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get receiptsScreenReasonOptionalLabel;

  /// No description provided for @receiptsScreenReceiptCount.
  ///
  /// In en, this message translates to:
  /// **'{count} receipt(s)'**
  String receiptsScreenReceiptCount(Object count);

  /// No description provided for @receiptsScreenReceiptNoLabel.
  ///
  /// In en, this message translates to:
  /// **'Receipt No.'**
  String get receiptsScreenReceiptNoLabel;

  /// No description provided for @receiptsScreenReceiptSentTo.
  ///
  /// In en, this message translates to:
  /// **'Receipt sent to {email}'**
  String receiptsScreenReceiptSentTo(Object email);

  /// No description provided for @receiptsScreenRefundAlreadyRefundedLine.
  ///
  /// In en, this message translates to:
  /// **'Already refunded: {amount}'**
  String receiptsScreenRefundAlreadyRefundedLine(Object amount);

  /// No description provided for @receiptsScreenRefundAmountLine.
  ///
  /// In en, this message translates to:
  /// **'Refund amount: {amount}'**
  String receiptsScreenRefundAmountLine(Object amount);

  /// No description provided for @receiptsScreenRefundConfirmPrefix.
  ///
  /// In en, this message translates to:
  /// **'Issue a refund for {reference}?'**
  String receiptsScreenRefundConfirmPrefix(Object reference);

  /// No description provided for @receiptsScreenRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get receiptsScreenRefund;

  /// No description provided for @receiptsScreenStatusVoid.
  ///
  /// In en, this message translates to:
  /// **'Void'**
  String get receiptsScreenStatusVoid;

  /// No description provided for @receiptsScreenStatusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get receiptsScreenStatusRefunded;

  /// No description provided for @receiptsScreenStatusPartiallyRefunded.
  ///
  /// In en, this message translates to:
  /// **'Partially Refunded'**
  String get receiptsScreenStatusPartiallyRefunded;

  /// No description provided for @receiptsScreenStatusCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get receiptsScreenStatusCredit;

  /// No description provided for @receiptsScreenStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get receiptsScreenStatusDraft;

  /// No description provided for @receiptsScreenStatusHold.
  ///
  /// In en, this message translates to:
  /// **'On Hold'**
  String get receiptsScreenStatusHold;

  /// No description provided for @receiptsScreenRefundReceiptFallback.
  ///
  /// In en, this message translates to:
  /// **'receipt #{id}'**
  String receiptsScreenRefundReceiptFallback(Object id);

  /// No description provided for @receiptsScreenRefundSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Refund submitted'**
  String get receiptsScreenRefundSubmitted;

  /// No description provided for @receiptsScreenRefundTotalLine.
  ///
  /// In en, this message translates to:
  /// **'Total: {amount}'**
  String receiptsScreenRefundTotalLine(Object amount);

  /// No description provided for @receiptsScreenSaleFallback.
  ///
  /// In en, this message translates to:
  /// **'Sale #{id}'**
  String receiptsScreenSaleFallback(Object id);

  /// No description provided for @receiptsScreenSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by invoice, customer...'**
  String get receiptsScreenSearchHint;

  /// No description provided for @receiptsScreenSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a receipt to view details'**
  String get receiptsScreenSelectHint;

  /// No description provided for @receiptsScreenSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get receiptsScreenSendButton;

  /// No description provided for @receiptsScreenSendByEmail.
  ///
  /// In en, this message translates to:
  /// **'Send by Email'**
  String get receiptsScreenSendByEmail;

  /// No description provided for @receiptsScreenShiftSegment.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get receiptsScreenShiftSegment;

  /// No description provided for @receiptsScreenTelLabel.
  ///
  /// In en, this message translates to:
  /// **'Tel: {phone}'**
  String receiptsScreenTelLabel(Object phone);

  /// No description provided for @receiptsScreenThankYouFooter.
  ///
  /// In en, this message translates to:
  /// **'Thank you ❤️'**
  String get receiptsScreenThankYouFooter;

  /// No description provided for @receiptsScreenTotalRielLabel.
  ///
  /// In en, this message translates to:
  /// **'Total (Riel)'**
  String get receiptsScreenTotalRielLabel;

  /// No description provided for @receiptsScreenWalkIn.
  ///
  /// In en, this message translates to:
  /// **'Walk-in'**
  String get receiptsScreenWalkIn;

  /// No description provided for @roleManagementScreenEmpty.
  ///
  /// In en, this message translates to:
  /// **'No roles found'**
  String get roleManagementScreenEmpty;

  /// No description provided for @roleManagementScreenListHeader.
  ///
  /// In en, this message translates to:
  /// **'Role List'**
  String get roleManagementScreenListHeader;

  /// No description provided for @roleManagementScreenNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching roles found'**
  String get roleManagementScreenNoMatch;

  /// No description provided for @roleManagementScreenPermissionsFor.
  ///
  /// In en, this message translates to:
  /// **'Permissions for {role}'**
  String roleManagementScreenPermissionsFor(Object role);

  /// No description provided for @roleManagementScreenPermissionsGranted.
  ///
  /// In en, this message translates to:
  /// **'{count} permission(s) granted'**
  String roleManagementScreenPermissionsGranted(Object count);

  /// No description provided for @roleManagementScreenSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String roleManagementScreenSaveFailed(Object error);

  /// No description provided for @roleManagementScreenSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search roles...'**
  String get roleManagementScreenSearchHint;

  /// No description provided for @roleManagementScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get roleManagementScreenTitle;

  /// No description provided for @shiftScreenBlockers.
  ///
  /// In en, this message translates to:
  /// **'Blockers: {list}'**
  String shiftScreenBlockers(Object list);

  /// No description provided for @shiftScreenCashEvents.
  ///
  /// In en, this message translates to:
  /// **'Cash Events'**
  String get shiftScreenCashEvents;

  /// No description provided for @shiftScreenCashIn.
  ///
  /// In en, this message translates to:
  /// **'Cash In'**
  String get shiftScreenCashIn;

  /// No description provided for @shiftScreenCashOut.
  ///
  /// In en, this message translates to:
  /// **'Cash Out'**
  String get shiftScreenCashOut;

  /// No description provided for @shiftScreenCloseShiftFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to close shift: {error}'**
  String shiftScreenCloseShiftFailed(Object error);

  /// No description provided for @shiftScreenCloseShift.
  ///
  /// In en, this message translates to:
  /// **'Close Shift'**
  String get shiftScreenCloseShift;

  /// No description provided for @shiftScreenClosingCashLabel.
  ///
  /// In en, this message translates to:
  /// **'Closing cash'**
  String get shiftScreenClosingCashLabel;

  /// No description provided for @shiftScreenExpectedCash.
  ///
  /// In en, this message translates to:
  /// **'Expected cash: {amount}'**
  String shiftScreenExpectedCash(Object amount);

  /// No description provided for @shiftScreenNoCashEvents.
  ///
  /// In en, this message translates to:
  /// **'No cash events yet'**
  String get shiftScreenNoCashEvents;

  /// No description provided for @shiftScreenNoOpenShiftSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open a shift before taking sales.'**
  String get shiftScreenNoOpenShiftSubtitle;

  /// No description provided for @shiftScreenNoOpenShiftTitle.
  ///
  /// In en, this message translates to:
  /// **'No open shift'**
  String get shiftScreenNoOpenShiftTitle;

  /// No description provided for @shiftScreenOpened.
  ///
  /// In en, this message translates to:
  /// **'Opened {time}'**
  String shiftScreenOpened(Object time);

  /// No description provided for @shiftScreenOpeningCash.
  ///
  /// In en, this message translates to:
  /// **'Opening cash: {amount}'**
  String shiftScreenOpeningCash(Object amount);

  /// No description provided for @shiftScreenOpeningCashLabel.
  ///
  /// In en, this message translates to:
  /// **'Opening cash'**
  String get shiftScreenOpeningCashLabel;

  /// No description provided for @shiftScreenOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get shiftScreenOpen;

  /// No description provided for @shiftScreenOpenShiftFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open shift: {error}'**
  String shiftScreenOpenShiftFailed(Object error);

  /// No description provided for @shiftScreenOpenShift.
  ///
  /// In en, this message translates to:
  /// **'Open Shift'**
  String get shiftScreenOpenShift;

  /// No description provided for @shiftScreenPrecheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load close precheck: {error}'**
  String shiftScreenPrecheckFailed(Object error);

  /// No description provided for @shiftScreenReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get shiftScreenReasonLabel;

  /// No description provided for @shiftScreenSaveCashEventFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save cash event: {error}'**
  String shiftScreenSaveCashEventFailed(Object error);

  /// No description provided for @shiftScreenShiftNumber.
  ///
  /// In en, this message translates to:
  /// **'Shift #{id}'**
  String shiftScreenShiftNumber(Object id);

  /// No description provided for @shiftScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Management'**
  String get shiftScreenTitle;

  /// No description provided for @shiftScreenVariance.
  ///
  /// In en, this message translates to:
  /// **'Variance: {amount}'**
  String shiftScreenVariance(Object amount);

  /// No description provided for @posDrawerManageShift.
  ///
  /// In en, this message translates to:
  /// **'Manage Shift'**
  String get posDrawerManageShift;

  /// No description provided for @posDrawerShiftHistory.
  ///
  /// In en, this message translates to:
  /// **'Shift History'**
  String get posDrawerShiftHistory;

  /// No description provided for @shiftHistoryScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift History'**
  String get shiftHistoryScreenTitle;

  /// No description provided for @shiftHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No shifts yet'**
  String get shiftHistoryEmpty;

  /// No description provided for @shiftHistoryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load shift history: {error}'**
  String shiftHistoryLoadFailed(Object error);

  /// No description provided for @shiftHistoryClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed {time}'**
  String shiftHistoryClosed(Object time);

  /// No description provided for @shiftHistoryClosingCash.
  ///
  /// In en, this message translates to:
  /// **'Closing cash: {amount}'**
  String shiftHistoryClosingCash(Object amount);

  /// No description provided for @shiftHistorySales.
  ///
  /// In en, this message translates to:
  /// **'Sales: {amount}'**
  String shiftHistorySales(Object amount);

  /// No description provided for @shiftHistoryStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get shiftHistoryStatusOpen;

  /// No description provided for @shiftHistoryStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get shiftHistoryStatusClosed;

  /// No description provided for @shiftHistoryStatusPendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending approval'**
  String get shiftHistoryStatusPendingApproval;

  /// No description provided for @paginationPageOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {totalPages}'**
  String paginationPageOfTotal(Object page, Object totalPages);

  /// No description provided for @tableManagementDeleteTablesTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete tables'**
  String get tableManagementDeleteTablesTitle;

  /// No description provided for @tableManagementDeleteTablesMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} selected table(s)? Occupied tables cannot be deleted.'**
  String tableManagementDeleteTablesMessage(Object count);

  /// No description provided for @tableManagementDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'{count} table(s) deleted successfully.'**
  String tableManagementDeleteSuccess(Object count);

  /// No description provided for @tableManagementDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete tables: {error}'**
  String tableManagementDeleteFailed(Object error);

  /// No description provided for @tableManagementAddTable.
  ///
  /// In en, this message translates to:
  /// **'Add Table'**
  String get tableManagementAddTable;

  /// No description provided for @tableManagementDeleteSelectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete selected tables'**
  String get tableManagementDeleteSelectedTooltip;

  /// No description provided for @tableManagementSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String tableManagementSelectedCount(Object count);

  /// No description provided for @tableManagementSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tables...'**
  String get tableManagementSearchHint;

  /// No description provided for @tableManagementNoResults.
  ///
  /// In en, this message translates to:
  /// **'No tables found'**
  String get tableManagementNoResults;

  /// No description provided for @tableManagementSeatsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} seats'**
  String tableManagementSeatsCount(Object count);

  /// No description provided for @tableManagementEmptyStateDescription.
  ///
  /// In en, this message translates to:
  /// **'Set up the tables available for dine-in orders.'**
  String get tableManagementEmptyStateDescription;

  /// No description provided for @userAccountAllFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'All fields are required'**
  String get userAccountAllFieldsRequired;

  /// No description provided for @userAccountCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create user: {error}'**
  String userAccountCreateFailed(Object error);

  /// No description provided for @userAccountAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add User Account'**
  String get userAccountAddTitle;

  /// No description provided for @userAccountFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name *'**
  String get userAccountFullNameLabel;

  /// No description provided for @userAccountEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email *'**
  String get userAccountEmailLabel;

  /// No description provided for @userAccountPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password *'**
  String get userAccountPasswordLabel;

  /// No description provided for @userAccountRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role *'**
  String get userAccountRoleLabel;

  /// No description provided for @userAccountCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get userAccountCreateButton;

  /// No description provided for @userAccountUpdateStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update status: {error}'**
  String userAccountUpdateStatusFailed(Object error);

  /// No description provided for @userAccountScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'User Accounts'**
  String get userAccountScreenTitle;

  /// No description provided for @userAccountAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add User'**
  String get userAccountAddButton;

  /// No description provided for @userAccountSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search users...'**
  String get userAccountSearchHint;

  /// No description provided for @userAccountEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No user accounts yet'**
  String get userAccountEmptyMessage;

  /// No description provided for @userAccountNoResultsMessage.
  ///
  /// In en, this message translates to:
  /// **'No user accounts found'**
  String get userAccountNoResultsMessage;

  /// No description provided for @cartActionsApplyDiscountTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply Discount'**
  String get cartActionsApplyDiscountTitle;

  /// No description provided for @cartActionsAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get cartActionsAmountHint;

  /// No description provided for @cartActionsClearCart.
  ///
  /// In en, this message translates to:
  /// **'Clear Cart'**
  String get cartActionsClearCart;

  /// No description provided for @cartFooterTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total: {amount}'**
  String cartFooterTotalAmount(Object amount);

  /// No description provided for @cartFooterDiscountAmount.
  ///
  /// In en, this message translates to:
  /// **'Discount: -{amount}'**
  String cartFooterDiscountAmount(Object amount);

  /// No description provided for @cartFooterLoyaltyAmount.
  ///
  /// In en, this message translates to:
  /// **'Loyalty: -{amount}'**
  String cartFooterLoyaltyAmount(Object amount);

  /// No description provided for @cartFooterFinalAmount.
  ///
  /// In en, this message translates to:
  /// **'Final: {amount}'**
  String cartFooterFinalAmount(Object amount);

  /// No description provided for @cartFooterClearDiscount.
  ///
  /// In en, this message translates to:
  /// **'Clear Discount'**
  String get cartFooterClearDiscount;

  /// No description provided for @cartFooterClearLoyalty.
  ///
  /// In en, this message translates to:
  /// **'Clear Loyalty'**
  String get cartFooterClearLoyalty;

  /// No description provided for @cartItemsListTapToAdd.
  ///
  /// In en, this message translates to:
  /// **'Tap a product to add it'**
  String get cartItemsListTapToAdd;

  /// No description provided for @cartItemsListOpenHeldTickets.
  ///
  /// In en, this message translates to:
  /// **'Open Held Tickets'**
  String get cartItemsListOpenHeldTickets;

  /// No description provided for @cartItemsListDescriptionHeader.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get cartItemsListDescriptionHeader;

  /// No description provided for @cartItemsListEditItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String cartItemsListEditItemTitle(Object name);

  /// No description provided for @cartItemsListQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get cartItemsListQuantityLabel;

  /// No description provided for @cartItemsListNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get cartItemsListNoteLabel;

  /// No description provided for @cartItemsListNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. extra sauce, no ice'**
  String get cartItemsListNoteHint;

  /// No description provided for @cartItemsListDiscountPerUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Discount per unit'**
  String get cartItemsListDiscountPerUnitLabel;

  /// No description provided for @cartItemsListMaxDiscountHint.
  ///
  /// In en, this message translates to:
  /// **'Max {amount}'**
  String cartItemsListMaxDiscountHint(Object amount);

  /// No description provided for @cartItemsListRemovedItem.
  ///
  /// In en, this message translates to:
  /// **'Removed {name}'**
  String cartItemsListRemovedItem(Object name);

  /// No description provided for @cartItemsListUndoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get cartItemsListUndoAction;

  /// No description provided for @cartItemsListBaseModifierBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Base: {base} + Modifier: {modifier}'**
  String cartItemsListBaseModifierBreakdown(Object base, Object modifier);

  /// No description provided for @cartItemsListModifierLink.
  ///
  /// In en, this message translates to:
  /// **'Modifier'**
  String get cartItemsListModifierLink;

  /// No description provided for @cartPanelCancelTicketTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel ticket'**
  String get cartPanelCancelTicketTitle;

  /// No description provided for @cartPanelCancelTicketMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel Ticket #{ticketId}? This cannot be undone.'**
  String cartPanelCancelTicketMessage(Object ticketId);

  /// No description provided for @cartPanelKeepButton.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get cartPanelKeepButton;

  /// No description provided for @cartPanelCancelTicketButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel Ticket'**
  String get cartPanelCancelTicketButton;

  /// No description provided for @cartPanelCancelTicketFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel ticket: {error}'**
  String cartPanelCancelTicketFailed(Object error);

  /// No description provided for @cartPanelTicketCancelled.
  ///
  /// In en, this message translates to:
  /// **'Ticket cancelled'**
  String get cartPanelTicketCancelled;

  /// No description provided for @cartPanelTicketLabel.
  ///
  /// In en, this message translates to:
  /// **'Ticket'**
  String get cartPanelTicketLabel;

  /// No description provided for @cartPanelWalkIn.
  ///
  /// In en, this message translates to:
  /// **'Walk-in'**
  String get cartPanelWalkIn;

  /// No description provided for @cartPanelCustomerFallback.
  ///
  /// In en, this message translates to:
  /// **'Customer #{id}'**
  String cartPanelCustomerFallback(Object id);

  /// No description provided for @cartPanelSearchCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'Search name or phone'**
  String get cartPanelSearchCustomerHint;

  /// No description provided for @cartPanelWalkInNoCustomerButton.
  ///
  /// In en, this message translates to:
  /// **'Walk-in (no customer)'**
  String get cartPanelWalkInNoCustomerButton;

  /// No description provided for @cartPanelLoadCustomersFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load customers: {error}'**
  String cartPanelLoadCustomersFailed(Object error);

  /// No description provided for @cartPanelNoCustomersFound.
  ///
  /// In en, this message translates to:
  /// **'No customers found'**
  String get cartPanelNoCustomersFound;

  /// No description provided for @cartPanelFooterCharge.
  ///
  /// In en, this message translates to:
  /// **'Charge'**
  String get cartPanelFooterCharge;

  /// No description provided for @cartPanelFooterHold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get cartPanelFooterHold;

  /// No description provided for @cartTotalsItemDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Item Discounts'**
  String get cartTotalsItemDiscounts;

  /// No description provided for @cartTotalsTicketHeld.
  ///
  /// In en, this message translates to:
  /// **'Ticket #{ticketNumber} held'**
  String cartTotalsTicketHeld(Object ticketNumber);

  /// No description provided for @cartTotalsHoldFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not hold order: {error}'**
  String cartTotalsHoldFailed(Object error);

  /// No description provided for @cartTotalsHold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get cartTotalsHold;

  /// No description provided for @cartTotalsAddDiscount.
  ///
  /// In en, this message translates to:
  /// **'Add Discount'**
  String get cartTotalsAddDiscount;

  /// No description provided for @cartTotalsFixedAmount.
  ///
  /// In en, this message translates to:
  /// **'Fixed \$'**
  String get cartTotalsFixedAmount;

  /// No description provided for @cartTotalsPercentAmount.
  ///
  /// In en, this message translates to:
  /// **'Percent %'**
  String get cartTotalsPercentAmount;

  /// No description provided for @cartTotalsAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount (\$)'**
  String get cartTotalsAmountLabel;

  /// No description provided for @cartTotalsPercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Percent (%)'**
  String get cartTotalsPercentLabel;

  /// No description provided for @cartTotalsQuickSelect.
  ///
  /// In en, this message translates to:
  /// **'Quick select:'**
  String get cartTotalsQuickSelect;

  /// No description provided for @cartTotalsRemoveDiscount.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get cartTotalsRemoveDiscount;

  /// No description provided for @categoryTabsAllItems.
  ///
  /// In en, this message translates to:
  /// **'All Items'**
  String get categoryTabsAllItems;

  /// No description provided for @heldTicketsCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel ticket'**
  String get heldTicketsCancelTitle;

  /// No description provided for @heldTicketsCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel Ticket #{ticketId}? This cannot be undone.'**
  String heldTicketsCancelConfirm(Object ticketId);

  /// No description provided for @heldTicketsKeep.
  ///
  /// In en, this message translates to:
  /// **'KEEP'**
  String get heldTicketsKeep;

  /// No description provided for @heldTicketsCancelTicketButton.
  ///
  /// In en, this message translates to:
  /// **'CANCEL TICKET'**
  String get heldTicketsCancelTicketButton;

  /// No description provided for @heldTicketsCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel ticket: {error}'**
  String heldTicketsCancelFailed(Object error);

  /// No description provided for @heldTicketsCancelled.
  ///
  /// In en, this message translates to:
  /// **'Ticket #{ticketId} cancelled'**
  String heldTicketsCancelled(Object ticketId);

  /// No description provided for @heldTicketsTitle.
  ///
  /// In en, this message translates to:
  /// **'Held Tickets'**
  String get heldTicketsTitle;

  /// No description provided for @heldTicketsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tickets...'**
  String get heldTicketsSearchHint;

  /// No description provided for @heldTicketsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No held tickets'**
  String get heldTicketsEmpty;

  /// No description provided for @heldTicketsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Hold\" on a sale to save it here'**
  String get heldTicketsEmptyHint;

  /// No description provided for @heldTicketsTicketLabel.
  ///
  /// In en, this message translates to:
  /// **'Ticket #{ticketNumber}'**
  String heldTicketsTicketLabel(Object ticketNumber);

  /// No description provided for @heldTicketsTapToRestore.
  ///
  /// In en, this message translates to:
  /// **'Tap to restore'**
  String get heldTicketsTapToRestore;

  /// No description provided for @modifierSheetQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get modifierSheetQuantity;

  /// No description provided for @modifierSheetNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note...'**
  String get modifierSheetNoteHint;

  /// No description provided for @modifierSheetValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please select an option for all required modifiers.'**
  String get modifierSheetValidationError;

  /// No description provided for @modifierSheetLineTotal.
  ///
  /// In en, this message translates to:
  /// **'Line Total'**
  String get modifierSheetLineTotal;

  /// No description provided for @modifierSheetUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get modifierSheetUpdate;

  /// No description provided for @phoneScannerConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting POS to scanner relay...'**
  String get phoneScannerConnecting;

  /// No description provided for @phoneScannerWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for phone scanner'**
  String get phoneScannerWaiting;

  /// No description provided for @phoneScannerStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start phone scanner session'**
  String get phoneScannerStartFailed;

  /// No description provided for @phoneScannerStopped.
  ///
  /// In en, this message translates to:
  /// **'Scanner session stopped'**
  String get phoneScannerStopped;

  /// No description provided for @phoneScannerDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone scanner'**
  String get phoneScannerDialogTitle;

  /// No description provided for @phoneScannerInstructions.
  ///
  /// In en, this message translates to:
  /// **'On the phone, open Phone 1D Scanner. Enter the Windows computer/server LAN address and this code:'**
  String get phoneScannerInstructions;

  /// No description provided for @phoneScannerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get phoneScannerUnavailable;

  /// No description provided for @phoneScannerCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy session code'**
  String get phoneScannerCopyCode;

  /// No description provided for @phoneScannerExampleUrl.
  ///
  /// In en, this message translates to:
  /// **'Example phone URL: http://192.168.1.10:8081\nDo not enter localhost on the phone.'**
  String get phoneScannerExampleUrl;

  /// No description provided for @phoneScannerStopSession.
  ///
  /// In en, this message translates to:
  /// **'Stop session'**
  String get phoneScannerStopSession;

  /// No description provided for @phoneScannerKeepRunning.
  ///
  /// In en, this message translates to:
  /// **'Keep running'**
  String get phoneScannerKeepRunning;

  /// No description provided for @phoneScannerPhoneReady.
  ///
  /// In en, this message translates to:
  /// **'Phone connected and ready'**
  String get phoneScannerPhoneReady;

  /// No description provided for @phoneScannerPhoneDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Phone disconnected — session stopped'**
  String get phoneScannerPhoneDisconnected;

  /// No description provided for @phoneScannerRelayError.
  ///
  /// In en, this message translates to:
  /// **'Scanner relay error'**
  String get phoneScannerRelayError;

  /// No description provided for @phoneScannerConnectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Phone scanner connected'**
  String get phoneScannerConnectedTooltip;

  /// No description provided for @phoneScannerConnectTooltip.
  ///
  /// In en, this message translates to:
  /// **'Connect phone scanner'**
  String get phoneScannerConnectTooltip;

  /// No description provided for @phoneScannerSessionStoppedStatus.
  ///
  /// In en, this message translates to:
  /// **'Scanner session is stopped'**
  String get phoneScannerSessionStoppedStatus;

  /// No description provided for @productCardOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get productCardOutOfStock;

  /// No description provided for @statusBarToggleMenu.
  ///
  /// In en, this message translates to:
  /// **'Toggle menu'**
  String get statusBarToggleMenu;

  /// No description provided for @statusBarShiftLabel.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get statusBarShiftLabel;

  /// No description provided for @statusBarOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get statusBarOnline;

  /// No description provided for @statusBarOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get statusBarOffline;

  /// No description provided for @statusBarTransactions.
  ///
  /// In en, this message translates to:
  /// **'Trans'**
  String get statusBarTransactions;

  /// No description provided for @statusBarBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get statusBarBills;

  /// No description provided for @tableSelectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Table'**
  String get tableSelectorTitle;

  /// No description provided for @tableSelectorEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tables available'**
  String get tableSelectorEmpty;

  /// No description provided for @tableSelectorInUseBadge.
  ///
  /// In en, this message translates to:
  /// **'IN USE'**
  String get tableSelectorInUseBadge;

  /// No description provided for @tableSelectorInUse.
  ///
  /// In en, this message translates to:
  /// **'{table} is in use'**
  String tableSelectorInUse(Object table);

  /// No description provided for @tableSelectorNoTable.
  ///
  /// In en, this message translates to:
  /// **'No Table'**
  String get tableSelectorNoTable;

  /// No description provided for @waitingTicketsTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting Numbers'**
  String get waitingTicketsTitle;

  /// No description provided for @waitingTicketsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No waiting customers'**
  String get waitingTicketsEmpty;

  /// No description provided for @waitingTicketsItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String waitingTicketsItemsCount(Object count);

  /// No description provided for @waitingTicketsReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get waitingTicketsReady;

  /// No description provided for @waitingTicketsCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get waitingTicketsCollected;

  /// No description provided for @waitingTicketsPrintYourNumber.
  ///
  /// In en, this message translates to:
  /// **'Your Number'**
  String get waitingTicketsPrintYourNumber;

  /// No description provided for @waitingTicketsPrintInstruction.
  ///
  /// In en, this message translates to:
  /// **'Please come to the counter when your number is called'**
  String get waitingTicketsPrintInstruction;

  /// No description provided for @cashierPerformanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales by Cashier'**
  String get cashierPerformanceTitle;

  /// No description provided for @reportsNoDataForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No data for this period'**
  String get reportsNoDataForPeriod;

  /// No description provided for @reportsTxCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tx'**
  String reportsTxCount(Object count);

  /// No description provided for @categoryPerformanceTopByRevenue.
  ///
  /// In en, this message translates to:
  /// **'Top Categories by Revenue'**
  String get categoryPerformanceTopByRevenue;

  /// No description provided for @categoryPerformanceFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Category #{id}'**
  String categoryPerformanceFallbackName(Object id);

  /// No description provided for @categoryPerformanceItemsSoldCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items sold'**
  String categoryPerformanceItemsSoldCount(Object count);

  /// No description provided for @discountsScreenSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get discountsScreenSummary;

  /// No description provided for @discountsScreenDiscountsGiven.
  ///
  /// In en, this message translates to:
  /// **'Discounts Given'**
  String get discountsScreenDiscountsGiven;

  /// No description provided for @discountsScreenTotalDiscountAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Discount Amount'**
  String get discountsScreenTotalDiscountAmount;

  /// No description provided for @discountsScreenNoData.
  ///
  /// In en, this message translates to:
  /// **'No discounts for this period'**
  String get discountsScreenNoData;

  /// No description provided for @discountsScreenChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Discount Amount'**
  String get discountsScreenChartTitle;

  /// No description provided for @discountsScreenTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Discount Transactions'**
  String get discountsScreenTransactionsTitle;

  /// No description provided for @monthlySalesTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly Sales — {year}'**
  String monthlySalesTitle(Object year);

  /// No description provided for @monthlySalesPreviousYear.
  ///
  /// In en, this message translates to:
  /// **'Previous year'**
  String get monthlySalesPreviousYear;

  /// No description provided for @monthlySalesNextYear.
  ///
  /// In en, this message translates to:
  /// **'Next year'**
  String get monthlySalesNextYear;

  /// No description provided for @monthlySalesNoData.
  ///
  /// In en, this message translates to:
  /// **'No data for this year'**
  String get monthlySalesNoData;

  /// No description provided for @monthlySalesTotalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get monthlySalesTotalRevenue;

  /// No description provided for @paymentMixShareByMethod.
  ///
  /// In en, this message translates to:
  /// **'Share by Payment Method'**
  String get paymentMixShareByMethod;

  /// No description provided for @paymentMixTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total:'**
  String get paymentMixTotalLabel;

  /// No description provided for @reportsHubSalesReportsSection.
  ///
  /// In en, this message translates to:
  /// **'Sales Reports'**
  String get reportsHubSalesReportsSection;

  /// No description provided for @reportsHubSalesSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Daily sales totals with filters by store & cashier'**
  String get reportsHubSalesSummarySubtitle;

  /// No description provided for @reportsHubSalesByItemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quantity sold, gross, discount & net per product'**
  String get reportsHubSalesByItemSubtitle;

  /// No description provided for @reportsHubSalesByCategorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Revenue & quantity per product category'**
  String get reportsHubSalesByCategorySubtitle;

  /// No description provided for @reportsHubSalesByCashierSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sales totals & transaction counts per cashier'**
  String get reportsHubSalesByCashierSubtitle;

  /// No description provided for @reportsHubPaymentMixSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Revenue breakdown by payment method'**
  String get reportsHubPaymentMixSubtitle;

  /// No description provided for @reportsHubReceiptsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'In-depth sales with items, customers & payments'**
  String get reportsHubReceiptsSubtitle;

  /// No description provided for @reportsHubSalesByModifierTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales by Modifier'**
  String get reportsHubSalesByModifierTitle;

  /// No description provided for @reportsHubSalesByModifierSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Revenue & quantity per modifier option'**
  String get reportsHubSalesByModifierSubtitle;

  /// No description provided for @reportsHubDiscountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discounts applied across receipts'**
  String get reportsHubDiscountsSubtitle;

  /// No description provided for @reportsHubTaxesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Taxable sales & tax collected per day'**
  String get reportsHubTaxesSubtitle;

  /// No description provided for @reportsHubOtherReportsSection.
  ///
  /// In en, this message translates to:
  /// **'Other Reports'**
  String get reportsHubOtherReportsSection;

  /// No description provided for @reportsHubDailyReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily / X-Report'**
  String get reportsHubDailyReportTitle;

  /// No description provided for @reportsHubDailyReportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s sales snapshot with top products & payments'**
  String get reportsHubDailyReportSubtitle;

  /// No description provided for @reportsHubTopProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'Top Products'**
  String get reportsHubTopProductsTitle;

  /// No description provided for @reportsHubTopProductsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Best-selling items by quantity & revenue'**
  String get reportsHubTopProductsSubtitle;

  /// No description provided for @reportsHubPerformanceSection.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get reportsHubPerformanceSection;

  /// No description provided for @reportsHubMonthlySalesTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly Sales'**
  String get reportsHubMonthlySalesTitle;

  /// No description provided for @reportsHubMonthlySalesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Revenue trend across months in a year'**
  String get reportsHubMonthlySalesSubtitle;

  /// No description provided for @reportsHubStockMovementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock Movements'**
  String get reportsHubStockMovementsTitle;

  /// No description provided for @reportsHubStockMovementsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'In/out movements within a date range'**
  String get reportsHubStockMovementsSubtitle;

  /// No description provided for @reportsHubChangeDateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change date'**
  String get reportsHubChangeDateTooltip;

  /// No description provided for @reportsHubGrossSales.
  ///
  /// In en, this message translates to:
  /// **'Gross Sales'**
  String get reportsHubGrossSales;

  /// No description provided for @reportsHubNetSales.
  ///
  /// In en, this message translates to:
  /// **'Net Sales'**
  String get reportsHubNetSales;

  /// No description provided for @reportsHubTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get reportsHubTransactions;

  /// No description provided for @reportsHubAvgPerSale.
  ///
  /// In en, this message translates to:
  /// **'Avg per Sale'**
  String get reportsHubAvgPerSale;

  /// No description provided for @reportsHubPaymentBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Payment Breakdown'**
  String get reportsHubPaymentBreakdown;

  /// No description provided for @reportsHubQuantitySold.
  ///
  /// In en, this message translates to:
  /// **'{count} sold'**
  String reportsHubQuantitySold(Object count);

  /// No description provided for @reportsHubCashierPerformanceSection.
  ///
  /// In en, this message translates to:
  /// **'Cashier Performance'**
  String get reportsHubCashierPerformanceSection;

  /// No description provided for @reportsHubNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get reportsHubNotAvailable;

  /// No description provided for @salesByItemSortByRevenue.
  ///
  /// In en, this message translates to:
  /// **'By Revenue'**
  String get salesByItemSortByRevenue;

  /// No description provided for @salesByItemSortByQuantity.
  ///
  /// In en, this message translates to:
  /// **'By Quantity'**
  String get salesByItemSortByQuantity;

  /// No description provided for @salesByItemTopItems.
  ///
  /// In en, this message translates to:
  /// **'Top Items'**
  String get salesByItemTopItems;

  /// No description provided for @salesByItemSkuLabel.
  ///
  /// In en, this message translates to:
  /// **'SKU:'**
  String get salesByItemSkuLabel;

  /// No description provided for @salesByItemGrossLabel.
  ///
  /// In en, this message translates to:
  /// **'Gross'**
  String get salesByItemGrossLabel;

  /// No description provided for @salesByItemNetLabel.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get salesByItemNetLabel;

  /// No description provided for @reportsSalesByModifier.
  ///
  /// In en, this message translates to:
  /// **'Sales by Modifier'**
  String get reportsSalesByModifier;

  /// No description provided for @salesByModifierTopOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Top Modifier Options by Revenue'**
  String get salesByModifierTopOptionsTitle;

  /// No description provided for @reportsRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get reportsRevenue;

  /// No description provided for @reportsSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get reportsSummary;

  /// No description provided for @reportsGrossSales.
  ///
  /// In en, this message translates to:
  /// **'Gross Sales'**
  String get reportsGrossSales;

  /// No description provided for @reportsNetSales.
  ///
  /// In en, this message translates to:
  /// **'Net Sales'**
  String get reportsNetSales;

  /// No description provided for @reportsSalesCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Sales Count'**
  String get reportsSalesCountLabel;

  /// No description provided for @reportsItemsSold.
  ///
  /// In en, this message translates to:
  /// **'Items Sold'**
  String get reportsItemsSold;

  /// No description provided for @reportsAvgSale.
  ///
  /// In en, this message translates to:
  /// **'Avg Sale'**
  String get reportsAvgSale;

  /// No description provided for @reportsPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get reportsPaymentMethods;

  /// No description provided for @reportsTransactionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tx'**
  String reportsTransactionsCount(Object count);

  /// No description provided for @reportsNoReceiptsForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No receipts for this period'**
  String get reportsNoReceiptsForPeriod;

  /// No description provided for @reportsGross.
  ///
  /// In en, this message translates to:
  /// **'Gross'**
  String get reportsGross;

  /// No description provided for @reportsBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get reportsBalance;

  /// No description provided for @reportsCreditSale.
  ///
  /// In en, this message translates to:
  /// **'Credit Sale'**
  String get reportsCreditSale;

  /// No description provided for @reportsTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get reportsTransactions;

  /// No description provided for @reportsAvgPerSale.
  ///
  /// In en, this message translates to:
  /// **'Avg per Sale'**
  String get reportsAvgPerSale;

  /// No description provided for @reportsNetSalesPerDay.
  ///
  /// In en, this message translates to:
  /// **'Net Sales per Day'**
  String get reportsNetSalesPerDay;

  /// No description provided for @reportsSalesByCashier.
  ///
  /// In en, this message translates to:
  /// **'Sales by Cashier'**
  String get reportsSalesByCashier;

  /// No description provided for @reportsDailyBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Daily Breakdown'**
  String get reportsDailyBreakdown;

  /// No description provided for @reportsOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get reportsOrders;

  /// No description provided for @reportsNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get reportsNet;

  /// No description provided for @reportsSalesCountSingular.
  ///
  /// In en, this message translates to:
  /// **'{count} sale'**
  String reportsSalesCountSingular(Object count);

  /// No description provided for @reportsSalesCountPlural.
  ///
  /// In en, this message translates to:
  /// **'{count} sales'**
  String reportsSalesCountPlural(Object count);

  /// No description provided for @reportsStockMovements.
  ///
  /// In en, this message translates to:
  /// **'Stock Movements'**
  String get reportsStockMovements;

  /// No description provided for @reportsNoMovementsForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No movements for this period'**
  String get reportsNoMovementsForPeriod;

  /// No description provided for @reportsProductFallback.
  ///
  /// In en, this message translates to:
  /// **'Product #{id}'**
  String reportsProductFallback(Object id);

  /// No description provided for @reportsTotalTaxCollected.
  ///
  /// In en, this message translates to:
  /// **'Total Tax Collected'**
  String get reportsTotalTaxCollected;

  /// No description provided for @reportsNoTaxDataForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No tax data for this period'**
  String get reportsNoTaxDataForPeriod;

  /// No description provided for @reportsTaxCollectedPerDay.
  ///
  /// In en, this message translates to:
  /// **'Tax Collected per Day'**
  String get reportsTaxCollectedPerDay;

  /// No description provided for @reportsTaxableSales.
  ///
  /// In en, this message translates to:
  /// **'Taxable Sales'**
  String get reportsTaxableSales;

  /// No description provided for @reportsTaxCollected.
  ///
  /// In en, this message translates to:
  /// **'Tax Collected'**
  String get reportsTaxCollected;

  /// No description provided for @reportsSalesLabel.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get reportsSalesLabel;

  /// No description provided for @reportsTopProducts.
  ///
  /// In en, this message translates to:
  /// **'Top Products'**
  String get reportsTopProducts;

  /// No description provided for @reportsQuantitySold.
  ///
  /// In en, this message translates to:
  /// **'{qty} sold'**
  String reportsQuantitySold(Object qty);

  /// No description provided for @reportFilterToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get reportFilterToday;

  /// No description provided for @reportFilterYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get reportFilterYesterday;

  /// No description provided for @reportFilterThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get reportFilterThisWeek;

  /// No description provided for @reportFilterLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get reportFilterLastWeek;

  /// No description provided for @reportFilterThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get reportFilterThisMonth;

  /// No description provided for @reportFilterLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get reportFilterLastMonth;

  /// No description provided for @reportFilterLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get reportFilterLast7Days;

  /// No description provided for @reportFilterLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get reportFilterLast30Days;

  /// No description provided for @reportFilterThisYear.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get reportFilterThisYear;

  /// No description provided for @reportFilterCustomRange.
  ///
  /// In en, this message translates to:
  /// **'Custom range…'**
  String get reportFilterCustomRange;

  /// No description provided for @reportFilterAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get reportFilterAllDay;

  /// No description provided for @reportFilterCustomPeriod.
  ///
  /// In en, this message translates to:
  /// **'Custom period'**
  String get reportFilterCustomPeriod;

  /// No description provided for @reportFilterStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get reportFilterStart;

  /// No description provided for @reportFilterEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get reportFilterEnd;

  /// No description provided for @reportFilterAllCashiers.
  ///
  /// In en, this message translates to:
  /// **'All cashiers'**
  String get reportFilterAllCashiers;

  /// No description provided for @reportPaginationPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get reportPaginationPreviousPage;

  /// No description provided for @reportPaginationNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get reportPaginationNextPage;

  /// No description provided for @reportPaginationPageInfo.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {totalPages} ({total} total)'**
  String reportPaginationPageInfo(Object page, Object totalPages, Object total);

  /// No description provided for @customerDisplayTooltipConnected.
  ///
  /// In en, this message translates to:
  /// **'Customer display connected'**
  String get customerDisplayTooltipConnected;

  /// No description provided for @customerDisplayTooltipConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect customer display'**
  String get customerDisplayTooltipConnect;

  /// No description provided for @customerDisplayDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer Display'**
  String get customerDisplayDialogTitle;

  /// No description provided for @customerDisplayDialogInstructions.
  ///
  /// In en, this message translates to:
  /// **'On the customer-screen device, enter this store\'s server address and the code below to connect.'**
  String get customerDisplayDialogInstructions;

  /// No description provided for @customerDisplayCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get customerDisplayCopyCode;

  /// No description provided for @customerDisplayStopSession.
  ///
  /// In en, this message translates to:
  /// **'Stop session'**
  String get customerDisplayStopSession;

  /// No description provided for @customerDisplayKeepRunning.
  ///
  /// In en, this message translates to:
  /// **'Keep running'**
  String get customerDisplayKeepRunning;

  /// No description provided for @customerDisplayStatusStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting session...'**
  String get customerDisplayStatusStarting;

  /// No description provided for @customerDisplayStatusStopped.
  ///
  /// In en, this message translates to:
  /// **'Session stopped'**
  String get customerDisplayStatusStopped;

  /// No description provided for @customerDisplayStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Customer display connected'**
  String get customerDisplayStatusConnected;

  /// No description provided for @customerDisplayStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the customer display to connect...'**
  String get customerDisplayStatusWaiting;

  /// No description provided for @reportPdfGeneratedLabel.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get reportPdfGeneratedLabel;

  /// No description provided for @reportPdfPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get reportPdfPageLabel;

  /// No description provided for @salesSummaryPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales Summary Report'**
  String get salesSummaryPdfTitle;

  /// No description provided for @salesSummaryPdfColDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get salesSummaryPdfColDate;

  /// No description provided for @salesSummaryPdfColOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get salesSummaryPdfColOrders;

  /// No description provided for @salesSummaryPdfColQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get salesSummaryPdfColQty;

  /// No description provided for @salesSummaryPdfColGross.
  ///
  /// In en, this message translates to:
  /// **'Gross'**
  String get salesSummaryPdfColGross;

  /// No description provided for @salesSummaryPdfColDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get salesSummaryPdfColDiscount;

  /// No description provided for @salesSummaryPdfColTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get salesSummaryPdfColTax;

  /// No description provided for @salesSummaryPdfColNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get salesSummaryPdfColNet;

  /// No description provided for @salesSummaryPdfGrossSalesLabel.
  ///
  /// In en, this message translates to:
  /// **'Gross Sales'**
  String get salesSummaryPdfGrossSalesLabel;

  /// No description provided for @salesSummaryPdfDiscountsLabel.
  ///
  /// In en, this message translates to:
  /// **'Discounts'**
  String get salesSummaryPdfDiscountsLabel;

  /// No description provided for @salesSummaryPdfNetSalesLabel.
  ///
  /// In en, this message translates to:
  /// **'Net Sales'**
  String get salesSummaryPdfNetSalesLabel;

  /// No description provided for @salesSummaryPdfTransactionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get salesSummaryPdfTransactionsLabel;

  /// No description provided for @salesSummaryPdfItemsSoldLabel.
  ///
  /// In en, this message translates to:
  /// **'Items Sold'**
  String get salesSummaryPdfItemsSoldLabel;

  /// No description provided for @salesReportPdfColReceiptNo.
  ///
  /// In en, this message translates to:
  /// **'Receipt #'**
  String get salesReportPdfColReceiptNo;

  /// No description provided for @salesReportPdfColPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get salesReportPdfColPayment;

  /// No description provided for @stockMovementPdfColType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get stockMovementPdfColType;

  /// No description provided for @stockMovementPdfMovementsLabel.
  ///
  /// In en, this message translates to:
  /// **'Movements'**
  String get stockMovementPdfMovementsLabel;

  /// No description provided for @inventoryValuationPdfTotalValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Value'**
  String get inventoryValuationPdfTotalValueLabel;

  /// No description provided for @salesByModifierPdfColGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get salesByModifierPdfColGroup;

  /// No description provided for @salesByModifierPdfColOption.
  ///
  /// In en, this message translates to:
  /// **'Option'**
  String get salesByModifierPdfColOption;

  /// No description provided for @commonLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get commonLocation;

  /// No description provided for @commonUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get commonUser;

  /// No description provided for @commonStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get commonStatus;

  /// No description provided for @formSupplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get formSupplier;

  /// No description provided for @formFromStore.
  ///
  /// In en, this message translates to:
  /// **'From Store'**
  String get formFromStore;

  /// No description provided for @formToStore.
  ///
  /// In en, this message translates to:
  /// **'To Store'**
  String get formToStore;

  /// No description provided for @formStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get formStore;

  /// No description provided for @formRecipe.
  ///
  /// In en, this message translates to:
  /// **'Recipe'**
  String get formRecipe;

  /// No description provided for @inventoryHubInStockLabel.
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get inventoryHubInStockLabel;

  /// No description provided for @inventoryHistoryPdfFilterProduct.
  ///
  /// In en, this message translates to:
  /// **'Product: {name}'**
  String inventoryHistoryPdfFilterProduct(Object name);

  /// No description provided for @stockAdjustmentsPdfFilterQuery.
  ///
  /// In en, this message translates to:
  /// **'Search: {query}'**
  String stockAdjustmentsPdfFilterQuery(Object query);

  /// No description provided for @purchaseOrderPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase Order'**
  String get purchaseOrderPdfTitle;

  /// No description provided for @purchaseOrderPdfNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'PO Number'**
  String get purchaseOrderPdfNumberLabel;

  /// No description provided for @purchaseOrderPdfLineTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Line Total'**
  String get purchaseOrderPdfLineTotalLabel;

  /// No description provided for @transferOrderPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock Transfer'**
  String get transferOrderPdfTitle;

  /// No description provided for @transferOrderPdfNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Transfer Number'**
  String get transferOrderPdfNumberLabel;

  /// No description provided for @productionOrderPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'Production Order'**
  String get productionOrderPdfTitle;

  /// No description provided for @productionOrderPdfNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Production Order #'**
  String get productionOrderPdfNumberLabel;

  /// No description provided for @productionOrderPdfStartedLabel.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get productionOrderPdfStartedLabel;

  /// No description provided for @productionOrderPdfCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get productionOrderPdfCompletedLabel;

  /// No description provided for @productionOrderPdfYieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Yield %'**
  String get productionOrderPdfYieldLabel;

  /// No description provided for @productionOrderPdfWasteLabel.
  ///
  /// In en, this message translates to:
  /// **'Waste Qty'**
  String get productionOrderPdfWasteLabel;

  /// No description provided for @productionOrderPdfComponentLabel.
  ///
  /// In en, this message translates to:
  /// **'Component'**
  String get productionOrderPdfComponentLabel;

  /// No description provided for @productionOrderPdfRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get productionOrderPdfRequiredLabel;

  /// No description provided for @productionOrderPdfConsumedLabel.
  ///
  /// In en, this message translates to:
  /// **'Consumed'**
  String get productionOrderPdfConsumedLabel;

  /// No description provided for @inventoryCountPdfSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Count Sheet'**
  String get inventoryCountPdfSheetTitle;

  /// No description provided for @inventoryCountPdfReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Count Report'**
  String get inventoryCountPdfReportTitle;

  /// No description provided for @inventoryCountPdfExpectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get inventoryCountPdfExpectedLabel;

  /// No description provided for @inventoryCountPdfCountedLabel.
  ///
  /// In en, this message translates to:
  /// **'Counted'**
  String get inventoryCountPdfCountedLabel;

  /// No description provided for @inventoryCountPdfVarianceLabel.
  ///
  /// In en, this message translates to:
  /// **'Variance'**
  String get inventoryCountPdfVarianceLabel;

  /// No description provided for @inventoryCountPdfPrintSheet.
  ///
  /// In en, this message translates to:
  /// **'Print Count Sheet'**
  String get inventoryCountPdfPrintSheet;

  /// No description provided for @inventoryCountPdfSaveSheet.
  ///
  /// In en, this message translates to:
  /// **'Save Count Sheet PDF'**
  String get inventoryCountPdfSaveSheet;

  /// No description provided for @inventoryCountPdfPrintReport.
  ///
  /// In en, this message translates to:
  /// **'Print Count Report'**
  String get inventoryCountPdfPrintReport;

  /// No description provided for @inventoryCountPdfSaveReport.
  ///
  /// In en, this message translates to:
  /// **'Save Count Report PDF'**
  String get inventoryCountPdfSaveReport;

  /// No description provided for @inventoryDocumentActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Print / Save PDF'**
  String get inventoryDocumentActionsTooltip;

  /// No description provided for @itemManagementProductTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Product Type'**
  String get itemManagementProductTypeLabel;

  /// No description provided for @itemManagementProductTypeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What kind of item this is — determines how it can be sold, stocked, and purchased.'**
  String get itemManagementProductTypeSubtitle;

  /// No description provided for @itemManagementProductTypeSaleItem.
  ///
  /// In en, this message translates to:
  /// **'Sale Item'**
  String get itemManagementProductTypeSaleItem;

  /// No description provided for @itemManagementProductTypeStockItem.
  ///
  /// In en, this message translates to:
  /// **'Stock Item'**
  String get itemManagementProductTypeStockItem;

  /// No description provided for @itemManagementProductTypeService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get itemManagementProductTypeService;

  /// No description provided for @itemManagementProductTypeIngredient.
  ///
  /// In en, this message translates to:
  /// **'Ingredient'**
  String get itemManagementProductTypeIngredient;

  /// No description provided for @itemManagementProductTypeConversionOnly.
  ///
  /// In en, this message translates to:
  /// **'Conversion Only'**
  String get itemManagementProductTypeConversionOnly;

  /// No description provided for @itemManagementSectionUnits.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get itemManagementSectionUnits;

  /// No description provided for @itemManagementSaleUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Sale Unit'**
  String get itemManagementSaleUnitLabel;

  /// No description provided for @itemManagementPurchaseUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Purchase Unit'**
  String get itemManagementPurchaseUnitLabel;

  /// No description provided for @itemManagementStockUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Stock Unit'**
  String get itemManagementStockUnitLabel;

  /// No description provided for @itemManagementUnitDefaultOption.
  ///
  /// In en, this message translates to:
  /// **'Default (EACH)'**
  String get itemManagementUnitDefaultOption;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'km'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'km':
      return AppLocalizationsKm();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
