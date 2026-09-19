# İlk sürüm tasarım kararlarım

Tek şubeli bir restoranın günlük finansal takibini sade bir uygulamada bir araya getirmek için bu kapsamı belirledim.

Uygulama adı: **Restaurant Defter Takibi**. Tek, orta ölçekli restoran. Başlangıçta mevcut kayıt yok. İlk hedef altyapı ücreti 0; ihtiyaç oluştuğunda yaklaşık 25 ABD doları/ay değerlendirilebilir.

## Kapsam

Günlük manuel toplamlar; nakit, kart, tek sipariş başlığı; malzeme/kira/personel/fatura giderleri; kısmi tahsilat ve ödeme; tedarikçi borçları; personel ad soyad ve maaş ödemeleri. Stok, vardiya, izin, adisyon, POS ve Yemeksepeti entegrasyonu bu sürümde yok. İnternet bağlantısı gerekir; çevrimdışı eşitleme yok.

## Yetkiler

| Rol | Yetki |
|---|---|
| İşletme sahibi | Tüm raporlar, maaşlar, kayıtlar, iptal, kullanıcı yetkilendirme ve işlem geçmişi |
| Müdür | Raporlar, gelir/gider, ödemeler, tedarikçi, maaşlar ve iptal |
| Muhasebeci | Gelir/gider, tedarikçiler, tahsilat/ödeme; kişi bazında maaşlar hariç |
| Çalışan | Yalnızca gelir ekleme; mevcut gelirleri veya toplamları okuma yok |

Muhasebeci personel giderinin aylık kategori toplamını görür; personel listesi ve tek tek maaş kayıtları verilmez. Bu, toplam mali raporun tutarlı kalması için seçilmiştir.

## Hesaplama kuralları

1. Tutarlar veritabanında kuruş cinsinden tam sayı tutulur.
2. Sipariş satış kanalıdır. Nakit/kart ödeme yöntemidir. 500 TL kartlı sipariş gelirde bir kez sayılır; iki filtrede görünür. Kart, nakit ve sipariş kutuları birbiriyle toplanmaz.
3. Gün + kanal + ödeme yöntemi için tek aktif günlük toplam vardır. Beş alanın tek formda kaydı atomiktir: biri hatalıysa hiçbiri kaydedilmez. 0 girilen alan için kayıt oluşmaz.
4. Günlük form restoran nakit/kart, sipariş nakit/kart ve platformdan tahsil edilecek tutar alanlarından oluşur. Sipariş platformları ayrı raporlanmaz.
5. Nakit ve kart günlük toplamları aynı gün tahsil edilmiş kabul edilir. Kartın bankaya valörle geçişi, POS komisyon mutabakatı ve brüt/net platform komisyon hesabı bu sürümde otomatik yapılmaz. Kullanıcı tutarları tutarlı biçimde girmelidir; gerçek banka bakiyesi hesaplanmaz.
6. Gider, gider tarihinin ayına yazılır. Ödeme kendi tarihinin ayındaki para hareketine yazılır. Borcu kapatmak yeni gider oluşturmaz. Tahsilat da yeni gelir oluşturmaz.
7. Ana ekrandaki gelir-gider farkı resmi net kâr değildir. Tahsilat-ödeme farkı da başlangıç bakiyesi içermediği için kasa/banka bakiyesi değildir.
8. Aylık tablolar seçilen aya aittir. Bekleyen tahsilat ve borç kutuları tüm dönemlerin güncel açık bakiyesidir.
9. Gider girişi ödenen tutarı da alır; fazlası kabul edilmez. Ek ödemelerde satır kilidi kullanılarak borç üstü ödeme engellenir.
10. İptal, kaydı ve bağlı para hareketlerini tüm raporlardan çıkarır; veriler ile gerekçe saklanır. Normal yeni ödeme veya iade yerine kullanılmaz. Hatalı kayıt düzeltilirken doğru kayıt ve tarihli ödemeler yeniden girilir. İptal geri alınamaz; geçmişteki kaydı görmek mümkündür.
11. Tarihler Türkiye takvimine göredir. Gelecek tarihli gelir/gider/ödeme kabul edilmez; gelecekteki ödeme vadesi kabul edilir.

## Veritabanı

- `members`: kullanıcı kimliği, ad, rol, aktiflik; kimlik doğrulama Supabase Auth'ta.
- `entries`: gelir ve gider; iptal bilgileri; ilgili tedarikçi veya personel.
- `payments`: kayıtla ilişkili bir veya daha fazla ödeme/tahsilat.
- `suppliers`: tedarikçi adı.
- `employees`: personel ad soyad.
- `audit_log`: ekleme, ödeme, iptal ve yetki değişiklikleri.

Tarayıcı tabloları doğrudan değiştiremez. Yazma fonksiyonları veritabanında kimlik ve rolü doğrular. Rapor fonksiyonu çalışanlara mali veri dönmez. Maaş detayları muhasebeci için veritabanı seviyesinde filtrelenir. `service_role` anahtarı arayüzde kullanılmaz.

## Canlıya geçişte kalan işler

Supabase ve Cloudflare hesapları; veritabanı kurulumu; ilk işletme sahibi hesabı; canlı bağlantı; dört gerçek kullanıcıyla doğrulama; şifreli yedek ve ayrı konum; test projesinde geri yükleme. Bunlar bitmeden gerçek işletme verileriyle kullanım başlamamalı.
