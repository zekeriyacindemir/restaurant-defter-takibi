# Doğrulama kaydı

Son kontrol: 27 Eylül 2026.

Gelir girişini ve borç ekranlarını güncelledikten sonra uyguladığım kontrolleri burada belgeledim.

## Otomatik testler

`npm test`: **16 test geçti**. Node.js test çalıştırıcısı ve PGlite üzerinde:

- Türkçe binlik ayırıcılar ve kuruş hassasiyeti: `1.000`, `1.234,56`, `0,29`.
- Boş, negatif, geçersiz biçimli ve ikiden fazla ondalık basamaklı tutarların reddi.
- Kartlı paket satışının toplam gelire bir kez eklenmesi.
- Aynı gün aynı kanal/ödeme yöntemiyle birden fazla gelir kaydı.
- Gelirlerin sunucuda Türkiye tarihini alması; gider ve ödemenin tarih verilmediğinde bugüne atanması.
- Çalışanın mali kayıtları ve raporları okuyamaması.
- Muhasebecinin kişi bazında maaşları görememesi.
- Kısmi ödeme, farklı ayda ödeme, fazla ödeme engeli ve iptal.
- Tedarikçi toplamına yalnızca aktif tedarikçi giderlerinin kalanının dahil edilmesi.
- SQL geçiş dosyasının mevcut kayıtları koruması ve eski tekillik indeksini kaldırması.
- Yetkisiz, pasif ve anonim hesapların engellenmesi.

## Tarayıcıda kontrol ettiğim akışlar

1. Genel bakıştaki Gelir ekle düğmesi yeni formu açtı. Tutar boş, ödeme yöntemi ve satış yeri seçimli; tarih alanı yok.
2. `1000` yazarken alan `1.000` oldu. Aynı gün aynı nakit/restoran içi seçimiyle iki adet 1.000 TL kayıt başarıyla eklendi. Toplam gelir 148.940 TL'den 150.940 TL'ye çıktı.
3. 1.234,56 TL kartlı paket satışı toplam geliri, kart ve paket kırılımlarını doğru artırdı. Toplam gelir 152.174,56 TL oldu; çift sayılmadı.
4. Negatif tutar ve kalan borcu aşan ödeme reddedildi.
5. 10.000 TL tedarikçi gideri ve 4.000 TL ödeme sonrasında 6.000 TL borç oluştu. Toplam tedarikçi borcu 15.300 TL'den 21.300 TL'ye çıktı. Kalan 6.000 TL ödendiğinde 15.300 TL'ye döndü; toplam gider ikinci kez artmadı.
6. Ağustos raporu açıkken girilen 1,05 TL gelir Eylül'e kaydedildi; arayüz güncel aya döndü.
7. Çalışan hesabıyla gelir ekledim; yalnızca gelir giriş ekranı gösterildi. Muhasebeci menüsünde personel ve kullanıcı yönetimi bulunmadı.
8. Müdür hesabıyla 26.000 TL maaş ödemesi ekledim; ilgili personelin aylık ödeme toplamı 26.000 TL'den 52.000 TL'ye çıktı.
9. Ay filtresi değişse de Ödenmemişler tüm dönemlerin açık borçlarını gösterdi. Kalan toplam 15.300 TL olarak hesaplandı; brüt gider toplamıyla karışmadı.
10. 390 × 844 telefon görünümünde yeni formu ve masaüstü genel bakışı inceledim. Sayfa yatay taşması veya formda kesilen kontrol görülmedi. Mobil formda tarih girişi bulunmuyor.
11. Ayrı Tahsilat ve ödemeler menüsü ve genel bakıştaki ilgili panel kaldırıldı. Tedarikçi borçlarını kendi ekranından ödemek mümkün.
12. Kontrol edilen akışlarda tarayıcı konsolunda hata bulunmadı.

## Düzelttiğim ek sorunlar

- Geçmiş ay açıkken yeni kayıt görünmez kalabiliyordu; başarılı kayıttan sonra güncel aya dönülüyor.
- Ödenmemiş kayıtların özetinde brüt tutar kafa karıştırıyordu; kalan borç gösteriliyor.
- Ayrı ödeme ekranı kaldırılınca eski dönem borçlarının erişimi kaybolmaması için giderlerde tüm dönem filtresi ve personelde açık maaş kayıtları eklendi.
- Ay değişimlerinde geç gelen eski hata yanıtlarının güncel ekranı değiştirmesi engellendi.
- Uzun grafik ekseni etiketleri için sol boşluk artırıldı.

## Sınırlar

Tarayıcı testleri örnek veri modunda yapıldı. PGlite gerçek PostgreSQL sorguları ve RLS kurallarını çalıştırdı; Supabase Auth yerine test kimlikleri kullanıldı. Canlı Supabase hesabı, internet yayını, gerçek eşzamanlı ağ işlemleri, zamanlanmış yedekleme ve gerçek geri yükleme henüz doğrulanmadı. Bu kontroller tüm olası hataların bulunmadığı garantisi değildir.

## 27 Eylül: işletme sahibi senaryoları

- Gider ekranından personel seçmeden maaş girilebildiğini tarayıcıda yeniden ürettim. Bu kayıt kişinin ödeme toplamına yansımıyordu. Maaşlarda personel seçimini arayüzde ve veritabanı fonksiyonunda zorunlu yaptım; maaşın tedarikçiye bağlanmasını engelledim.
- Yeni kayıt sonrası eski arama ve filtreler yeni kaydı gizleyebiliyordu. Başarılı kayıttan sonra filtre ve aramayı temizledim. Nakit filtresi ve eşleşmeyen arama açıkken kartlı satış girerek görünür olduğunu doğruladım.
- 1.000 TL maaşın önce 400 TL, sonra 600 TL ödenmesini denedim. Personelin toplamı 26.000 → 26.400 → 27.000 TL oldu; kayıt iptalinde 26.000 TL'ye döndü. Kalan 600 TL iken 601 TL ödeme reddedildi.
- Aynı gün iki kez 1.234,56 TL kartlı paket satış girdim. Aylık gelir 148.940 → 151.409,12 TL oldu.
- 10.000 TL tedarikçi giderinde 4.000 TL ödeme, 6.000 TL borç bıraktı. Kalan ödendiğinde borç kapandı; aylık gider 137.750 TL kaldı, ikinci kez artmadı.
- Çalışan hesabında sıfır tutar reddedildi, 1.000 TL gelir eklendi; raporlar görünmedi. Muhasebeci görünümünde personel adları ve personel menüsü yoktu.
- Ödenen tutarın boş bırakılmasının “ödenmedi” anlamına geldiğini alanda açıkça belirttim. Boş sonuç metnini filtreli listelere uygun hâle getirdim.
- İki yeni PostgreSQL testi maaş ilişkilendirmesini, geçişin veri korumasını, kısmi maaş ödemesini, muhasebecinin ödeme engelini ve iptal sonrası toplamları doğruluyor.
- Örnek sürüm derlemesi başarılı. Canlı bağlantı henüz tanımlanmadı; gerçek giriş ve cihazlar arası kalıcılık testleri kurulumdan sonra yapılacak.

Yedekleme kurulumu, kullanıcının isteğiyle sonraki aşamaya bırakıldı.

Son tarayıcı kontrolünde konsolda hata/uyarı görülmedi. Görünüm aracı 390 px isteğine rağmen sayfayı 831 px genişlikte sundu; bu turda yeni bir 390 px mobil doğrulaması yapıldığı iddia edilmiyor. Gerçek telefonda canlı kabul testi hâlâ gerekli.
