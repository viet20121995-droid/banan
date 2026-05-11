import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

class BananCustomerApp extends ConsumerWidget {
  const BananCustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(customerRouterProvider);
    return MaterialApp.router(
      title: 'Banan',
      debugShowCheckedModeBanner: false,
      theme: BananTheme.light(),
      darkTheme: BananTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
