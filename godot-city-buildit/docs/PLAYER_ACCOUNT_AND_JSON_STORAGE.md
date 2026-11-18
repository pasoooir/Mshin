# حساب بازیکن و ذخیره‌سازی JSON مستقل — ممیزی و اجرای مرحله اول

**تاریخ:** 2026-11-16  
**PR:** [#567](https://github.com/pasoooir/Mshin/pull/567) — merged to main (`5ea0716a60cf37a02bdc30230563ed106686d52f`)  
**وضعیت:** جریان Cloudflare Worker، نگاشت هویت در D1 و ذخیره پروفایل در مخزن خصوصی GitHub در کد و پیکربندی پروژه وجود دارد. این سند قرارداد پیاده‌سازی را توصیف می‌کند؛ موفقیت CI به‌تنهایی سلامت end-to-end حساب واقعی را اثبات نمی‌کند.

## تصمیم معماری
1. Google OpenID Connect فقط هویت را تأیید می‌کند.
2. Cloudflare Auth Worker شناسه عددی دائمی را از D1 می‌گیرد و توکن کوتاه‌عمر صادر می‌کند.
3. D1 فقط `player_id` و SHA-256 شناسه مستعار Google (`google_subject_hash`) را نگه می‌دارد؛ ایمیل ذخیره نمی‌شود.
4. Cloudflare Worker پس از اعتبارسنجی نشست، درخواست API را به هماهنگ‌کننده Durable Object می‌فرستد؛ شناسه بازیکن از claim معتبر نشست به هدر داخلی منتقل می‌شود، نه از ورودی آزاد کلاینت.
5. هماهنگ‌کننده با `GITHUB_JSON_TOKEN` که فقط در Secret قرار دارد، فایل JSON خصوصی `players/<player_id>.json` را در مخزن `pasoooir/mshin-player-data` می‌خواند/می‌نویسد.
6. GitHub Pages فقط میزبان فایل‌های عمومی بازی است؛ مخزن داده بازیکنان خصوصی است.

## ممیزی وضعیت واقعی مخزن
- موتور Godot 4.3 است و autoloadهای اقتصاد، پرداخت، انبار، ساخت، تولید، مناطق، تجارت، دستاورد و ذخیره‌سازی دارد.
- `SaveManager.gd` از schema نسخه 5 استفاده می‌کند و سطح، XP، جمعیت، رضایت، نام شهر، ارزها، دفتر تراکنش، پرداخت‌ها، انبار، معاملات، دستاوردها، مناطق، جاده‌ها و ساختمان‌ها را ذخیره می‌کند.
- snapshot هر منطقه شامل انبار همان منطقه، جاده‌ها، ساختمان‌ها، پروژه‌های ویژه، گسترش زمین و رضایت است. وضعیت ساختمان شامل مرحله، موقعیت، چرخش، جمعیت، ساخت، ارتقا، تایمرها و صف slotهای تولید است.
- پیش از این تغییر، همه پیشرفت اصلی در مسیر ثابت `user://pasoo_city_buildit_save.json` ذخیره می‌شد؛ شناسه حساب به فایل متصل نبود. در این شاخه، SaveManager هم برای خواندن و هم نوشتن از مسیر حساب‌محور استفاده می‌کند.
- تنظیمات صدا، لرزش، گرافیک، اعلان‌های ساختمان/تولید و اعلان‌های پیشرفت شهر، به‌همراه پیشرفت Tutorial در پروفایل JSON هر بازیکن ذخیره می‌شوند؛ فایل‌های cache محلی تنظیمات نیز با شناسه همان بازیکن scope می‌شوند.
- تنظیمات اعلان در مسیر `preferences.notifications` داخل JSON شهر قرار دارند. فایل قدیمی `notification_preferences.cfg` فقط برای مهاجرت بازیکن مهمان خوانده می‌شود؛ انتخاب‌های مهمان به حساب تازه‌وارد منتقل نمی‌شوند. تغییر هر toggle فوراً روی سیستم زنده اعمال و در ذخیره محلی ثبت می‌شود؛ در حالت ورودشده همان snapshot از صف پروفایل خصوصی GitHub عبور می‌کند.
- TradeManager شامل Trade Depot و معاملات NPC/بین مناطق است؛ بازار واقعی بازیکن‌به‌بازیکن نیست.
- پیش از این شاخه، سرور JSON مستقل، احراز هویت Google و اتصال آنلاین حساب در مخزن وجود نداشت.

## اجزای این مرحله
### Cloudflare Worker و مخزن خصوصی JSON
- Worker احراز هویت Google و APIهای `/v1/profile` و `/v1/rewards/claim` را ارائه می‌کند.
- D1 نگاشت hash هویت به شناسه عددی را نگه می‌دارد؛ هماهنگ‌کننده Durable Object عملیات JSON را serialize می‌کند.
- `GitHubJsonStore` فایل `players/<player_id>.json` را از مخزن خصوصی می‌خواند و با optimistic revision می‌نویسد.
- ایمیل و شناسه خام Google در JSON بازیکن ذخیره نمی‌شوند؛ فیلدهای ایمیل در payload نیز رد می‌شوند.
- `server/` نسخه Node.js محلی/مرجع API است، نه مسیر ذخیره‌سازی production مستقر روی GitHub Pages.

### Cloudflare Auth Worker (`cloudflare-auth/`)
- فقط endpoint ورود Google را ارائه می‌کند.
- امضای RS256 توکن Google، issuer، audience، expiry و nonce بررسی می‌شود.
- D1 فقط hash شناسه Google را به player_id عددی نگاشت می‌کند؛ ایمیل ذخیره نمی‌شود.
- Worker توکن HS256 بیست‌وچهارساعته برای API پروفایل صادر می‌کند و درخواست‌ها را از مسیر هماهنگ‌کننده Durable Object عبور می‌دهد.
- `AUTH_TOKEN_SECRET` باید به‌صورت secret در Worker و سرور مستقل تنظیم شود؛ هرگز در Git یا بازی قرار نمی‌گیرد.
- D1 ID و Google Client ID فایل نمونه placeholder هستند و به حساب واقعی متصل نشده‌اند.

### Godot
- `PlayerAccountManager.gd` session، توسعه admin، adapter ورود Google، بازیابی پروفایل و صف ذخیره آنلاین را مدیریت می‌کند.
- `SaveManager.gd` برای حساب واردشده از مسیر محلی مستقل `user://players/<player_id>/pasoo_city_buildit_save.json` استفاده می‌کند و payload کامل فعلی را به API صف می‌کند؛ پیشرفت Tutorial نیز در همین payload ذخیره می‌شود.
- Guest/offline همچنان مسیر محلی قدیمی را دارد.
- شناسه‌های آزمایشی `admin=100001` و `player2=100002` فقط در محیط توسعه سرور و Godot Editor قابل استفاده‌اند. endpoint توسعه در NODE_ENV=production همیشه 404 است.
- توکن نشست در فایل ذخیره نمی‌شود؛ پس از اجرای مجدد باید ورود دوباره انجام شود.

## محدودیت‌های پیش از انتشار
- Node API باید روی میزبان مستقل با دیسک پایدار، HTTPS و backup مستقر شود.
- مقادیر Worker و اتصال Google/D1 باید در محیط deployment معتبر باقی بمانند؛ رازها فقط در Secretهای سمت سرور نگهداری می‌شوند.
- رابط Settings جریان Google Identity Services را از طریق nonce و callback به API احراز هویت متصل می‌کند؛ آزمون ورود واقعی باید با حساب Google و origin مجاز انجام شود.
- آدرس API و Auth Worker در `project.godot` تنظیم شده‌اند؛ پیش از تغییر endpointها باید health و مسیر auth/profile بررسی شوند.
- این مرحله فایل save را ذخیره می‌کند اما قواعد بازی هنوز client-authoritative هستند؛ این ضدتقلب کامل نیست. پیش از بازار واقعی، رزرو کالا، کیف پول، خرید، فروش و ledger باید عملیات سمت سرور اتمیک و idempotent داشته باشند.
- تنظیمات صدا/گرافیک/haptics و پیشرفت Tutorial در payload پروفایل JSON ثبت می‌شوند و فایل‌های cache محلی با شناسه بازیکن جدا می‌شوند.
- تعارض چند دستگاه رد می‌شود؛ auto-merge انجام نمی‌شود.

## تست پذیرش
- Node: جداسازی دو شناسه، stale-write، رد فیلد ایمیل، خاموش بودن dev auth در production و رد token نامعتبر.
- Godot: جداسازی مسیر SaveManager بین شناسه‌های 100001 و 100002.
- CI: Godot Validation، GameplaySmoke، Android export، Web/Chromium و Node tests.
- تا استقرار واقعی سرور و پیکربندی Google/D1، ورود واقعی Google یا multiplayer production تأییدشده نیست.

## ممیزی زنجیره رویداد تنظیمات (Settings Event → State → JSON)

| کنترل / فرم | رویداد و مسیر اجرا | اثر واقعی | محل ذخیره |
|---|---|---|---|
| Music / Sounds | `Button.toggled → AudioManager.set_*_enabled` | پخش/توقف موسیقی و افکت‌ها | `preferences.audio.*` در JSON؛ فایل CFG فقط cache محلی حساب‌محور |
| Advanced volume | `HSlider.value_changed → AudioManager.set_*_volume` | تغییر فوری صدای خروجی | `preferences.audio.*`؛ نوشتن دیسک و JSON با debounce |
| Graphics quality | `OptionButton.item_selected → GraphicsSettingsManager.set_quality` | اعمال Low / Balanced / High روی 3D viewport | `preferences.graphics.quality` |
| Device benchmark | `Button.pressed → PerformanceMonitor.start_benchmark` | اجرای سنجش ۳۰ ثانیه‌ای و گزارش نتیجه در HUD | گزارش runtime؛ داده حسابی/مالی تولید نمی‌کند |
| Change City Name | `Button.pressed → GameManager.set_city_name → SaveManager.save_game` | اعتبارسنجی و تغییر نام شهر | `game.city_name`؛ برای حساب واردشده sync فوری پروفایل |
| Building alerts / City updates | `CheckButton.toggled → SaveManager.set_notification_preference` | اعمال فوری روی NotificationLayer و CitizenFeedback | `preferences.notifications.*`؛ sync صف‌شده برای پروفایل خصوصی |
| Wallet | `Button.pressed → EconomyManager balances` | نمایش موجودی واقعی Simoleons / SimCash / Golden Keys | داده از JSON اقتصاد بازی خوانده می‌شود؛ این پنل خرید بانکی انجام نمی‌دهد |
| Wallet purchase info | `Button.pressed → _show_wallet_purchase_info` | توضیح صریح عدم فعال‌بودن پرداخت واقعی؛ بدون درخواست پرداخت | هیچ تراکنش یا تغییری در موجودی ایجاد نمی‌کند |
| Help | `Button.pressed → TutorialGuide.open_help` | بازکردن راهنمای تعاملی شهر | وضعیت مراحل Tutorial در `tutorial` و فایل cache مستقل |
| Google account | `Button.pressed → PlayerAccountManager.begin_google_sign_in / logout` | شروع ورود امن یا خروج؛ خطای شروع ورود دکمه را قفل نمی‌کند | هویت/توکن در JSON ذخیره نمی‌شود؛ فقط پروفایل بازیکن در JSON خصوصی سرور |
| Close | `Button.pressed → _close_settings_panel` | بستن Overlay و آزادسازی پنل | نیازی به ذخیره ندارد |

**قواعد ذخیره‌سازی:** تغییرات مهم ابتدا در فایل محلی فعال نوشته می‌شوند. وقتی نشست معتبر وجود دارد، همان snapshot از مسیر `PlayerAccountManager.queue_profile_save` به API پروفایل و JSON خصوصی `players/<player_id>.json` ارسال می‌شود. خطای sync ابری از ذخیره محلی جدا گزارش می‌شود؛ شکست شبکه نباید انتخاب کاربر را بی‌صدا حذف کند. تنظیمات بازیکن مهمان نیز در save محلی خودش می‌ماند و به حساب تازه‌وارد نشت نمی‌کند.

**قواعد Responsive:** پنل اصلی Settings در صفحه اصلی بدون اسکرول و با grid دو ستونه باقی می‌ماند؛ فرم پیشرفته About اسکرول عمودی مستقل دارد. اندازه پنجره‌های modal و عرض ورودی نام شهر بر اساس viewport محدود می‌شوند تا در موبایل افقی از صفحه بیرون نزنند.

## نمونه قرارداد JSON
```json
{
  "schema_version": 1,
  "user_id": 100001,
  "revision": 7,
  "created_at": "2026-11-16T18:00:00.000Z",
  "updated_at": "2026-11-16T18:05:00.000Z",
  "game_state": {
    "version": 5,
    "game": {},
    "economy": {},
    "storage": {},
    "regions": {},
    "buildings": [],
    "roads": []
  }
}
```
هیچ ایمیل یا Google ID خامی در این فایل قرار نمی‌گیرد.
