import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory_models.dart';
import '../services/inventory_service.dart';

// ─────────────────────────────────────────────────────────────
// Stock Adjustments / Movements Provider
// (Stock Adjustments and Inventory History screens both use this — the
// backend has one movement log; the two screens just query/filter it
// differently.)
// ─────────────────────────────────────────────────────────────
final movementsProvider = StateNotifierProvider<MovementsNotifier,
    AsyncValue<List<StockMovementEntry>>>(
  (ref) {
    final service = ref.watch(inventoryServiceProvider);
    return MovementsNotifier(service);
  },
);

class MovementsNotifier
    extends StateNotifier<AsyncValue<List<StockMovementEntry>>> {
  final InventoryService _service;

  MovementsNotifier(this._service) : super(const AsyncValue.loading());

  Future<void> load({int? productId, int? storeId}) async {
    try {
      state = const AsyncValue.loading();
      final list =
          await _service.getMovements(productId: productId, storeId: storeId);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createAdjustment(StockAdjustmentRequest request) async {
    await _service.createAdjustment(request);
    await load();
  }
}

// ─────────────────────────────────────────────────────────────
// Inventory Count Provider — one count (today's, by default) at a time.
// ─────────────────────────────────────────────────────────────
final inventoryCountProvider =
    StateNotifierProvider<InventoryCountNotifier, AsyncValue<InventoryCount?>>(
  (ref) {
    final service = ref.watch(inventoryServiceProvider);
    return InventoryCountNotifier(service);
  },
);

class InventoryCountNotifier extends StateNotifier<AsyncValue<InventoryCount?>> {
  final InventoryService _service;
  String _snapshotDate = _today();
  int _storeId = defaultInventoryStoreId;

  InventoryCountNotifier(this._service) : super(const AsyncValue.data(null));

  static String _today() => DateTime.now().toIso8601String().split('T').first;

  String get snapshotDate => _snapshotDate;

  Future<void> load({String? snapshotDate, int? storeId}) async {
    _snapshotDate = snapshotDate ?? _snapshotDate;
    _storeId = storeId ?? _storeId;
    try {
      state = const AsyncValue.loading();
      final count = await _service.getCount(_snapshotDate, storeId: _storeId);
      state = AsyncValue.data(count);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> startCount() async {
    try {
      await _service.startCount(_snapshotDate, storeId: _storeId);
      await load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> recordEntry({
    required int snapshotId,
    required double countedQuantity,
    String? notes,
  }) async {
    try {
      await _service.recordCountEntry(
        snapshotDate: _snapshotDate,
        storeId: _storeId,
        snapshotId: snapshotId,
        countedQuantity: countedQuantity,
        notes: notes,
      );
      await load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> post() async {
    try {
      await _service.postCount(_snapshotDate, storeId: _storeId);
      await load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Suppliers Provider
// ─────────────────────────────────────────────────────────────
final suppliersProvider =
    StateNotifierProvider<SuppliersNotifier, AsyncValue<List<Supplier>>>(
  (ref) {
    final service = ref.watch(inventoryServiceProvider);
    return SuppliersNotifier(service);
  },
);

class SuppliersNotifier extends StateNotifier<AsyncValue<List<Supplier>>> {
  final InventoryService _service;

  SuppliersNotifier(this._service) : super(const AsyncValue.loading());

  Future<void> loadSuppliers() async {
    try {
      state = const AsyncValue.loading();
      final list = await _service.getSuppliers();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createSupplier(Supplier supplier) async {
    await _service.createSupplier(supplier);
    await loadSuppliers();
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await _service.updateSupplier(supplier);
    await loadSuppliers();
  }

  Future<void> deleteSupplier(int id) async {
    await _service.deleteSupplier(id);
    await loadSuppliers();
  }
}

// ─────────────────────────────────────────────────────────────
// Purchase Orders Provider
// ─────────────────────────────────────────────────────────────
final purchaseOrdersProvider = StateNotifierProvider<PurchaseOrdersNotifier,
    AsyncValue<List<PurchaseOrder>>>(
  (ref) {
    final service = ref.watch(inventoryServiceProvider);
    return PurchaseOrdersNotifier(service);
  },
);

class PurchaseOrdersNotifier
    extends StateNotifier<AsyncValue<List<PurchaseOrder>>> {
  final InventoryService _service;

  PurchaseOrdersNotifier(this._service) : super(const AsyncValue.loading());

  Future<void> loadOrders() async {
    try {
      state = const AsyncValue.loading();
      final list = await _service.getPurchaseOrders();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createOrder(PurchaseOrder order) async {
    await _service.createPurchaseOrder(order);
    await loadOrders();
  }

  Future<void> updateOrder(PurchaseOrder order) async {
    await _service.updatePurchaseOrder(order);
    await loadOrders();
  }

  Future<void> transition(int id, String action) async {
    await _service.transitionPurchaseOrder(id, action);
    await loadOrders();
  }
}

// ─────────────────────────────────────────────────────────────
// Transfer Orders Provider
// ─────────────────────────────────────────────────────────────
final transferOrdersProvider = StateNotifierProvider<TransferOrdersNotifier,
    AsyncValue<List<TransferOrder>>>(
  (ref) {
    final service = ref.watch(inventoryServiceProvider);
    return TransferOrdersNotifier(service);
  },
);

class TransferOrdersNotifier
    extends StateNotifier<AsyncValue<List<TransferOrder>>> {
  final InventoryService _service;

  TransferOrdersNotifier(this._service) : super(const AsyncValue.loading());

  Future<void> loadOrders() async {
    try {
      state = const AsyncValue.loading();
      final list = await _service.getTransferOrders();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createOrder(TransferOrder order) async {
    await _service.createTransferOrder(order);
    await loadOrders();
  }

  Future<void> completeOrder(int id) async {
    await _service.completeTransferOrder(id);
    await loadOrders();
  }

  Future<void> cancelOrder(int id) async {
    await _service.cancelTransferOrder(id);
    await loadOrders();
  }
}

// ─────────────────────────────────────────────────────────────
// Inventory Valuation Provider
// ─────────────────────────────────────────────────────────────
final inventoryValuationProvider = StateNotifierProvider<
    InventoryValuationNotifier, AsyncValue<InventoryValuationReport?>>(
  (ref) {
    final service = ref.watch(inventoryServiceProvider);
    return InventoryValuationNotifier(service);
  },
);

class InventoryValuationNotifier
    extends StateNotifier<AsyncValue<InventoryValuationReport?>> {
  final InventoryService _service;

  InventoryValuationNotifier(this._service) : super(const AsyncValue.data(null));

  Future<void> loadReport() async {
    try {
      state = const AsyncValue.loading();
      final report = await _service.getValuationReport();
      state = AsyncValue.data(report);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Locations Provider
// ─────────────────────────────────────────────────────────────
final locationsProvider =
    StateNotifierProvider<LocationsNotifier, AsyncValue<List<StoreLocation>>>(
  (ref) {
    final service = ref.watch(inventoryServiceProvider);
    return LocationsNotifier(service);
  },
);

class LocationsNotifier extends StateNotifier<AsyncValue<List<StoreLocation>>> {
  final InventoryService _service;

  LocationsNotifier(this._service) : super(const AsyncValue.loading());

  Future<void> loadLocations() async {
    try {
      state = const AsyncValue.loading();
      final list = await _service.getLocations();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
