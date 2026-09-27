# Ücretsiz canlı kurulum

Bu rehberi geliştirdiğim uygulamayı gerçek Supabase ve Cloudflare hesaplarına bağlamak için hazırladım. Hesap açma, şifre belirleme ve hizmet koşullarını kabul etme adımlarını hesap sahibi tamamlar. Şifreleri veya gizli anahtarları kaynak koduna ve herkese açık kanallara eklemeyin.

Hesaplar hazırsa ekran ekran kısa yol için [BASLANGIC.md](BASLANGIC.md) dosyasını kullanın.

## 1. Supabase projesi

1. [Supabase](https://supabase.com/dashboard) üzerinden ücretsiz hesap açın, Free planla yeni proje oluşturun. Güçlü veritabanı şifresini parola yöneticisinde saklayın.
2. Yeni ve boş projenin SQL Editor alanında `supabase/schema.sql` dosyasının tamamını bir kez çalıştırın. Bu başlangıç şeması mevcut veritabanına tekrar çalıştırılmak veya tabloları sıfırlamak için değildir.
3. Authentication ayarlarında yeni kullanıcıların kendi kendine kayıt olmasını kapatın. Kullanıcıları yalnızca işletme sahibi oluşturacak.
4. Authentication / Users üzerinden işletme sahibinin e-posta giriş hesabını oluşturun. Kullanıcı kendi şifresini belirlemeli; davet kullanılacaksa e-posta ve yönlendirme ayarları ayrıca doğrulanmalı.
5. Oluşan kullanıcının UUID kimliğini kopyalayın. SQL Editor'da aşağıdaki yer tutucuyu gerçek kimlikle değiştirip çalıştırın:

```sql
insert into public.members (id, name, role)
values ('ISLETME_SAHIBI_UUID', 'İşletme sahibi', 'owner');
```

Diğer kullanıcıların giriş hesaplarını Authentication üzerinden oluşturduktan sonra uygulamadaki **Kullanıcılar → Kullanıcı yetkilendir** formunda e-posta, ad ve görev atayın. Hesabı pasife almak veritabanı erişimini kapatır. Kullanıcıların kendi kendine rol yükseltmesi mümkün değildir.

### Önceki sürümü kurduysanız

Eski şemanın kurulu olduğu projede sırasıyla `supabase/migrations/20260921_flexible_income.sql` ve `supabase/migrations/20260927_salary_assignment.sql` dosyalarını çalıştırın. İkinci geçiş yeni maaş kayıtlarında personel seçimini zorunlu yapar. Bu geçiş, eski günlük tekillik kuralını kaldırır, tek satış gelir fonksiyonunu kurar ve otomatik tarih desteğini ekler. Mevcut kayıtlar silinmez. Yeni kurulumda güncel `schema.sql` yeterlidir; başlangıç şemasını mevcut veritabanının üzerine tekrar çalıştırmayın.

## 2. Uygulamayı bağlama

Proje ayarlarındaki Project URL ve **publishable** anahtarı alın. Eski projelerde `anon` anahtarı da kullanılabilir. `service_role`, `sb_secret_...` veya veritabanı şifresi kesinlikle arayüze konulmaz.

`.env.example` dosyasını `.env` adıyla kopyalayın:

```dotenv
VITE_SUPABASE_URL=https://PROJE_REFERANSI.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=PROJENIN_PUBLISHABLE_ANAHTARI
VITE_RESTAURANT_NAME=Restaurant Defter Takibi
```

`.env` dosyasını paylaşmayın veya kaynak kod deposuna eklemeyin. Tarayıcı için publishable anahtarın görünür olması normaldir; veri korumasını RLS ve veritabanı fonksiyonlarındaki yetki kontrolleri sağlar.

Geliştirme sunucusunu yeniden başlatın. Bağlantı tanımlandığında rol seçmeli örnek ekran gider, gerçek giriş ekranı açılır. Yeni canlı veritabanı boş başlar.

## 3. Cloudflare Pages

1. Ücretsiz Cloudflare hesabında Workers & Pages altında Pages projesi açın.
2. Kaynak kodu özel bir Git deposuna bağlayabilirsiniz. Derleme komutu `npm run build`, çıktı klasörü `dist`; Node.js 24 kullanın.
3. Pages derleme ortamına yukarıdaki iki bağlantı değişkenini ve uygulama adını ekleyin. Ortam değişkeni değiştikten sonra yeniden derleme gerekir.
4. Git bağlantısı yerine bilgisayarda `npm run build` çalıştırıp üretilen **dist klasörünü** Pages Direct Upload üzerinden yükleyebilirsiniz. Kaynak kodun tamamını, `.env`, yedekleri veya `node_modules` klasörünü yüklemeyin.
5. Verilen HTTPS adresini Supabase Site URL ayarında kullanın. Giriş yapan gerçek kullanıcılarla test edin.

`npm run build:demo` sadece örnek verili önizleme üretir; gerçek işletme yayını için kullanmayın. `public/_headers` dosyasındaki tarayıcı güvenlik başlıkları Pages çıktısına dahildir.

## 4. Canlı kabul kontrolü

- İşletme sahibi ve müdür maaşları görüyor.
- Muhasebeci toplam gideri görüyor, kişi bazında maaşlara erişemiyor.
- Çalışan yalnızca gelir ekliyor; geliştirici araçlarından doğrudan tablo okuma girişimi de mali veri döndürmüyor.
- Aynı gün aynı ödeme yöntemiyle iki satış girilebiliyor; iki tutar da birer kez toplanıyor.
- 10.000 TL gider ve 4.000 TL ödeme girildiğinde borç 6.000 TL; kalan ödendiğinde gider hâlâ 10.000 TL.
- Kartla ödenen 500 TL sipariş toplam geliri yalnızca 500 TL artırıyor.
- Telefon ve bilgisayarda aynı güncel veriler geliyor. Başka cihazdaki yeni kayıtları görmek için sayfayı yenileyin; canlı anlık eşitleme bu sürümde yok.
- İptal ve rol değişiklikleri işlem geçmişinde görülüyor.

## 5. Ücretsiz planda yedekleme

Supabase Free otomatik günlük yedek sunmuyor; düşük etkinlikte proje duraklayabiliyor. Yedekleme kurulumu kullanıcının isteğiyle sonraki aşamaya bırakıldı; aşağıdaki bölüm ileride uygulanacak rehberdir. Şu anda yedekleme etkin değildir. Pro başlangıcı 25 ABD doları/ay; son 7 günlük günlük yedek erişimi içeriyor. Kullanım, vergi ve ek özellikler faturayı değiştirebilir. Fiyatı geçiş anında yeniden kontrol edin. [Planlar](https://supabase.com/pricing), [yedekleme](https://supabase.com/docs/guides/platform/backups).

Önerilen düzen: her gece şifreli yedek; son 30 günün saklanması; yedeğin ikinci cihazda veya işletme sahibinin özel depolamasında ikinci kopyası; ayda bir geri yükleme denemesi. İşlem başarısız olursa sorumlu kişinin haberdar olacağı kontrol kurulmalı. Bilgisayar kapalıysa yerel zamanlanmış iş çalışmaz; bunu ücretsiz çözümün sınırı olarak kabul etmek gerekir. Bu teslimde görev zamanlanmadı ve depolama hesabına erişilmedi.

Hazırlanan `scripts/backup.ps1` aracı Supabase CLI ile roller, şema ve verileri dışarı alır; ZIP arşivini **age** ile şifreler; yalnızca kendi ürettiği geçici açık dosyaları temizler. Başarılı yedek için SHA-256 dosyası da üretir. Yedekler otomatik silinmez ve otomatik yüklenmez. Supabase Storage dosyaları bu uygulamada kullanılmıyor; ileride eklenirse ayrıca yedeklenmeli.

Kurulum sırasında teknik olarak gerekenler:

1. Supabase CLI, Docker Desktop ve [age](https://github.com/FiloSottile/age) resmi kaynaklarından kurulmalı.
2. `age-keygen` ile şifreleme anahtar çifti oluşturulmalı. Özel anahtar yedeklerden ayrı, güvenli ikinci bir yerde tutulmalı. Yedekleme görevinde sadece `age1...` açık anahtar bulunur.
3. Supabase Connect bölümündeki Session pooler bağlantısı `SUPABASE_DB_URL` ortam değişkenine güvenli biçimde tanımlanmalı. Bu değer gizlidir; hiçbir `VITE_` değişkenine veya kaynak kod dosyasına yazılmaz.
4. Çalıştırma örneği:

```powershell
.\scripts\backup.ps1 -Recipient 'age1_ACIK_ANAHTAR'
```

5. Gerçek proje üzerinde ilk yedek alınmalı, şifreli dosya ikinci konuma aktarılmalı. CLI veya yedek hatası çözülmeden işlem başarılı sayılmamalı.
6. Sonrasında işletme sahibinin bilgisayarında zamanlama ve başarısızlık takibi yapılandırılabilir. Şu an otomatik yedek varmış gibi davranılmamalı.

### Geri yükleme denemesi

Şifreli arşiv `age --decrypt --identity OZEL_ANAHTAR_DOSYASI --output backup.zip YEDEK.zip.age` ile açılır. ZIP içindeki dosyalar **yeni bir test projesine**, Supabase'in resmi [yedekleme ve geri yükleme rehberi](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore) takip edilerek alınır. Üretim projesinin üzerine deneme yapılmaz. Yönetilen roller ve Auth sürümleri nedeniyle geri yükleme sırasında resmi rehberdeki özel durumlar uygulanabilir.

Kontrol: girişler, kullanıcı rolleri, kayıt sayıları, seçilmiş aylık toplamlar, kalan tedarikçi borçları ve maaş erişim kısıtları eski proje ile eşleşmeli. Şifre çözme anahtarı yoksa şifreli yedek kullanılamaz. Veritabanı yedeği Supabase kontrol paneli ayarlarını ve harici hesapları otomatik kopyalamaz.

Yedekleme aracı hesap/bağlantı olmadığı için canlı ortamda çalıştırılmadı; gerçek geri yükleme denemesi de henüz yapılmadı.

## Kaynaklar

- [Supabase bağlantı seçenekleri](https://supabase.com/docs/guides/database/connecting-to-postgres)
- [Supabase satır düzeyi güvenlik](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Cloudflare Pages Vite dağıtımı](https://developers.cloudflare.com/pages/framework-guides/deploy-a-vite3-project/)
