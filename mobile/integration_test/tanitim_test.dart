// Tanitim turu: uygulamayi otomatik gezerek App Review icin video uretir.
//
// Amaci test etmek degil, uygulamanin tarayicida yapilamayacak yerel
// islevlerini gostermek: cevrimdisi arama, cihaza kaydetme, yerel hatirlatma.
// Ekran kaydi is akisinda simctl ile alinir; buradaki bekleme sureleri
// videonun izlenebilir olmasi icin bilerek uzun tutuldu.
import 'package:antrenor/main.dart' as uygulama;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tanitim turu', (WidgetTester tester) async {
    uygulama.main();

    // Veri agdan iniyor; ilk kare cizilene kadar bekle
    await _bekle(tester, saniye: 12);

    // --- 1. Akis ve kategori suzgeci ------------------------------------
    await _dokun(tester, find.text('Kurs & seminer'));
    await _bekle(tester, saniye: 4);
    await _dokun(tester, find.text('Tümü'));
    await _bekle(tester, saniye: 3);

    // --- 2. Cevrimdisi arama --------------------------------------------
    final aramaDugmesi = find.byIcon(Icons.search);
    if (aramaDugmesi.evaluate().isNotEmpty) {
      await _dokun(tester, aramaDugmesi.first);
      await _bekle(tester, saniye: 2);

      final kutu = find.byType(TextField);
      if (kutu.evaluate().isNotEmpty) {
        await tester.enterText(kutu.first, 'vize');
        await _bekle(tester, saniye: 4);
        await tester.enterText(kutu.first, 'antrenor');
        await _bekle(tester, saniye: 4);
      }
      await _geriDon(tester);
      await _bekle(tester, saniye: 2);
    }

    // --- 3. Duyuru: kaydet ve hatirlatici --------------------------------
    final kartlar = find.byType(InkWell);
    if (kartlar.evaluate().isNotEmpty) {
      await _dokun(tester, kartlar.first);
      await _bekle(tester, saniye: 4);

      await _dokun(tester, find.text('Kaydet'));
      await _bekle(tester, saniye: 3);

      await _dokun(tester, find.text('Hatırlatıcı kur'));
      await _bekle(tester, saniye: 3);

      // Tarih secici: bugunun ertesi gunu onceden secili gelir
      await _dokun(tester, find.text('Tamam'));
      await _bekle(tester, saniye: 2);
      await _dokun(tester, find.text('Tamam'));
      await _bekle(tester, saniye: 4);

      await _geriDon(tester);
      await _bekle(tester, saniye: 2);
    }

    // --- 4. Kayitlar sekmesi ---------------------------------------------
    await _dokun(tester, find.text('Kayıtlar'));
    await _bekle(tester, saniye: 6);

    // --- 5. Federasyonlar ------------------------------------------------
    await _dokun(tester, find.text('Federasyonlar'));
    await _bekle(tester, saniye: 5);
  });
}

/// pumpAndSettle kullanilamiyor: reklam ve ag istekleri yuzunden animasyon
/// hic durmuyor, test zaman asimina ugruyor. Sabit sureli pump ile ilerliyoruz.
Future<void> _bekle(WidgetTester tester, {required int saniye}) async {
  for (var i = 0; i < saniye * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Aranan oge yoksa tur kesilmesin; video eksik ama gecerli olsun.
Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  if (hedef.evaluate().isEmpty) return;
  try {
    await tester.tap(hedef.first, warnIfMissed: false);
  } catch (_) {}
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _geriDon(WidgetTester tester) async {
  final geri = find.byType(BackButton);
  if (geri.evaluate().isNotEmpty) {
    await _dokun(tester, geri);
    return;
  }
  final durum = tester.state<NavigatorState>(find.byType(Navigator).first);
  if (durum.canPop()) durum.pop();
  await tester.pump(const Duration(milliseconds: 600));
}
