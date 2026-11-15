# اقتصاد پیشرفت شهر با Simoleons و SimCash

**وضعیت:** PR #503 با commit `4c6b5be6a922b2a3a483f5af7f52db7c9690d5c5` و اصلاح منبع‌محور PR #505 با commit `84329766109cab4760317d37c2f645337f0b616e` و PR #506 با commit `8735b7b6f8491c0f385548ad2846d03ccaf29e09` نیز در `main` ادغام شدند. Godot Validation، Android Debug APK export/signature و Web/Chromium Desktop+Mobile CI موفق‌اند؛ آزمون فیزیکی Android و بالانس نهایی هنوز باز است. PR #505 مسیر خرید را از کاتالوگ مستقیم به پیشنهادهای چرخشی Global Trade HQ منتقل کرد تا قفل پیشرفت بازی دور زده نشود.
**مرجع رسمی:** EA Beginner Guide — https://help.ea.com/en/articles/simcity/simcity-buildit/beginner-guide/
**مرجع جامعه:** Building Materials — https://simcity-buildit.fandom.com/wiki/Building_Materials
**City Storage:** https://simcity-buildit.fandom.com/wiki/City_Storage
**Special Items:** https://simcity-buildit.fandom.com/wiki/Special_Items
**Trade Depot:** https://simcity-buildit.fandom.com/wiki/Trade_Depot

## ۱. رفتارهای منبع‌دار

### EA-confirmed
- Simoleons ارز روزمره برای خرید انواع ساختمان و ارتقای جاده است.
- SimCash می‌تواند تولید را سریع کند، اسلات فروشگاه تجاری را افزایش دهد، ظرفیت انبار و زمین گسترش را باز کند و به Simoleons تبدیل شود.
- Golden Keys با Simoleons یا SimCash خریداری نمی‌شوند و از مسیرهای بازی کسب می‌شوند.
- کارخانه‌ها مواد خام می‌سازند؛ بازیکن خروجی را جمع‌آوری می‌کند.
- فروشگاه تجاری مواد خام و محصولات قبلی را به محصولات تجاری تبدیل می‌کند؛ خروجی نیز باید جمع‌آوری شود.
- اقلام تولیدشده در انبار مرکزی شهر قرار می‌گیرند.
- نقشه خانه فهرست اقلام موردنیاز پیمانکار را نشان می‌دهد؛ پس از جمع‌آوری همه مواد، اقلام روی ساختمان اعمال می‌شوند.
- ارتقای فروشگاه تجاری با Simoleons انجام می‌شود و سطح ستاره زمان تولید را کاهش می‌دهد.

### Community-reference
- City Storage در مرجع فعلی با Storage Bar/Lock/Camera ارتقا می‌یابد؛ هر مرحله +5 ظرفیت و هر سه قلم به تعداد برابر مصرف می‌شوند. خرید هر Storage Special Item برابر 18 SimCash و آزادسازی از Level 4 است؛ فروش هر قطعه حداکثر 650 Simoleons است.
- Building Materials دو گروه اصلی دارد: Industrial Raw Materials و Commercial Items.
- مواد خام ۱۱گانه شهر اصلی و محصولات تجاری به ترتیب در کارخانه و فروشگاه تولید می‌شوند.
- زمان تولید، سطح آزادسازی، recipe و حداکثر قیمت فروش در جدول جامعه درج شده است؛ ممکن است با نسخه بازی تغییر کند.
- تولید می‌تواند در چند اسلات کارخانه به‌طور هم‌زمان انجام شود؛ فروشگاه‌ها صف دارند.
- SimCash برای تسریع تولید و خرید اسلات‌های اضافی فروشگاه به کار می‌رود.
- هزینه اسلات‌های تجاری در مرجع جامعه برای Building Supplies/Hardware از سایر فروشگاه‌های عادی کمتر است.

## ۲. سیاست‌های صریح Mshin (نه ادعای قیمت رسمی EA)

| عملیات | ارز | قاعده Mshin |
|---|---|---|
| خرید ساختمان | Simoleons | قیمت تعریف ساختمان در BuildManager |
| ساخت/ارتقای جاده | Simoleons | قیمت و سطح تعریف‌شده RoadSystem |
| ارتقای غیرمسکونی | Simoleons + مواد | BOM و هزینه تعریف‌شده برای نوع ساختمان و مرحله |
| ارتقای ستاره فروشگاه | Simoleons | offer داده‌محور ProductionManager |
| خرید کالا از بازار | Simoleons | فقط پیشنهادهای چرخشی Global Trade HQ موجود در `TradeManager`؛ قیمت/تعداد همان پیشنهاد و خرید با کنترل ظرفیت/موجودی. فرمول فعلی پیشنهادهای Mshin برابر ۲× ارزش کاتالوگ × تعداد است و قیمت رسمی EA نیست |
| تبدیل ارز | SimCash → Simoleons | نرخ داخلی فعلی 1 به 1000؛ نرخ Mshin، نه نرخ رسمی EA |
| تسریع تولید | SimCash | هر دقیقه باقیمانده یا بخشی از آن = 1 SimCash |
| اسلات صف فروشگاه | SimCash | جدول هزینه جامعه برای فروشگاه‌های شناخته‌شده، تا سقف 11 اسلات |
| خرید Dozer Wheel/Blade/Exhaust | SimCash | 24 SimCash برای هر Special Item؛ فقط از Mayor Level 10 و با حفظ مصرف عادی سه قلم در توسعه زمین |
| خرید Storage Bar/Lock/Camera | SimCash | 18 SimCash برای هر قلم؛ Level 4 به بالا |
| ارتقای City Storage | Special Items | +5 ظرفیت؛ مصرف تعداد برابر از هر سه Storage Item؛ سقف فعلی طراحی 1000
| خرید SimCash | پرداخت | فقط Sandbox تا اتصال درگاه؛ بدون دریافت وجه یا داده کارت |

قیمت فروش مواد در Fandom، «حداکثر قیمت فروش» است و قیمت خرید رسمی Global Trade HQ محسوب نمی‌شود. Mshin از پیشنهادهای چرخشی موجود TradeManager استفاده می‌کند؛ فرمول فعلی ۲× ارزش کاتالوگ × تعداد یک قاعده موجود Mshin است و نباید به EA نسبت داده شود.

## ۳. مسیرهای اجرایی متصل

### Simoleons
1. مشاهده پیشنهادهای چرخشی Global Trade HQ در پنل ارز، فقط وقتی Global Trade HQ عملیاتی باشد.
2. خرید پیشنهاد با `TradeManager.buy_global_offer` و کسر اتمی Simoleons؛ خرید در انبار با کنترل ظرفیت ثبت می‌شود.
3. رد خرید در صورت قفل بودن Global Trade HQ، پیشنهاد فروخته‌شده، کمبود Simoleons یا ظرفیت ناکافی.
4. استفاده از کالاهای خریداری‌شده در BOM ساخت ساختمان، ارتقای خانه، ارتقای غیرمسکونی و ورودی دستورهای فروشگاه.
5. حفظ مسیر تولید رایگان از کارخانه و زنجیره‌های خودکار موجود؛ بازار یک مسیر اختیاری برای صرفه‌جویی در زمان است.

### SimCash
1. تسریع هر اسلات فعال کارخانه یا فروشگاه؛ فقط اسلات در حال تولید قابل تسریع است، نه سفارش queued یا محصول آماده.
2. تکمیل فوری زمان ساخت ساختمان، فقط در صورت داشتن اتصال جاده‌ای معتبر.
3. تکمیل فوری ارتقای ساختمان، فقط در صورت operational بودن ساختمان.
4. خرید اسلات صف اضافه برای فروشگاه‌های پشتیبانی‌شده؛ ظرفیت و قیمت طبق کاتالوگ مشخص است.
5. خرید Special Itemهای توسعه زمین با SimCash: هر Dozer Wheel/Blade/Exhaust برابر ۲۴ SimCash؛ فقط پس از Mayor Level 10. خرید، موجودی را افزایش می‌دهد و بازکردن زمین همچنان از مسیر عادی `LandExpansionManager` و مصرف هر سه قلم انجام می‌شود.
6. اعطای SimCash خریداری‌شده فقط پس از نتیجه موفق provider؛ در Sandbox فقط انتخاب نتیجه آزمایشی و برچسب عدم دریافت پول واقعی.

### قواعد اتمی و جلوگیری از سوءاستفاده
- ابتدا شرایط سطح، ظرفیت، وضعیت زمان‌سنج و موجودی ارز بررسی می‌شوند.
- هزینه تنها یک بار و پس از quote معتبر کسر می‌شود.
- در خرید کالا، اگر افزودن انبار شکست بخورد پول بازگردانده می‌شود.
- تولید تسریع‌شده به وضعیت Ready می‌رود و آیتم همچنان باید توسط بازیکن جمع‌آوری شود؛ هیچ آیتمی مستقیماً در انبار دو بار شمرده نمی‌شود.
- عملیات به محدودیت‌های جاده، خدمات و نیروی کار دسترسی ندارند مگر آنکه خود سیستم عملیاتی ساختمان آن را تأیید کند.
- SaveManager باید موجودی، اسلات‌ها، زمان‌های پایان و دفتر سفارش پرداخت را پایدار کند.

## ۴. فایل‌های پیاده‌سازی

- `scripts/autoload/EconomyManager.gd`: quote هزینه تسریع؛ خرید بازار از TradeManager موجود انجام می‌شود.
- `scripts/production/ProductionComponent.gd`: quote و اجرای تسریع اسلات کارخانه/فروشگاه.
- `scripts/buildings/Building.gd`: تسریع ساخت، ارتقا و تولید legacy.
- `scripts/ui/CurrencyPanels.gd`: بازار کالا در پنل Simoleons؛ پیشرفت سریع، اسلات فروشگاه، خرید Dozer Special Item و خرید Sandbox در پنل SimCash.
- `tests/currency_economy_smoke.gd`: آزمون Global Trade HQ، ظرفیت انبار، خرید Dozer Special Item و توسعه زمین، قفل سطح، تسریع تولید، تبدیل، خرید Sandbox، یکتایی اعطا و حضور کنترل‌های UI.

## ۵. شکاف‌های باقیمانده و گیت پذیرش

- [x] اجرای Godot CI و رفع تمام خطاهای parser/runtime/test؛ run `43700782340` موفق شد.
- [x] اجرای Web/Chromium در دسکتاپ و موبایل افقی؛ run `43700782353` موفق شد. [ ] آزمون لمس و نمایش روی Android فیزیکی.
- [ ] بررسی توازن قیمت پیشنهادهای TradeManager و هزینه‌های SimCash با داده‌های واقعی بازی؛ هزینه ۲۴ SimCash برای Dozer Special Item از مرجع جامعه آمده است.
- [x] Trade Depot محلی: ثبت کالا، قفل‌کردن موجودی در زمان ثبت، شمارش اسلات‌ها، انتظار تا آماده‌شدن و دریافت Simoleons پیاده‌سازی شده بود؛ قابلیت لغو آگهی و بازگرداندن اتمی کالا اضافه شد. [ ] فروش چندبازیکنه واقعی، تبلیغ در Global Trade HQ و قیمت‌گذاری پویا به backend آنلاین نیاز دارد.
- [x] خرید Storage Bar/Lock/Camera با SimCash، آزادسازی Level 4 و ارتقای +5 با مصرف اتمی هر سه قلم پیاده‌سازی شد؛ مسیر قدیمی Simoleons-only غیرفعال شد. جدول دقیق افزایش تعداد اقلام باید در مرحله بعد با snapshot نسخه فعلی بازی تطبیق داده شود.
- [ ] درگاه واقعی: اعتبارسنجی سمت سرور و callback/webhook امضاشده پیش از اعطای ارز.
- [ ] گزارش تراکنش کامل برای بازار کالا و هزینه‌های SimCash، شامل شناسه، زمان، منبع و موجودی قبل/بعد.

- [x] خرید Dozer Wheel/Blade/Exhaust با SimCash به قیمت مرجع جامعه ۲۴ SimCash برای هر قلم؛ آیتم در انبار ذخیره می‌شود و `LandExpansionManager.expand_tile()` همچنان قفل سطح، مجاورت و BOM سه‌قلمی را اعمال می‌کند. PR #506 Godot Validation run `43701669455` و Web/Chromium run `43701669452` هر دو موفق شدند.

## ۶. منابع
- EA Beginner Guide: https://help.ea.com/en/articles/simcity/simcity-buildit/beginner-guide/
- Fandom Building Materials: https://simcity-buildit.fandom.com/wiki/Building_Materials
- Fandom Special Items: https://simcity-buildit.fandom.com/wiki/Special_Items
- Fandom Commercial Buildings: https://simcity-buildit.fandom.com/wiki/Commercial_Buildings
- Fandom Industrial Buildings: https://simcity-buildit.fandom.com/wiki/Industrial_Buildings
- Fandom SimCash: https://simcity-buildit.fandom.com/wiki/Simcash
- Fandom Simoleons: https://simcity-buildit.fandom.com/wiki/Simoleons
