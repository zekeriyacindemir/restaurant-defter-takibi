# Restaurant Defter Takibi

Orta ölçekli, tek şubeli bir restoranın günlük finansal hareketlerini takip etmek için geliştirdiğim web uygulaması. Bu projede amacım, işletme sahibinin gelirlerini, giderlerini ve açık borçlarını bilgisayarından veya telefonundan anlaşılır bir arayüz üzerinden takip edebilmesini sağlamak.

İlk sürümü günlük manuel kayıtlar üzerine kurdum. POS entegrasyonu veya kapsamlı bir muhasebe yazılımı yerine, restoranın günlük işleyişinde ihtiyaç duyduğu gelir–gider ve ödeme takibine odaklandım.

> **Durum: v0.1.0 — çalışan yerel önizleme ve Supabase'e bağlanmaya hazır uygulama kodu.** Canlı Supabase bağlantısı, bulut yayını ve otomatik yedekleme henüz kurulmadı. Ortam değişkenleri tanımlanmadan açılan önizlemede örnek veriler kullanılır; değişiklikler sayfa yenilendiğinde silinir.

## Neler yapabiliyor?

- Aylık gelir, gider ve gelir–gider farkını gösterir.
- Günlük hareketleri ve kategori bazında gider dağılımını grafiklerle sunar.
- Nakit, kart ve sipariş gelirlerini aynı tabloda, ayrı filtrelerle takip eder.
- Malzeme alımı, kira, personel ve fatura giderlerini kaydeder.
- Vadeli borçları, kısmi ödemeleri ve bekleyen tahsilatları takip eder.
- Tedarikçi bazında kalan borcu gösterir.
- Personelin ad soyad ve maaş ödemelerini yönetir.
- Kayıtlarda arama, ay/kategori filtreleri ve CSV dışa aktarma sunar.
- Hatalı kayıtları gerekçeli iptal eder ve işlem geçmişini saklar.
- Mobil ve masaüstü ekranlarına uyum sağlar.

## Teknik yaklaşımım

Arayüzü **JavaScript, HTML ve CSS** ile geliştirdim; geliştirme ve dağıtım sürecinde **Vite** kullandım. İlk sürümün kapsamını sade tutmak ve bakım yükünü azaltmak için ek bir arayüz framework'üne ihtiyaç duymadım.

Kalıcı veriler için **PostgreSQL**, kullanıcı girişleri için **Supabase Auth** bağlantısını hazırladım. Yetkilendirmeyi yalnızca arayüzde düğmeleri gizleyerek çözmedim: tablo erişimlerini **Row Level Security (RLS)** ile sınırlandırdım, yazma işlemlerini rol kontrolü yapan veritabanı fonksiyonları üzerinden yürüttüm.

Veritabanı testlerinde **PGlite**, test çalıştırıcısı olarak Node.js'in yerleşik test modülünü kullandım. Yayın hedefini **Cloudflare Pages** olarak belirledim. Ücretsiz altyapıyla başlamayı, kullanım ihtiyacına göre ücretli plana geçmeyi planladım.

```text
Tarayıcıdaki arayüz
        │
        ├── Supabase Auth → kullanıcı girişi
        │
        └── Supabase RPC → rol ve işlem kontrolleri
                                  │
                              PostgreSQL
                        kayıtlar + ödeme geçmişi
```

## Önem verdiğim hesaplama kuralları

**Para tutarlarını kuruş cinsinden tam sayı olarak sakladım.** Örneğin 1.234,56 TL, veritabanında 123456 olarak tutulur. Böylece para hesaplarında kayan nokta kaynaklı yuvarlama hatalarından kaçındım.

**Satış kanalı ile ödeme yöntemini ayırdım.** Kartla ödenen 500 TL'lik sipariş, hem sipariş hem kart filtresinde görünür; toplam gelire yalnızca 500 TL eklenir. Nakit, kart ve sipariş kutularının birbiriyle toplanmaması gerekir.

**Gider ile ödemeyi ayrı modelledim.** 10.000 TL'lik malzeme alımının 4.000 TL'si ödendiğinde gider 10.000 TL, kalan borç 6.000 TL olur. Borç daha sonra kapatıldığında ikinci kez gider oluşmaz. Ödeme, gerçekleştiği ayın para hareketinde görünür.

**Mükerrer günlük toplamları engelledim.** Aynı gün, kanal ve ödeme yöntemi için tek aktif gelir kaydı tutulur. Günlük form atomik olarak kaydedilir; alanlardan biri hatalıysa formun tamamı geri alınır.

**Düzeltmelerde geçmişi korudum.** Hatalı kayıtlar fiziksel olarak silinmez; iptal gerekçesi ve işlemi yapan kişi saklanır. İptal edilen kayıt ve bağlı para hareketleri raporlardan çıkarılır.

## Kullanıcı rolleri

| Rol | Erişim |
|---|---|
| İşletme sahibi | Tüm kayıtlar, raporlar, maaşlar, iptal, kullanıcı yetkilendirme ve işlem geçmişi |
| Müdür | Gelir–gider, raporlar, tedarikçiler, ödemeler, maaşlar ve iptal |
| Muhasebeci | Mali kayıtlar ve ödemeler; kişi bazında maaş bilgileri hariç |
| Çalışan | Yalnızca gelir ekleme; mevcut gelir kayıtlarını ve toplamları okuma yetkisi yok |

Muhasebecinin raporlarında personel giderinin aylık toplamını gösterdim; personel listesini ve kişi bazındaki maaş kayıtlarını erişime kapattım.

## Yerelde çalıştırma

Node.js 22.12+ veya 24 LTS gerekir.

```bash
npm ci
npm run dev
```

Supabase ayarları yoksa uygulama örnek verili önizleme modunda açılır. Bu modda gerçek işletme verisi kullanılmamalıdır.

Canlı bağlantıyı hazırlamak için `.env.example` dosyasını `.env` adıyla kopyalayın ve Supabase proje URL'si ile publishable/anon anahtarını tanımlayın. Veritabanı kurulumu ve ilk kullanıcı için [kurulum rehberini](KURULUM.md) izleyin.

`service_role`, secret anahtarları veya veritabanı şifresi arayüz ortam değişkenlerine yazılmamalıdır. `.env` dosyaları ve yedekler Git kapsamı dışındadır.

| Komut | İşlev |
|---|---|
| `npm run dev` | Yerel geliştirme sunucusu |
| `npm test` | Hesaplama ve PostgreSQL yetki testleri |
| `npm run build:demo` | Örnek verili önizleme paketi |
| `npm run build` | Supabase bağlantı ayarları doğrulanarak üretim paketi |
| `npm run preview` | Derlenmiş paketin yerel önizlemesi |

## Veri modeli

| Tablo | Sorumluluk |
|---|---|
| `members` | Kullanıcı adı, rolü ve aktiflik durumu |
| `entries` | Gelir/gider kayıtları ve iptal bilgileri |
| `payments` | Bir kayda bağlı ödeme veya tahsilatlar |
| `suppliers` | Tedarikçi bilgileri |
| `employees` | Personel ad ve soyadı |
| `audit_log` | İşlem ve yetki değişikliği geçmişi |

## Testler ve mevcut sınırlar

İlk sürümde **10 otomatik test başarıyla geçti**. Kuruş hassasiyetini, siparişin tek sayılmasını, kısmi ödemeleri, aylar arası ödeme hareketlerini, mükerrer kayıtları, iptalleri ve rol kısıtlarını kontrol ettim. Mobil görünüm ile temel gelir/gider akışlarını tarayıcıda da doğruladım.

PGlite testleri PostgreSQL sorgularını ve RLS kurallarını çalıştırır; gerçek Supabase Auth hizmetinin uçtan uca testi değildir. Canlıya geçmeden önce gerçek kullanıcılarla erişim kontrollerini ve yedekten geri yüklemeyi ayrıca doğrulayacağım. Ayrıntılar: [doğrulama kaydı](DOGRULAMA.md).

Bu sürümde stok, adisyon, vardiya, POS/Yemeksepeti entegrasyonu, otomatik komisyon hesabı ve çevrimdışı eşitleme bulunmuyor. Nakit/kart toplamları aynı gün tahsil edilmiş kabul ediliyor. Gelir–gider farkı resmi net kârı; tahsilat–ödeme farkı gerçek banka/kasa bakiyesini temsil etmiyor.

## Sonraki adımlar

- [ ] Supabase projesini oluşturup şemayı kurmak.
- [ ] Gerçek kullanıcı hesaplarını ve rollerini tanımlamak.
- [ ] Cloudflare Pages üzerinden yayınlamak.
- [ ] Şifreli yedekleme ve ayrı konumda saklama düzenini kurmak.
- [ ] Test projesinde geri yüklemeyi doğrulamak.
- [ ] Dört gerçek kullanıcı rolüyle canlı kabul testlerini tamamlamak.

## Proje yapısı

```text
src/         Arayüz, hesaplama fonksiyonları ve Supabase bağlantısı
public/      Favicon ve yayın ortamının güvenlik başlıkları
supabase/    Veritabanı şeması, RLS politikaları ve RPC fonksiyonları
tests/       Hesaplama ve veritabanı erişim testleri
scripts/     Üretim ayarı kontrolü ve şifreli yedekleme aracı
```

Tasarım ve kapsam kararlarını [PLAN.md](PLAN.md), canlı kurulum adımlarını [KURULUM.md](KURULUM.md) içinde belgeledim. Yedekleme betiği henüz canlı bağlantıyla çalıştırılmadı; hazırlanmış olması otomatik yedeklemenin aktif olduğu anlamına gelmiyor.
