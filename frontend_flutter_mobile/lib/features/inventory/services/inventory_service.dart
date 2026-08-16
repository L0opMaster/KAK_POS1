import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory_models.dart';
import '../../../core/services/api_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/inventory/services/
/// inventory_service.dart` — COPY/ADAPT NEARLY EXACTLY, full file.
///
/// Abstract service for inventory operations. Method shapes match the real
/// backend endpoints/DTOs directly — see inventory_models.dart for the DTO
/// mapping notes.
abstract class InventoryService {
  // ── Stock Movements (Stock Adjustments + Inventory History share this) ──
  Future<List<StockMovementEntry>> getMovements({
    int? productId,
    int? storeId,
  });
  Future<StockMovementEntry> createAdjustment(StockAdjustmentRequest request);

  // ── Inventory Counts ──
  Future<InventoryCount> getCount(String snapshotDate, {int storeId = 1});
  Future<void> startCount(String snapshotDate, {int storeId = 1});
  Future<void> recordCountEntry({
    required String snapshotDate,
    required int storeId,
    required int snapshotId,
    required double countedQuantity,
    String? notes,
  });
  Future<void> postCount(String snapshotDate, {int storeId = 1});

  // ── Suppliers ──
  Future<List<Supplier>> getSuppliers();
  Future<Supplier> createSupplier(Supplier supplier);
  Future<Supplier> updateSupplier(Supplier supplier);
  Future<void> deleteSupplier(int id);

  // ── Purchase Orders ──
  Future<List<PurchaseOrder>> getPurchaseOrders();
  Future<PurchaseOrder> getPurchaseOrder(int id);
  Future<PurchaseOrder> createPurchaseOrder(PurchaseOrder order);
  Future<PurchaseOrder> updatePurchaseOrder(PurchaseOrder order);
  Future<PurchaseOrder> transitionPurchaseOrder(int id, String action);

  // ── Transfer Orders ──
  Future<List<TransferOrder>> getTransferOrders();
  Future<TransferOrder> createTransferOrder(TransferOrder order);
  Future<TransferOrder> completeTransferOrder(int id);
  Future<TransferOrder> cancelTransferOrder(int id);

  // ── Inventory Valuation ──
  Future<InventoryValuationReport> getValuationReport({int? storeId});

  // ── Store Locations ──
  Future<List<StoreLocation>> getLocations();
}

/// API-based implementation.
class ApiInventoryService extends InventoryService {
  final ApiService _api;

  ApiInventoryService(this._api);

  // ── Movements ──
  @override
  Future<List<StockMovementEntry>> getMovements({
    int? productId,
    int? storeId,
  }) async {
    final resp = await _api.get<List<dynamic>>(
      '/api/inventory/movements',
      queryParameters: {if (storeId != null) 'storeId': storeId},
    );
    // The backend only filters by storeId; productId isn't a supported
    // query param there, so filter it client-side to keep the filter working.
    return resp
        .cast<Map<String, dynamic>>()
        .map(StockMovementEntry.fromJson)
        .where((m) => productId == null || m.productId == productId)
        .toList();
  }

  @override
  Future<StockMovementEntry> createAdjustment(
    StockAdjustmentRequest request,
  ) async {
    final resp = await _api.post<Map<String, dynamic>>(
      '/api/inventory/adjust',
      data: request.toJson(),
    );
    // The adjust endpoint returns the resulting StockResponse, not a
    // movement row — surface it back as a movement-shaped entry so callers
    // can show it immediately without a second round-trip.
    return StockMovementEntry(
      productId: (resp['productId'] as num?)?.toInt() ?? request.productId,
      productName: resp['productNameEn'] as String? ?? '',
      storeId: (resp['storeId'] as num?)?.toInt() ?? request.storeId,
      storeName: resp['storeName'] as String?,
      movementType: 'ADJUSTMENT',
      quantity: request.quantity,
      reason: request.reason,
      createdAt: DateTime.now(),
    );
  }

  // ── Counts ──
  @override
  Future<InventoryCount> getCount(
    String snapshotDate, {
    int storeId = 1,
  }) async {
    final resp = await _api.get<List<dynamic>>(
      '/api/inventory/counts',
      queryParameters: {'date': snapshotDate, 'storeId': storeId},
    );
    final items = resp
        .cast<Map<String, dynamic>>()
        .map(InventoryCountItem.fromJson)
        .toList();
    return InventoryCount(
      snapshotDate: snapshotDate,
      status: _resolveCountStatus(items),
      items: items,
    );
  }

  @override
  Future<void> startCount(String snapshotDate, {int storeId = 1}) async {
    await _api.post<void>(
      '/api/inventory/snapshots',
      queryParameters: {'date': snapshotDate, 'storeId': storeId},
    );
  }

  @override
  Future<void> recordCountEntry({
    required String snapshotDate,
    required int storeId,
    required int snapshotId,
    required double countedQuantity,
    String? notes,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/api/inventory/counts/entry',
      data: {
        'snapshotDate': snapshotDate,
        'storeId': storeId,
        'snapshotId': snapshotId,
        'countedQuantity': countedQuantity,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  @override
  Future<void> postCount(String snapshotDate, {int storeId = 1}) async {
    await _api.post<Map<String, dynamic>>(
      '/api/inventory/counts/post',
      data: {'snapshotDate': snapshotDate, 'storeId': storeId},
    );
  }

  CountStatus _resolveCountStatus(List<InventoryCountItem> items) {
    final statuses = items
        .map((e) => (e.countStatus ?? 'SNAPSHOT').toUpperCase())
        .toSet();
    if (statuses.contains('POSTED')) return CountStatus.completed;
    if (statuses.contains('COUNTED')) return CountStatus.inProgress;
    return CountStatus.draft;
  }

  // ── Suppliers ──
  @override
  Future<List<Supplier>> getSuppliers() async {
    final resp = await _api.get<List<dynamic>>('/api/suppliers');
    return resp.cast<Map<String, dynamic>>().map(Supplier.fromJson).toList();
  }

  @override
  Future<Supplier> createSupplier(Supplier supplier) async {
    final resp = await _api.post<Map<String, dynamic>>(
      '/api/suppliers',
      data: supplier.toJson(),
    );
    return Supplier.fromJson(resp);
  }

  @override
  Future<Supplier> updateSupplier(Supplier supplier) async {
    final resp = await _api.put<Map<String, dynamic>>(
      '/api/suppliers/${supplier.id}',
      data: supplier.toJson(),
    );
    return Supplier.fromJson(resp);
  }

  @override
  Future<void> deleteSupplier(int id) async {
    await _api.delete('/api/suppliers/$id');
  }

  // ── Purchase Orders ──
  @override
  Future<List<PurchaseOrder>> getPurchaseOrders() async {
    final resp = await _api.get<List<dynamic>>('/api/purchase-orders');
    return resp
        .cast<Map<String, dynamic>>()
        .map(PurchaseOrder.fromJson)
        .toList();
  }

  @override
  Future<PurchaseOrder> getPurchaseOrder(int id) async {
    final resp = await _api.get<Map<String, dynamic>>(
      '/api/purchase-orders/$id',
    );
    return PurchaseOrder.fromJson(resp);
  }

  @override
  Future<PurchaseOrder> createPurchaseOrder(PurchaseOrder order) async {
    final resp = await _api.post<Map<String, dynamic>>(
      '/api/purchase-orders',
      data: order.toJson(),
    );
    return PurchaseOrder.fromJson(resp);
  }

  @override
  Future<PurchaseOrder> updatePurchaseOrder(PurchaseOrder order) async {
    final resp = await _api.put<Map<String, dynamic>>(
      '/api/purchase-orders/${order.id}',
      data: order.toJson(),
    );
    return PurchaseOrder.fromJson(resp);
  }

  @override
  Future<PurchaseOrder> transitionPurchaseOrder(int id, String action) async {
    final resp = await _api.post<Map<String, dynamic>>(
      '/api/purchase-orders/$id/$action',
    );
    return PurchaseOrder.fromJson(resp);
  }

  // ── Transfer Orders ──
  @override
  Future<List<TransferOrder>> getTransferOrders() async {
    final resp = await _api.get<List<dynamic>>('/api/inventory/transfers');
    return resp
        .cast<Map<String, dynamic>>()
        .map(TransferOrder.fromJson)
        .toList();
  }

  @override
  Future<TransferOrder> createTransferOrder(TransferOrder order) async {
    final resp = await _api.post<Map<String, dynamic>>(
      '/api/inventory/transfers',
      data: order.toJson(),
    );
    return TransferOrder.fromJson(resp);
  }

  @override
  Future<TransferOrder> completeTransferOrder(int id) async {
    final resp = await _api.post<Map<String, dynamic>>(
      '/api/inventory/transfers/$id/complete',
    );
    return TransferOrder.fromJson(resp);
  }

  @override
  Future<TransferOrder> cancelTransferOrder(int id) async {
    final resp = await _api.post<Map<String, dynamic>>(
      '/api/inventory/transfers/$id/cancel',
    );
    return TransferOrder.fromJson(resp);
  }

  // ── Valuation ──
  @override
  Future<InventoryValuationReport> getValuationReport({int? storeId}) async {
    final resp = await _api.get<Map<String, dynamic>>(
      '/api/inventory/valuation',
      queryParameters: {if (storeId != null) 'storeId': storeId},
    );
    return InventoryValuationReport.fromJson(resp);
  }

  // ── Locations ──
  @override
  Future<List<StoreLocation>> getLocations() async {
    final resp = await _api.get<List<dynamic>>('/api/stores');
    return resp
        .cast<Map<String, dynamic>>()
        .map(
          (e) => StoreLocation(
            id: (e['id'] as num?)?.toInt(),
            name: e['name'] as String? ?? e['storeName'] as String? ?? '',
          ),
        )
        .toList();
  }
}

/// Provider for InventoryService.
final inventoryServiceProvider = Provider<InventoryService>((ref) {
  final api = ref.watch(apiServiceProvider);
  return ApiInventoryService(api);
});

/// Default store id used across inventory screens until a store picker
/// exists — matches the backend's single-store assumption elsewhere in
/// this codebase.
const int defaultInventoryStoreId = 1;
