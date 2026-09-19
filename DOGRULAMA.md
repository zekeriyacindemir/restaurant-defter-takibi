# Doğrulama kaydı

Tarih: 19 Eylül 2026.

İlk sürümün tesliminden önce uyguladığım kontrolleri ve henüz tamamlamadığım canlı ortam testlerini burada belgeledim.

## Tamamlanan kontroller

- `npm test`: 10 test geçti. Para hassasiyeti; siparişin tek sayılması; PostgreSQL üzerinde çalışan, müdür ve muhasebeci erişim sınırları; mükerrer günlük kayıt ve atomik geri alma; kısmi ödeme; farklı ayda ödeme; maaş detaylarının gizlenmesi; iptal; geçersiz tutarlar; pasif/atanmamış/anonim kullanıcı engeli.
- PGlite, gerçek PostgreSQL sorguları ve PL/pgSQL fonksiyonları çalıştırdı. Supabase Auth yerine test kimlikleri kullanıldı.
- Örnek önizleme dağıtım paketi başarıyla derlendi.
- Tarayıcıda 1.234,56 TL nakit ve 500 TL kartlı sipariş eklenerek gelir toplamının 1.734,56 TL artması doğrulandı.
- Tarayıcıda 10.000 TL gider, 4.000 TL ödeme ve 6.000 TL kalan borç akışı kontrol edildi; kalan borç kapatıldı.
- Çalışan ekranında sadece gelir girişinin, muhasebeci menüsünde maaş ve kullanıcı yönetimi dışındaki yetkili ekranların bulunduğu görüldü.
- 390 × 844 telefon görünümünde ana ekran incelendi; sayfa yatay taşması yok. Uzun tablolar kendi alanlarında yatay kayar. Masaüstü görünümü de incelendi.
- Tarayıcıda kontrol edilen akışlarda konsol hatası yok.
- Yedekleme PowerShell betiğinin sözdizimi doğrulandı.

## Henüz tamamlanmayan canlı kontroller

Supabase hesabı yok: gerçek Auth girişleri, gerçek ağ üzerinde RLS ve eşzamanlı ödeme testi, Cloudflare canlı yayın, zamanlanmış yedekleme, şifre çözme ve test projesine gerçek geri yükleme henüz yapılmadı. Bunların tamamlandığı iddia edilmez. İlk kayıtlar üretim sistemine girilmeden önce KURULUM.md uygulanmalıdır.
