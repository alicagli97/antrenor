import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:antrenor/main.dart';

void main() {
  testWidgets('Uygulama acilir ve alt menu gorunur', (tester) async {
    await tester.pumpWidget(const AntrenorUygulamasi());
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Anasayfa'), findsOneWidget);
    expect(find.text('Federasyonlar'), findsOneWidget);
    expect(find.text('Bildirimler'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);
  });
}
