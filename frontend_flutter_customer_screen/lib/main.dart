import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/main_color_provider.dart';
import 'features/display/screens/connect_screen.dart';

void main() {
  runApp(const ProviderScope(child: CustomerDisplayApp()));
}

class CustomerDisplayApp extends ConsumerWidget {
  const CustomerDisplayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'CUSTOMER DISPLAY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: ref.watch(mainColorProvider)),
        useMaterial3: true,
      ),
      home: const ConnectScreen(),
    );
  }
}
