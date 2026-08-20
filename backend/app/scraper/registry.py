# -*- coding: utf-8 -*-
"""Turkiye spor federasyonlari kaynak kutugu.

Her kayit: slug, resmi ad, kisa ad, ana site, branslar.
Kesif adimi (scripts/discover_sources.py) bu kutuge duyuru uclarini ekleyip
data/sources.json dosyasini uretir.
"""
from dataclasses import dataclass, field
from typing import List


@dataclass
class Federation:
    slug: str
    name: str
    short: str
    site: str
    branches: List[str] = field(default_factory=list)
    olympic: bool = False
    para: bool = False


# Not: Turkiye Kick Boks Federasyonu (kickboks.gov.tr) kutukten cikarildi;
# site tum otomatik istekleri reddediyor (gercek tarayici ve yerel baglanti
# dahil 403). Federasyondan duyuru akisi alinirsa yeniden eklenebilir.
FEDERATIONS: List[Federation] = [
    Federation("futbol", "Türkiye Futbol Federasyonu", "TFF", "https://www.tff.org", ["Futbol"], olympic=True),
    Federation("basketbol", "Türkiye Basketbol Federasyonu", "TBF", "https://www.tbf.org.tr", ["Basketbol"], olympic=True),
    Federation("voleybol", "Türkiye Voleybol Federasyonu", "TVF", "https://www.tvf.org.tr", ["Voleybol", "Plaj Voleybolu"], olympic=True),
    Federation("atletizm", "Türkiye Atletizm Federasyonu", "TAF", "https://www.taf.org.tr", ["Atletizm"], olympic=True),
    Federation("hentbol", "Türkiye Hentbol Federasyonu", "THF", "https://thf.org.tr", ["Hentbol"], olympic=True),
    Federation("judo", "Türkiye Judo Federasyonu", "TJF", "https://www.judo.org.tr", ["Judo", "Kuraş"], olympic=True),
    Federation("gures", "Türkiye Güreş Federasyonu", "TGF", "https://tgf.tr", ["Güreş"], olympic=True),
    Federation("halter", "Türkiye Halter Federasyonu", "THF", "https://halter.gov.tr", ["Halter"], olympic=True),
    Federation("boks", "Türkiye Boks Federasyonu", "TBF", "https://www.turkboks.gov.tr", ["Boks"], olympic=True),
    Federation("taekwondo", "Türkiye Taekwondo Federasyonu", "TTF", "https://turkiyetaekwondofed.gov.tr", ["Taekwondo", "Hapkido"], olympic=True),
    Federation("karate", "Türkiye Karate Federasyonu", "TKF", "https://karate.gov.tr", ["Karate"]),
    Federation("yuzme", "Türkiye Yüzme Federasyonu", "TYF", "https://tyf.gov.tr", ["Yüzme", "Su Topu", "Artistik Yüzme", "Atlama"], olympic=True),
    Federation("tenis", "Türkiye Tenis Federasyonu", "TTF", "https://www.ttf.org.tr", ["Tenis"], olympic=True),
    Federation("masatenisi", "Türkiye Masa Tenisi Federasyonu", "TMTF", "https://tmtf.gov.tr", ["Masa Tenisi"], olympic=True),
    Federation("badminton", "Türkiye Badminton Federasyonu", "TBF", "https://badminton.org.tr", ["Badminton"], olympic=True),
    Federation("bisiklet", "Türkiye Bisiklet Federasyonu", "TBF", "https://bisiklet.org.tr", ["Bisiklet"], olympic=True),
    Federation("okculuk", "Türkiye Okçuluk Federasyonu", "TOF", "https://okculuk.org.tr", ["Okçuluk"], olympic=True),
    # Federasyon taaf.org.tr adresinden taf.gov.tr adresine tasindi; eski site 2018'de donmus.
    Federation("aticilik", "Türkiye Atıcılık Federasyonu", "TAF", "https://www.taf.gov.tr", ["Atıcılık", "Trap", "Skeet", "Havalı Silahlar"], olympic=True),
    Federation("binicilik", "Türkiye Binicilik Federasyonu", "TBF", "https://binicilik.org.tr", ["Binicilik"], olympic=True),
    Federation("cimnastik", "Türkiye Cimnastik Federasyonu", "TCF", "https://tcf.gov.tr", ["Artistik Cimnastik", "Ritmik Cimnastik", "Aerobik Cimnastik"], olympic=True),
    Federation("eskrim", "Türkiye Eskrim Federasyonu", "TEF", "https://eskrim.org.tr", ["Eskrim"], olympic=True),
    Federation("kurek", "Türkiye Kürek Federasyonu", "TKF", "https://tkf.gov.tr", ["Kürek"], olympic=True),
    Federation("kano", "Türkiye Kano Federasyonu", "TKF", "https://kano.org.tr", ["Kano", "Rafting"], olympic=True),
    Federation("yelken", "Türkiye Yelken Federasyonu", "TYF", "https://tyf.org.tr", ["Yelken", "Sörf"], olympic=True),
    Federation("triatlon", "Türkiye Triatlon Federasyonu", "TTF", "https://triatlon.org.tr", ["Triatlon", "Duatlon"], olympic=True),
    Federation("pentatlon", "Türkiye Modern Pentatlon Federasyonu", "TMPF", "https://tmpf.org.tr", ["Modern Pentatlon"], olympic=True),
    Federation("buzpateni", "Türkiye Buz Pateni Federasyonu", "TBPF", "https://buzpateni.org.tr", ["Buz Pateni", "Artistik Patinaj", "Kısa Kulvar"], olympic=True),
    Federation("buzhokeyi", "Türkiye Buz Hokeyi Federasyonu", "TBHF", "https://www.tbhf.org.tr", ["Buz Hokeyi"], olympic=True),
    Federation("curling", "Türkiye Curling Federasyonu", "TCF", "https://curling.gov.tr", ["Curling"], olympic=True),
    Federation("kayak", "Türkiye Kayak Federasyonu", "TKF", "https://tkf.org.tr", ["Kayak", "Snowboard", "Biatlon"], olympic=True),
    Federation("dagcilik", "Türkiye Dağcılık Federasyonu", "TDF", "https://tdf.tr", ["Dağcılık", "Spor Tırmanış"], olympic=True),
    Federation("golf", "Türkiye Golf Federasyonu", "TGF", "https://tgf.org.tr", ["Golf"], olympic=True),
    Federation("satranc", "Türkiye Satranç Federasyonu", "TSF", "https://www.tsf.org.tr", ["Satranç"]),
    Federation("bric", "Türkiye Briç Federasyonu", "TBF", "https://tbricfed.org.tr", ["Briç"]),
    Federation("bocce", "Türkiye Bocce Bowling ve Dart Federasyonu", "TBBDF", "https://tbbdf.gov.tr", ["Bocce", "Bowling", "Dart"]),
    Federation("bilardo", "Türkiye Bilardo Federasyonu", "TBF", "https://bilardo.gov.tr", ["Bilardo"]),
    Federation("motosiklet", "Türkiye Motosiklet Federasyonu", "TMF", "https://tmf.org.tr", ["Motosiklet"]),
    Federation("otomobil", "Türkiye Otomobil Sporları Federasyonu", "TOSFED", "https://www.tosfed.org.tr", ["Otomobil Sporları", "Ralli", "Pist"]),
    Federation("sualti", "Türkiye Sualtı Sporları Federasyonu", "TSSF", "https://tssf.gov.tr", ["Sualtı Sporları", "Dalış", "Paletli Yüzme"]),
    Federation("vucutgelistirme", "Türkiye Vücut Geliştirme, Fitness ve Bilek Güreşi Federasyonu", "TVGFBF", "https://tvgfbf.gov.tr", ["Vücut Geliştirme", "Fitness", "Bilek Güreşi"]),
    Federation("wushu", "Türkiye Wushu Kung Fu Federasyonu", "TWKF", "https://twkf.gov.tr", ["Wushu", "Kung Fu"]),
    Federation("muaythai", "Türkiye Muaythai Federasyonu", "TMF", "https://muaythai.gov.tr", ["Muaythai"]),
    Federation("bedenselengelliler", "Türkiye Bedensel Engelliler Spor Federasyonu", "TBESF", "https://www.tbesf.org.tr/tr/", ["Ampute Futbol", "Tekerlekli Sandalye Basketbol", "Para Yüzme", "Boccia"], para=True),
    Federation("isitmeengelliler", "Türkiye İşitme Engelliler Spor Federasyonu", "TİESF", "https://tiesf.org.tr", ["İşitme Engelliler Sporları"], para=True),
    Federation("gormeengelliler", "Türkiye Görme Engelliler Spor Federasyonu", "GESF", "https://www.gesf.org.tr", ["Goalball", "Görme Engelliler Sporları"], para=True),
    Federation("ozelsporcular", "Türkiye Özel Sporcular Spor Federasyonu", "TÖSSF", "https://tossfed.gov.tr", ["Özel Sporcular"], para=True),
    Federation("herkesicinspor", "Türkiye Herkes İçin Spor Federasyonu", "HİS", "https://his.gov.tr", ["Herkes İçin Spor", "Yoga", "Wellness"]),
    Federation("gelenekselguresler", "Türkiye Geleneksel Güreşler Federasyonu", "TGGF", "https://tggf.org.tr", ["Yağlı Güreş", "Aba Güreşi", "Karakucak"]),
    Federation("gelenekselsporlar", "Türkiye Geleneksel Spor Dalları Federasyonu", "GSDF", "https://www.gsdf.gov.tr/tr", ["Atlı Cirit", "Rahvan Binicilik", "Atlı Okçuluk", "Mas Güreşi"]),
    Federation("halkoyunlari", "Türkiye Halk Oyunları Federasyonu", "THOF", "https://thof.gov.tr", ["Halk Oyunları"]),
    Federation("hokey", "Türkiye Hokey Federasyonu", "THF", "https://www.turkhokey.gov.tr", ["Çim Hokeyi", "Salon Hokeyi"], olympic=True),
    Federation("beyzbol", "Türkiye Beyzbol, Softbol, Korumalı Futbol ve Ragbi Federasyonu", "TBSF", "https://tbsf.org.tr", ["Beyzbol", "Softbol", "Korumalı Futbol"]),
    Federation("ragbi", "Türkiye Ragbi Federasyonu", "TRF", "https://trf.gov.tr", ["Ragbi"], olympic=True),
    Federation("oryantiring", "Türkiye Oryantiring Federasyonu", "TOF", "https://oryantiring.org.tr", ["Oryantiring"]),
    Federation("universitesporlari", "Türkiye Üniversite Sporları Federasyonu", "TÜSF", "https://tusf.org.tr", ["Üniversite Sporları"]),
    Federation("danssporlari", "Türkiye Dans Sporları Federasyonu", "TDSF", "https://tdsf.org.tr", ["Dans Sporları"]),
    Federation("gelismekteolan", "Türkiye Gelişmekte Olan Spor Branşları Federasyonu", "GOSBF", "https://www.gosbf.org.tr", ["Korfbol", "Floorball", "Halat Çekme", "Sumo"]),
    Federation("havasporlari", "Türkiye Hava Sporları Federasyonu", "THSF", "https://thsf.org.tr", ["Yamaç Paraşütü", "Paraşüt", "Planör", "Model Uçak"]),
    Federation("izcilik", "Türkiye İzcilik Federasyonu", "TİF", "https://tif.org.tr", ["İzcilik"]),
    Federation("kaykay", "Türkiye Kaykay Federasyonu", "TKF", "https://kaykay.org.tr", ["Kaykay", "Skateboard"], olympic=True),
    # Ust kuruluslar, mevzuat ve antrenor egitimi kaynaklari
    Federation("shgm", "Spor Hizmetleri Genel Müdürlüğü", "SHGM", "https://shgm.gsb.gov.tr", ["Mevzuat", "Antrenör Eğitimi"]),
    Federation("gsb", "Gençlik ve Spor Bakanlığı", "GSB", "https://gsb.gov.tr", ["Bakanlık Duyuruları"]),
    Federation("tmok", "Türkiye Milli Olimpiyat Komitesi", "TMOK", "https://olimpiyat.org.tr", ["Olimpik Hareket"]),
    Federation("paralimpik", "Türkiye Milli Paralimpik Komitesi", "TMPK", "https://www.tmpk.org.tr", ["Paralimpik Hareket"], para=True),
    Federation("sportoto", "Spor Toto Teşkilat Başkanlığı", "Spor Toto", "https://sportoto.gov.tr", ["Kurumsal"]),
]

BY_SLUG = {f.slug: f for f in FEDERATIONS}
