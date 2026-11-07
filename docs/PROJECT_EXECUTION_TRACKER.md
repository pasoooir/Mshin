## ادامه طبیعی‌سازی دریا و آسمان — 2026-11-07

- Shader دریا اکنون چهار مقیاس نویز متحرک را برای ریزتغییرات رنگدانه‌ای سطح آب ترکیب می‌کند؛ این جزئیات روی گرادیان چندمرحله‌ای، موج‌ها، caustics و برق نور اضافه شده‌اند.
- Shader آسمان از دو میدان ابر رویه‌ای با مقیاس و حرکت متفاوت استفاده می‌کند و ابرها را با ماسک نرم در لایه‌های بالاتر جو شکل می‌دهد؛ نویز یکنواخت قبلی کاهش یافته است.
- تست رگرسیون برای جزئیات چندمقیاسی آب و میدان‌های ابر اضافه شده است.
- هنوز معیار پذیرش نهایی، مشاهده بصری واقعی روی موبایل و عبور CI روی آخرین commit است؛ این commit به‌تنهایی اثبات کیفیت نهایی نیست.

---

## فاز رنگ‌آمیزی طبیعی 24-bit RGB — 2026-11-07

- دریا: گرادیان پیوسته چندمرحله‌ای از آب کم‌عمق فیروزه‌ای تا آبی عمیق، چند میدان موج، برق نور و caustics.
- دشت: بافت رویه‌ای 1536×1536 با لکه‌های ارگانیک و grain چندطیفی؛ رنگ‌ها از ترکیب RGB پیوسته تولید می‌شوند، نه یک پالت محدود.
- خاک: نوار خاک طبیعی میان دشت و شن ساحل با بافت مستقل، لکه‌های رنگی و تغییر تدریجی به ساحل.
- آسمان: گرادیان چندمرحله‌ای افق/پایین/میانه/سمت‌الرأس، نویز جوی ظریف و لایه ابرهای نازک روی dome سه‌بعدی.
- رندر خروجی در مسیر 24-bit RGB (حدود 16.7 میلیون ترکیب رنگ در 8-bit/channel) نگه داشته می‌شود؛ نمایش واقعی به پشتیبانی نمایشگر و GPU دستگاه نیز وابسته است.
- اصلاح UV ساحل انجام شد؛ تست رگرسیون از UV، خاک، چمن، دریا، آسمان و cache نسخه v83 محافظت می‌کند.
- تغییرات روی PR #324 باقی می‌مانند؛ تا موفقیت CI و بررسی بصری موبایل merge نشود.

---

# وضعیت اجرایی به‌روزشده — 2026-11-07

## فاز واقع‌گرایی بصری: ساحل و دنیای طبیعی

- **PR #324 — ساحل سه‌بعدی و رنگ‌آمیزی طبیعی:** 🟡 باز و در حال اعتبارسنجی؛ head فعلی `ae55df4dc8954f6ad4c5cbe227840097feeddc2e`.
- دریا با گرادیان چندمرحله‌ای از آب کم‌عمق فیروزه‌ای تا آبی عمیق، سه میدان موج، caustics، برق نور خورشید و foam چندلایه ساخته شده است.
- هندسه سطح آب 192 قطعه در امتداد ساحل و 72 ردیف در عمق دارد؛ رندر آب یک mesh است.
- ساحل شنی با گرادیان نرم شن خشک تا مرطوب و grain رویه‌ای ایجاد شده است.
- بافت چمن چندطیفی و ارگانیک به زمین پیوسته renderer اصلی متصل شده است.
- فایل‌ها محلی و آفلاین هستند؛ Service Worker به `mshin-arcade-v82` ارتقا یافته است.
- شبکه ساخت اولیه 32×32 همچنان خالی و قابل ساخت باقی می‌ماند؛ ساختمان پیش‌ساخته‌ای به شهر افزوده نشده است.
- **CI روی همین head:** regressionهای اشتغال/جمعیت، جاده/زونینگ/ترافیک و خدمات شهری موفق‌اند (runs `42340375884`, `42340376434`, `42340375919`). validate (`42340375906`)، mobile browser smoke (`42340375908`) و city mobile rendering (`42340375868`) هنوز در حال اجرا/صف هستند.
- **گیت انتشار:** تا موفقیت validate، mobile browser smoke و rendering روی همین head، ادغام انجام نشود. تست فیزیکی GPU و دستگاه Android همچنان مستقل و باز است.
- **موتور:** Three.js/WebGL برای خروجی فعلی GitHub Pages حفظ می‌شود؛ مهاجرت Unity در این milestone انجام نشده است.

---

# وضعیت اجرایی محیط شهر — 2026-11-04

- **PR #244 — دوربین طبیعی:** 🟢 ادغام‌شده؛ تست مرورگر موبایل، دوربین و دورهای مسابقه موفق.
- **PR #246 — سیلوئت اختصاصی ساختمان‌های خدماتی:** 🟢 ادغام‌شده؛ validate، regressionهای خدمات/راه/اشتغال و browser-smoke موفق.
- **PR #245 — پیاده‌رو و حق تقدم:** 🟡 در حال اعتبارسنجی؛ validate، regressionها و viewport performance موفق؛ browser-smoke نهایی در حال اجرا.
- **PR #242 — سایت ساخت‌وساز و HUD موبایل:** باز؛ ساخت‌وساز زمان‌دار با کارگران متحرک، عدم فعال‌سازی ساختمان تا پایان تایمر و تست‌های مرورگر.
- **Slice فصل و آب‌وهوا:** شاخه `feat/city-four-seasons-rebased`؛ چهار فصل، آب‌وهوای deterministic، تغییر رنگ درختان/آسمان و باران/برف/برگ‌ریزان؛ اثر آب‌وهوا بر بهره‌وری اقتصادی هم پیاده شده و از افت ترافیک جداگانه سنجیده می‌شود. تست واحد و Playwright موبایل در حال اجراست.
- **مرزهای تأیید:** Playwright موبایل جایگزین تست فیزیکی Android و بررسی GPU/frame-time واقعی نیست.

---

# وضعیت اجرایی به‌روزشده — 2026-11-03 20:27 UTC

> این بخش جدیدترین وضعیت را ثبت می‌کند و بر snapshotهای قدیمی‌تر پایین فایل اولویت دارد.

## شواهد انتشار و milestoneهای بصری

- **main فعلی:** `0876027e09b46a7ffc1beaf8766e5363fcaf0ec2`. این commit پاک‌سازی بازگشت فایل تست موقت است؛ runtime با merge قبلی PR #236 تغییر نکرده است.
- **PR #233 — orbit دو انگشتی:** 🟢 ادغام‌شده؛ main browser smoke run `41707299966` شامل city entry، mobile-only، سه دور مسابقه و offline موفق شد.
- **PR #236 — GLTF architecture asset pipeline:** 🟢 ادغام‌شده با commit `0debc46d38709472446eee75875eef95f24c9236`.
  - سه مدل GLTF 2.0 خودساخته: خانه شیروانی، آپارتمان بالکن‌دار، فروشگاه با ویترین و سایبان.
  - manifest محلی، embedded geometry، PBR material factors، ابعاد/scale و provenance با مجوز CC0-1.0.
  - مدل‌ها و preview در Service Worker cache `mshin-arcade-v67` precache شدند.
  - mobile GLTF preview acceptance و سایر browser smokeها روی main در run `41710669198` موفق‌اند؛ artifact تصویر/diagnostics همان run موجود است.
  - main validate run `41710669284` و Pages build/deploy run `41710668169` موفق‌اند.
- **PR #237 — accessible road crossings:** 🟡 در حال اعتبارسنجی؛ head فعلی `4586a73c7902ed720cc607835bc29ce741a6c99e`.
  - curb runs در محل تقاطع و گذرگاه‌ها قطع می‌شوند.
  - ۳۲ رمپ جدول جهت‌دار و ۱۶۰ قطعه tactile paving برای چهار تقاطع.
  - ۸۰ خط گذرگاه عابر در هر دو جهت.
  - این گذرگاه‌ها در preview صرفاً نشانه بصری‌اند؛ مسیریابی و حق تقدم واقعی همچنان از pedestrian graph شهر اصلی تبعیت می‌کند.
  - تست مرورگر موبایل باید تعداد رمپ‌ها، tactile paving، گذرگاه‌ها و رندر GLTF را تأیید کند.
- **مرزهای باز:** LOD، texture maps، بودجه GPU/frame time روی Android واقعی، Cocos Creator Editor import و QA دستگاه Android واقعی هنوز تأیید نشده‌اند.
- **شروع شهر اصلی:** خالی می‌ماند؛ محله GLTF و جزئیات خیابان فقط در صفحه preview مستقل هستند.

## صف اجرایی

1. تکمیل exact-head validate و mobile browser acceptance در PR #237؛ هیچ check در حال اجرا یا شکست‌خورده نادیده گرفته نشود.
2. پس از merge، Pages deploy و preview نهایی بررسی شود.
3. Slice C: تنوع درخت، فضای سبز و props با instancing و محدودیت draw-call.
4. Slice D: چرخه روز/شب و سایه‌های با بودجه موبایل.
5. سپس Android physical QA و Cocos Editor verification به‌عنوان gateهای مستقل.

---

# وضعیت اجرایی به‌روزشده — 2026-11-03 19:59 UTC

> این بخش جدیدترین شواهد است و بر snapshotهای قدیمی‌تر پایین همین فایل اولویت دارد.

## وضعیت دقیق main و PRها

- **main:** commit `3a1d527e300f51bffe2ded9a6907b3602cb65736`؛ PR #233 قابلیت orbit دو انگشتی را ادغام کرد.
- **انتشار main:** Pages build و deploy در run `41707298289` موفق؛ validate روی main در run `41707531890` موفق.
- **Browser smoke پس از merge #233:** run `41707299966` هنوز در حال اجراست؛ ورود شهر و mobile-only smoke موفق‌اند؛ آزمون سه دور مسابقه و offline هنوز در حال اجراست. بنابراین Gate 0 از نظر مرورگر کامل اعلام نمی‌شود.
- **PR #236 — GLTF architecture asset pipeline:** 🟡 باز و در حال اعتبارسنجی؛ head فعلی `3254abd71f0bebac180e8d8762152b156aff409f`.
  - سه مدل اصلی GLTF 2.0: خانه شیروانی، آپارتمان چهارطبقه با بالکن، فروشگاه شیشه‌ای با سایبان.
  - manifest محلی نسخه‌دار، مختصات Y-up، ابعاد، provenance و مجوز CC0-1.0 ثبت شده‌اند.
  - geometry داخل فایل‌ها embed شده؛ مدل/بافر/تکسچر خارجی وجود ندارد.
  - پیش‌نمایش محله سه مدل را بارگذاری می‌کند و در خطای بارگذاری به blockout رویه‌ای برمی‌گردد.
  - مدل‌ها و صفحه پیش‌نمایش در Service Worker با cache `mshin-arcade-v67` precache شده‌اند.
  - regressionهای جمعیت/اشتغال، جاده/زونینگ/ترافیک و مهاجرت/بازیابی/offline روی head فعلی موفق‌اند (runs `41708479954`, `41708480104`, `41708479952`).
  - validate run `41708479930` و mobile browser smoke run `41708470204` هنوز در حال اجرا هستند؛ تست مرورگر اختصاصی باید بارگذاری هر سه مدل و اولین frame سه‌بعدی را تأیید کند.
- **مرزهای باز:** LOD، texture maps، Android GPU profiling، Cocos Editor import و QA روی دستگاه Android واقعی هنوز تأیید نشده‌اند. شبیه‌سازی Playwright جایگزین دستگاه واقعی نیست.
- **شروع شهر اصلی:** همچنان خالی است؛ مدل‌های نمونه فقط در صفحه preview مجزا استفاده می‌شوند.

## صف اجرایی بعدی

1. تکمیل exact-head validate و mobile GLTF preview acceptance در PR #236؛ رفع هر شکست واقعی پیش از merge.
2. پس از merge، تأیید Pages deployment و بازبینی خروجی preview.
3. Slice B: بهبود هندسه خیابان/پیاده‌رو/تقاطع و افزودن regression بصری.
4. Slice C/D: فضای سبز، props و سپس نور/سایه با اندازه‌گیری بودجه موبایل.
5. Android physical QA و Cocos Editor verification همچنان دروازه‌های مستقل باقی می‌مانند.

---

# وضعیت اجرایی جاری — بازبینی 2026-11-03 روی main و PR #229

> وضعیت‌ها بر اساس commit و اجرای CI قابل مشاهده ثبت شده‌اند. CI موبایل، QA دستگاه Android واقعی یا Cocos Creator Editor نیست.

## خط مبنای main

- **main:** `bdd0ef8127a8b7e708a49b12645e73cf6c8ec102` (آخرین commit مستندات؛ Pages/validate/browser smoke موفق).
- **PR #217 — چرخه ساخت و ارتقای ساختمان:** 🟢 ادغام‌شده؛ هسته مستقل چرخه ساخت و ارتقا و تست‌های deterministic.
- **PR #221 — اصلاح معماری NodeNext:** 🟢 ادغام‌شده؛ مسیر importهای `.js` به سورس TypeScript و طبقه‌بندی دامنه شهر اصلاح شد.
- **PR #222 — جانمایی لمسی ساختمان:** 🟢 ادغام‌شده؛ پرتاب پرتو دوربین، برخورد با صفحه زمین، grid snapping و مالکیت تک‌لمسی.
- **اشغال خانه‌های ساخت‌وساز:** 🟢 پیاده‌سازی و تست روی main؛ helper مستقل هندسی، رد خانه اشغال‌شده و جلوگیری از هم‌پوشانی در حالت بدون grid. فقط ساختمان‌های دارای `CityBuildingProgression` خانه را رزرو می‌کنند.
- **PR #227 — توقف چرخش دوربین هنگام ساخت:** 🟢 ادغام‌شده با commit `9282953a6af2922d5da0616919f79cee53f04822`; هنگام فعال بودن placement، drag/pinch دوربین متوقف و در commit/cancel/disable آزاد می‌شود.
- **شواهد exact-main روی `bdd0ef8`:** validate run `41674006422`، mobile browser smoke run `41674006278` و Pages build/deploy run `41674005644` همگی موفق‌اند؛ build و deploy هر دو موفق‌اند.
- **PR #229 — ژست واقعی ورود موبایل:** 🟡 باز و در حال اعتبارسنجی؛ تست به‌جای کلیک مختصاتی از دکمه واقعی ورود شهر در viewport عمودی استفاده می‌کند و سپس fullscreen و landscape را بررسی می‌کند. روی head `4d9afbe08991192650ffe8ef0cfb9907b1073c4b`، validate run `41684655346` و mobile rendering run `41684655094` موفق‌اند؛ browser smoke run `41684655648` در حال اجراست. تا پایان browser smoke ادغام نشود.
- **Texture pipeline:** شش texture با ابعاد 512×512 تولید و اعتبارسنجی می‌شوند؛ material assignment نهایی، normal/roughness maps و Android GPU profiling هنوز تأیید نشده‌اند.
- **Cocos Creator 3.8.6:** فایل scene واقعی، اتصال prefab/component در Editor، build APK و QA روی دستگاه Android هنوز انجام/تأیید نشده‌اند.

## وضعیت اجرایی شهر

| حوزه | وضعیت | شواهد و گام بعدی |
|---|---|---|
| ذخیره و بازیابی | 🟢 PR #188 | مهاجرت v1 به v2، پشتیبان‌گیری و بازیابی؛ QA دستگاه واقعی باز است. |
| اشتغال و رشد منطقه‌ای | 🟢 PR #190 و #195 | ظرفیت شغل، نیروی کار، بیکاری و محدودیت رشد مناطق بر اساس نیروی کار. |
| خدمات شهری و رفاه | 🟢 PR #192، #193 و #197 | ظرفیت محدود خدمات و رضایت وزن‌دار ساکنان؛ اثر تراکم بر رفاه در PR #204 افزوده شد. |
| تخصیص محل کار و رفت‌وآمد | 🟢 PR #199، #200، #201 و #202 | مسیر کوتاه جاده‌ای، عامل‌های عابر شاغل و حرکت وابسته به تراکم؛ اثر congestion بر رضایت شهروندان در #204. |
| تجربه موبایل شهر | 🟢 CI مرورگر | اجرای main شماره `41674006278` 🟢 موفق؛ PR #229 تست ژست ورود موبایل را تکمیل می‌کند؛ Android واقعی باز است. |
| گرافیک بومی Cocos شهر | 🟡 blockout در PR #208 ادغام شد | palette، خانه، آپارتمان، فروشگاه، کارخانه، پارک، خیابان و مبلمان شهری؛ Editor/scene/texture/APK/device acceptance باز است. |
| CI و انتشار | 🟢 main مرورگر/انتشار | روی `bdd0ef8`، validate `41674006422`، mobile browser `41674006278` و Pages build/deploy `41674005644` موفق‌اند. |

## قواعد ثبت پیشرفت

- وضعیت 🟢 فقط با تست موفق روی commit دقیق و معیار پذیرش قابل ردیابی ثبت می‌شود.
- Playwright موبایل، اجرای مرورگر شبیه‌سازی‌شده است؛ نه تأیید دستگاه Android.
- درصد کلی بدون وزن‌دهی معیارهای محصول و QA واقعی گزارش نمی‌شود.
- PR دارای check در حال اجرا یا شکست‌خورده ادغام نمی‌شود.

# Mshin — Project Execution Tracker

Last evidence refresh: 2026-10-31 (after PR #54 and Cocos menu source update)

## Verified release 0.9.3 — repository-local runtime assets

- **Status:** 🟢 تکمیل‌شده و تأییدشده؛ PR #52 merged to `main` as `07695e04a4645dedd6fc0fed6a85ffbd8f895412`.
- **Validation:** merged-main run `41206965694` succeeded, including all 136 Node tests and desktop/mobile Playwright; Pages deployment run `41206965179` succeeded.
- **Asset inventory:** ۱۰ تصویر محیط، ۳ آیکون کنترل و ۱۰ فایل صوتی در `cdn/assets/{scenes,icons,audio}/`.
- **Runtime policy:** مسیرهای `src` در manifest همگی relative/local هستند؛ CDN fallback از Service Worker حذف شده و فایل‌ها در app shell با cache فعلی `mshin-arcade-v34` precache می‌شوند (نسخه اولیه 0.9.3 از v33 استفاده می‌کرد؛ PR #54 کش را ارتقا داد).
- **Version markers:** package/PWA برابر `0.9.3`؛ asset marker برابر `2026.10.31.17`؛ Cocos vector catalog نیز `2026.10.31.17`.
- **Provenance:** `docs/VENDORED_ASSETS.md` باید URL اصلی و وضعیت مجوز هر فایل را ثبت کند؛ پیش از انتشار عمومی، مجوزهای upstream باید بازبینی شوند.
- **Acceptance:** Node tests، data/syntax checks، Playwright desktop/mobile، بررسی same-origin بودن همه دارایی‌ها، merged-main validation و GitHub Pages deployment همگی موفق شدند.

## Verified menu redesign — PR #54 and PR #56

- **Browser menu:** PR #54 merged as `24f395546e2edd979c52c70934cbf319d9fe0462`; five-tab navigation uses an angular motorsport rail and a dedicated content panel with responsive mobile sizing.
- **Cocos runtime menus:** PR #56 merged as `1f822e597ec397c0b65ef6438c52b806aa39a8ff`; home, world, stage, pause and finish screens now share dark-navy panels, red racing accents and angular high-contrast buttons.
- **Validation:** PR #54 runs `41209240425` (PR) and `41209236363` (push) passed; PR #56 run `41209845420` passed; merged-main validation run `41210029961` and Pages deployment `41210029747` passed.
- **Boundary:** Cocos Creator Editor import, serialized startup scene, Creator Web build and physical-device QA remain unverified; source-level CI is not an Editor build.
- **Published browser URL:** https://pasoooir.github.io/Mshin/\n\n## Previous verified release — 0.9.2

- PR #51 merged as `e2b3af25b645e4c05ce73dd62d50d2bfe3bf1a42`; eight-second scenery-cache refresh for evolving aerial lighting.
- Live game: https://pasoooir.github.io/Mshin/

## Repository and delivery state


- Default branch `main` includes merge commit `8bd105a4ac33fa2606a23715aba4a68db98ccc30` (PR #9), following PR #8 merge commit `7722d011720a2dfa709d8966dcc56d6ee60ab636`.
- PR #1 (Cocos/game foundation), PR #2 (50-stage browser edition), PR #3 (Playwright browser QA), PR #4 (browser race audio and mute control), PR #5 (visible car animation and particles), PR #6 (garage, nitro and offline PWA), PR #7 (AI rivals, live position, minimap and mobile HUD refinement), PR #8 (coin economy, car unlocks, workshop upgrades and weather), and PR #9 (race achievements and milestone rewards) are merged.
- PR #4 adds dependency-free Web Audio engine tone, collision and finish effects, lazy AudioContext initialization after user interaction, and an accessible mute toggle.
- PR #4 validation passed: merged-main run `41064474829`; source-branch push and PR validation runs `41063447733` and `41063457438` also passed.
- PR #5 adds animated car details, world-accent lighting, exhaust trails, collision bursts and a finish celebration; it also verifies non-blank canvas pixels and captures desktop/mobile gameplay previews.
- PR #5 push and PR validation run `41065176095` and `41065195236` passed; screenshot artifact `mshin-gameplay-previews` is attached to PR run `41065195236` (expires 2026-11-06).
- Merged-main validation run `41065496716` passed. Pages build and deploy for the PR #5 merge commit succeeded in run `41065496240`.
- PR #6 adds a three-car garage (Rally Fox, Comet GT, Lynx 4x4), distinct speed/acceleration/grip profiles, trackside nitro pickups, a charge meter and timed boost; selected car and sound preference persist locally.
- PR #6 also adds a landscape PWA manifest, vector app icon and offline-first service worker. Playwright verifies reload/offline launch and that all 10 worlds remain selectable without a network connection.
- PR #6 source push run `41067407332` and PR run `41067417413` passed; screenshot artifact `mshin-gameplay-previews` is attached to run `41067417413` (expires 2026-11-06).
- Merged-main validation run `41067626291` and Pages build/deployment run `41067626354` both succeeded for merge commit `722ec96f62a1a78c2832219cb41eb17ac31c7da8`.
- PR #7 adds three AI rival cars with independent progress, live 1–4 race position, a circuit minimap with player/rival markers, finish placement feedback, and compact portrait HUD spacing. PR browser validation run `41070776069` passed; merged-main validation run `41071069297` passed after the service-worker cache version was advanced to `mshin-arcade-v2` so returning offline users receive the updated game.
- GitHub Pages build and deployment for merge commit `36fa6d7673ec4fd0f91db73be4487d8d67eef22a` succeeded in run `41071069211`.
- Main contains `index.html`, `src/web-game.js`, `src/audio.js`, and `tests/browser-smoke.mjs`; CI captures desktop and mobile gameplay screenshots.
- PR #8 adds first-clear/replay coin rewards and placement bonuses, two unlockable cars (Thunder EV and Desert Raptor), persistent per-car engine/grip/nitro upgrades (three levels each), ten world-specific weather profiles with animated rain/snow/sand/dust/storm/cosmic effects and weather-dependent handling, plus a cache-version bump to `mshin-arcade-v4`. Expanded Playwright verified wallet persistence, unlock purchases, all three workshop upgrade types, weather selection and a complete rewarded race.
- PR #9 adds five persistent milestones (First Finish, Podium Racer, World Tour, Garage Collector and Fully Tuned), each with a one-time coin bonus, an achievement board and finish-screen unlock announcements. It advances the offline cache to `mshin-arcade-v4`; Playwright verifies the first-finish badge, board state and bonus announcement.
- No Cloudflare R2, D1, KV, Durable Objects, paid storage, or paid services are used.

## Evidence-based status

| Workstream | Status | Progress | Evidence / remaining acceptance gate |
|---|---:|---:|---|
| Repository foundation and stage catalog | 🟢 | 100% | 10 world themes and 50 deterministic stage definitions exist and pass data validation. Gameplay balancing remains tracked separately. |
| Portable driving/race core | 🟡 | 68% | Off-road handling, bounded frame-step timing and invalid-input safeguards have regression coverage; broader play balance remains. |
| Cocos Creator project/runtime integration | 🔴 | 20% | Project metadata and runtime scripts are in `assets/scripts/`; no Editor-created startup scene, engine type-check, Editor import, or Cocos preview/build has been verified. |
| Cocos world visuals and hazards | 🟡 | 38% | Theme-specific decorations, route generation and hazard drawing are implemented in source; Creator visual QA is outstanding. |
| Cocos menus, selection and HUD | 🟡 | 40% | Runtime-created home/world/stage/pause/finish screens now share an angular navy/red motorsport visual system; Creator Editor/device responsive QA and actual scene integration remain outstanding. |
| Browser playable edition | 🟡 | 98% | Merged game includes five cars, persistent workshop upgrades, coin rewards, five milestone achievements, ten weather profiles, AI rivals, live ranking, minimap, nitro and 50 stages. Real-device balance, Cocos parity and final art polish remain. |
| Browser automated QA | 🟢 | 100% | Main validation run `41076533036` passed data validation, TypeScript/core build, syntax checks, Node tests and desktop/mobile Playwright. Tests cover five-car garage, coin unlocks, three persistent upgrades, weather profiles, full race and payout, First Finish achievement and bonus announcement, AI rivals, nitro, canvas rendering and offline PWA. |
| Audio, animation and polish | 🟡 | 64% | Browser engine tone, collision/finish audio, saved mute setting, animated vehicle details, AI rival cars, minimap, exhaust particles, nitro trails, collision bursts, finish celebration, weather overlays and achievement unlock feedback are implemented. More vehicle/environment animation and final art polish remain. |
| Persistence and records | 🟡 | 88% | Browser localStorage stores completion, best times, selected car, sound, wallet balance, unlocks, per-car engine/grip/nitro levels and one-time achievement IDs; backward-compatible migration supplies starter cars, safe upgrade levels, an empty achievement list and a zero-coin wallet for older saves. Playwright verifies reload, purchases, race rewards and achievement persistence. No server leaderboard. |
| Cloudflare Worker backend | 🟡 | 35% | Stateless health/config API and seven tests exist; not deployed or wired to a live game endpoint. |
| Portable automated tests | 🟢 | 100% | PR #7 validation run `41070456724` passed Node tests, syntax checks and Playwright desktop/mobile smoke tests covering AI-rival position HUD, garage, saved settings, nitro gameplay, rendered canvas, screenshots and offline PWA launch. |
| GitHub Pages delivery | 🟢 | 100% | Pages build and deploy for PR #9 merge commit `8bd105a4ac33fa2606a23715aba4a68db98ccc30` succeeded in run `41076531730`. |
| PWA installability and offline support | 🟡 | 94% | Manifest and vector icon remain; deployed app-shell cache `mshin-arcade-v4` refreshes old caches so returning offline users receive economy/workshop/weather/achievement updates. Playwright verifies offline reload and world selection; native install prompt and device-specific install UX remain to verify. |
| Cocos Web build and browser QA | 🔴 | 0% | No Creator-generated Web output; requires Creator 3.8.6 and a real startup scene. Browser Canvas edition is separate from a Cocos build. |
| Android APK/AAB and device QA | 🔴 | 0% | No APK/AAB; Android SDK/NDK/native toolchain and device testing are unavailable in the inspected runner. |

## CI and deployment evidence

- PR #4 merged: https://github.com/pasoooir/Mshin/pull/4 — audio and mute control.
- PR #5 merged: https://github.com/pasoooir/Mshin/pull/5 — animated car, particles and visible canvas assertions.
- PR #6 merged: https://github.com/pasoooir/Mshin/pull/6 — three-car garage, persistent settings, collectible nitro boost and offline PWA; merge commit `722ec96f62a1a78c2832219cb41eb17ac31c7da8`.
- PR #7 merged: https://github.com/pasoooir/Mshin/pull/7 — AI rivals, live race position, minimap, finishing placement and portrait HUD refinement; merge commit `36fa6d7673ec4fd0f91db73be4487d8d67eef22a`.
- PR #7 browser QA: https://github.com/pasoooir/Mshin/actions/runs/41070776069 — success.
- Merged-main validation: https://github.com/pasoooir/Mshin/actions/runs/41071069297 — success.
- Final-main validation with vehicle-relative AI pace balancing: https://github.com/pasoooir/Mshin/actions/runs/41071431670 — success.
- Last confirmed successful GitHub Pages deployment: https://github.com/pasoooir/Mshin/actions/runs/41071069211 — success.
- Latest Pages build: https://github.com/pasoooir/Mshin/actions/runs/41071430943 — build success; deploy step failed twice with GitHub API HTTP 500.
- PR #7 merged: https://github.com/pasoooir/Mshin/pull/7 — three AI rivals, live position indicator, minimap and finish placement.
- PR #7 validation: https://github.com/pasoooir/Mshin/actions/runs/41070456724 — success; browser QA and desktop/mobile screenshots passed.
- PR #8 merged: https://github.com/pasoooir/Mshin/pull/8 — coin rewards, two unlockable cars, three persistent upgrade tracks per car, ten weather profiles, handling effects and service-worker cache v3; merge commit `7722d011720a2dfa709d8966dcc56d6ee60ab636`.
- PR #8 browser QA: https://github.com/pasoooir/Mshin/actions/runs/41075069708 — success; wallet persistence, car unlocks, workshop purchases, weather selection and full rewarded race passed; screenshot artifact uploaded.
- PR #8 merged-main validation: https://github.com/pasoooir/Mshin/actions/runs/41075364077 — success.
- PR #8 GitHub Pages build and deployment: https://github.com/pasoooir/Mshin/actions/runs/41075362659 — success.
- PR #9 merged: https://github.com/pasoooir/Mshin/pull/9 — five persistent achievements with one-time coin bonuses and finish-screen announcements; merge commit `8bd105a4ac33fa2606a23715aba4a68db98ccc30`.
- PR #9 browser QA: https://github.com/pasoooir/Mshin/actions/runs/41076271293 — success; milestone unlock and bonus payout assertions passed with desktop/mobile screenshots.
- PR #9 merged-main validation: https://github.com/pasoooir/Mshin/actions/runs/41076533036 — success.
- PR #9 GitHub Pages build and deployment: https://github.com/pasoooir/Mshin/actions/runs/41076531730 — success.
- PR #9 adds five one-time achievements with bonus coin payouts, a persistent achievement board and finish-screen announcements; validation and Pages deployment passed.
- PR #6 push validation: https://github.com/pasoooir/Mshin/actions/runs/41067407332 — success.
- PR #6 browser QA and screenshot artifact: https://github.com/pasoooir/Mshin/actions/runs/41067417413 — success.
- Merged-main validation: https://github.com/pasoooir/Mshin/actions/runs/41067626291 — success.
- PR #4 branch push validation: https://github.com/pasoooir/Mshin/actions/runs/41063447733 — success.
- PR #4 validation: https://github.com/pasoooir/Mshin/actions/runs/41063457438 — success.
- Pages build and deployment for PR #6 merge commit: https://github.com/pasoooir/Mshin/actions/runs/41067626354 — success.
- Browser smoke covers 10 worlds, five stages/world, five-car garage and saved car selection, coin wallet and car unlock purchases, engine/grip/nitro upgrades and reload persistence, first-clear/replay/placement race rewards, five milestone achievements and one-time bonus announcements, ten weather profiles and handling, saved mute setting, nitro pickup/boost, non-blank rendered canvas, desktop/mobile screenshots, pause/resume, mobile touch sizing and offline PWA launch.
- Cocos syntax transpilation is not an engine type-check, Editor import, scene preview or Creator build.

## Browser 50-stage edition

- Main entry: `index.html`; runtime: `src/web-game.js`; audio module: `src/audio.js`.
- 10 themed worlds, 5 stages per world, 5 route styles, world-specific trackside scenery, hazard silhouettes and handling grip.
- World/stage selection, five-car garage (three starters plus two coin unlocks), per-car engine/grip/nitro workshop upgrades, first-clear/replay coin rewards with placement bonuses, five persistent milestone achievements with one-time bonuses, three AI rivals, live race ranking, track minimap, ten world-specific weather profiles and weather-dependent handling, keyboard steering, touch joystick/pedals/nitro, collectible nitro boost, 3-lap race flow, pause/finish, local completion and best-time records.
- Audio is generated through the Web Audio API without downloaded audio assets or third-party runtime dependencies. AudioContext initializes after user interaction; mute/unmute is available in the HUD.
- No third-party runtime dependencies; progress and settings are stored locally in the browser. The deployed versioned service worker (`mshin-arcade-v4`) caches the app shell and refreshes old caches so returning offline users receive the current gameplay after deployment.
- Automated Chromium tests exercise desktop and mobile menu-to-race flow and save `mshin-gameplay-desktop.png` and `mshin-gameplay-mobile.png` as the `mshin-gameplay-previews` workflow artifact. Full race completion, performance on low-end Android, touch gesture ergonomics, audio hardware compatibility, and art quality remain to be tuned.

## Cocos build feasibility and external gates

The inspected development runner has no Cocos Creator/Dashboard, Android SDK/NDK, `adb`, `sdkmanager`, `avdmanager` or Gradle. Official Creator 3.8 command-line publishing still requires an installed Creator GUI environment. Do not fabricate `.scene` files or claim Creator build/device QA based on Node tests.

External environment needed: a desktop with Cocos Creator 3.8.6 installed and opened, plus Android build dependencies and a physical device/emulator for APK/AAB and touch/orientation verification.

## Cloudflare boundary

`workers.js` exposes health/config and CORS preflight only. It is stateless, has no player-data persistence/leaderboard, and is not deployed or connected to the browser client. No R2/D1/KV/DO bindings or paid services are configured.


## Newly requested gameplay backlog — next priority

These items are planned work, not yet implemented or accepted. They are ordered so that traffic behavior and physically credible collision response are established before the final destruction effects.

| Priority | Work item | Status | Acceptance criteria |
|---|---|---|---|
| P1 | Intelligent, continuously moving nearby traffic (browser + Cocos AI foundation) | 🟢 تکمیل‌شده و تأییدشده | Rival/traffic cars maintain independent speed and progress, continuously steer, change lanes/route position, anticipate bends, keep safe following gaps, overtake when safe, and react to the player and other traffic. Motion must not look like cars sliding on fixed rails or teleporting between lanes. |
| P1 | Rear-end impact momentum transfer | ⬜ شروع‌نشده | When a rear car hits the car ahead, the front car receives a visible forward impulse and accelerates/gets displaced forward according to mass, closing speed, restitution and contact point. The rear car loses speed and may yaw/drift; momentum and energy behavior remain bounded and deterministic. Add chain-collision tests for multiple cars. |
| P2 | Progressive blackened paint after repeated impacts (browser) | 🟢 تکمیل‌شده و تأییدشده | Each new impact increases localized soot, scorch and paint-darkening on the struck panels. Damage accumulates per vehicle and per panel; one small touch must not instantly turn the whole car black. |
| P2 | Dense black smoke from heavily damaged front/engine area (browser) | 🟢 تکمیل‌شده و تأییدشده | Smoke starts subtle, becomes darker/denser with accumulated engine/front damage, rises and trails with vehicle motion/wind, and remains attached to the correct vehicle. |
| P2 | Fire and explosion at critical damage (browser) | 🟢 تکمیل‌شده و تأییدشده | Critical cumulative damage triggers a staged sequence: sparks/heat → visible flames → one controlled explosion with particles, flash, sound and camera response. Trigger once only; avoid repeated explosion loops. |
| P2 | Burn-out and vehicle removal (browser) | 🟢 تکمیل‌شده و تأییدشده | After the explosion, the wreck continues burning briefly, emits fading black smoke, then fades/shrinks and is removed from active traffic/collision/ranking safely. Player vehicle must use a clear race-over/recovery flow rather than silently disappearing. |
| P1 | Collision and destruction regression suite (browser integration + desktop/mobile smoke) | 🟢 تکمیل‌شده و تأییدشده | Automated tests cover impulse transfer, mass differences, off-centre yaw, repeated-hit damage accumulation, smoke/fire thresholds, one-shot explosion, burn duration, despawn cleanup, and no ghost collisions after removal. Desktop and mobile gameplay previews must show the complete sequence. |

**Implementation notes:** use the existing rigid-body/impulse and localized damage foundations rather than scripted teleportation. Keep browser and Cocos behavior aligned where each runtime is supported. Tune thresholds for readable arcade gameplay while preserving physically plausible direction and relative response. Treat smoke, flames and debris as pooled effects so repeated traffic collisions do not create unbounded per-frame allocations. The browser edition is released as 0.8.0 (PR #33 merged; release and deployment evidence linked below). Rear-end multi-car chain-collision tuning and full Cocos Editor/device validation remain separate follow-up gates.


## Release 0.7.0 — 2026-10-31

- **Status:** released and merged to `main` as PR #32 (merge commit `dab62a69b35e57f7ccd8c2898895cbd1b43d947f`).
- **Visible browser changes:** adaptive lane-changing traffic; progressive localized soot; dark smoke and fire; one-shot explosion feedback; wreck burn/fade/despawn; explicit player destruction finish state.
- **Offline compatibility:** service-worker cache v18 includes `rigid-body-physics.js`, `traffic-ai.js`, and `vehicle-destruction.js` in addition to the existing app shell.
- **Verification:** PR #32 release CI run `41172188163` passed all 15 steps, including `npm test`, desktop/mobile Playwright smoke and gameplay preview upload. Merged-main validation run `41172531303` passed; GitHub Pages build/deployment run `41172530906` succeeded.
- **Limit:** Cocos Creator Editor/device runtime validation is not claimed by browser CI.


## Release 0.7.0 — publication evidence

- Release PR #32: https://github.com/pasoooir/Mshin/pull/32 — merged.
- Release CI: https://github.com/pasoooir/Mshin/actions/runs/41172188163 — success; desktop/mobile smoke and gameplay preview artifacts uploaded.
- Merged-main validation: https://github.com/pasoooir/Mshin/actions/runs/41172531303 — success.
- GitHub Pages build/deployment: https://github.com/pasoooir/Mshin/actions/runs/41172530906 — success.
- Published commit: `dab62a69b35e57f7ccd8c2898895cbd1b43d947f`.
- Browser release URL: https://pasoooir.github.io/Mshin/ (deployment workflow succeeded; verify the live UI in a browser with cache refresh if an older service-worker shell appears).


## Release 0.8.0 — publication evidence

- **Status:** released and merged to `main` through PR #33; merge commit `2b564023744c9a0578943c33242d0e8504667be4`.
- **Engine audio:** replaced the synthetic oscillator with preloaded CDN race-car idle/rev, braking and downshift clips; the sound bank is decoded before GO. The selected SFXMint CC0 1.0 files are AI-generated effects rather than field recordings; this provenance is documented.
- **Road and camera:** 360-unit asphalt with four traffic lanes, four lane centers and pulled-back camera framing; road width is exposed in runtime telemetry.
- **Race start:** animated 3 → 2 → 1 → GO; player and AI movement remain frozen until GO.
- **Controls:** gas, brake and nitro use accessible jsDelivr SVG icons instead of text labels.
- **Preload:** ten world illustrations, five car sprites, ten photographic scenes, three control icons and four audio clips are loaded before importing the game loop; browser smoke confirms no asset/network requests during countdown or gameplay.
- **Verification:** release CI run #522 (`41174957473`) passed; merged-main validation run #523 (`41175066815`) passed; GitHub Pages build and deployment run #61 (`41175066541`) succeeded.
- **Release links:** PR #33 https://github.com/pasoooir/Mshin/pull/33 · CI https://github.com/pasoooir/Mshin/actions/runs/41175066815 · Pages https://github.com/pasoooir/Mshin/actions/runs/41175066541.
- **Published browser URL:** https://pasoooir.github.io/Mshin/
- **Limit:** Cocos Creator Editor/device runtime validation is not claimed by browser CI.


## Release candidate 0.8.3 — vehicle identity, cinematic intro and traffic variety

- Branch: `feat/vehicle-identity-cinematic-traffic-rewards`.
- Adds Rally, GT, 4x4 and Desert Raptor-specific recorded-loop processing profiles; Thunder EV switches to a speed-linked electric motor whine.
- Adds a full-screen close-up race intro behind the 3–2–1–GO overlay; countdown still freezes race movement.
- Progressively adds pickup, Formula, truck, bus and motorcycle traffic in stages 11, 21, 31 and 41.
- Strong front impacts initiated by the player award 10–60 persistent coins, rate-limited to prevent farming.
- Acceptance gates: all Node tests, syntax checks, desktop/mobile Playwright smoke, race intro rendering, later-stage traffic roster, persistent impact rewards, and GitHub Pages deployment.
- Cocos Creator Editor/device validation remains a separate external gate.


## 0.8.3 — 🟢 تکمیل‌شده و تأییدشده

- PR #36 با commit `672ec8ae0c4280d7380b4406998b3611146b0ded` در شاخه `main` ادغام شد.
- ۱۲۷ تست خودکار: ۱۲۷ موفق، صفر ناموفق.
- بررسی syntax، build، data validation و Playwright دسکتاپ/موبایل موفق شد.
- GitHub Pages build و deploy موفق شد.
- صداهای اختصاصی خودروها، intro معکوس ۳–۲–۱–GO، ترافیک مرحله‌ای و پاداش امتیاز/سکه برخورد در نسخه ۰.۸.۳ منتشر شد.
- تست فیزیکی روی بلندگو/گوشی واقعی هنوز انجام نشده و به‌عنوان تأیید دستگاه واقعی ادعا نمی‌شود.


## Release 0.8.4 — 🟡 در انتظار تأیید CI و انتشار

- نمایش واضح شماره نسخه منتشرشده ۰.۸.۴ روی صفحه آغازین و منوی اصلی؛ پیوند مستقیم مشاهده تغییرات نسخه نیز اضافه شد.
- نسخه package/PWA و کاتالوگ دارایی‌ها به‌صورت هماهنگ به ۰.۸.۴ و 2026.10.31.9 ارتقا یافتند؛ کش Service Worker به v23 تغییر کرد تا نصب‌های قبلی نسخه جدید را دریافت کنند.
- تأیید نهایی منوط به تست خودکار، مرورگر و استقرار موفق GitHub Pages است.


## Release 0.8.5 — 🟡 در حال اجرا

- هدف: رفع ناهماهنگی نسخه در README و رابط کاربری، فارسی‌سازی راهنمای چرخاندن گوشی و جلوگیری از اختلاف نسخه بین package، PWA، asset catalogs و Service Worker.
- تغییرات: نسخه نمایشی ۰.۸.۵؛ نشانگر دارایی `2026.10.31.10`؛ کش آفلاین `mshin-arcade-v24`؛ تست رگرسیون نسخه و نمایش badge در مرورگر.
- معیار پذیرش: `npm test`، اعتبارسنجی داده و syntax، Playwright دسکتاپ/موبایل، بررسی تطابق همه نشانگرهای نسخه، سپس merge و استقرار موفق Pages.
- محدودیت: تست واقعی روی دستگاه فیزیکی و تأیید Cocos Creator Editor از CI مرورگر استنتاج نمی‌شود.


## Release 0.8.6 — 🟢 تکمیل‌شده و تأییدشده

- هدف: بازطراحی منوی بازی با الگوی بازی‌های مسابقه‌ای GT؛ منوی تک‌صفحه‌ای با Tabهای مستقل و کارت‌های افقی تصویرمحور.
- تغییرات: تب‌های مسابقه، خودروها، تعمیرگاه، افتخارات و تنظیمات؛ تصویر بدون نوشته و توضیح فارسی زیر آن؛ طراحی سه‌بعدی/عمق‌دار؛ حذف پیوند آخرین تغییرات از صفحه اول.
- معیار پذیرش: تست‌های Node، اعتبارسنجی داده و syntax، Playwright دسکتاپ/موبایل، پیمایش تب‌ها با صفحه‌کلید، بررسی افقی‌بودن ریل‌ها و حفظ عملکرد انتخاب دنیا/مرحله/خودرو؛ تست‌های Node و Playwright دسکتاپ/موبایل موفق؛ PR #39 ادغام و استقرار GitHub Pages موفق.
- شناسه‌های نسخه: `0.8.6`، دارایی `2026.10.31.11`، کش آفلاین `mshin-arcade-v25`؛ merge: `ac716d561b01071851281425742128b9a07c57f3`؛ CI run: `41190710002`؛ Pages deployment: `41191114909` (موفق).


## Aerial environment and audio overhaul — active work (2026-10-31)

- **Status:** 🟢 پیاده‌سازی پایه ادغام شد؛ PR #43 merged at `0acb69f6fb11bf5ca9698b5e79d7680f9836165a`; visual/device acceptance remains open.
- **Implemented in PR #43:** a deterministic, lightweight Canvas 2.5D scenery pass for all ten world themes (layered tree canopies, shaded terrain/rock forms, raised building silhouettes, crowd clusters and trackside barriers); a moving rotor/body helicopter shadow rendered in world coordinates; unit tests for world-space shadow anchoring.
- **Changed files:** `src/aerial-environment.js`, `src/web-game.js`, `tests/aerial-environment.test.mjs`.
- **PR:** https://github.com/pasoooir/Mshin/pull/43
- **Validation:** PR #43 browser CI runs `41200716665` and `41200711698` passed; no visual screenshot/device QA has been captured; the existing renderer is still Canvas 2D (this is a 2.5D approximation, not a true 3D renderer).
- **Remaining mission gates:** independent music/SFX toggles and volume sliders with persistence; menu/race music; broader recorded SFX profiles and RPM/transient tuning; preload failure gating and verified audio decoding; cache/PWA updates; desktop/mobile visual and performance tests; all 50 stage screenshots/spot checks. Do not merge or deploy until these gates are addressed and CI passes.


## Independent music/SFX mixer and racing soundtrack — active work (2026-10-31)

- **Status:** 🟡 در حال اجرا؛ implementation branch `feat/audio-mixer-music-settings`; not merged or released.
- **Implemented:** separate Web Audio SFX and music buses; separate enable switches and 0–100 sliders; persistent values in `mshin-settings-v1`; menu/race loop selection with gain crossfade; mandatory decode of six RPM layers, brake/downshift effects and both music tracks before race countdown; abort countdown with an explicit message if required audio decode fails.
- **Music licensing:** MintoDog's “Racing Game Menu” and “Pure Raceway” are registered as CC0 in the manifest; source pages: https://opengameart.org/content/racing-game-menu and https://opengameart.org/content/pure-raceway.
- **Changed files:** `index.html`, `src/audio.js`, `src/web-game.js`, `src/asset-manifest.json`, `service-worker.js`, `package.json`, `manifest.webmanifest`, `tests/browser-smoke.mjs`.
- **PWA:** app version `0.9.1`, asset marker `2026.10.31.15`, cache `mshin-arcade-v31`; app shell now includes the aerial renderer.
- **Acceptance still pending:** CI must confirm OGA audio CORS/download/decode; browser assertions for independent switches and persisted slider values must pass; visual mobile settings QA and offline re-entry with the new music assets remain to be verified. No release is accepted until all required checks pass.


## اجرای دستی حوزه شهرسازی از GitHub Actions — 2026-11-03

پنج workflow مستقل با رویداد `workflow_dispatch` به شاخه `main` افزوده شدند و در تب Actions قابل اجرای دستی هستند:

| Workflow | دامنه اجرا | محدودیت مهم |
|---|---|---|
| `city-employment-demand.yml` | رگرسیون جمعیت و هسته شهر | تطبیق واقعی شهروند با شغل، vacancy و بازخورد تقاضای کار هنوز پیاده‌سازی/پذیرفته نشده؛ این workflow صریحاً baseline را گزارش می‌کند. |
| `city-service-impact.yml` | پوشش زیرساخت، خدمات عمومی و اقتصاد | تقاضای پویای خدمات، اشباع ظرفیت و اثر رضایت شهروندی هنوز نیازمند توسعه و تست اختصاصی است. |
| `city-save-recovery.yml` | مهاجرت ذخیره، backup round-trip و سازگاری آفلاین | آزمون‌های موجود را اجرا می‌کند؛ بازیابی‌های خطا/کمبود فضا و UX کامل هنوز باید توسعه یابد. |
| `city-roads-zoning-traffic.yml` | اتصال جاده، zoning، رشد و ترافیک | رگرسیون سیستم‌های موجود؛ پذیرش دستگاه واقعی را جایگزین نمی‌کند. |
| `city-mobile-performance.yml` | smoke موبایل شهر، rendering budget و artifactها | Playwright شبیه‌سازی موبایل است؛ اندازه‌گیری Android واقعی همچنان باز است. |

این workflowها ابزار اجرای دستی تست و دروازه پذیرش هستند، نه ادعای تکمیل خودکار قابلیت‌های مفقود. هر نتیجه فقط پس از اجرای واقعی و بررسی log/artifact می‌تواند وضعیت tracker را تغییر دهد.


## PR — two-finger 3D city orbit camera (2026-11-03)

- 🟡 پیاده‌سازی در شاخه `feat/city-two-finger-orbit-camera`: ژست دو انگشتی هم‌زمان زوم و چرخش دوربین Three.js را انجام می‌دهد؛ حرکت افقی مرکز دو انگشت و چرخش مچ (twist) هر دو زاویه دید را تغییر می‌دهند.
- دوربین از نمای ثابت ایزومتریک به orbit واقعی حول مرکز دید تغییر می‌کند؛ حرکت تک‌انگشتی همچنان برای pan و انتخاب/ساخت تک‌لمسی حفظ می‌شود.
- تست مرورگر موبایل باید هم‌زمان افزایش zoom و تغییر orbit را روی canvas شهر تأیید کند. تأیید دستگاه Android واقعی و بررسی عملکرد GPU همچنان باز است.
- نسخه وب هدف: `0.15.4`؛ service-worker cache: `mshin-arcade-v66`؛ asset marker: `2026.11.03.02`.

## PR #324 — Full-spectrum coastal city environment (2026-11-07)

- 🟡 فعال، در شاخه `feat/city-coastal-world-foundation`؛ هنوز merge یا deploy نشده است.
- ساحل با سه ناحیه مستقل meadow/soil/sand، اقیانوس چندگرادیانی با چهار مقیاس pigment/noise، موج و foam چندلایه؛ آسمان dome با دو میدان ابری procedural.
- مسیر رنگ renderer روی sRGB و ACES قرار دارد؛ دارایی‌های محیطی procedural و local/offline هستند.
- اصلاح این مرحله: آمار runtime آسمان اکنون وجود veil ابری و دو لایه میدان ابر را صریح گزارش می‌کند؛ تست رگرسیون همین telemetry را بررسی می‌کند.
- تست جدید `tests/city-coastal-world.test.mjs` به‌روزرسانی شده؛ اجرای محلی در این محیط ممکن نبود (دسترسی شبکه به GitHub و clone مخزن در دسترس نیست) و GitHub Actions برای HEAD جدید هنوز run/status قابل مشاهده‌ای برنگردانده است.
- پذیرش نهایی همچنان به اجرای CI روی HEAD نهایی، بررسی screenshot در مرورگر Android landscape و ارزیابی FPS/زمان ساخت texture روی موبایل واقعی وابسته است. تا آن زمان ادعای کیفیت نهایی یا انتشار نمی‌شود.

### PR #324 — shoreline continuity and mobile render budget (2026-11-07)

- 🟡 پیاده‌سازی روی شاخه feature ادامه یافت؛ هنوز ادغام/انتشار نشده است.
- مرز خاک و ماسه اکنون ۱٫۵ متر هم‌پوشانی کنترل‌شده دارد تا شکاف باریک ناشی از اختلاف نمونه‌برداری ساحل دیده نشود.
- تولید texture روی دستگاه‌های موبایل/کم‌حافظه به 1024px، تعداد bloom برابر 220 و grain برابر 36,000 کاهش تطبیقی یافت؛ دسکتاپ کیفیت 1536px و جزئیات بالاتر را حفظ می‌کند. آمار محیط، رزولوشن/کیفیت و زمان تولید texture را گزارش می‌کند.
- رندر موبایل: سقف pixel ratio برابر 1.25، خاموشی MSAA در موبایل و shadow map با وضوح 512؛ دسکتاپ تنظیمات باکیفیت‌تر را حفظ می‌کند.
- تست‌های رگرسیون برای هم‌پوشانی ساحل، کیفیت تطبیقی texture و بودجه رندر موبایل افزوده شد.
- محدودیت پذیرش: تست‌ها هنوز روی GitHub Actions برای HEAD جدید اجرا/قابل مشاهده نشده‌اند؛ screenshot، FPS و حافظه روی Android واقعی نیز هنوز اندازه‌گیری نشده‌اند. این مرحله را آماده انتشار تلقی نکنید.


# Coastal world quality gate — 2026-11-07

- **PR #324 head:** `2192dacafd1bf9770b26ad24e4cd20266d572169` (open, not merged).
- **Coastline geometry:** the beach and soil belt remain separate meshes; the soil upper edge overlaps the beach by 1.5 m to prevent a visible hairline seam. Beach/soil use independent sRGB procedural textures and receive shadows.
- **Mobile rendering tier:** constrained devices use 1024px organic textures, 128 shoreline segments × 48 water rows, 2 high-frequency pigment layers, 1.25 renderer pixel-ratio cap, no MSAA, and 512px shadow maps. Desktop retains 1536px textures, 192 × 72 water mesh, four pigment layers and 1024px shadow maps.
- **Shader regression fix:** mobile quality uniform is declared in the fragment shader and bypasses the two finest noise fields on phones; this avoids the previous risk of an undeclared GLSL uniform.
- **Automated evidence:** source-level regression assertions cover adaptive texture sizes, mobile geometry tier, shader uniform, shoreline overlap, and renderer settings. CI results for this exact head have not yet been returned by the GitHub workflow/status endpoints; no pass is claimed.
- **Still open:** verify the actual shoreline from multiple camera zoom levels, inspect for z-fighting/gaps at the grass–soil–sand junction, record mobile frame time/GPU memory on a physical Android device, and validate the shader in a real WebGL browser. Browser automation is not a substitute for physical-device QA.
