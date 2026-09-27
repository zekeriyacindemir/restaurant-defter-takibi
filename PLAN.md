# İlk sürüm tasarım kararlarım

Tek şubeli bir restoranın günlük finansal takibini sade bir uygulamada bir araya getirmek için bu kapsamı belirledim.

Uygulama adı: **Restaurant Defter Takibi**. Tek, orta ölçekli restoran. Başlangıçta mevcut kayıt yok. İlk hedef altyapı ücreti 0; ihtiyaç oluştuğunda yaklaşık 25 ABD doları/ay değerlendirilebilir.

## Kapsam

Gün içinde sınırsız manuel gelir kaydı; nakit, kart, tek sipariş başlığı; malzeme/kira/personel/fatura giderleri; kısmi tahsilat ve ödeme; tedarikçi borçları; personel ad soyad ve maaş ödemeleri. Stok, vardiya, izin, adisyon, POS ve Yemeksepeti entegrasyonu bu sürümde yok. İnternet bağlantısı gerekir; çevrimdışı eşitleme yok.

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
3. Aynı gün, kanal ve ödeme yöntemiyle sınırsız gelir kaydı eklenebilir. Her form bir satış oluşturur; sıfır veya negatif tutar kabul edilmez. Kayıt, tahsilat ve işlem geçmişi tek veritabanı işlemi içinde yazılır.
4. Gelir formunda tek tutar, nakit/kart ve restoran içi/paket servisi seçenekleri vardır. Tarih girilmez; Türkiye saatine göre otomatik belirlenir. Tutar alanları boş başlar; nokta binlik, virgül kuruş ayırıcıdır. Yeni platform tahsilatı kaydı oluşturulmaz; eski kayıtlar korunur ve gelirlerin bekleyen tahsilatlar filtresinden kapatılabilir.
5. Nakit ve kart satışları aynı gün tahsil edilmiş kabul edilir. Kartın bankaya valörle geçişi, POS komisyon mutabakatı ve brüt/net platform komisyon hesabı bu sürümde otomatik yapılmaz. Kullanıcı tutarları tutarlı biçimde girmelidir; gerçek banka bakiyesi hesaplanmaz.
6. Gider, gider tarihinin ayına yazılır. Ödeme kendi tarihinin ayındaki para hareketine yazılır. Borcu kapatmak yeni gider oluşturmaz. Tahsilat da yeni gelir oluşturmaz.
7. Ana ekrandaki gelir-gider farkı resmi net kâr değildir. Tahsilat-ödeme farkı da başlangıç bakiyesi içermediği için kasa/banka bakiyesi değildir.
8. Aylık tablolar seçilen aya aittir. Tedarikçi ve bekleyen borç kutuları tüm dönemlerin güncel açık bakiyesidir.
9. Gider girişi ödenen tutarı da alır; fazlası kabul edilmez. Ek ödemelerde satır kilidi kullanılarak borç üstü ödeme engellenir.
10. İptal, kaydı ve bağlı para hareketlerini tüm raporlardan çıkarır; veriler ile gerekçe saklanır. Normal yeni ödeme veya iade yerine kullanılmaz. Arayüzden yeniden girilen düzeltme kayıtları bugünün tarihini alır; geçmiş ayı düzeltmek gerekirse ayrı bir kontrollü süreç gerekir. İptal geri alınamaz; geçmişteki kaydı görmek mümkündür.
11. Yeni gelir, gider ve ödeme kayıtlarında tarih otomatik olarak bugündür. Formlarda tarih/vade seçimi yoktur. Eski kayıtların tarih ve vadeleri korunur. Ayrı tahsilat–ödemeler sayfası yoktur; tedarikçi borçları ve ödemeleri tedarikçilerde, diğer açık giderler giderler filtresinde, eski maaş borçları personelde erişilebilir kalır.

## Veritabanı

- `members`: kullanıcı kimliği, ad, rol, aktiflik; kimlik doğrulama Supabase Auth'ta.
- `entries`: gelir ve gider; iptal bilgileri; ilgili tedarikçi veya personel.
- `payments`: kayıtla ilişkili bir veya daha fazla ödeme/tahsilat.
- `suppliers`: tedarikçi adı.
- `employees`: personel ad soyad.
- `audit_log`: ekleme, ödeme, iptal ve yetki değişiklikleri.

Tarayıcı tabloları doğrudan değiştiremez. Yazma fonksiyonları veritabanında kimlik ve rolü doğrular. Rapor fonksiyonu çalışanlara mali veri dönmez. Maaş detayları muhasebeci için veritabanı seviyesinde filtrelenir. `service_role` anahtarı arayüzde kullanılmaz.

## Canlıya geçişte kalan işler

Supabase ve Cloudflare hesapları kullanıcı tarafından açıldı. Veritabanı kurulumu, ilk işletme sahibi hesabı, canlı bağlantı ve dört gerçek kullanıcıyla doğrulama bekliyor. Yedekleme ve geri yükleme, 27 Eylül tarihinde kullanıcının isteğiyle sonraki aşamaya bırakıldı.
