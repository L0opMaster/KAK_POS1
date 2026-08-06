import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_models.dart';
import '../services/waiting_number_service.dart';

final Provider<WaitingNumberService> waitingNumberServiceProvider =
    Provider<WaitingNumberService>(
  (Ref ref) => WaitingNumberService(),
);

final FutureProvider<List<WaitingTicket>> waitingTicketsProvider =
    FutureProvider<List<WaitingTicket>>(
  (Ref ref) async {
    final WaitingNumberService service =
        ref.watch(waitingNumberServiceProvider);

    return service.getWaitingTickets();
  },
);
