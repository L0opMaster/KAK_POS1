// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'KAKNNEA';

  @override
  String get commonName => 'Name';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonClose => 'Close';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonDone => 'Done';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonPrint => 'Print';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonSelect => 'Select';

  @override
  String get commonSelectAll => 'Select All';

  @override
  String get commonRequired => 'Required';

  @override
  String get commonOptional => 'Optional';

  @override
  String get commonNone => 'None';

  @override
  String get commonAll => 'All';

  @override
  String get commonActive => 'Active';

  @override
  String get commonInactive => 'Inactive';

  @override
  String get commonEnabled => 'Enabled';

  @override
  String get commonDisabled => 'Disabled';

  @override
  String get commonError => 'Error';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonWarning => 'Warning';

  @override
  String get commonInfo => 'Info';

  @override
  String get errorGeneric => 'An error occurred';

  @override
  String get errorNetwork => 'Network error';

  @override
  String get errorUnauthorized => 'You are not authorized';

  @override
  String get errorNotFound => 'Not found';

  @override
  String get errorValidation => 'Please check the highlighted fields';

  @override
  String get errorSomethingWentWrong => 'Something went wrong';

  @override
  String get errorTryAgain => 'Please try again';

  @override
  String get navPos => 'POS';

  @override
  String get navSettings => 'Settings';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navReports => 'Reports';

  @override
  String get navCustomers => 'Customers';

  @override
  String get navItems => 'Items';

  @override
  String get navCategories => 'Categories';

  @override
  String get navTables => 'Tables';

  @override
  String get navShifts => 'Shifts';

  @override
  String get navReceipts => 'Receipts';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKhmer => 'Khmer';

  @override
  String languageSwitchTo(String language) {
    return 'Switch to $language';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsCompanyProfile => 'Company Profile';

  @override
  String get settingsTax => 'Tax';

  @override
  String get settingsPrinters => 'Printers';

  @override
  String get settingsPaymentMethods => 'Payment Methods';

  @override
  String get settingsPosSettings => 'POS Settings';

  @override
  String get settingsCurrencies => 'Currencies';

  @override
  String get settingsCurrencySymbol => 'Symbol';

  @override
  String get settingsExchangeRatePerUsd => 'Exchange rate (per 1 USD)';

  @override
  String get settingsDarkMode => 'Dark mode';

  @override
  String get settingsLanguage => 'App language';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsSaveGeneral => 'Save General';

  @override
  String get settingsSaveCompany => 'Save Company';

  @override
  String get settingsSaveTax => 'Save Tax';

  @override
  String get settingsSavePrinters => 'Save Printers';

  @override
  String get settingsTaxRateLabel => 'Tax rate';

  @override
  String get settingsDefaultLanguage => 'Default language';

  @override
  String get settingsReceiptFooter => 'Receipt footer';

  @override
  String get settingsRequireShiftForSales => 'Require shift for sales';

  @override
  String get settingsShowKhqrOnReceipts => 'Show KHQR on receipts';

  @override
  String get printerTransportType => 'Connection type';

  @override
  String get printerPdfDriver => 'PDF / Driver printer';

  @override
  String get printerBluetooth => 'Bluetooth';

  @override
  String get printerUsb => 'USB';

  @override
  String get printerNetwork => 'Network';

  @override
  String get printerPaperSize => 'Paper size';

  @override
  String get printerPaper58mm => '58mm';

  @override
  String get printerPaper80mm => '80mm';

  @override
  String get printerIpAddress => 'IP address';

  @override
  String get printerPort => 'Port';

  @override
  String get printerSelectDevice => 'Select device';

  @override
  String get printerTestPrint => 'Test print';

  @override
  String get printerConnect => 'Connect';

  @override
  String get printerDisconnect => 'Disconnect';

  @override
  String get printerConnected => 'Connected';

  @override
  String get printerNotConnected => 'Not connected';

  @override
  String get printerScanDevices => 'Scan devices';

  @override
  String get printerPrintSuccess => 'Print succeeded';

  @override
  String get printerPrintFailed => 'Print failed';

  @override
  String get posTitle => 'POS';

  @override
  String get posSearchProducts => 'Search products';

  @override
  String get posSearchHint => 'Search by name or SKU';

  @override
  String get posBarcodeHint => 'Scan or enter barcode';

  @override
  String get posCategories => 'Categories';

  @override
  String get posCart => 'Cart';

  @override
  String get posEmptyCart => 'Cart is empty';

  @override
  String get posCheckout => 'Checkout';

  @override
  String get posHoldTicket => 'Hold ticket';

  @override
  String get posOpenTickets => 'Open tickets';

  @override
  String get posCustomer => 'Customer';

  @override
  String get posTable => 'Table';

  @override
  String get posNotifications => 'Notifications';

  @override
  String get posScannerReady =>
      'Scanner ready — scan a code or type it and press Enter';

  @override
  String get posConnectScanner => 'Connect / focus barcode scanner';

  @override
  String get posNotificationsComingSoon => 'Notifications coming soon';

  @override
  String get cartSubtotal => 'Subtotal';

  @override
  String get cartDiscount => 'Discount';

  @override
  String get cartTax => 'Tax';

  @override
  String get cartTotal => 'Total';

  @override
  String get cartQty => 'Qty';

  @override
  String get cartPrice => 'Price';

  @override
  String get cartRemove => 'Remove';

  @override
  String get cartClear => 'Clear';

  @override
  String get cartAddNote => 'Add note';

  @override
  String get cartSelectCustomer => 'Select customer';

  @override
  String get cartSelectTable => 'Select table';

  @override
  String get cartPayment => 'Payment';

  @override
  String get cartCash => 'Cash';

  @override
  String get cartCard => 'Card';

  @override
  String get cartKhqr => 'KHQR';

  @override
  String get cartAmountPaid => 'Amount paid';

  @override
  String get cartChange => 'Change';

  @override
  String get cartCompleteSale => 'Complete sale';

  @override
  String get receiptTitle => 'Receipt';

  @override
  String get receiptSaleReceipt => 'Sale Receipt';

  @override
  String get receiptInvoiceNumber => 'Invoice No.';

  @override
  String get receiptDate => 'Date';

  @override
  String get receiptTime => 'Time';

  @override
  String get receiptCashier => 'Cashier';

  @override
  String get receiptCustomer => 'Customer';

  @override
  String get receiptTable => 'Table';

  @override
  String get receiptItem => 'Item';

  @override
  String get receiptQty => 'Qty';

  @override
  String get receiptPrice => 'Price';

  @override
  String get receiptAmount => 'Amount';

  @override
  String get receiptSubtotal => 'Subtotal';

  @override
  String get receiptDiscount => 'Discount';

  @override
  String get receiptDelivery => 'Delivery';

  @override
  String get receiptOtherCharge => 'Other Charge';

  @override
  String get receiptTax => 'Tax';

  @override
  String get receiptTotal => 'Total';

  @override
  String get receiptPaid => 'Paid';

  @override
  String get receiptChange => 'Change';

  @override
  String get receiptPaymentMethod => 'Payment Method';

  @override
  String get receiptThankYou => 'Thank you for your purchase!';

  @override
  String get receiptPrint => 'Print';

  @override
  String get receiptReprint => 'Reprint';

  @override
  String get receiptExchangeRate => 'Exchange rate';

  @override
  String get dialogConfirmTitle => 'Confirm';

  @override
  String get dialogConfirmDeleteTitle => 'Confirm Delete';

  @override
  String get dialogConfirmDeleteMessage =>
      'Are you sure you want to delete this item? This action cannot be undone.';

  @override
  String get dialogUnsavedChangesTitle => 'Unsaved changes';

  @override
  String get dialogUnsavedChangesMessage =>
      'You have unsaved changes. Discard them?';

  @override
  String get formName => 'Name';

  @override
  String get formNameEn => 'Name (English)';

  @override
  String get formNameKm => 'Name (Khmer)';

  @override
  String get formPrice => 'Price';

  @override
  String get formCost => 'Cost';

  @override
  String get formSku => 'SKU';

  @override
  String get formBarcode => 'Barcode';

  @override
  String get formCategory => 'Category';

  @override
  String get formPhone => 'Phone';

  @override
  String get formEmail => 'Email';

  @override
  String get formAddress => 'Address';

  @override
  String get formPleaseEnterValue => 'Please enter a value';

  @override
  String get formInvalidValue => 'Invalid value';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsSalesSummary => 'Sales Summary';

  @override
  String get reportsSalesByItem => 'Sales by Item';

  @override
  String get reportsSalesByCategory => 'Sales by Category';

  @override
  String get reportsSalesByEmployee => 'Sales by Employee';

  @override
  String get reportsSalesByPaymentType => 'Sales by Payment Type';

  @override
  String get reportsDiscounts => 'Discounts';

  @override
  String get reportsTaxes => 'Taxes';

  @override
  String get reportsDateRange => 'Date range';

  @override
  String get reportsExport => 'Export';

  @override
  String get authLogin => 'Login';

  @override
  String get authUsername => 'Username';

  @override
  String get authPassword => 'Password';

  @override
  String get authLoginFailed => 'Login failed';

  @override
  String get authLogout => 'Logout';

  @override
  String get loginScreenBadge => 'Smart Restaurant POS';

  @override
  String get loginScreenHeadline => 'Modern POS\nFor Fast Business';

  @override
  String get loginScreenDescription =>
      'Manage restaurant orders, inventory, kitchen workflow,\ncustomer management, payments, and business reports\nfrom one complete POS platform.';

  @override
  String get loginScreenFeatureRestaurant => 'Restaurant';

  @override
  String get loginScreenFeatureMultiBranch => 'Multi Branch';

  @override
  String get loginScreenCopyright => '© 2026 KAKNNEA Technologies';

  @override
  String get loginScreenWelcomeBack => 'Welcome Back';

  @override
  String get loginScreenSubtitle =>
      'Login to access your dashboard and manage\nyour restaurant or retail business operations.';

  @override
  String get loginScreenEnterUsernameHint => 'Enter username';

  @override
  String get loginScreenEmailRequired => 'Please enter your email';

  @override
  String get loginScreenEnterPasswordHint => 'Enter password';

  @override
  String get loginScreenPasswordRequired => 'Please enter your password';

  @override
  String get loginScreenPasswordMinLength => 'Min 6 characters';

  @override
  String get loginScreenRememberMe => 'Remember me';

  @override
  String get loginScreenForgotPassword => 'Forgot Password?';

  @override
  String get loginScreenNoAccount => 'Don\'t have an account?';

  @override
  String get loginScreenRegisterLink => 'Register';

  @override
  String get createEmployeeSelectExistingAccountError =>
      'Select an existing user account to link';

  @override
  String get createEmployeeAccountFieldsRequiredError =>
      'Email, password, and role are required to create a user account';

  @override
  String get createEmployeeUpdatedMessage => 'Employee updated';

  @override
  String get createEmployeeCreatedMessage => 'Employee created';

  @override
  String get createEmployeeSaveFailedPrefix => 'Failed to save';

  @override
  String get createEmployeeHasUserAccountTitle => 'Has User Account';

  @override
  String get createEmployeeHasUserAccountSubtitle =>
      'Allow this employee to log into the POS with a role';

  @override
  String get createEmployeeLinkedAccountPrefix => 'Linked to user account:';

  @override
  String get createEmployeeLinkedAccountManageHint =>
      'Manage its role or password from User Accounts.';

  @override
  String get createEmployeeCreateNewOption => 'Create New';

  @override
  String get createEmployeeLinkExistingOption => 'Link Existing';

  @override
  String get createEmployeeLoginEmailLabel => 'Login Email *';

  @override
  String get createEmployeeAccountPasswordLabel => 'Password *';

  @override
  String get createEmployeeSelectRoleHint => 'Select role';

  @override
  String get createEmployeeRoleLabel => 'Role *';

  @override
  String get createEmployeeExistingUserAccountLabel =>
      'Existing User Account *';

  @override
  String get createEmployeeSelectUserHint => 'Select user';

  @override
  String get createEmployeeNoUnlinkedAccountsMessage =>
      'No unlinked user accounts available. Create one instead.';

  @override
  String get createEmployeeEditTitle => 'Edit Employee';

  @override
  String get createEmployeeNewTitle => 'New Employee';

  @override
  String get createEmployeeFullNameLabel => 'Full Name *';

  @override
  String get createEmployeeCodeLabel => 'Employee Code';

  @override
  String get createEmployeeCodeHint => 'Leave blank to auto-generate';

  @override
  String get createEmployeePositionLabel => 'Position';

  @override
  String get createEmployeePositionHint => 'Cashier, Chef, Manager...';

  @override
  String get createEmployeeDepartmentLabel => 'Department';

  @override
  String get createEmployeeHireDateLabel => 'Hire Date';

  @override
  String get createEmployeeNotSetLabel => 'Not set';

  @override
  String get createEmployeeBaseSalaryLabel => 'Base Salary *';

  @override
  String get createEmployeeInvalidAmountError => 'Enter a valid amount';

  @override
  String get createEmployeeNegativeAmountError => 'Cannot be negative';

  @override
  String get createEmployeePayTypeLabel => 'Pay Type';

  @override
  String get createEmployeeStatusLabel => 'Status';

  @override
  String get createEmployeeNotesLabel => 'Notes';

  @override
  String get createEmployeeSavingLabel => 'Saving...';

  @override
  String get createEmployeeSaveChangesLabel => 'Save Changes';

  @override
  String get createEmployeeCreateButtonLabel => 'Create Employee';

  @override
  String get createModifierMinOneOptionError =>
      'A modifier must have at least one option.';

  @override
  String get createModifierDiscardChangesMessage =>
      'Are you sure you want to leave this page and discard changes?';

  @override
  String get createModifierContinueEditingButton => 'CONTINUE EDITING';

  @override
  String get createModifierDiscardChangesButton => 'DISCARD CHANGES';

  @override
  String get createModifierEditTitle => 'Edit Modifier';

  @override
  String get createModifierCreateTitle => 'Create Modifier';

  @override
  String get createModifierAddOptionButton => 'ADD OPTION';

  @override
  String get createModifierRequiredSubtitle =>
      'Customer must select an option.';

  @override
  String get createModifierMultiSelectTitle => 'Allow multiple selections';

  @override
  String get createModifierMultiSelectSubtitle =>
      'Customer can select more than one option.';

  @override
  String get createModifierNameLabel => 'Modifier name';

  @override
  String get createModifierNameRequiredError => 'Modifier name cannot be blank';

  @override
  String get createModifierDeleteOptionTooltip => 'Delete option';

  @override
  String get createModifierOptionNameLabel => 'Option name';

  @override
  String get createModifierOptionNameRequiredError => 'Option name is required';

  @override
  String get createModifierPriceRequiredError => 'Price is required';

  @override
  String get createModifierInvalidPriceError => 'Enter a valid price';

  @override
  String get createModifierNegativePriceError => 'Price cannot be negative';

  @override
  String get createModifierDeleteTitle => 'Delete modifier';

  @override
  String get createModifierDeleteConfirmPrefix =>
      'Are you sure you want to delete';

  @override
  String get createModifierUpdatedMessage => 'Modifier updated successfully.';

  @override
  String get createModifierCreatedMessage => 'Modifier created successfully.';

  @override
  String get createModifierSaveFailedFallback => 'Failed to save modifier.';

  @override
  String get createModifierDeletedMessage => 'Modifier deleted successfully.';

  @override
  String get createModifierDeleteFailedFallback => 'Failed to delete modifier.';

  @override
  String get createTableUpdatedMessage => 'Table updated';

  @override
  String get createTableCreatedMessage => 'Table created';

  @override
  String get createTableSaveFailedPrefix => 'Failed to save';

  @override
  String get createTableEditTitle => 'Edit Table';

  @override
  String get createTableNewTitle => 'New Table';

  @override
  String get createTableNumberLabel => 'Table Number *';

  @override
  String get createTableNumberHint => 'A1, B2, T-01...';

  @override
  String get createTableNumberLockedHint => 'Table number cannot be changed';

  @override
  String get createTableDisplayNameLabel => 'Display Name';

  @override
  String get createTableDisplayNameHint =>
      'Leave blank to use the table number';

  @override
  String get createTableCapacityLabel => 'Capacity (seats) *';

  @override
  String get createTableInvalidNumberError => 'Enter a valid number';

  @override
  String get createTableMinCapacityError => 'Must be at least 1';

  @override
  String get createTableSectionLabel => 'Section';

  @override
  String get createTableSectionHint => 'Main Hall, Patio, VIP...';

  @override
  String get createTableStatusLabel => 'Status';

  @override
  String get createTableActiveSubtitle =>
      'Table is available for use in the POS';

  @override
  String get createTableNotesLabel => 'Notes';

  @override
  String get createTableSavingLabel => 'Saving...';

  @override
  String get createTableSaveChangesLabel => 'Save Changes';

  @override
  String get createTableCreateButtonLabel => 'Create Table';

  @override
  String get categoryManagementUpdateFailedPrefix => 'Failed to update';

  @override
  String get categoryManagementEmptyTitle => 'No categories yet';

  @override
  String get categoryManagementEmptyHint => 'Tap + to add a category';

  @override
  String get categoryManagementAddButton => 'Add Category';

  @override
  String get categoryManagementEditTitle => 'Edit Category';

  @override
  String get categoryManagementNewTitle => 'New Category';

  @override
  String get categoryManagementColorLabel => 'Color';

  @override
  String get categoryManagementActiveSubtitle => 'Show in POS category filter';

  @override
  String get categoryManagementPreviewNamePlaceholder => 'Category Name';

  @override
  String get categoryManagementUpdatedSuffix => 'updated';

  @override
  String get categoryManagementCreatedSuffix => 'created';

  @override
  String get categoryManagementSaveFailedPrefix => 'Failed to save';

  @override
  String get customerManagementDeleteTitle => 'Delete customers';

  @override
  String get customerManagementDeleteConfirmPrefix =>
      'Are you sure you want to delete';

  @override
  String get customerManagementDeleteConfirmSuffix => 'selected customer(s)?';

  @override
  String get customerManagementDeletedSuffix =>
      'customer(s) deleted successfully.';

  @override
  String get customerManagementDeleteFailedPrefix =>
      'Failed to delete customers';

  @override
  String get customerManagementAddButton => 'ADD CUSTOMER';

  @override
  String get customerManagementDeleteSelectedTooltip =>
      'Delete selected customers';

  @override
  String get customerManagementSelectedSuffix => 'selected';

  @override
  String get customerManagementSearchHint =>
      'Search by name, phone or email...';

  @override
  String get customerManagementShowingPrefix => 'Showing';

  @override
  String get customerManagementOfLabel => 'of';

  @override
  String get customerManagementNoResultsTitle => 'No customers found';

  @override
  String get customerManagementNoContactInfo => 'No contact info';

  @override
  String get customerManagementPagePrefix => 'Page';

  @override
  String get customerManagementFirstPageTooltip => 'First page';

  @override
  String get customerManagementPreviousPageTooltip => 'Previous page';

  @override
  String get customerManagementNextPageTooltip => 'Next page';

  @override
  String get customerManagementLastPageTooltip => 'Last page';

  @override
  String get customerManagementEmptyDescription =>
      'Keep track of customers and their credit balances.';

  @override
  String get customerManagementEditTitle => 'Edit Customer';

  @override
  String get customerManagementNewTitle => 'New Customer';

  @override
  String get customerManagementNameLabel => 'Customer Name *';

  @override
  String get customerManagementCreditLimitLabel => 'Credit Limit (\$)';

  @override
  String get customerManagementNotesLabel => 'Notes';

  @override
  String get customerManagementSavingLabel => 'Saving...';

  @override
  String get customerManagementUpdateButtonLabel => 'Update Customer';

  @override
  String get customerManagementCreateButtonLabel => 'Create Customer';

  @override
  String get customerManagementCreatedMessage => 'Customer created';

  @override
  String get customerManagementUpdatedMessage => 'Customer updated';

  @override
  String get customerManagementSaveFailedPrefix => 'Failed to save';

  @override
  String get customerManagementDetailFallbackTitle => 'Customer';

  @override
  String get customerManagementCreditAccountTitle => 'Credit Account';

  @override
  String get customerManagementBalanceLabel => 'Balance';

  @override
  String get customerManagementLimitPrefix => 'Limit:';

  @override
  String get customerManagementUsedSuffix => 'used';

  @override
  String get customerManagementNoPurchaseHistory => 'No purchase history';

  @override
  String get customerManagementPurchaseHistoryTitle => 'Purchase History';

  @override
  String get customerManagementSalePrefix => 'Sale #';

  @override
  String get debugSettingsUpdatedMessage => 'Settings updated';

  @override
  String get debugSettingsUnavailableMessage => 'Unavailable in release mode';

  @override
  String get debugSettingsTitle => 'Debug Settings';

  @override
  String get debugSettingsUseApiCartLabel => 'Use API cart service';

  @override
  String get debugSettingsHeldTicketSyncLabel => 'Enable held-ticket sync';

  @override
  String get createPurchaseOrderSelectSupplier => 'Select a supplier';

  @override
  String get inventoryLinesAddAtLeastOne => 'Add at least one line';

  @override
  String get createPurchaseOrderCreated => 'Purchase order created';

  @override
  String inventoryFailedToSave(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String get createPurchaseOrderTitle => 'New Purchase Order';

  @override
  String get createPurchaseOrderSupplierLabel => 'Supplier *';

  @override
  String get createPurchaseOrderDeliverToStore => 'Deliver to Store';

  @override
  String get inventoryNotSet => 'Not set';

  @override
  String get createPurchaseOrderOrderDeadline => 'Order Deadline';

  @override
  String get createPurchaseOrderExpectedArrival => 'Expected Arrival';

  @override
  String get createPurchaseOrderTaxRate => 'Tax Rate (%)';

  @override
  String get inventoryNotesLabel => 'Notes';

  @override
  String get inventoryLinesLabel => 'Lines';

  @override
  String get inventoryAddLine => 'Add Line';

  @override
  String get inventoryProductLabel => 'Product';

  @override
  String get createPurchaseOrderUnitCost => 'Unit Cost';

  @override
  String get createRecipeEnterName => 'Enter a recipe name';

  @override
  String get createRecipeSelectOutputProduct => 'Select an output product';

  @override
  String get createRecipeEnterValidQuantity => 'Enter a valid output quantity';

  @override
  String get createRecipeAddAtLeastOneComponent => 'Add at least one component';

  @override
  String get createRecipeUpdated => 'Recipe updated';

  @override
  String get createRecipeCreated => 'Recipe created';

  @override
  String get createRecipeEditTitle => 'Edit Recipe';

  @override
  String get createRecipeNewTitle => 'New Recipe';

  @override
  String get createRecipeNameLabel => 'Recipe Name *';

  @override
  String get createRecipeOutputProductLabel => 'Output Product';

  @override
  String createRecipeProductNumber(Object id) {
    return 'Product #$id';
  }

  @override
  String get createRecipeOutputProductRequiredLabel => 'Output Product *';

  @override
  String get createRecipeOutputQtyLabel => 'Output Quantity *';

  @override
  String get createRecipeComponentsLabel => 'Components';

  @override
  String get createRecipeAddComponent => 'Add Component';

  @override
  String get createRecipeComponentLabel => 'Component';

  @override
  String get createSupplierUpdated => 'Supplier updated';

  @override
  String get createSupplierCreated => 'Supplier created';

  @override
  String get createSupplierEditTitle => 'Edit Supplier';

  @override
  String get createSupplierNewTitle => 'New Supplier';

  @override
  String get createSupplierNameLabel => 'Supplier Name *';

  @override
  String get createSupplierContactPerson => 'Contact Person';

  @override
  String get createSupplierPaymentTerms => 'Payment Terms';

  @override
  String get createSupplierPaymentTermsHint => 'Net 30, COD...';

  @override
  String get createSupplierLeadTime => 'Lead Time (days)';

  @override
  String get createSupplierTaxId => 'Tax ID';

  @override
  String get createSupplierDefaultCurrency => 'Default Currency';

  @override
  String get createSupplierActiveSubtitle =>
      'Available when creating purchase orders';

  @override
  String get createSupplierSaving => 'Saving...';

  @override
  String get createSupplierSaveChanges => 'Save Changes';

  @override
  String get createSupplierCreateButton => 'Create Supplier';

  @override
  String get createTransferOrderSelectBothStores => 'Select both stores';

  @override
  String get createTransferOrderStoresMustDiffer =>
      'From and To store must be different';

  @override
  String get createTransferOrderCreated => 'Transfer created';

  @override
  String get createTransferOrderTitle => 'New Transfer';

  @override
  String get createTransferOrderFromStore => 'From Store *';

  @override
  String get createTransferOrderToStore => 'To Store *';

  @override
  String inventoryCountsFailedToStart(Object error) {
    return 'Failed to start count: $error';
  }

  @override
  String get inventoryCountsEnterValidQuantity => 'Enter a valid quantity';

  @override
  String get inventoryCountsExpectedPrefix => 'Expected';

  @override
  String get inventoryCountsCountedQtyLabel => 'Counted quantity *';

  @override
  String get inventoryCountsPostDialogTitle => 'Post count';

  @override
  String get inventoryCountsPostDialogMessage =>
      'This applies every counted variance to stock on hand and cannot be undone. Continue?';

  @override
  String get inventoryCountsPostAction => 'Post';

  @override
  String get inventoryCountsPostedSuccess => 'Count posted successfully';

  @override
  String inventoryCountsFailedToPost(Object error) {
    return 'Failed to post count: $error';
  }

  @override
  String get inventoryCountsTitle => 'Inventory Counts';

  @override
  String inventoryCountsForDate(Object date) {
    return 'Count for $date';
  }

  @override
  String get inventoryCountsStartCount => 'Start Count';

  @override
  String get inventoryCountsPostCountButton => 'Post Count';

  @override
  String get inventoryCountsEmptyTitle => 'No count started for today';

  @override
  String get inventoryCountsEmptySubtitle =>
      'Tap Start Count to snapshot expected quantities';

  @override
  String inventoryCountsProductsCount(Object count) {
    return '$count products';
  }

  @override
  String inventoryCountsUnitsOff(Object count) {
    return '$count unit(s) off';
  }

  @override
  String get inventoryCountsEnterCountTooltip => 'Enter count';

  @override
  String get inventoryHistoryTitle => 'Inventory History';

  @override
  String get inventoryHistoryFilterByProduct => 'Filter by product';

  @override
  String get inventoryHistoryAllProducts => 'All products';

  @override
  String get inventoryHistoryMovementsLabel => 'Movements';

  @override
  String inventoryHistoryShowingCount(Object shown, Object total) {
    return 'Showing $shown of $total';
  }

  @override
  String get inventoryHistoryNoMovements => 'No movements found';

  @override
  String inventoryHistoryPaginationRange(
      Object first, Object last, Object total) {
    return '$first–$last of $total';
  }

  @override
  String get inventoryHistoryFirstPage => 'First page';

  @override
  String get inventoryHistoryPrevPage => 'Previous page';

  @override
  String inventoryHistoryPageOf(Object page, Object total) {
    return 'Page $page of $total';
  }

  @override
  String get inventoryHistoryNextPage => 'Next page';

  @override
  String get inventoryHistoryLastPage => 'Last page';

  @override
  String inventoryActionFailed(Object error) {
    return 'Failed: $error';
  }

  @override
  String get inventoryCancelOrderButton => 'CANCEL ORDER';

  @override
  String get inventoryFirstPageTooltip => 'First page';

  @override
  String get inventoryHubLowStockLabel => 'Low Stock';

  @override
  String get inventoryHubOutOfStockLabel => 'Out';

  @override
  String get inventoryHubTitle => 'Stock Lookup';

  @override
  String get inventoryHubTotalLabel => 'Total';

  @override
  String get inventoryKeepButton => 'KEEP';

  @override
  String get inventoryLastPageTooltip => 'Last page';

  @override
  String inventoryLineCount(Object count) {
    return '$count line(s)';
  }

  @override
  String get inventoryNextPageTooltip => 'Next page';

  @override
  String get inventoryNoProductsFound => 'No products found';

  @override
  String inventoryOrderCount(Object count) {
    return '$count order(s)';
  }

  @override
  String inventoryPaginationPage(Object page, Object total) {
    return 'Page $page of $total';
  }

  @override
  String inventoryPaginationRange(Object start, Object end, Object total) {
    return '$start–$end of $total';
  }

  @override
  String get inventoryPreviousPageTooltip => 'Previous page';

  @override
  String inventoryShowingCount(Object shown, Object total) {
    return 'Showing $shown of $total';
  }

  @override
  String inventoryValuationAsOf(Object date) {
    return 'As of $date';
  }

  @override
  String get inventoryValuationColProduct => 'Product';

  @override
  String get inventoryValuationColStock => 'Stock';

  @override
  String get inventoryValuationColValue => 'Value';

  @override
  String get inventoryValuationProductsLabel => 'Products';

  @override
  String get inventoryValuationStockByProduct => 'Stock Value by Product';

  @override
  String get inventoryValuationTitle => 'Inventory Valuation';

  @override
  String get inventoryValuationTotalValue => 'Total Inventory Value';

  @override
  String get productionsActionComplete => 'Complete';

  @override
  String get productionsActionStart => 'Start';

  @override
  String get productionsAllComponentsAvailable => 'All components available';

  @override
  String productionsCancelOrderConfirm(Object name) {
    return 'Cancel $name?';
  }

  @override
  String get productionsCancelOrderTitle => 'Cancel production order';

  @override
  String get productionsCheckAvailabilityButton =>
      'Check Component Availability';

  @override
  String productionsCheckAvailabilityFailed(Object error) {
    return 'Failed to check availability: $error';
  }

  @override
  String get productionsCompleteButton => 'COMPLETE';

  @override
  String get productionsCompleteOrderTitle => 'Complete Production Order';

  @override
  String productionsComponentCount(Object count) {
    return '$count component(s)';
  }

  @override
  String productionsComponentNeedHave(Object required, Object onHand) {
    return 'need $required, have $onHand';
  }

  @override
  String get productionsCreateButton => 'CREATE';

  @override
  String get productionsDeactivateButton => 'DEACTIVATE';

  @override
  String productionsDeactivateRecipeConfirm(Object name) {
    return 'Deactivate \"$name\"? It will no longer be usable for new production orders.';
  }

  @override
  String get productionsDeactivateRecipeTitle => 'Deactivate recipe';

  @override
  String get productionsDeactivateTooltip => 'Deactivate';

  @override
  String get productionsInsufficientStock => 'Insufficient stock';

  @override
  String get productionsInvalidProducedQtyError =>
      'Enter a valid produced quantity';

  @override
  String get productionsMakesLabel => 'Makes';

  @override
  String get productionsNewOrderButton => 'NEW ORDER';

  @override
  String get productionsNewOrderTitle => 'New Production Order';

  @override
  String get productionsNewRecipeButton => 'NEW RECIPE';

  @override
  String get productionsNoOrdersFound => 'No production orders found';

  @override
  String get productionsNoRecipesFound => 'No recipes found';

  @override
  String get productionsNotesLabel => 'Notes';

  @override
  String productionsOrderFallback(Object id) {
    return 'Order #$id';
  }

  @override
  String get productionsOrdersTab => 'Orders';

  @override
  String get productionsPickRecipeQtyError =>
      'Pick a recipe and enter a valid quantity';

  @override
  String get productionsPlannedLabel => 'Planned';

  @override
  String get productionsPlannedQuantityLabel => 'Planned Quantity *';

  @override
  String get productionsProducedLabel => 'Produced';

  @override
  String get productionsProducedQuantityLabel => 'Produced Quantity *';

  @override
  String productionsProductFallback(Object id) {
    return 'Product #$id';
  }

  @override
  String productionsRecipeCount(Object count) {
    return '$count recipe(s)';
  }

  @override
  String productionsRecipeFallback(Object id) {
    return 'Recipe #$id';
  }

  @override
  String get productionsRecipeLabel => 'Recipe *';

  @override
  String get productionsRecipesTab => 'Recipes';

  @override
  String get productionsTitle => 'Productions';

  @override
  String get productionsWasteQuantityLabel => 'Waste Quantity';

  @override
  String get purchaseOrdersActionApprove => 'Approve';

  @override
  String purchaseOrdersActionDoneSnackbar(Object action) {
    return '$action done';
  }

  @override
  String get purchaseOrdersActionSendToSupplier => 'Send to Supplier';

  @override
  String purchaseOrdersCancelConfirm(Object name) {
    return 'Cancel $name?';
  }

  @override
  String get purchaseOrdersCancelTitle => 'Cancel purchase order';

  @override
  String get purchaseOrdersEmptySubtitle => 'Order stock from your suppliers.';

  @override
  String get purchaseOrdersNewButton => 'NEW PURCHASE ORDER';

  @override
  String get purchaseOrdersNoOrdersFound => 'No purchase orders found';

  @override
  String purchaseOrdersPoFallback(Object id) {
    return 'PO #$id';
  }

  @override
  String purchaseOrdersSupplierFallback(Object id) {
    return 'Supplier #$id';
  }

  @override
  String get purchaseOrdersTitle => 'Purchase Orders';

  @override
  String get stockAdjustmentReasonDamaged => 'Damaged';

  @override
  String get stockAdjustmentReasonFound => 'Found';

  @override
  String get stockAdjustmentReasonLost => 'Lost';

  @override
  String get stockAdjustmentReasonManualCount => 'Manual Count';

  @override
  String get stockAdjustmentReasonOther => 'Other';

  @override
  String get stockAdjustmentReasonReceived => 'Received';

  @override
  String get stockAdjustmentReasonReturned => 'Returned';

  @override
  String get stockAdjustmentsEmptySubtitle =>
      'Record manual stock corrections — damaged, lost, found, or recounted items.';

  @override
  String get stockAdjustmentsMovementsHeader => 'Movements';

  @override
  String get stockAdjustmentsNewButton => 'NEW ADJUSTMENT';

  @override
  String get stockAdjustmentsNewTitle => 'New Stock Adjustment';

  @override
  String get stockAdjustmentsNoMatchingMovements =>
      'No matching movements found';

  @override
  String get stockAdjustmentsNoMovements => 'No movements found';

  @override
  String get stockAdjustmentsPickProductError =>
      'Pick a product and enter a non-zero quantity';

  @override
  String get stockAdjustmentsProductLabel => 'Product *';

  @override
  String get stockAdjustmentsQuantityChangeLabel => 'Quantity change *';

  @override
  String get stockAdjustmentsQuantityHint => 'e.g. 10 or -5';

  @override
  String get stockAdjustmentsReasonLabel => 'Reason';

  @override
  String get stockAdjustmentsSearchHint => 'Search by product or reason...';

  @override
  String get stockAdjustmentsTitle => 'Stock Adjustments';

  @override
  String get suppliersAddButton => 'ADD SUPPLIER';

  @override
  String suppliersDeleteConfirm(Object count) {
    return 'Are you sure you want to delete $count selected supplier(s)?';
  }

  @override
  String suppliersDeleteFailed(Object error) {
    return 'Failed to delete suppliers: $error';
  }

  @override
  String get suppliersDeleteSelectedTooltip => 'Delete selected suppliers';

  @override
  String suppliersDeleteSuccess(Object count) {
    return '$count supplier(s) deleted successfully.';
  }

  @override
  String get suppliersDeleteTitle => 'Delete suppliers';

  @override
  String get suppliersEmptySubtitle => 'Keep track of who you buy stock from.';

  @override
  String get suppliersNoContactSet => 'No contact set';

  @override
  String get suppliersNoMatchingSuppliersFound => 'No matching suppliers found';

  @override
  String get suppliersNoSuppliersFound => 'No suppliers found';

  @override
  String suppliersOwedAmount(Object amount) {
    return 'Owed $amount';
  }

  @override
  String get suppliersSearchHint => 'Search suppliers...';

  @override
  String suppliersSelectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get suppliersTitle => 'Suppliers';

  @override
  String transferOrdersCancelConfirm(Object name) {
    return 'Cancel transfer $name?';
  }

  @override
  String get transferOrdersCancelTitle => 'Cancel transfer';

  @override
  String get transferOrdersCancelTransferButton => 'CANCEL TRANSFER';

  @override
  String get transferOrdersCompletedSnackbar => 'Transfer completed';

  @override
  String transferOrdersCount(Object count) {
    return '$count transfer(s)';
  }

  @override
  String get transferOrdersEmptySubtitle =>
      'Move stock between store locations.';

  @override
  String transferOrdersFailedToCancel(Object error) {
    return 'Failed to cancel: $error';
  }

  @override
  String transferOrdersFailedToComplete(Object error) {
    return 'Failed to complete: $error';
  }

  @override
  String get transferOrdersMarkComplete => 'Mark Complete';

  @override
  String get transferOrdersNewButton => 'NEW TRANSFER';

  @override
  String get transferOrdersNoTransfersFound => 'No transfers found';

  @override
  String get transferOrdersTitle => 'Transfer Orders';

  @override
  String transferOrdersTransferFallback(Object id) {
    return 'Transfer #$id';
  }

  @override
  String get paymentScreenMethodAba => 'ABA Pay';

  @override
  String get paymentScreenMethodBankTransfer => 'Bank Transfer';

  @override
  String get paymentScreenMethodWing => 'Wing';

  @override
  String get paymentScreenMethodAcleda => 'ACLEDA';

  @override
  String get paymentScreenMethodCheck => 'Check';

  @override
  String get paymentScreenMethodOther => 'Other';

  @override
  String paymentScreenSplitAmountTitle(Object number) {
    return 'Split $number Amount';
  }

  @override
  String get paymentScreenSplitPayment => 'Split Payment';

  @override
  String get paymentScreenPaymentComplete => 'Payment Complete';

  @override
  String get paymentScreenPaymentFailed => 'Payment Failed';

  @override
  String paymentScreenCartCount(Object count) {
    return 'Cart ($count)';
  }

  @override
  String paymentScreenBaseModifierLine(Object base, Object modifier) {
    return 'Base: $base + Modifier: $modifier';
  }

  @override
  String get paymentScreenTotalDue => 'Total Due';

  @override
  String get paymentScreenCashReceived => 'Cash Received';

  @override
  String get paymentScreenExact => 'Exact';

  @override
  String get paymentScreenShort => 'Short';

  @override
  String get paymentScreenChargeCash => 'Charge Cash';

  @override
  String get paymentScreenPayFullAmount => 'Pay Full Amount';

  @override
  String paymentScreenTotalLabel(Object amount) {
    return 'Total: $amount';
  }

  @override
  String paymentScreenRemainingLabel(Object amount) {
    return 'Remaining: $amount';
  }

  @override
  String get paymentScreenAllPaid => 'All paid';

  @override
  String get paymentScreenRemaining => 'Remaining';

  @override
  String paymentScreenOfAmount(Object amount) {
    return 'of $amount';
  }

  @override
  String get paymentScreenCharge => 'Charge';

  @override
  String get paymentScreenSubmitting => 'Submitting…';

  @override
  String paymentScreenInvoiceNumber(Object number) {
    return 'Invoice #$number';
  }

  @override
  String paymentScreenWaitingNumber(Object number) {
    return 'Waiting Number  #$number';
  }

  @override
  String get paymentScreenReceiptHeader => 'KAKNNEA POS';

  @override
  String get paymentScreenPayments => 'Payments';

  @override
  String get paymentScreenPrintReceipt => 'Print Receipt';

  @override
  String get paymentScreenEmailReceipt => 'Email Receipt';

  @override
  String get paymentScreenNewSale => 'New Sale';

  @override
  String get paymentScreenTryAgain => 'Try Again';

  @override
  String paymentScreenWaitingTicketSaveFailed(Object error) {
    return 'Payment succeeded, but waiting ticket was not saved: $error';
  }

  @override
  String paymentScreenSaleFailed(Object error) {
    return 'Sale failed: $error';
  }

  @override
  String get itemManagementDeleteItemsTitle => 'Delete items';

  @override
  String itemManagementDeleteItemsMessage(Object count) {
    return 'Are you sure you want to delete $count selected item(s)?';
  }

  @override
  String itemManagementItemsDeletedSuccess(Object count) {
    return '$count item(s) deleted successfully.';
  }

  @override
  String itemManagementFailedToDeleteItems(Object error) {
    return 'Failed to delete items: $error';
  }

  @override
  String get itemManagementAddItem => 'Add Item';

  @override
  String get itemManagementDeleteSelectedItemsTooltip =>
      'Delete selected items';

  @override
  String itemManagementSelectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get itemManagementSearchHint => 'Search items by name or SKU...';

  @override
  String itemManagementShowingCount(Object shown, Object total) {
    return 'Showing $shown of $total';
  }

  @override
  String get itemManagementNoItemsFound => 'No items found';

  @override
  String get itemManagementNoCategorySet => 'No category set';

  @override
  String get itemManagementFirstPage => 'First page';

  @override
  String get itemManagementPreviousPage => 'Previous page';

  @override
  String itemManagementPageOfPages(Object current, Object total) {
    return 'Page $current of $total';
  }

  @override
  String get itemManagementNextPage => 'Next page';

  @override
  String get itemManagementLastPage => 'Last page';

  @override
  String itemManagementRangeOfTotal(Object first, Object last, Object total) {
    return '$first–$last of $total';
  }

  @override
  String get itemManagementEmptyStateDescription =>
      'Create and manage the items sold at the POS.';

  @override
  String get itemManagementProductImageTitle => 'Product Image';

  @override
  String get itemManagementImageUrlLabel => 'Image URL';

  @override
  String get itemManagementUseUrl => 'Use URL';

  @override
  String get itemManagementOrUploadFromDevice => 'Or upload from device';

  @override
  String get itemManagementUploadImage => 'Upload Image';

  @override
  String get itemManagementSkuRequired => 'SKU is required';

  @override
  String get itemManagementBarcodeRequired => 'Barcode is required';

  @override
  String get itemManagementKhmerNameRequired => 'Khmer name is required';

  @override
  String get itemManagementPleaseSelectCategory => 'Please select a category';

  @override
  String itemManagementItemUpdated(Object name) {
    return '\"$name\" updated';
  }

  @override
  String itemManagementItemCreated(Object name) {
    return '\"$name\" created';
  }

  @override
  String itemManagementFailedToSave(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String itemManagementModifiersNotUpdated(Object error) {
    return 'Item saved, but modifiers were not updated: $error';
  }

  @override
  String get itemManagementEditItemTitle => 'Edit Item';

  @override
  String get itemManagementNewItemTitle => 'New Item';

  @override
  String get itemManagementSectionBasicInfo => 'Basic Info';

  @override
  String get itemManagementSelectCategoryHint => 'Select a category';

  @override
  String get itemManagementSectionDescriptionOptional =>
      'Description (optional)';

  @override
  String get itemManagementDescriptionHint =>
      'Additional details visible in POS ticket';

  @override
  String get itemManagementSectionPricing => 'Pricing';

  @override
  String get itemManagementSellPriceLabel => 'Sell Price *';

  @override
  String get itemManagementInvalidNumber => 'Invalid number';

  @override
  String get itemManagementSectionInventory => 'Inventory';

  @override
  String get itemManagementTrackInventoryTitle => 'Track inventory';

  @override
  String get itemManagementManageStockQuantitySubtitle =>
      'Manage stock quantity';

  @override
  String get itemManagementInitialStockLabel => 'Initial Stock';

  @override
  String get itemManagementLowStockAlertLabel => 'Low Stock Alert';

  @override
  String get itemManagementSectionStatus => 'Status';

  @override
  String get itemManagementProductAvailableSubtitle =>
      'Product is available for sale';

  @override
  String get itemManagementSellableTitle => 'Sellable';

  @override
  String get itemManagementCanBeSoldInPosSubtitle => 'Can be sold in POS';

  @override
  String get itemManagementSectionModifiers => 'Modifiers';

  @override
  String get itemManagementNoModifiersYet =>
      'No modifiers yet. Create one from Modifiers management first.';

  @override
  String get itemManagementNoOptions => 'No options';

  @override
  String get itemManagementSectionImage => 'Image';

  @override
  String get itemManagementSavingEllipsis => 'Saving...';

  @override
  String get itemManagementUpdateItem => 'Update Item';

  @override
  String get itemManagementCreateItem => 'Create Item';

  @override
  String get employeeManagementTitle => 'Employee List';

  @override
  String get employeeManagementDeleteDialogTitle => 'Delete employees';

  @override
  String employeeManagementDeleteDialogMessage(Object count) {
    return 'Are you sure you want to delete $count selected employee(s)?';
  }

  @override
  String employeeManagementDeleteSuccess(Object count) {
    return '$count employee(s) deleted successfully.';
  }

  @override
  String employeeManagementDeleteFailed(Object error) {
    return 'Failed to delete employees: $error';
  }

  @override
  String get employeeManagementAddEmployee => 'ADD EMPLOYEE';

  @override
  String get employeeManagementDeleteSelectedTooltip =>
      'Delete selected employees';

  @override
  String employeeManagementSelectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get employeeManagementSearchHint => 'Search employees...';

  @override
  String get employeeManagementEmployeesHeader => 'Employees';

  @override
  String employeeManagementShowingCount(Object shown, Object total) {
    return 'Showing $shown of $total';
  }

  @override
  String get employeeManagementNoEmployeesFound => 'No employees found';

  @override
  String get employeeManagementNoPositionSet => 'No position set';

  @override
  String employeeManagementRangeOfTotal(
      Object first, Object last, Object total) {
    return '$first–$last of $total';
  }

  @override
  String get employeeManagementFirstPage => 'First page';

  @override
  String get employeeManagementPreviousPage => 'Previous page';

  @override
  String employeeManagementPageOf(Object current, Object total) {
    return 'Page $current of $total';
  }

  @override
  String get employeeManagementNextPage => 'Next page';

  @override
  String get employeeManagementLastPage => 'Last page';

  @override
  String get employeeManagementEmptyTitle => 'Employee';

  @override
  String get employeeManagementEmptyDescription =>
      'Create sets of options that can be applied to employees.';

  @override
  String get modifierManagementTitle => 'Modifiers';

  @override
  String get modifierManagementDeleteDialogTitle => 'Delete modifiers';

  @override
  String modifierManagementDeleteDialogMessage(Object count) {
    return 'Are you sure you want to delete $count selected modifier(s)?';
  }

  @override
  String modifierManagementDeleteSuccess(Object count) {
    return '$count modifier(s) deleted successfully.';
  }

  @override
  String get modifierManagementDeleteFailedDefault =>
      'Failed to delete modifiers.';

  @override
  String get modifierManagementEmptyTitle => 'Item modifiers';

  @override
  String get modifierManagementEmptyDescription =>
      'Create sets of options that can be applied to items.';

  @override
  String get modifierManagementAddModifier => 'ADD MODIFIER';

  @override
  String get modifierManagementDeleteSelectedTooltip =>
      'Delete selected modifiers';

  @override
  String modifierManagementSelectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get modifierManagementSearchHint => 'Search modifiers...';

  @override
  String get modifierManagementSectionHeader => 'Modifier';

  @override
  String modifierManagementShowingCount(Object shown, Object total) {
    return 'Showing $shown of $total';
  }

  @override
  String get modifierManagementNoModifiersFound => 'No modifiers found';

  @override
  String get modifierManagementNoOptions => 'No options';

  @override
  String get modifierManagementApplyToProductsTooltip => 'Apply to products';

  @override
  String modifierManagementProductsUpdated(Object name) {
    return 'Updated products for \"$name\".';
  }

  @override
  String modifierManagementRangeOfTotal(
      Object first, Object last, Object total) {
    return '$first–$last of $total';
  }

  @override
  String get modifierManagementFirstPage => 'First page';

  @override
  String get modifierManagementPreviousPage => 'Previous page';

  @override
  String modifierManagementPageOf(Object current, Object total) {
    return 'Page $current of $total';
  }

  @override
  String get modifierManagementNextPage => 'Next page';

  @override
  String get modifierManagementLastPage => 'Last page';

  @override
  String modifierProductAssignmentSearchFailed(Object error) {
    return 'Search failed: $error';
  }

  @override
  String modifierProductAssignmentTitle(Object groupName) {
    return 'Apply \"$groupName\" to products';
  }

  @override
  String get modifierProductAssignmentDescription =>
      'Customers will be able to choose from this modifier whenever a checked product is added to the cart.';

  @override
  String modifierProductAssignmentSelectedCount(Object count) {
    return '$count product(s) selected';
  }

  @override
  String get modifierProductAssignmentNoProducts => 'No products found';

  @override
  String get openTicketPageEmptyTitle => 'No held tickets';

  @override
  String get openTicketPageEmptySubtitle =>
      'Tap \"Hold\" on the POS screen to save a sale here';

  @override
  String openTicketPageTicketNumber(Object number) {
    return 'Ticket #$number';
  }

  @override
  String openTicketPageItemCount(Object count) {
    return '$count items';
  }

  @override
  String get openTicketPageJustNow => 'Just now';

  @override
  String openTicketPageMinutesAgo(Object minutes) {
    return '${minutes}m ago';
  }

  @override
  String openTicketPageHoursAgo(Object hours) {
    return '${hours}h ago';
  }

  @override
  String openTicketPageDaysAgo(Object days) {
    return '${days}d ago';
  }

  @override
  String get openTicketPageRestore => 'Restore';

  @override
  String get paginationFirstPage => 'First page';

  @override
  String get paginationLastPage => 'Last page';

  @override
  String get paginationNextPage => 'Next page';

  @override
  String paginationPageOf(Object current, Object total) {
    return 'Page $current of $total';
  }

  @override
  String get paginationPreviousPage => 'Previous page';

  @override
  String paginationRangeOfTotal(Object first, Object last, Object total) {
    return '$first–$last of $total';
  }

  @override
  String paginationShowingOfTotal(Object shown, Object total) {
    return 'Showing $shown of $total';
  }

  @override
  String get permissionScreenEmpty => 'No permissions found';

  @override
  String get permissionScreenListHeader => 'Permission List';

  @override
  String get permissionScreenNoMatch => 'No matching permissions found';

  @override
  String get permissionScreenSearchHint => 'Search permissions...';

  @override
  String get permissionScreenTitle => 'Permissions';

  @override
  String phoneScanScreenBarcodeSent(Object value) {
    return '$value sent to POS';
  }

  @override
  String get phoneScanScreenConnectButton => 'Connect to POS';

  @override
  String get phoneScanScreenConnectedReady =>
      'Connected — point the camera at a 1D barcode';

  @override
  String get phoneScanScreenConnectFailed =>
      'Could not connect. Check the server URL, Wi-Fi and code.';

  @override
  String get phoneScanScreenConnectHeadline =>
      'Connect this phone to the active POS';

  @override
  String get phoneScanScreenConnecting => 'Connecting...';

  @override
  String get phoneScanScreenConnectSubtitle =>
      'The phone and POS must use the same Wi-Fi and backend server.';

  @override
  String phoneScanScreenDetectedSending(Object value) {
    return '$value detected — sending to POS';
  }

  @override
  String get phoneScanScreenDisconnected => 'Disconnected';

  @override
  String get phoneScanScreenDisconnectTooltip => 'Disconnect';

  @override
  String get phoneScanScreenEnterCode =>
      'Enter the 8-character code shown on the POS';

  @override
  String get phoneScanScreenFlashlight => 'Flashlight';

  @override
  String phoneScanScreenLastBarcode(Object barcode) {
    return 'Last barcode: $barcode';
  }

  @override
  String get phoneScanScreenPosEndedSession =>
      'The POS ended this scanner session';

  @override
  String get phoneScanScreenReadyToScan => 'Ready to scan';

  @override
  String get phoneScanScreenRelayError => 'Scanner relay error';

  @override
  String get phoneScanScreenServerUrlLabel => 'POS server URL';

  @override
  String get phoneScanScreenSessionCodeHint => 'Example: 7KMX4P2R';

  @override
  String get phoneScanScreenSessionCodeLabel => 'POS session code';

  @override
  String get phoneScanScreenTitle => 'Phone 1D Scanner';

  @override
  String get posDrawerAddCustomer => 'Add Customer';

  @override
  String get posDrawerAddItem => 'Add Item';

  @override
  String get posDrawerAddTable => 'Add Table';

  @override
  String get posDrawerCustomerList => 'Customer List';

  @override
  String get posDrawerEmployees => 'Employees';

  @override
  String get posDrawerEmployeesList => 'Employees List';

  @override
  String get posDrawerHeldTickets => 'Held Tickets';

  @override
  String get posDrawerInventoryCounts => 'Inventory Counts';

  @override
  String get posDrawerInventoryHistory => 'Inventory History';

  @override
  String get posDrawerInventoryManagement => 'Inventory Management';

  @override
  String get posDrawerInventoryValuation => 'Inventory Valuation';

  @override
  String get posDrawerItemList => 'Item List';

  @override
  String get posDrawerLogoutConfirm => 'Are you sure you want to logout?';

  @override
  String get posDrawerModifiers => 'Modifiers';

  @override
  String get posDrawerOnlineStatus => 'Online · Cashier';

  @override
  String get posDrawerPermission => 'Permission';

  @override
  String get posDrawerProductions => 'Productions';

  @override
  String get posDrawerPurchaseOrders => 'Purchase Orders';

  @override
  String get posDrawerRegister => 'Register';

  @override
  String get posDrawerRole => 'Role';

  @override
  String get posDrawerSalesByCashier => 'Sales by Cashier';

  @override
  String get posDrawerSalesByModifier => 'Sales by Modifier';

  @override
  String get posDrawerStockAdjustments => 'Stock Adjustments';

  @override
  String get posDrawerStockLookup => 'Stock Lookup';

  @override
  String get posDrawerStoreName => 'Kaknnea Store';

  @override
  String get posDrawerSuppliers => 'Suppliers';

  @override
  String get posDrawerTableList => 'Table List';

  @override
  String get posDrawerTransferOrders => 'Transfer Orders';

  @override
  String get posDrawerUnits => 'Units';

  @override
  String get posDrawerUserAccount => 'User Account';

  @override
  String get posSettingsScreenAlertEmailLabel => 'Alert email (optional)';

  @override
  String get posSettingsScreenAutoPrint => 'Auto-print after payment';

  @override
  String get posSettingsScreenCashRounding => 'Cash Rounding';

  @override
  String get posSettingsScreenColumns => 'Columns';

  @override
  String get posSettingsScreenDefaultLayout => 'Default layout';

  @override
  String get posSettingsScreenDiscount => 'Discount';

  @override
  String get posSettingsScreenEnableFavorites => 'Enable favorites';

  @override
  String get posSettingsScreenEnableKitchenDisplay => 'Enable kitchen display';

  @override
  String get posSettingsScreenKitchenDisplay => 'Kitchen Display';

  @override
  String get posSettingsScreenKitchenPrinterLabel => 'Kitchen printer name/IP';

  @override
  String get posSettingsScreenKitchenSubtitle =>
      'Send orders to kitchen printer';

  @override
  String get posSettingsScreenLowStockAlert => 'Low stock alert';

  @override
  String get posSettingsScreenPaperWidth => 'Paper width (mm)';

  @override
  String get posSettingsScreenPinFavoriteProducts => 'Pin favourite products';

  @override
  String get posSettingsScreenPinSubtitle => 'Cashier must enter PIN on launch';

  @override
  String posSettingsScreenQuickPresets(Object presets) {
    return 'Quick presets: $presets';
  }

  @override
  String get posSettingsScreenRequireDiscountReason =>
      'Require reason for discount';

  @override
  String get posSettingsScreenRequirePin => 'Require PIN to open POS';

  @override
  String get posSettingsScreenRoundingInterval => 'Rounding interval';

  @override
  String get posSettingsScreenRoundingMode => 'Rounding mode';

  @override
  String get posSettingsScreenSaleScreen => 'Sale Screen';

  @override
  String get posSettingsScreenSaveAll => 'Save All Settings';

  @override
  String get posSettingsScreenSaveAllTooltip => 'Save all settings';

  @override
  String get posSettingsScreenSaved => 'POS settings saved';

  @override
  String posSettingsScreenSaveFailed(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String get posSettingsScreenSaving => 'Saving...';

  @override
  String get posSettingsScreenSecurity => 'Security';

  @override
  String get posSettingsScreenShowBarcodes => 'Show barcodes';

  @override
  String get posSettingsScreenShowCustomerInfo => 'Show customer info';

  @override
  String get posSettingsScreenStockAlerts => 'Stock Alerts';

  @override
  String receiptsScreenBaseWithUnit(Object amount, Object unit) {
    return 'Base: $amount/$unit';
  }

  @override
  String get receiptsScreenConfirmRefundButton => 'Confirm Refund';

  @override
  String receiptsScreenDaysAgo(Object days) {
    return '${days}d ago';
  }

  @override
  String get receiptsScreenDeliveryLabel => 'Delivery';

  @override
  String get receiptsScreenDescriptionHeader => 'Description';

  @override
  String get receiptsScreenEachUnitFallback => 'ea';

  @override
  String get receiptsScreenEmailDialogBody =>
      'Enter the customer\'s email address:';

  @override
  String get receiptsScreenEmailDialogTitle => 'Email Receipt';

  @override
  String get receiptsScreenEmailHint => 'customer@example.com';

  @override
  String get receiptsScreenEmptySubtitle => 'Complete a sale to see it here';

  @override
  String get receiptsScreenEmptyTitle => 'No receipts yet';

  @override
  String receiptsScreenExchangeRateValue(Object rate) {
    return '1 USD = $rate KHR';
  }

  @override
  String receiptsScreenHoursAgo(Object hours) {
    return '${hours}h ago';
  }

  @override
  String get receiptsScreenItemFallback => 'Item';

  @override
  String get receiptsScreenJustNow => 'just now';

  @override
  String get receiptsScreenManagerEmailLabel => 'Manager email';

  @override
  String get receiptsScreenManagerPasswordLabel => 'Manager password';

  @override
  String receiptsScreenMinutesAgo(Object minutes) {
    return '${minutes}m ago';
  }

  @override
  String get receiptsScreenModeLabel => 'Mode';

  @override
  String receiptsScreenModifiersWithUnit(Object amount, Object unit) {
    return 'Modifiers: $amount/$unit';
  }

  @override
  String get receiptsScreenOtherLabel => 'Other';

  @override
  String get receiptsScreenPaymentFallback => 'Payment';

  @override
  String get receiptsScreenPoweredBy => 'Powered by KAKNNEA';

  @override
  String get receiptsScreenPrintNotConnected =>
      'Print receipt - connect a printer';

  @override
  String get receiptsScreenPrintReceipt => 'Print Receipt';

  @override
  String get receiptsScreenPrintAll => 'Print All';

  @override
  String get receiptsScreenPrintAllTooltip => 'Print all receipts';

  @override
  String get receiptsScreenPrintAllConfirmTitle => 'Print all receipts?';

  @override
  String receiptsScreenPrintAllConfirmBody(Object count) {
    return 'Print all $count receipts?';
  }

  @override
  String get receiptsScreenPreparingReceipts => 'Preparing receipts...';

  @override
  String get receiptsScreenPrintingReceipts => 'Printing receipts...';

  @override
  String receiptsScreenPrintAllProgress(Object done, Object total) {
    return '$done / $total';
  }

  @override
  String receiptsScreenLoadReceiptFailed(Object invoice) {
    return 'Unable to load receipt $invoice.';
  }

  @override
  String get receiptsScreenPrintReceiptFailed => 'Unable to print receipt.';

  @override
  String receiptsScreenPrintAllDone(Object printed, Object total) {
    return 'Printed $printed of $total receipts.';
  }

  @override
  String receiptsScreenPrintAllPartialFailure(Object count) {
    return '$count receipt(s) could not be printed.';
  }

  @override
  String get receiptsScreenSavePdf => 'Save PDF';

  @override
  String get receiptsScreenReasonOptionalLabel => 'Reason (optional)';

  @override
  String receiptsScreenReceiptCount(Object count) {
    return '$count receipt(s)';
  }

  @override
  String get receiptsScreenReceiptNoLabel => 'Receipt No.';

  @override
  String receiptsScreenReceiptSentTo(Object email) {
    return 'Receipt sent to $email';
  }

  @override
  String receiptsScreenRefundAlreadyRefundedLine(Object amount) {
    return 'Already refunded: $amount';
  }

  @override
  String receiptsScreenRefundAmountLine(Object amount) {
    return 'Refund amount: $amount';
  }

  @override
  String receiptsScreenRefundConfirmPrefix(Object reference) {
    return 'Issue a refund for $reference?';
  }

  @override
  String get receiptsScreenRefund => 'Refund';

  @override
  String receiptsScreenRefundReceiptFallback(Object id) {
    return 'receipt #$id';
  }

  @override
  String get receiptsScreenRefundSubmitted => 'Refund submitted';

  @override
  String receiptsScreenRefundTotalLine(Object amount) {
    return 'Total: $amount';
  }

  @override
  String receiptsScreenSaleFallback(Object id) {
    return 'Sale #$id';
  }

  @override
  String get receiptsScreenSearchHint => 'Search by invoice, customer...';

  @override
  String get receiptsScreenSelectHint => 'Tap a receipt to view details';

  @override
  String get receiptsScreenSendButton => 'Send';

  @override
  String get receiptsScreenSendByEmail => 'Send by Email';

  @override
  String get receiptsScreenShiftSegment => 'Shift';

  @override
  String receiptsScreenTelLabel(Object phone) {
    return 'Tel: $phone';
  }

  @override
  String get receiptsScreenThankYouFooter => 'Thank you ❤️';

  @override
  String get receiptsScreenTotalRielLabel => 'Total (Riel)';

  @override
  String get receiptsScreenWalkIn => 'Walk-in';

  @override
  String get roleManagementScreenEmpty => 'No roles found';

  @override
  String get roleManagementScreenListHeader => 'Role List';

  @override
  String get roleManagementScreenNoMatch => 'No matching roles found';

  @override
  String roleManagementScreenPermissionsFor(Object role) {
    return 'Permissions for $role';
  }

  @override
  String roleManagementScreenPermissionsGranted(Object count) {
    return '$count permission(s) granted';
  }

  @override
  String roleManagementScreenSaveFailed(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String get roleManagementScreenSearchHint => 'Search roles...';

  @override
  String get roleManagementScreenTitle => 'Roles';

  @override
  String shiftScreenBlockers(Object list) {
    return 'Blockers: $list';
  }

  @override
  String get shiftScreenCashEvents => 'Cash Events';

  @override
  String get shiftScreenCashIn => 'Cash In';

  @override
  String get shiftScreenCashOut => 'Cash Out';

  @override
  String shiftScreenCloseShiftFailed(Object error) {
    return 'Failed to close shift: $error';
  }

  @override
  String get shiftScreenCloseShift => 'Close Shift';

  @override
  String get shiftScreenClosingCashLabel => 'Closing cash';

  @override
  String shiftScreenExpectedCash(Object amount) {
    return 'Expected cash: $amount';
  }

  @override
  String get shiftScreenNoCashEvents => 'No cash events yet';

  @override
  String get shiftScreenNoOpenShiftSubtitle =>
      'Open a shift before taking sales.';

  @override
  String get shiftScreenNoOpenShiftTitle => 'No open shift';

  @override
  String shiftScreenOpened(Object time) {
    return 'Opened $time';
  }

  @override
  String shiftScreenOpeningCash(Object amount) {
    return 'Opening cash: $amount';
  }

  @override
  String get shiftScreenOpeningCashLabel => 'Opening cash';

  @override
  String get shiftScreenOpen => 'Open';

  @override
  String shiftScreenOpenShiftFailed(Object error) {
    return 'Failed to open shift: $error';
  }

  @override
  String get shiftScreenOpenShift => 'Open Shift';

  @override
  String shiftScreenPrecheckFailed(Object error) {
    return 'Failed to load close precheck: $error';
  }

  @override
  String get shiftScreenReasonLabel => 'Reason';

  @override
  String shiftScreenSaveCashEventFailed(Object error) {
    return 'Failed to save cash event: $error';
  }

  @override
  String shiftScreenShiftNumber(Object id) {
    return 'Shift #$id';
  }

  @override
  String get shiftScreenTitle => 'Shift Management';

  @override
  String shiftScreenVariance(Object amount) {
    return 'Variance: $amount';
  }

  @override
  String paginationPageOfTotal(Object page, Object totalPages) {
    return 'Page $page of $totalPages';
  }

  @override
  String get tableManagementDeleteTablesTitle => 'Delete tables';

  @override
  String tableManagementDeleteTablesMessage(Object count) {
    return 'Are you sure you want to delete $count selected table(s)? Occupied tables cannot be deleted.';
  }

  @override
  String tableManagementDeleteSuccess(Object count) {
    return '$count table(s) deleted successfully.';
  }

  @override
  String tableManagementDeleteFailed(Object error) {
    return 'Failed to delete tables: $error';
  }

  @override
  String get tableManagementAddTable => 'Add Table';

  @override
  String get tableManagementDeleteSelectedTooltip => 'Delete selected tables';

  @override
  String tableManagementSelectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get tableManagementSearchHint => 'Search tables...';

  @override
  String get tableManagementNoResults => 'No tables found';

  @override
  String tableManagementSeatsCount(Object count) {
    return '$count seats';
  }

  @override
  String get tableManagementEmptyStateDescription =>
      'Set up the tables available for dine-in orders.';

  @override
  String get userAccountAllFieldsRequired => 'All fields are required';

  @override
  String userAccountCreateFailed(Object error) {
    return 'Failed to create user: $error';
  }

  @override
  String get userAccountAddTitle => 'Add User Account';

  @override
  String get userAccountFullNameLabel => 'Full Name *';

  @override
  String get userAccountEmailLabel => 'Email *';

  @override
  String get userAccountPasswordLabel => 'Password *';

  @override
  String get userAccountRoleLabel => 'Role *';

  @override
  String get userAccountCreateButton => 'Create';

  @override
  String userAccountUpdateStatusFailed(Object error) {
    return 'Failed to update status: $error';
  }

  @override
  String get userAccountScreenTitle => 'User Accounts';

  @override
  String get userAccountAddButton => 'Add User';

  @override
  String get userAccountSearchHint => 'Search users...';

  @override
  String get userAccountEmptyMessage => 'No user accounts yet';

  @override
  String get userAccountNoResultsMessage => 'No user accounts found';

  @override
  String get cartActionsApplyDiscountTitle => 'Apply Discount';

  @override
  String get cartActionsAmountHint => 'Amount';

  @override
  String get cartActionsClearCart => 'Clear Cart';

  @override
  String cartFooterTotalAmount(Object amount) {
    return 'Total: $amount';
  }

  @override
  String cartFooterDiscountAmount(Object amount) {
    return 'Discount: -$amount';
  }

  @override
  String cartFooterLoyaltyAmount(Object amount) {
    return 'Loyalty: -$amount';
  }

  @override
  String cartFooterFinalAmount(Object amount) {
    return 'Final: $amount';
  }

  @override
  String get cartFooterClearDiscount => 'Clear Discount';

  @override
  String get cartFooterClearLoyalty => 'Clear Loyalty';

  @override
  String get cartItemsListTapToAdd => 'Tap a product to add it';

  @override
  String get cartItemsListOpenHeldTickets => 'Open Held Tickets';

  @override
  String get cartItemsListDescriptionHeader => 'Description';

  @override
  String cartItemsListEditItemTitle(Object name) {
    return 'Edit $name';
  }

  @override
  String get cartItemsListQuantityLabel => 'Quantity';

  @override
  String get cartItemsListNoteLabel => 'Note';

  @override
  String get cartItemsListNoteHint => 'e.g. extra sauce, no ice';

  @override
  String get cartItemsListDiscountPerUnitLabel => 'Discount per unit';

  @override
  String cartItemsListMaxDiscountHint(Object amount) {
    return 'Max $amount';
  }

  @override
  String cartItemsListRemovedItem(Object name) {
    return 'Removed $name';
  }

  @override
  String get cartItemsListUndoAction => 'Undo';

  @override
  String cartItemsListBaseModifierBreakdown(Object base, Object modifier) {
    return 'Base: $base + Modifier: $modifier';
  }

  @override
  String get cartItemsListModifierLink => 'Modifier';

  @override
  String get cartPanelCancelTicketTitle => 'Cancel ticket';

  @override
  String cartPanelCancelTicketMessage(Object ticketId) {
    return 'Are you sure you want to cancel Ticket #$ticketId? This cannot be undone.';
  }

  @override
  String get cartPanelKeepButton => 'Keep';

  @override
  String get cartPanelCancelTicketButton => 'Cancel Ticket';

  @override
  String cartPanelCancelTicketFailed(Object error) {
    return 'Failed to cancel ticket: $error';
  }

  @override
  String get cartPanelTicketCancelled => 'Ticket cancelled';

  @override
  String get cartPanelTicketLabel => 'Ticket';

  @override
  String get cartPanelWalkIn => 'Walk-in';

  @override
  String cartPanelCustomerFallback(Object id) {
    return 'Customer #$id';
  }

  @override
  String get cartPanelSearchCustomerHint => 'Search name or phone';

  @override
  String get cartPanelWalkInNoCustomerButton => 'Walk-in (no customer)';

  @override
  String cartPanelLoadCustomersFailed(Object error) {
    return 'Failed to load customers: $error';
  }

  @override
  String get cartPanelNoCustomersFound => 'No customers found';

  @override
  String get cartPanelFooterCharge => 'Charge';

  @override
  String get cartPanelFooterHold => 'Hold';

  @override
  String get cartTotalsItemDiscounts => 'Item Discounts';

  @override
  String cartTotalsTicketHeld(Object ticketNumber) {
    return 'Ticket #$ticketNumber held';
  }

  @override
  String cartTotalsHoldFailed(Object error) {
    return 'Could not hold order: $error';
  }

  @override
  String get cartTotalsHold => 'Hold';

  @override
  String get cartTotalsAddDiscount => 'Add Discount';

  @override
  String get cartTotalsFixedAmount => 'Fixed \$';

  @override
  String get cartTotalsPercentAmount => 'Percent %';

  @override
  String get cartTotalsAmountLabel => 'Amount (\$)';

  @override
  String get cartTotalsPercentLabel => 'Percent (%)';

  @override
  String get cartTotalsQuickSelect => 'Quick select:';

  @override
  String get cartTotalsRemoveDiscount => 'Remove';

  @override
  String get categoryTabsAllItems => 'All Items';

  @override
  String get heldTicketsCancelTitle => 'Cancel ticket';

  @override
  String heldTicketsCancelConfirm(Object ticketId) {
    return 'Are you sure you want to cancel Ticket #$ticketId? This cannot be undone.';
  }

  @override
  String get heldTicketsKeep => 'KEEP';

  @override
  String get heldTicketsCancelTicketButton => 'CANCEL TICKET';

  @override
  String heldTicketsCancelFailed(Object error) {
    return 'Failed to cancel ticket: $error';
  }

  @override
  String heldTicketsCancelled(Object ticketId) {
    return 'Ticket #$ticketId cancelled';
  }

  @override
  String get heldTicketsTitle => 'Held Tickets';

  @override
  String get heldTicketsSearchHint => 'Search tickets...';

  @override
  String get heldTicketsEmpty => 'No held tickets';

  @override
  String get heldTicketsEmptyHint => 'Tap \"Hold\" on a sale to save it here';

  @override
  String heldTicketsTicketLabel(Object ticketNumber) {
    return 'Ticket #$ticketNumber';
  }

  @override
  String get heldTicketsTapToRestore => 'Tap to restore';

  @override
  String get modifierSheetQuantity => 'Quantity';

  @override
  String get modifierSheetNoteHint => 'Add a note...';

  @override
  String get modifierSheetValidationError =>
      'Please select an option for all required modifiers.';

  @override
  String get modifierSheetLineTotal => 'Line Total';

  @override
  String get modifierSheetUpdate => 'Update';

  @override
  String get phoneScannerConnecting => 'Connecting POS to scanner relay...';

  @override
  String get phoneScannerWaiting => 'Waiting for phone scanner';

  @override
  String get phoneScannerStartFailed => 'Could not start phone scanner session';

  @override
  String get phoneScannerStopped => 'Scanner session stopped';

  @override
  String get phoneScannerDialogTitle => 'Phone scanner';

  @override
  String get phoneScannerInstructions =>
      'On the phone, open Phone 1D Scanner. Enter the Windows computer/server LAN address and this code:';

  @override
  String get phoneScannerUnavailable => 'Unavailable';

  @override
  String get phoneScannerCopyCode => 'Copy session code';

  @override
  String get phoneScannerExampleUrl =>
      'Example phone URL: http://192.168.1.10:8081\nDo not enter localhost on the phone.';

  @override
  String get phoneScannerStopSession => 'Stop session';

  @override
  String get phoneScannerKeepRunning => 'Keep running';

  @override
  String get phoneScannerPhoneReady => 'Phone connected and ready';

  @override
  String get phoneScannerPhoneDisconnected =>
      'Phone disconnected — session stopped';

  @override
  String get phoneScannerRelayError => 'Scanner relay error';

  @override
  String get phoneScannerConnectedTooltip => 'Phone scanner connected';

  @override
  String get phoneScannerConnectTooltip => 'Connect phone scanner';

  @override
  String get phoneScannerSessionStoppedStatus => 'Scanner session is stopped';

  @override
  String get productCardOutOfStock => 'Out of Stock';

  @override
  String get statusBarToggleMenu => 'Toggle menu';

  @override
  String get statusBarShiftLabel => 'Shift';

  @override
  String get statusBarOnline => 'Online';

  @override
  String get statusBarOffline => 'Offline';

  @override
  String get statusBarTransactions => 'Trans';

  @override
  String get statusBarBills => 'Bills';

  @override
  String get tableSelectorTitle => 'Select Table';

  @override
  String get tableSelectorEmpty => 'No tables available';

  @override
  String get tableSelectorInUseBadge => 'IN USE';

  @override
  String tableSelectorInUse(Object table) {
    return '$table is in use';
  }

  @override
  String get tableSelectorNoTable => 'No Table';

  @override
  String get waitingTicketsTitle => 'Waiting Numbers';

  @override
  String get waitingTicketsEmpty => 'No waiting customers';

  @override
  String waitingTicketsItemsCount(Object count) {
    return '$count items';
  }

  @override
  String get waitingTicketsReady => 'Ready';

  @override
  String get waitingTicketsCollected => 'Collected';

  @override
  String get cashierPerformanceTitle => 'Sales by Cashier';

  @override
  String get reportsNoDataForPeriod => 'No data for this period';

  @override
  String reportsTxCount(Object count) {
    return '$count tx';
  }

  @override
  String get categoryPerformanceTopByRevenue => 'Top Categories by Revenue';

  @override
  String categoryPerformanceFallbackName(Object id) {
    return 'Category #$id';
  }

  @override
  String categoryPerformanceItemsSoldCount(Object count) {
    return '$count items sold';
  }

  @override
  String get discountsScreenSummary => 'Summary';

  @override
  String get discountsScreenDiscountsGiven => 'Discounts Given';

  @override
  String get discountsScreenTotalDiscountAmount => 'Total Discount Amount';

  @override
  String get discountsScreenNoData => 'No discounts for this period';

  @override
  String get discountsScreenChartTitle => 'Discount Amount';

  @override
  String get discountsScreenTransactionsTitle => 'Discount Transactions';

  @override
  String monthlySalesTitle(Object year) {
    return 'Monthly Sales — $year';
  }

  @override
  String get monthlySalesPreviousYear => 'Previous year';

  @override
  String get monthlySalesNextYear => 'Next year';

  @override
  String get monthlySalesNoData => 'No data for this year';

  @override
  String get monthlySalesTotalRevenue => 'Total Revenue';

  @override
  String get paymentMixShareByMethod => 'Share by Payment Method';

  @override
  String get paymentMixTotalLabel => 'Total:';

  @override
  String get reportsHubSalesReportsSection => 'Sales Reports';

  @override
  String get reportsHubSalesSummarySubtitle =>
      'Daily sales totals with filters by store & cashier';

  @override
  String get reportsHubSalesByItemSubtitle =>
      'Quantity sold, gross, discount & net per product';

  @override
  String get reportsHubSalesByCategorySubtitle =>
      'Revenue & quantity per product category';

  @override
  String get reportsHubSalesByCashierSubtitle =>
      'Sales totals & transaction counts per cashier';

  @override
  String get reportsHubPaymentMixSubtitle =>
      'Revenue breakdown by payment method';

  @override
  String get reportsHubReceiptsSubtitle =>
      'In-depth sales with items, customers & payments';

  @override
  String get reportsHubSalesByModifierTitle => 'Sales by Modifier';

  @override
  String get reportsHubSalesByModifierSubtitle =>
      'Revenue & quantity per modifier option';

  @override
  String get reportsHubDiscountsSubtitle => 'Discounts applied across receipts';

  @override
  String get reportsHubTaxesSubtitle => 'Taxable sales & tax collected per day';

  @override
  String get reportsHubOtherReportsSection => 'Other Reports';

  @override
  String get reportsHubDailyReportTitle => 'Daily / X-Report';

  @override
  String get reportsHubDailyReportSubtitle =>
      'Today\'s sales snapshot with top products & payments';

  @override
  String get reportsHubTopProductsTitle => 'Top Products';

  @override
  String get reportsHubTopProductsSubtitle =>
      'Best-selling items by quantity & revenue';

  @override
  String get reportsHubPerformanceSection => 'Performance';

  @override
  String get reportsHubMonthlySalesTitle => 'Monthly Sales';

  @override
  String get reportsHubMonthlySalesSubtitle =>
      'Revenue trend across months in a year';

  @override
  String get reportsHubStockMovementsTitle => 'Stock Movements';

  @override
  String get reportsHubStockMovementsSubtitle =>
      'In/out movements within a date range';

  @override
  String get reportsHubChangeDateTooltip => 'Change date';

  @override
  String get reportsHubGrossSales => 'Gross Sales';

  @override
  String get reportsHubNetSales => 'Net Sales';

  @override
  String get reportsHubTransactions => 'Transactions';

  @override
  String get reportsHubAvgPerSale => 'Avg per Sale';

  @override
  String get reportsHubPaymentBreakdown => 'Payment Breakdown';

  @override
  String reportsHubQuantitySold(Object count) {
    return '$count sold';
  }

  @override
  String get reportsHubCashierPerformanceSection => 'Cashier Performance';

  @override
  String get reportsHubNotAvailable => 'N/A';

  @override
  String get salesByItemSortByRevenue => 'By Revenue';

  @override
  String get salesByItemSortByQuantity => 'By Quantity';

  @override
  String get salesByItemTopItems => 'Top Items';

  @override
  String get salesByItemSkuLabel => 'SKU:';

  @override
  String get salesByItemGrossLabel => 'Gross';

  @override
  String get salesByItemNetLabel => 'Net';

  @override
  String get reportsSalesByModifier => 'Sales by Modifier';

  @override
  String get salesByModifierTopOptionsTitle =>
      'Top Modifier Options by Revenue';

  @override
  String get reportsRevenue => 'Revenue';

  @override
  String get reportsSummary => 'Summary';

  @override
  String get reportsGrossSales => 'Gross Sales';

  @override
  String get reportsNetSales => 'Net Sales';

  @override
  String get reportsSalesCountLabel => 'Sales Count';

  @override
  String get reportsItemsSold => 'Items Sold';

  @override
  String get reportsAvgSale => 'Avg Sale';

  @override
  String get reportsPaymentMethods => 'Payment Methods';

  @override
  String reportsTransactionsCount(Object count) {
    return '$count tx';
  }

  @override
  String get reportsNoReceiptsForPeriod => 'No receipts for this period';

  @override
  String get reportsGross => 'Gross';

  @override
  String get reportsBalance => 'Balance';

  @override
  String get reportsCreditSale => 'Credit Sale';

  @override
  String get reportsTransactions => 'Transactions';

  @override
  String get reportsAvgPerSale => 'Avg per Sale';

  @override
  String get reportsNetSalesPerDay => 'Net Sales per Day';

  @override
  String get reportsSalesByCashier => 'Sales by Cashier';

  @override
  String get reportsDailyBreakdown => 'Daily Breakdown';

  @override
  String get reportsOrders => 'Orders';

  @override
  String get reportsNet => 'Net';

  @override
  String reportsSalesCountSingular(Object count) {
    return '$count sale';
  }

  @override
  String reportsSalesCountPlural(Object count) {
    return '$count sales';
  }

  @override
  String get reportsStockMovements => 'Stock Movements';

  @override
  String get reportsNoMovementsForPeriod => 'No movements for this period';

  @override
  String reportsProductFallback(Object id) {
    return 'Product #$id';
  }

  @override
  String get reportsTotalTaxCollected => 'Total Tax Collected';

  @override
  String get reportsNoTaxDataForPeriod => 'No tax data for this period';

  @override
  String get reportsTaxCollectedPerDay => 'Tax Collected per Day';

  @override
  String get reportsTaxableSales => 'Taxable Sales';

  @override
  String get reportsTaxCollected => 'Tax Collected';

  @override
  String get reportsSalesLabel => 'Sales';

  @override
  String get reportsTopProducts => 'Top Products';

  @override
  String reportsQuantitySold(Object qty) {
    return '$qty sold';
  }

  @override
  String get reportFilterToday => 'Today';

  @override
  String get reportFilterYesterday => 'Yesterday';

  @override
  String get reportFilterThisWeek => 'This week';

  @override
  String get reportFilterLastWeek => 'Last week';

  @override
  String get reportFilterThisMonth => 'This month';

  @override
  String get reportFilterLastMonth => 'Last month';

  @override
  String get reportFilterLast7Days => 'Last 7 days';

  @override
  String get reportFilterLast30Days => 'Last 30 days';

  @override
  String get reportFilterThisYear => 'This Year';

  @override
  String get reportFilterCustomRange => 'Custom range…';

  @override
  String get reportFilterAllDay => 'All day';

  @override
  String get reportFilterCustomPeriod => 'Custom period';

  @override
  String get reportFilterStart => 'Start';

  @override
  String get reportFilterEnd => 'End';

  @override
  String get reportFilterAllCashiers => 'All cashiers';

  @override
  String get reportPaginationPreviousPage => 'Previous page';

  @override
  String get reportPaginationNextPage => 'Next page';

  @override
  String reportPaginationPageInfo(
      Object page, Object totalPages, Object total) {
    return 'Page $page of $totalPages ($total total)';
  }

  @override
  String get customerDisplayTooltipConnected => 'Customer display connected';

  @override
  String get customerDisplayTooltipConnect => 'Connect customer display';

  @override
  String get customerDisplayDialogTitle => 'Customer Display';

  @override
  String get customerDisplayDialogInstructions =>
      'On the customer-screen device, enter this store\'s server address and the code below to connect.';

  @override
  String get customerDisplayCopyCode => 'Copy code';

  @override
  String get customerDisplayStopSession => 'Stop session';

  @override
  String get customerDisplayKeepRunning => 'Keep running';

  @override
  String get customerDisplayStatusStarting => 'Starting session...';

  @override
  String get customerDisplayStatusStopped => 'Session stopped';

  @override
  String get customerDisplayStatusConnected => 'Customer display connected';

  @override
  String get customerDisplayStatusWaiting =>
      'Waiting for the customer display to connect...';

  @override
  String get reportPdfGeneratedLabel => 'Generated';

  @override
  String get reportPdfPageLabel => 'Page';

  @override
  String get salesSummaryPdfTitle => 'Sales Summary Report';

  @override
  String get salesSummaryPdfColDate => 'Date';

  @override
  String get salesSummaryPdfColOrders => 'Orders';

  @override
  String get salesSummaryPdfColQty => 'Qty';

  @override
  String get salesSummaryPdfColGross => 'Gross';

  @override
  String get salesSummaryPdfColDiscount => 'Discount';

  @override
  String get salesSummaryPdfColTax => 'Tax';

  @override
  String get salesSummaryPdfColNet => 'Net';

  @override
  String get salesSummaryPdfGrossSalesLabel => 'Gross Sales';

  @override
  String get salesSummaryPdfDiscountsLabel => 'Discounts';

  @override
  String get salesSummaryPdfNetSalesLabel => 'Net Sales';

  @override
  String get salesSummaryPdfTransactionsLabel => 'Transactions';

  @override
  String get salesSummaryPdfItemsSoldLabel => 'Items Sold';

  @override
  String get salesReportPdfColReceiptNo => 'Receipt #';

  @override
  String get salesReportPdfColPayment => 'Payment';

  @override
  String get stockMovementPdfColType => 'Type';

  @override
  String get stockMovementPdfMovementsLabel => 'Movements';

  @override
  String get inventoryValuationPdfTotalValueLabel => 'Total Value';

  @override
  String get salesByModifierPdfColGroup => 'Group';

  @override
  String get salesByModifierPdfColOption => 'Option';
}
