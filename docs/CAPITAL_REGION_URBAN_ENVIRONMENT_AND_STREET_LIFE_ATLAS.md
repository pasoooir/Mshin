# اطلس طراحی محیط شهری و زندگی خیابانی منطقه پایتخت
**Capital Region Urban Environment & Street Life Atlas**

- وضعیت: سند طراحی تفصیلی؛ نه ادعای تولید Asset یا پیاده‌سازی.
- موتور هدف: Cocos Creator 3.8.6 / TypeScript
- پلتفرم: Android و iOS؛ Mobile-first
- سبک هدف: stylized-realistic، خوانا، منسجم و بهینه برای موبایل.
- وابستگی: WORLD_SPATIAL_SPEC، VEHICLE_FLEET_FREIGHT_TRAFFIC_SPEC، MOBILE_CITY_UX_INTERACTION_ACCESSIBILITY_SPEC و FREE_ASSET_LIBRARY_AND_VISUAL_PRESENTATION_SPEC.

## 1. مأموریت محیط شهری
محیط باید حس یک شهر منسجم را منتقل کند: خیابان‌ها مقصد دارند، محله‌ها هویت دارند، وسایل نقلیه به سفر واقعی متصل‌اند و عناصر شهری با شبکه و کاربری زمین سازگارند. هیچ prop یا انیمیشنی نباید وضعیت simulation را جعل کند.

سه اصل:
1. قابلیت خواندن: از نمای دور نوع محله و سلسله‌مراتب خیابان تشخیص داده شود.
2. کارکردپذیری: هر عنصر عملیاتی به سیستم معتبر متصل باشد؛ عنصر تزئینی فقط نقش بصری دارد.
3. اقتصاد موبایل: جزئیات در نزدیکی دوربین افزایش یابند؛ هزینه رندر با فاصله و اهمیت کنترل شود.

## 2. سلسله‌مراتب شبکه خیابان
### 2.1 کلاس‌های راه
| کلاس | نقش فضایی | طراحی بصری | الزامات عملکردی |
|---|---|---|---|
| Local street | دسترسی محله مسکونی | مقطع آرام، پیاده‌رو و درخت در صورت امکان | اتصال به frontage و مسیر محلی |
| Collector | جمع‌آوری ترافیک چند خیابان | عرض بصری بیشتر و نشانه تقاطع | اتصال میان local و arterial |
| Arterial | محور اصلی شهر | چندخطی، میانه/چراغ در صورت تعریف | ظرفیت و تقاطع با کنترل ترافیک |
| Industrial access | دسترسی لجستیکی | شعاع گردش و فضای مانور کامیون | محدودیت وسیله و freight routing |
| Service lane | دسترسی خدماتی | ساده و کم‌عرض | دسترسی تعمیر/تحویل |
| Pedestrian path | حرکت پیاده | سنگ‌فرش و اتصال امن | فقط اگر pedestrian graph پشتیبانی شود |

ابعاد، عرض واقعی، ظرفیت، سرعت، فاصله تقاطع و هزینه‌ها TBD هستند و از spatial/traffic simulation استخراج می‌شوند. ظاهر عرض خیابان نباید ظرفیت را بدون data definition تغییر دهد.

### 2.2 اجزای قطعه خیابان
- سطح آسفالت/سنگ‌فرش با variation کنترل‌شده.
- جدول و لبه قابل خواندن.
- خط‌کشی فقط بر اساس نوع راه و جهت جریان.
- پیاده‌رو، curb ramp و گذرگاه در نقاط تعریف‌شده.
- چراغ راهنمایی و تابلو فقط در تقاطع‌هایی که traffic controller آن را پشتیبانی می‌کند.
- drain/manhole و utility cover به صورت ماژول کم‌هزینه.
- اتصال seam-free میان قطعات؛ UV و تکرار بافت باید از pattern واضح جلوگیری کند.

### 2.3 تقاطع
هر تقاطع باید turn connectivity، pedestrian crossing، priority، signal state و blockage را از graph بگیرد. مدل بصری باید ورودی/خروجی‌های واقعی را نشان دهد. چراغ سبز تزئینی بدون کنترل state ممنوع است. خطوط توقف، zebra crossing و lane arrows با قواعد حرکتی سازگار باشند.

## 3. هویت محله‌ها
### 3.1 محله مسکونی
- مقیاس انسانی، درختان خیابانی، پیاده‌رو، نور گرم پنجره‌ها و فضای نیمه‌عمومی.
- props: نیمکت، سطل، تابلو خیابان، دوچرخه یا خودروی پارک‌شده.
- تراکم propها نباید راه پیاده، ورودی خانه یا مسیر خودرو را مسدود کند.
- نشانه‌های زندگی مثل روشنایی و عبور ساکن باید به occupancy/time/agent sample معتبر متصل باشند یا صریحاً decorative باشند.

### 3.2 محله تجاری
- ویترین و تابلوهای اختصاصی و غیرواقعی، سایبان، ورودی بارگیری محدود و فضای توقف کوتاه.
- تفاوت retail و workshop از silhouette و frontage قابل تشخیص باشد.
- تابلوها باید از localization و brand-neutral content استفاده کنند.
- تجمع مردم یا صف فقط در صورت وجود service/visit event معتبر؛ در غیر این صورت crowd تزئینی محدود و غیرگمراه‌کننده.

### 3.3 محله صنعتی
- محوطه‌های خدماتی، fence، loading bay، سطوح مقاوم و علائم ایمنی.
- مسیر کامیون، شعاع گردش و فضای انتظار باید با freight access envelope هماهنگ باشد.
- دود، بخار، صدای ماشین‌آلات و نور هشدار فقط به process state و مجوز محیطی وصل باشند.
- props نباید دید راننده یا مسیر emergency را مسدود کنند.

### 3.4 ناحیه civic و خدماتی
- فضای ورودی خوانا، plaza یا setback محدود، مبلمان و روشنایی مناسب.
- رنگ و معماری از خانواده عمومی شهر پیروی کند اما نقش خدماتی از آیکون و silhouette مشخص باشد.
- پرچم/نشان دولتی واقعی و لوگوی سازمان‌های حقیقی استفاده نشود.

### 3.5 لبه طبیعی و فضای باز
- پوشش گیاهی، آبراه و توپوگرافی از terrain data پیروی کند.
- درخت و سنگ به‌صورت clusterهای کنترل‌شده چیده شوند؛ تکرار الگوی واضح در نمای دور دیده نشود.
- آب و بازتاب‌ها در کیفیت پایین ساده‌سازی شوند؛ مسیر آب یا آلودگی باید از simulation معتبر بیاید.

## 4. کتابخانه اجزای خیابانی (Street Furniture)
| خانواده | اجزا | ضابطه بصری | ضابطه فنی |
|---|---|---|---|
| Lighting | چراغ خیابان، چراغ پیاده‌رو | silhouette متمایز و نور کنترل‌شده | نور واقعی فقط در محدوده لازم؛ در Far به impostor/baked |
| Signage | تابلو نام خیابان، جهت، محدودیت | متن localization-ready و خوانا | atlas یا text mesh کم‌هزینه |
| Safety | bollard، barrier، crossing beacon | رنگ هشدار با کنتراست کافی | collision فقط اگر مانع واقعی است |
| Seating | نیمکت، میز، ایستگاه انتظار | مقیاس انسانی | collider غیرضروری نداشته باشد |
| Waste | سطل، مخزن، recycling bin | خانواده رنگی منسجم | فقط depot/waste system عملیاتی اثر دارد |
| Greenery | درخت، بوته، planter | گونه/فرم متنوع بر اساس ناحیه | LOD و impostor، wind محدود |
| Utility | hydrant، cabinet، manhole | placement منطقی | interaction فقط در صورت gameplay |
| Mobility | bike rack، bus stop placeholder | فقط در صورت پشتیبانی حمل‌ونقل | از ایجاد قابلیت غیرموجود خودداری شود |

Decorative propها نباید ناخواسته collider، service radius، traffic modifier، land value modifier یا resource modifier داشته باشند.

## 5. خودروها و پارکینگ در بافت شهری
- خودروهای متحرک باید از trip/job record و vehicle fleet system پیروی کنند.
- خودروی پارک‌شده می‌تواند decorative باشد، اما باید با جای پارک مجاز، footprint و عدم انسداد مسیر سازگار باشد.
- نوع وسیله، رنگ و variation نباید برند واقعی یا طرح دارای حق نشر را کپی کند.
- انیمیشن چرخ، چراغ ترمز، راهنما و توقف با velocity/route/traffic state هماهنگ باشد.
- خودرو در تقاطع، dock و مسیر emergency teleport یا عبور از ساختمان نداشته باشد.
- Far traffic به صورت aggregate flow یا impostor نمایش داده شود؛ Near agent فقط در محدوده توجه و بودجه دستگاه.
- تعداد agentها، نرخ spawn و فاصله LOD پس از profiling TBD می‌مانند.

## 6. عابران و زندگی پیاده
- عابر واقعی فقط در صورت وجود pedestrian trip یا مقصد معتبر در simulation حرکت کند.
- crowdهای نمایشی نباید تراکم جمعیت، رضایت یا کیفیت خدمات را جعل کنند.
- مسیر پیاده از road/sidewalk graph یا مسیرهای مجاز استخراج شود.
- عبور از خیابان فقط در crossing مجاز و با signal/priority معتبر.
- در صورت عدم پیاده‌سازی pedestrian simulation، از تعداد اندک idle decorative agents استفاده شود و در UI هیچ آمار جمعیتی از آن‌ها استخراج نشود.
- تنوع ظاهری با modular outfit/mesh و paletteهای عمومی؛ از stereotyping و نشانه‌گذاری حساس پرهیز شود.

## 7. نورپردازی و چرخه زمانی
### Day
نور خوانا و سایه‌های کنترل‌شده؛ رنگ متریال‌ها در نور مستقیم و سایه قابل تشخیص بماند.

### Golden hour / Sunset
تغییر تدریجی جهت/رنگ نور و روشن شدن چراغ‌ها بر اساس time-of-day. تغییرات نباید رنگ هشدار و کنتراست UI را مخدوش کند.

### Night
- پنجره‌های روشن فقط بر اساس occupancy یا یک الگوی decorative صریح.
- چراغ خیابان با محدوده نور محدود و نسخه کم‌هزینه در فاصله.
- تابلوهای درخشان با bloom محدود.
- چراغ خودروها از وضعیت چراغ/وسیله پیروی کنند.
- نور شب نباید اطلاعات operational تازه و نادرست بسازد.

چرخه زمان، سرعت گذر زمان و اثر آن بر simulation هنوز به تصمیم مستقل نیاز دارد؛ در این سند مقدار قطعی تعریف نمی‌شود.

## 8. آب‌وهوا و تغییرات محیطی
آب‌وهوا در نسخه اول فقط زمانی وارد شود که اثر simulation و هزینه موبایل آن مشخص باشد. مه، باران، برف، خیس‌شدن آسفالت و باد نباید صرفاً برای نمایش، ادعای تغییر وضعیت منابع یا ترافیک کنند. Weather visual-only باید برچسب طراحی داشته باشد و از تغییر gameplay منع شود. حوادث شدید و بلایای طبیعی خارج از دامنه فعلی‌اند مگر با تصمیم مستقل.

## 9. دوربین، خوانایی و composition
- نمای اصلی شهر باید ساختمان، راه و فضای سبز را بدون پوشاندن رابط نشان دهد.
- در نمای Far: silhouette بلوک‌ها، شبکه راه و zoning.
- در Mid: ورودی‌ها، درختان، خودروها، مبلمان شاخص و roofline.
- در Near: تابلو، چراغ، مصالح و تجهیزات.
- props مهم در footprint/access overlay نباید با hit target ساختمان اشتباه شوند.
- occlusion، انتخاب ساختمان و highlight باید از selection proxy پایدار استفاده کنند.
- safe area و HUD موبایل بخشی از composition هستند؛ قاب مرجع بدون HUD کافی نیست.

## 10. Asset pipeline و پلاگین‌های تخصصی
### مراحل اجباری
1. Research/reference board با source URL، creator، تاریخ، مجوز و hash در صورت دانلود.
2. Moodboard و silhouette exploration.
3. Blockout در Blender با grid و access envelope.
4. مدل‌سازی modular، UV، baking و material setup.
5. LOD/impostor و collider/selection proxy.
6. Import به Cocos Creator و ساخت prefabهای قابل استفاده.
7. تنظیمات کیفیت و profiling روی گوشی واقعی.
8. ثبت نتیجه art QA، technical QA، license QA و simulation-to-visual QA.

### نقش ابزارها و پلاگین‌ها
- Blender: blockout، modeling، UV، LOD، بررسی topology و batch validation.
- ابزارهای texture/material: ساخت/اصلاح PBR و کنترل channelها.
- ابزارهای concept/reference: تولید exploration و moodboard؛ خروجی آن‌ها reference است نه asset نهایی.
- ابزارهای asset inspection: بررسی مجوز، archive contents، metadata و checksum.
- Cocos Creator: prefab، material/shader، LOD integration، scene validation و device build.

ابزار یا پلاگین نباید صرفاً به‌عنوان نام در سند ثبت شود؛ باید خروجی قابل ویرایش، فایل منبع، مجوز و نتیجه تست ارائه کند. استفاده از تصویر تولیدشده به‌جای mesh/prefab ممنوع است.

## 11. استاندارد نام‌گذاری و بسته‌بندی
الگوی پیشنهادی:
- ENV_ROAD_LOCAL_*
- ENV_STREETLIGHT_*
- ENV_TREE_*
- ENV_SIGN_*
- ENV_PARKING_*
- ENV_VEHICLE_*
- ENV_PEDESTRIAN_*

نام نهایی باید در manifest و asset registry یکتا باشد. هر بسته شامل source، export، texture، material، LOD، collider، prefab، preview، license، provenance و version است. نام‌های عمومی مانند final2، new_asset یا texture1 قابل پذیرش نیستند.

## 12. گیت‌های پذیرش محیط شهری
| Gate | معیار قبولی | مدرک |
|---|---|---|
| Spatial fit | prop/vehicle با grid، frontage و clearance سازگار است | overlay screenshot |
| Visual identity | محله از Far/Mid قابل تشخیص است | camera captures |
| Seam quality | قطعات راه بدون شکاف و UV تکراری آزاردهنده | continuous road capture |
| State truth | VFX/traffic/light به state واقعی متصل است | event log + capture |
| Mobile readability | خطوط و props در گوشی قابل تشخیص‌اند | device screenshot |
| Performance | frame time/memory/thermal مطابق target مصوب | profiler report |
| Accessibility | کنتراست و اندازه تعامل قابل قبول | audit |
| License | مجوز همان فایل/بسته مستند است | license evidence |
| Prefab integrity | references، materials و colliders سالم‌اند | automated validation |
| Save/load | state و placement بعد از reload پایدار است | test evidence |

## 13. تصمیم‌های باز (TBD)
- ابعاد و مقاطع دقیق road classes؛
- projection، scale و camera framing نهایی؛
- climate، species و palette ناحیه؛
- چرخه زمان و اثر آن بر simulation؛
- pedestrian simulation scope؛
- parking rules و availability؛
- weather scope؛
- تعداد و کیفیت LODها، texture budgets، draw calls و frame-time budgets؛
- device floor و تنظیمات Low/Medium/High؛
- assetهای دقیق و مجوز فایل‌به‌فایل.

تا زمان blockout و آزمون دستگاه واقعی، اعداد بالا عمداً TBD هستند.


## Essential services visual integration and asset governance
Utility/service overlays and physical asset families are specified in [Capital Region Essential City Services & Utilities Atlas](CAPITAL_REGION_ESSENTIAL_CITY_SERVICES_AND_UTILITIES_ATLAS.md). Electricity, water, sewer, waste, emergency, healthcare and maintenance layers must be opt-in diagnostic views with legends, text/pattern cues, source tick and explicit unknown states. Surface props, pipes, hydrants, smoke, sirens, emergency lights and crew animations must reflect authoritative simulation state or be clearly decorative-only. Professional editable mesh/material/UV/LOD/prefab outputs, specialist tool/plugin pipeline, per-file commercial license evidence, provenance and hashes are mandatory before asset acceptance. No new asset or service is approved by this reference.


## Tourism public-realm and visual integration

The tourism destination model is specified in [Capital Region Tourism, Visitors, Attractions & Hospitality](CAPITAL_REGION_TOURISM_VISITORS_ATTRACTIONS_AND_HOSPITALITY_SYSTEM_SPEC.md). Parks, landmarks, signage, visitor characters, hotel exteriors and event staging must have clear decorative versus operational roles. A decorative asset cannot generate visitors, demand or revenue. Runtime visual assets require editable specialist-tool/plugin deliverables, mobile optimization, explicit commercial-use license, provenance and content hash. This reference approves no new asset or attraction ID.


## Day/night, seasons and weather visual integration

The environmental presentation and causal-state boundary is specified in [Capital Region Weather, Seasons, Day/Night & Environmental Impacts](CAPITAL_REGION_WEATHER_SEASONS_DAY_NIGHT_AND_ENVIRONMENTAL_IMPACTS_SPEC.md). Sky, lighting, rain, snow, fog, wet surfaces, foliage and seasonal variants must reflect authoritative state or be explicitly decorative-only. Professional editable assets/shaders via specialist tools/plugins, mobile optimization, explicit commercial license, provenance and hashes remain mandatory. Visual changes cannot grant unmodeled gameplay or ecological scores.
