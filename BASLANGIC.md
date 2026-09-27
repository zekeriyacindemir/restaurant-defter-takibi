# Ücretsiz yayına alma: ekran ekran

Bu rehberi Restaurant Defter Takibi uygulamasını sıfırdan Supabase ve Cloudflare Pages'e bağlamak için hazırladım. Hesapları kullanıcı yönetir. Güncel kod test edildi; canlı bağlantı tamamlanana kadar yerel ekran örnek veri kullanır. Yedekleme kurulumu sonraki aşamaya bırakıldı.

## 1. Supabase projesini oluştur

1. Supabase hesabında **New project** seç. Kuruluş/plan sorulursa **Free** kullan.
2. Proje adı: `restaurant-defter-takibi`.
3. Güçlü bir **Database password** belirle ve güvenli yerde sakla. Bu, uygulamaya giriş şifresinden farklıdır; Cloudflare'a yazılmaz.
4. Türkiye'ye yakın mevcut bir Avrupa bölgesi seç. **Create new project** ile oluştur ve hazır olmasını bekle. Zaten proje oluşturduysan yenisini açma.

## 2. Boş veritabanına tabloları kur

1. Projenin **SQL Editor** bölümünü aç, **New query** seç.
2. Bu depodaki [supabase/schema.sql](supabase/schema.sql) dosyasının tamamını kopyalayıp yapıştır.
3. **Run** düğmesine bas. Başarı mesajından sonra tablolar hazırdır.

Bu adım yeni ve boş projede bir kez çalıştırılır. Daha önce kurulu projede tekrar çalıştırılmaz; eski sürümden geliniyorsa KURULUM.md içindeki geçiş dosyaları kullanılır. Yeni kurulumda ayrıca migration dosyaları çalıştırılmaz.

## 3. İlk işletme sahibi girişini oluştur

1. **Authentication → Sign In / Providers** altında **Allow new users to sign up** seçeneğini kapat. Böylece dışarıdan herkes hesap açamaz. E-posta ile giriş açık kalmalı.
2. **Authentication → Users → Add user → Create new user** ekranında kendi e-postanla uygulama giriş hesabını oluştur. Uygulama şifreni kendin belirle. Kendi doğruladığın e-posta için **Auto Confirm User** seçeneğini kullanabilirsin; genel e-posta doğrulama ayarını kapatman gerekmez.
3. Oluşan kullanıcının **UID / User ID** bilgisini kopyala.
4. SQL Editor'da yeni sorgu aç. Aşağıdaki `KULLANICI_UUID` yerine bu kimliği yaz ve çalıştır:

```sql
insert into public.members (id, name, role)
values ('KULLANICI_UUID', 'İşletme sahibi', 'owner');
```

Bu ilk kullanıcı yetkilendirmesi bir kez yapılır. Supabase hesabın ile restoran uygulamasının kullanıcı hesabı ayrı şeylerdir. Diğer kullanıcılar da Authentication üzerinde oluşturulur; görevleri uygulamadaki **Kullanıcılar → Kullanıcı yetkilendir** ekranından atanır.

## 4. İki bağlantı bilgisini al

Projenin **Connect** penceresinden şu değerleri al:

- **Project URL**: `https://…supabase.co` biçimindeki adres.
- **Publishable key**: `sb_publishable_…` ile başlayan tarayıcı anahtarı. Gerekirse **Settings → API Keys** altında bulunur.

`secret`, `service_role`, veritabanı şifresi ve kişisel erişim tokenı kullanılmaz. Publishable anahtarı tarayıcı uygulaması içindir; kayıtları kullanıcı yetkileri ve RLS korur.

## 5. Cloudflare Pages üzerinden GitHub'daki kodu yayınla

### Zaten Workers projesi açtıysan

Mevcut projeyi kullanabilirsin. Depodaki `wrangler.jsonc`, derlenen `dist` klasörünü statik site olarak yayınlar; otomatik Vite dönüştürmesine gerek yoktur.

- **Settings → Build → Build command:** `npm run build`
- **Deploy command:** `npx wrangler deploy`
- **Build → Variables and secrets:** aşağıdaki dört ortam değişkenini ekle.
- Üretim dalı `main`, kök klasör depo kökü olmalı.
- Bu ayarları kaydettikten sonra son `main` commit'inden yeni derleme başlat. Eski başarısız commit'in yeniden denenmesi yeni yapılandırmayı içermez.
- Yayın adresi `workers.dev` olabilir. Son adımda Supabase Site URL alanına verilen gerçek adresi yaz.

`wrangler init` veya `wrangler setup` komutlarını deploy komutu olarak kullanma. Mevcut yapılandırmayla Vite eklentisi eklenmeden derlenmiş dosyalar yayınlanır. Yerel demo `dist` klasörü canlıya yüklenmez; Cloudflare önce gerçek ortam değişkenleriyle `npm run build` çalıştırır.

[Cloudflare statik dosya yapılandırması](https://developers.cloudflare.com/workers/static-assets/)

### Pages projesi açıyorsan

1. Cloudflare hesabında **Workers & Pages → Create application** yolunu aç. **Pages / Get started → Import an existing Git repository** veya **Connect to Git** seçeneğini bul. Menü metni değişebilir; hedef Git deposundan Pages projesi oluşturmaktır.
2. GitHub hesabını bağla. Depo erişimini yalnızca `restaurant-defter-takibi` ile sınırla. Bu bağlantı Cloudflare'ın kodu okuyup siteyi derlemesi içindir.
3. `zekeriyacindemir/restaurant-defter-takibi` deposunu seç.
4. Proje adı olarak `restaurant-defter-takibi`, üretim dalı olarak **main** kullan. Ad alınmışsa farklı bir ad seçebilirsin.
5. Derleme ayarları:

| Alan | Değer |
| --- | --- |
| Framework preset | Vite; listede yoksa None |
| Build command | `npm run build` |
| Build output directory | `dist` |
| Root directory | Boş bırak; uygulama Git deposunun kökünde |

6. **Environment variables** bölümüne ekle:

| Değişken | Değer |
| --- | --- |
| `VITE_SUPABASE_URL` | Supabase Project URL |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | Supabase publishable key |
| `VITE_RESTAURANT_NAME` | `Restaurant Defter Takibi` |
| `NODE_VERSION` | `24` |

7. **Save and Deploy** ile yayınla. Derleme başarılıysa Cloudflare bir `https://…pages.dev` adresi verir. Özel alan adı ve ücretli plan gerekmez.

`npm run build:demo` gerçek işletme yayını için kullanılmaz. Mevcut yerel `dist` klasörü örnek sürüm olabilir; yukarıdaki üretim derlemesi canlı bağlantıyı kullanır. Bağlantı bilgilerini sonradan değiştirirsen yeniden deployment başlat.

Git bağlantısı yerine dosya yüklemeyi tercih edersen KURULUM.md'deki Direct Upload yolunu kullan. O yol için önce gerçek Supabase bilgileriyle üretim derlemesi gerekir; kaynak proje ZIP'i yüklenmez. Direct Upload projesi sonradan aynı proje üzerinde Git entegrasyonuna çevrilemez.

## 6. Son bağlantı ve canlı kontrol

1. Supabase **Authentication → URL Configuration → Site URL** alanına Cloudflare'ın verdiği HTTPS adresini yaz ve kaydet.
2. Siteyi aç. **Önizleme** bandı ve rol seçici görünmemeli; e-posta/şifre giriş ekranı gelmeli.
3. Üçüncü adımda oluşturduğun işletme sahibi hesabıyla giriş yap. Yeni veritabanı boş olmalı; örnek restoran kayıtları taşınmaz.
4. Gerçek kayıt girmeden önce açıklamasına TEST yazarak iki satış, bir kısmi gider ve kalan borcun ödemesini dene. Telefonundan da aynı hesabı açıp sayfayı yenilediğinde kayıtların geldiğini kontrol et. Test bitince test kayıtlarını neden belirterek uygulamadan iptal et.
5. Çalışan, müdür ve muhasebeci girişlerini ayrı ayrı doğrula. Çalışan rapor görememeli; muhasebeci kişi bazında maaş görememeli.

Canlı test tamamlanmadan yalnızca yerel testlere dayanarak kurulum tamamlandı sayılmaz. Bu sürümde başka cihazdaki değişiklikleri görmek için sayfa yenilenir. Otomatik yedekleme şu an kapalıdır.

## Takılırsan

- **Canlı bağlantı ayarları gerekli**: Cloudflare ortam değişkenleri eksik. Değerleri ekleyip yeniden derle.
- **Aktif bir görev tanımlanmamış**: Authentication kullanıcısı var ama `members` tablosunda görev kaydı eksik veya pasif.
- **Giriş yapılamadı**: Restoran uygulaması için oluşturulan hesabı kullandığını kontrol et; Supabase yönetim hesabının şifresiyle karıştırma.
- **Önizleme** bandı: Demo derlemesi yayınlanmış. Komutu `npm run build` yap ve gerçek bağlantı değişkenleriyle yeniden yayınla.

## Resmî kaynaklar

- [Supabase API anahtarları](https://supabase.com/docs/guides/getting-started/api-keys)
- [Supabase giriş ayarları](https://supabase.com/docs/guides/auth/general-configuration)
- [Cloudflare Pages Git entegrasyonu](https://developers.cloudflare.com/pages/get-started/git-integration/)
- [Cloudflare Pages doğrudan yükleme](https://developers.cloudflare.com/pages/get-started/direct-upload/)
