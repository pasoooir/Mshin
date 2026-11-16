# حساب بازیکن و ذخیره‌سازی JSON مستقل — ممیزی و اجرای مرحله اول

**تاریخ:** 2026-11-16  
**PR:** [#567](https://github.com/pasoooir/Mshin/pull/567) — merged to main (`5ea0716a60cf37a02bdc30230563ed106686d52f`)  
**وضعیت:** کد هسته در main ادغام شده است. Godot Validation، Node JSON profile tests و GitHub Pages deploy در PR/main موفق شده‌اند؛ استقرار API مستقل و پیکربندی Google/D1 هنوز انجام نشده است.

## تصمیم معماری
1. Google OpenID Connect فقط هویت را تأیید می‌کند.
2. Cloudflare Auth Worker شناسه عددی دائمی را از D1 می‌گیرد و توکن کوتاه‌عمر صادر می‌کند.
3. D1 فقط `player_id` و SHA-256 شناسه مستعار Google (`google_subject_hash`) را نگه می‌دارد؛ ایمیل ذخیره نمی‌شود.
4. سرور مستقل Node.js توکن را اعتبارسنجی و فایل JSON خصوصی بازیکن را از روی شناسه عددی انتخاب می‌کند.
5. داده بازی در `MSHIN_DATA_DIR/players/<player_id>.json` قرار می‌گیرد؛ این مسیر نباید از وب‌سرور استاتیک قابل دسترسی باشد.
6. GitHub Pages فقط میزبان فایل‌های بازی است.

## ممیزی وضعیت واقعی مخزن
- موتور Godot 4.3 است و autoloadهای اقتصاد، پرداخت، انبار، ساخت، تولید، مناطق، تجارت، دستاورد و ذخیره‌سازی دارد.
- `SaveManager.gd` از schema نسخه 5 استفاده می‌کند و سطح، XP، جمعیت، رضایت، نام شهر، ارزها، دفتر تراکنش، پرداخت‌ها، انبار، معاملات، دستاوردها، مناطق، جاده‌ها و ساختمان‌ها را ذخیره می‌کند.
- snapshot هر منطقه شامل انبار همان منطقه، جاده‌ها، ساختمان‌ها، پروژه‌های ویژه، گسترش زمین و رضایت است. وضعیت ساختمان شامل مرحله، موقعیت، چرخش، جمعیت، ساخت، ارتقا، تایمرها و صف slotهای تولید است.
- پیش از این تغییر، همه پیشرفت اصلی در مسیر ثابت `user://pasoo_city_buildit_save.json` ذخیره می‌شد؛ شناسه حساب به فایل متصل نبود. در این شاخه، SaveManager هم برای خواندن و هم نوشتن از مسیر حساب‌محور استفاده می‌کند.
- تنظیمات صدا، لرزش، گرافیک و پیشرفت Tutorial در پروفایل JSON هر بازیکن ذخیره می‌شوند؛ فایل‌های محلی تنظیمات نیز با شناسه همان بازیکن scope می‌شوند.
- TradeManager شامل Trade Depot و معاملات NPC/بین مناطق است؛ بازار واقعی بازیکن‌به‌بازیکن نیست.
- پیش از این شاخه، سرور JSON مستقل، احراز هویت Google و اتصال آنلاین حساب در مخزن وجود نداشت.

## اجزای این مرحله
### Independent JSON API (`server/`)
- Node.js 20+ و فایل JSON مستقل برای هر شناسه.
- `GET /healthz`, `GET /v1/profile`, `PUT /v1/profile`.
- شناسه از claim توکن امضاشده گرفته می‌شود، نه ورودی کلاینت.
- نوشتن per-player serialized و با temp-file + atomic rename است.
- فیلدهای email/email_address/google_email در هر عمق payload رد می‌شوند.
- optimistic revision برای رد کردن stale write؛ سقف payload برابر 4 MiB.
- فقط یک writer process روی یک data directory پشتیبانی می‌شود؛ چند replica نیازمند قفل توزیع‌شده است.

### Cloudflare Auth Worker (`cloudflare-auth/`)
- فقط endpoint ورود Google را ارائه می‌کند.
- امضای RS256 توکن Google، issuer، audience، expiry و nonce بررسی می‌شود.
- D1 فقط hash شناسه Google را به player_id عددی نگاشت می‌کند؛ ایمیل ذخیره نمی‌شود.
- Worker توکن HS256 بیست‌وچهارساعته برای JSON API صادر می‌کند.
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
- D1 واقعی، Google Web Client ID و secretها باید در محیط deployment تنظیم شوند.
- UI ورود Google و تولید nonce در رابط بازی هنوز وصل نشده است؛ متد adapter آماده است.
- آدرس API و Auth Worker باید در تنظیمات پروژه تعیین شوند؛ مقدار پیش‌فرض خالی است.
- این مرحله فایل save را ذخیره می‌کند اما قواعد بازی هنوز client-authoritative هستند؛ این ضدتقلب کامل نیست. پیش از بازار واقعی، رزرو کالا، کیف پول، خرید، فروش و ledger باید عملیات سمت سرور اتمیک و idempotent داشته باشند.
- تنظیمات صدا/گرافیک/haptics و پیشرفت Tutorial در payload پروفایل JSON ثبت می‌شوند و فایل‌های cache محلی با شناسه بازیکن جدا می‌شوند.
- تعارض چند دستگاه رد می‌شود؛ auto-merge انجام نمی‌شود.

## تست پذیرش
- Node: جداسازی دو شناسه، stale-write، رد فیلد ایمیل، خاموش بودن dev auth در production و رد token نامعتبر.
- Godot: جداسازی مسیر SaveManager بین شناسه‌های 100001 و 100002.
- CI: Godot Validation، GameplaySmoke، Android export، Web/Chromium و Node tests.
- تا استقرار واقعی سرور و پیکربندی Google/D1، ورود واقعی Google یا multiplayer production تأییدشده نیست.

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
