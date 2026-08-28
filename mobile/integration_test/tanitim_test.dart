// Tanitim turu: uygulamayi otomatik gezerek App Review icin video uretir.
//
// Amaci test etmek degil, uygulamanin tarayicida yapilamayacak yerel
// islevlerini gostermek: cevrimdisi arama, cihaza kaydetme, yerel hatirlatma,
// takvime ekleme. Ekran kaydi is akisinda simctl ile alinir; buradaki
// bekleme sureleri videonun izlenebilir olmasi icin bilerek uzun tutuldu.
import 'package:antrenor/main.dart' as uygulama;
import 'package:antrenor/parcalar/duyuru_karti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tanitim turu', (WidgetTester tester) async {
    uygulama.main();

    // Veri agdan iniyor; akista kart cikana kadar bekle
    await _kadar(tester, () => find.byType(DuyuruKarti).evaluate().isNotEmpty,
        enFazlaSaniye: 40);
    await _bekle(tester, 3);

    // --- 1. Kategori suzgeci --------------------------------------------
    await _dokun(tester, find.text('Kurs & seminer'));
    await _bekle(tester, 5);
    await _dokun(tester, find.text('Tümü'));
    await _bekle(tester, 3);

    // --- 2. Cevrimdisi arama --------------------------------------------
    await _dokun(tester, find.byIcon(Icons.search).first);
    await _bekle(tester, 2);
    final kutu = find.byType(TextField);
    if (kutu.evaluate().isNotEmpty) {
      await tester.enterText(kutu.first, 'vize');
      await _bekle(tester, 5);
      await tester.enterText(kutu.first, 'antrenor');
      await _bekle(tester, 5);
    }
    await _geriDon(tester);
    await _bekle(tester, 3);

    // --- 3. Duyuru: kaydet ve hatirlatici --------------------------------
    await _dokun(tester, find.byType(DuyuruKarti).first);
    // Detay acildi mi? Reklam kapisi cikarsa "Reklam izle" gelir; TEST_PREMIUM
    // ile kapali olmali
    await _kadar(tester, () => find.text('Kaynakta aç').evaluate().isNotEmpty,
        enFazlaSaniye: 15);
    await _bekle(tester, 3);

    await _dokun(tester, find.text('Kaydet'));
    await _bekle(tester, 4);

    await _dokun(tester, find.text('Hatırlatıcı kur'));
    await _bekle(tester, 3);
    // Tarih secici: yarin onceden secili gelir
    await _dokun(tester, find.text('Tamam'));
    await _bekle(tester, 3);
    // Saat secici
    await _dokun(tester, find.text('Tamam'));
    await _bekle(tester, 5);

    await _geriDon(tester);
    await _bekle(tester, 3);

    // --- 4. Kayitlar sekmesi ---------------------------------------------
    await _dokun(tester, find.text('Kayıtlar'));
    await _bekle(tester, 7);

    // --- 5. Federasyon takvimi -------------------------------------------
    await _dokun(tester, find.text('Federasyonlar'));
    await _bekle(tester, 5);
  });
}

/// pumpAndSettle kullanilamiyor: ag ve reklam istekleri yuzunden animasyon
/// hic durmuyor, test zaman asimina ugruyor. Sabit sureli pump ile ilerliyoruz.
Future<void> _bekle(WidgetTester tester, int saniye) async {
  for (var i = 0; i < saniye * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Kosul saglanana kadar bekler; saglanmazsa turu kesmeden devam eder.
Future<void> _kadar(WidgetTester tester, bool Function() kosul,
    {required int enFazlaSaniye}) async {
  for (var i = 0; i < enFazlaSaniye * 4; i++) {
    if (kosul()) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Aranan oge yoksa tur kesilmesin; video eksik ama gecerli olsun.
Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  if (hedef.evaluate().isEmpty) return;
  try {
    await tester.tap(hedef.first, warnIfMissed: false);
  } catch (_) {}
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _geriDon(WidgetTester tester) async {
  final geri = find.byType(BackButton);
  if (geri.evaluate().isNotEmpty) {
    await _dokun(tester, geri);
    return;
  }
  final gezgin = tester.state<NavigatorState>(find.byType(Navigator).first);
  if (gezgin.canPop()) gezgin.pop();
  await tester.pump(const Duration(milliseconds: 700));
}
