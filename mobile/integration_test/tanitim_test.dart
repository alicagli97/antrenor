// Tanitim turu: uygulamayi otomatik gezerek App Review videosu ve magaza
// gorselleri icin kareler uretir.
//
// Amaci test etmek degil; uygulamanin tarayicida yapilamayacak yerel
// islevlerini gostermek. Ekran kaydi is akisinda simctl ile aliniyor, bu
// yuzden bekleme sureleri videonun izlenebilirligi icin uzun tutuldu.
//
// Vize profili ve kaydedilen duyuru dogrudan cekirdek uzerinden kuruluyor:
// acilir listelerle ve tarih seciciyle bogusmak turu kirilgan yapiyordu,
// ekranlarin dolu gorunmesi yeterli.
import 'package:antrenor/cekirdek/depo.dart';
import 'package:antrenor/cekirdek/profil.dart';
import 'package:antrenor/cekirdek/veri.dart';
import 'package:antrenor/main.dart' as uygulama;
import 'package:antrenor/parcalar/duyuru_karti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tanitim turu', (WidgetTester tester) async {
    // Vize panosu dolu gorunsun diye veriyi once cekiyoruz
    final veri = Veri();
    await veri.baslat();
    if (veri.federasyonlar.isNotEmpty) {
      await Profil.ornek.kaydet(
        brans: veri.federasyonlar.first.slug,
        kademe: 2,
        vizeBitis: DateTime.now().add(const Duration(days: 47)),
      );
    }
    if (veri.duyurular.isNotEmpty) {
      await Depo.kaydiDegistir(veri.duyurular.first);
    }

    uygulama.main();
    await _kadar(tester, () => find.byType(DuyuruKarti).evaluate().isNotEmpty,
        enFazla: 45);
    await _bekle(tester, 5); // ANASAYFA: vize geri sayimi + akis

    // --- Kategori suzgeci ------------------------------------------------
    await _dokun(tester, find.text('Kurs & seminer'));
    await _bekle(tester, 5);
    await _dokun(tester, find.text('Tümü'));
    await _bekle(tester, 3);

    // --- Vize Takibim panosu ---------------------------------------------
    await _dokun(tester, find.text('Vize Takibim'));
    await _kadar(tester, () => find.text('Branş').evaluate().isNotEmpty,
        enFazla: 10);
    await _bekle(tester, 7); // GORSEL: geri sayim panosu
    await _geriDon(tester);
    await _bekle(tester, 3);

    // --- Bilgi Deposu -----------------------------------------------------
    await _dokun(tester, find.text('Bilgi'));
    await _kadar(tester, () => find.textContaining('federasyon ·').evaluate().isNotEmpty,
        enFazla: 40);
    await _bekle(tester, 6); // GORSEL: kumeler

    // Ilk kumeyi ac
    final kumeler = find.byIcon(Icons.folder_outlined);
    if (kumeler.evaluate().isNotEmpty) {
      await _dokun(tester, kumeler.first);
      await _bekle(tester, 6); // GORSEL: acilmis kume
    }

    // Oyun kurallari sekmesi
    await _dokun(tester, find.text('Oyun kuralları'));
    await _bekle(tester, 6);
    await _dokun(tester, find.text('Mevzuat'));
    await _bekle(tester, 3);

    // Bir PDF belgesini uygulama icinde ac
    final belgeler = find.byIcon(Icons.picture_as_pdf_outlined);
    if (belgeler.evaluate().isNotEmpty) {
      await _dokun(tester, belgeler.first);
      await _bekle(tester, 18); // GORSEL: PDF uygulama icinde
      await _geriDon(tester);
      await _bekle(tester, 3);
    }

    // --- Cevrimdisi arama --------------------------------------------------
    await _dokun(tester, find.byIcon(Icons.search).first);
    await _bekle(tester, 2);
    final kutu = find.byType(TextField);
    if (kutu.evaluate().isNotEmpty) {
      await tester.enterText(kutu.first, 'vize');
      await _bekle(tester, 6); // GORSEL: arama sonuclari
      await tester.enterText(kutu.first, 'antrenör');
      await _bekle(tester, 6);
    }
    await _geriDon(tester);
    await _bekle(tester, 3);

    // --- Kayitlar ----------------------------------------------------------
    await _dokun(tester, find.text('Kayıtlar'));
    await _bekle(tester, 7); // GORSEL: kaydedilenler ve hatirlatmalar

    // --- Federasyonlar -----------------------------------------------------
    await _dokun(tester, find.text('Federasyonlar'));
    await _bekle(tester, 7); // GORSEL: 65 kurum, tam adlariyla
  });
}

/// pumpAndSettle kullanilamiyor: ag ve reklam istekleri yuzunden animasyon
/// hic durmuyor, test zaman asimina ugruyor.
Future<void> _bekle(WidgetTester tester, int saniye) async {
  for (var i = 0; i < saniye * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _kadar(WidgetTester tester, bool Function() kosul,
    {required int enFazla}) async {
  for (var i = 0; i < enFazla * 4; i++) {
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
