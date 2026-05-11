import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

class BananMerchantApp extends ConsumerWidget {
  const BananMerchantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(merchantRouterProvider);
    return MaterialApp.router(
      title: 'Banan Merchant',
      debugShowCheckedModeBanner: false,
      theme: BananTheme.light(),
      darkTheme: BananTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
