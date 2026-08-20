import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/main_color_provider.dart';
import 'screens/phone_scanner_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KAKNNEA SCANNER',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: ref.watch(mainColorProvider)),
        useMaterial3: true,
      ),
      home: const PhoneScannerScreen(),
    );
  }
}
