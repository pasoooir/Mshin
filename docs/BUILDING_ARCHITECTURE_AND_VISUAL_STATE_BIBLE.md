# کتاب طراحی معماری، خانواده‌ها و چرخه بصری ساختمان‌ها — Mshin

- موتور: Cocos Creator 3.8.6
- پلتفرم: موبایل Android/iOS، با اولویت طراحی و آزمون روی موبایل
- سبک هدف: stylized-realistic؛ معماری خوانا، رنگ و نور کنترل‌شده، جزئیات نزدیک با هزینه معقول
- وضعیت: سند طراحی و قرارداد تولید؛ مدل‌ها و prefabهای production هنوز تولید یا تأیید نشده‌اند.
- وابستگی: CITY_GAME_DESIGN_MASTER.md، CAPITAL_REGION_V1_CONTENT_CATALOG.md، BUILDING_PROGRESSION_ACCEPTANCE_MATRIX.md، VISUAL_DEVELOPMENT_3D_ASSET_BIBLE.md، INITIAL_FREE_ASSET_REGISTRY.md

## 1. هدف و اصول غیرقابل مذاکره

1. هر ساختمان باید از silhouette، footprint، رنگ غالب، فرم سقف، ریتم پنجره و جزئیات شاخص خود قابل شناسایی باشد.
2. ارتقا باید تغییر معماری قابل مشاهده ایجاد کند؛ افزایش scale یا تغییر رنگ به‌تنهایی ارتقا نیست.
3. هر نشانه بصری وضعیت باید به state معتبر simulation متصل باشد. ظاهر نمی‌تواند ظرفیت، تولید، جمعیت یا سلامت جعلی القا کند.
4. Decoration از ساختمان عملیاتی تفکیک شود؛ تزئینات هیچ اثر پنهان بر اقتصاد/خدمات نداشته باشند.
5. تمام familyها از grid، pivot، naming، material conventions و قرارداد LOD مشترک پیروی کنند.
6. موبایل محدودیت اصلی است؛ کیفیت هنری با silhouette، ترکیب‌بندی، texture هوشمند و variation به دست آید، نه صرفاً polygon بیشتر.
7. Asset رایگان فقط پس از بررسی مجوز دقیق همان بسته/فایل و provenance قابل استفاده در release است.
8. خروجی خام generator، marketplace یا پلاگین مستقیماً production-ready محسوب نمی‌شود؛ Art/Tech QA لازم است.

## 2. نظام طبقه‌بندی ساختمان

### 2.1 کاربری‌های اصلی
- Residential: خانه، آپارتمان، مجتمع مسکونی.
- Commercial: فروشگاه محلی، بازار، مرکز خرید، خدمات روزمره.
- Industrial: کارگاه، کارخانه، انبار، مرکز پردازش.
- Civic/Public: شهرداری، خدمات شهری، آموزش، سلامت، ایمنی و امداد.
- Infrastructure: نیرو، آب، فاضلاب، پسماند، مخابرات و حمل‌ونقل.
- Recreation: پارک، میدان، فضای ورزشی و فرهنگی.
- Landmark: ساختمان شاخص با هویت معماری منحصربه‌فرد.

هر definition باید buildingId پایدار، familyId، category، operationalClass، footprintDefinition، tierDefinitions، assetRefs، serviceLinks، unlockRules و localizationKeys داشته باشد. شناسه‌ها پس از انتشار تغییرناپذیرند؛ rename فقط در display name انجام شود.

### 2.2 دسته عملیاتی
- Operational: در simulation ورودی/خروجی، ظرفیت، خدمت یا مصرف دارد.
- Decorative: فقط ظاهر و محیط؛ بدون اثر gameplay.
- Hybrid: تنها با تعریف صریح زیرسیستم عملیاتی و آزمون؛ پیش‌فرض ممنوع.
- Landmark: می‌تواند عملیاتی یا صرفاً تزئینی باشد؛ نام Landmark به‌تنهایی رفتار اقتصادی ایجاد نمی‌کند.

## 3. قرارداد خانواده معماری

برای هر family یک برگه طراحی (Family Sheet) شامل این موارد الزامی است:
- هدف احساسی و شخصیت معماری؛
- silhouette از نمای بالا/سه‌ربع و دور؛
- محدوده footprint و فضای خدماتی؛
- فرم roofline و خط آسمان؛
- نسبت تقریبی بازشوها و سطوح بسته؛
- palette پایه و accent؛
- مصالح اصلی و پاسخ نوری؛
- زبان پنجره، در، ورودی، سایبان و بالکن؛
- عناصر هویت‌بخش از فاصله دور؛
- قطعات مشترک/قابل‌استفاده مجدد؛
- variationهای مجاز و موارد ممنوع؛
- رفتار در Day/Golden Hour/Night؛
- تغییرات هر tier؛
- LOD، collider، occlusion و performance notes؛
- فهرست Assetها و مجوز آن‌ها.

## 4. طراحی خانواده‌ها

### 4.1 مسکونی کم‌تراکم
**هویت:** مقیاس انسانی، سقف مشخص، ورودی قابل مشاهده، حیاط یا فضای سبز کوچک.
- Tier آغازین: حجم ساده و جمع‌وجور، ورودی روشن، سقف با silhouette واضح، پنجره‌های کم‌شمار اما خوانا.
- Tier میانی: تغییر فرم یا امتداد سقف، ایوان/بالکن، مصالح نما متنوع‌تر، محوطه مرتب‌تر.
- Tier پیشرفته: حجم معماری پیچیده‌تر، فضای نیمه‌باز، پنجره‌بندی غنی‌تر، تجهیزات rooftop محدود.
- تفاوت tier: تغییر roofline، massing، تعداد/چیدمان بازشوها و محوطه؛ نه فقط افزودن تزئینات.
- نشانه وضعیت: نور داخلی محدود در ساعات شب؛ تعمیرات با scaffold کوتاه‌مدت فقط در حالت تعمیر.
- موارد ممنوع: نور پنجره تصادفی و بی‌ارتباط با وضعیت occupancy، دود یا VFX بی‌دلیل.

### 4.2 مسکونی پرتراکم
**هویت:** خوانایی عمودی و ریتم طبقات، تراس و ورودی مجتمع.
- Tier آغازین: بلوک آپارتمانی کوتاه با طبقات قابل شمارش و ورودی اصلی.
- Tier میانی: تغییر ترکیب حجم، بالکن‌های متنوع، podium یا فضای ورودی.
- Tier پیشرفته: برج/بلوک بلندتر یا چندبخشی با crown و roof equipment متمایز.
- از افزایش بی‌رویه تعداد پنجره‌های واقعی پرهیز؛ از facade atlas، instancing یا جزئیات baked استفاده شود.
- انتخاب ساختمان در نمای نزدیک باید به ورودی یا base marker دسترسی داشته باشد؛ ارتفاع نباید لمس را دشوار کند.

### 4.3 تجاری محلی
**هویت:** ویترین، تابلو، ورودی رو به خیابان، سایبان و نور قابل تشخیص.
- Tier آغازین: مغازه مستقل با ویترین واضح.
- Tier میانی: واحدهای چندگانه، سایبان و signage بیشتر، نمای طبقه بالا.
- Tier پیشرفته: بنای تجاری گوشه‌ای/چندطبقه یا بازار کوچک با ورودی شاخص.
- تابلوها از متن‌های واقعی برندها و علائم تجاری حفاظت‌شده استفاده نکنند؛ نام‌ها از localization keys و فونت مجاز بیایند.
- شب: نور ویترین وابسته به schedule/status تعریف‌شده؛ روشنایی نمایشی نباید فروش را القا کند.

### 4.4 مرکز خرید و بازار
**هویت:** حجم افقی بزرگ، ورودی‌های متعدد، سقف/سایبان و فضای عمومی پیرامونی.
- تفاوت tier از تغییر ورودی، تقسیم‌بندی حجم، atrium/roofline و کیفیت محوطه مشخص شود.
- ورودی‌ها باید در نقشه از خیابان قابل دسترسی و از ساختمان‌های همسایه قابل تفکیک باشند.
- ازدحام جمعیت در benchmark صرفاً بصری و Sample است، مگر سیستم جمعیت آن را تأیید کند.

### 4.5 صنعتی و تولیدی
**هویت:** حجم عملکردی، سالن تولید، سقف صنعتی، دودکش/تهویه، بارانداز و دسترسی حمل بار.
- Tier آغازین: سالن تولید ساده با درگاه بارگیری و تجهیزات حداقلی.
- Tier میانی: توسعه سالن، بخش اداری/کنترل، مخزن یا خطوط فرعی.
- Tier پیشرفته: چند حجم متصل، تجهیزات فرایندی و مسیرهای لجستیک خواناتر.
- انیمیشن ماشین‌آلات فقط هنگام state تولید فعال؛ در توقف، حرکت conveyor/چراغ وضعیت باید متوقف یا به idle واقعی تبدیل شود.
- دود، بخار، شعله و آلودگی به process definition و وضعیت معتبر وابسته‌اند؛ دود تزئینی دائمی ممنوع.
- بارانداز و درهای بارگیری باید با route و دسترسی simulation همخوان باشند؛ مدل نباید ورودی مسدود داشته باشد.

### 4.6 انبار و لجستیک
**هویت:** حجم ساده و بزرگ، دهانه‌های بارگیری، dock، محوطه گردش و قفسه/مخزن در صورت مشاهده.
- ارتقا با افزایش سازمان‌یافتگی dockها، توسعه حجم و بهبود تجهیزات دیده شود.
- کامیون/وسیله نقلیه فقط در صورت وجود trip/dispatch معتبر نمایش داده شود؛ benchmark می‌تواند loop نمایشی برچسب‌خورده داشته باشد.
- موجودی در HUD یا نمای داخلی نباید از مقدار ذخیره واقعی جدا باشد.

### 4.7 خدمات شهری و مدنی
**هویت:** فرم عمومی و قابل اعتماد، ورودی واضح، نشانه کاربری و فضای دسترسی.
- درمانگاه/بیمارستان: ورودی امداد و نشانه‌های پزشکی عمومی و غیرمقلد برند.
- آتش‌نشانی: درگاه خروج خودرو، برج/نشانه شاخص، محوطه مانور.
- پلیس/امنیت: ورودی عمومی و بخش عملیاتی؛ بدون استفاده از نشان رسمی واقعی کشورها.
- مدرسه/آموزش: ورودی دانش‌آموز، حیاط یا فضای جمعی، پنجره‌های قابل خواندن.
- شهرداری: civic plaza یا ورودی مرکزی؛ به‌عنوان landmark محله قابل شناسایی.
- ارتقا باید ظرفیت/پوشش خدمات را فقط در definition simulation تغییر دهد؛ ظاهر به‌تنهایی آن را تغییر نمی‌دهد.

### 4.8 زیرساخت و تأسیسات
**هویت:** فرم صنعتی/مهندسی با اجزای قابل فهم از دور.
- نیرو: ژنراتور/ترانس/پست یا واحد تولید مطابق نوع واقعی.
- آب: مخزن، پمپ‌خانه و مسیر اتصال.
- فاضلاب: مخازن/حوضچه‌ها و خطوط فرایندی.
- پسماند: ورودی جمع‌آوری، بخش پردازش و محل خروج.
- مخابرات: دکل/آنتن و ساختمان کنترل؛ جزئیات حساس/واقع‌نما بیش از نیاز بازی لازم نیست.
- اجزای hazard باید با فاصله ایمنی و overlay خدماتی قابل تشخیص باشند.
- VFX محیطی تنها در صورت تعریف فرایند و state معتبر.

### 4.9 پارک و تفریح
**هویت:** فضای باز، پوشش گیاهی لایه‌ای، مسیر پیاده و landmark کوچک.
- tierها از تنوع canopy، مسیر، مبلمان و امکانات قابل مشاهده متمایز شوند.
- Decorationهای پارک operational نیستند مگر definition جداگانه و آزمون‌شده داشته باشند.
- از ترکیب چند asset با silhouette و ارتفاع متفاوت استفاده شود تا تکرار الگو آشکار نباشد.
- انیمیشن گیاهان کم‌دامنه و گروهی باشد؛ wind update مستقل برای هر برگ ممنوع.

### 4.10 Landmark
**هویت:** silhouette یکتا، کانون بصری skyline و palette محدود.
- در یک منطقه نباید landmarkها با هم رقابت بصری کنند.
- landmark باید از Far قابل شناسایی و در Mid/Near دارای جزئیات معنادار باشد.
- نام/معماری/نشان از آثار حفاظت‌شده یا کپی مستقیم نمونه‌های مشهور اجتناب کند.
- اگر اثر gameplay دارد، اثر آن در simulation definition و acceptance test ثبت شود.

## 5. قرارداد Tier و ارتقا

Tierها برای هر building تعریف می‌شوند؛ تعداد tier و نام آن‌ها global hardcode نشود. هر tier شامل:
- tierId، displayNameKey، unlockRequirements؛
- visualAssetSet، footprint، heightEnvelope؛
- functionalDelta، economicDelta، serviceDelta؛
- constructionDuration، requiredMaterials، laborRequirements؛
- downtimePolicy، maintenanceProfile؛
- demolitionAndRefundPolicy؛
- saveMigrationVersion.

تغییر بصری هر tier باید حداقل از چند بُعد مستقل انتخاب شود: massing/roofline، facade rhythm، openings، materials، equipment، landscaping، lighting. تعداد و شدت تغییرها بعد از art review تعیین می‌شود؛ افزایش عملکرد باید از داده‌های simulation و تست اقتصاد بیاید، نه از ارزیابی زیبایی.

## 6. ساختمان به‌مثابه state machine بصری

هر ساختمان یک state gameplay و یک presentation mapping دارد. mapping صرفاً نمایش state است و authority ندارد.

| وضعیت simulation | نمایش مجاز | نمایش ممنوع |
|---|---|---|
| Planned/Preview | ghost/outline، footprint و خطای جانمایی | نمای کامل فعال یا ادعای تولید |
| UnderConstruction | scaffold، مصالح، progress UI معتبر | ساختمان تکمیل‌شده |
| Operational | وضعیت عادی، فعالیت متناسب با schedule | دود/کارگر/وسیله بی‌دلیل |
| Idle | چراغ/ماشین‌آلات idle و نشانه کم‌تحرک | انیمیشن تولید فعال |
| InputShortage | علامت کمبود و توقف/کاهش فرایند مطابق state | نمایش تولید کامل |
| OutputBlocked | انبار/خروجی مسدود در UI و فعالیت متناسب | بارگیری موفق جعلی |
| UtilityDisconnected | خاموشی/نشانه اتصال قطع‌شده متناسب با نوع خدمت | جلوه فعالیت کامل |
| Damaged | آسیب قابل تشخیص در محدوده شدت | تخریب شدید بدون state |
| Maintenance | داربست/تیم تعمیر/ماشین متوقف طبق سیاست | تولید عادی در downtime کامل |
| Disabled | نشانه توقف واضح و عدم فعالیت | چراغ و VFX فعال تولید |
| Abandoned | نشانه فرسودگی تدریجی و کنترل‌شده | collapse ناگهانی بدون event |

State transition باید از simulation event بیاید؛ client animation فقط نمایشگر است. event تکراری نباید انیمیشن، اعلان یا تراکنش را دوبار اعمال کند.

## 7. تفکیک visual state و operational state

- Operational state منبع حقیقت server/simulation است.
- Visual state از operational state مشتق می‌شود و قابل ذخیره‌سازی مستقل به‌عنوان حقیقت gameplay نیست.
- اگر asset یا animation بارگذاری نشد، simulation باید سالم بماند و fallback visual استفاده شود.
- VFX نباید منابع، جمعیت، رضایت یا بهره‌وری را تغییر دهد.
- نشانگر وضعیت باید علاوه بر رنگ، شکل/آیکون/متن داشته باشد تا برای کوررنگی قابل تشخیص باشد.
- در حالت reduced motion، چراغ چشمک‌زن و حرکت‌های تکراری به حالت ثابت/آرام تبدیل شوند.

## 8. استاندارد مدل‌سازی و بسته تحویل

هر building asset package شامل:
1. فایل منبع قابل ویرایش (در صورت وجود مجوز و ابزار).
2. مدل runtime با transform و scale استاندارد.
3. prefab اصلی و variantهای tier.
4. meshهای LOD و معیار switch ثبت‌شده.
5. colliderهای ساده و جدا از mesh تزئینی.
6. materialها و textureهای بهینه.
7. socketها: door, loadingDock, servicePort, effectAnchor, selectionAnchor, cameraFocus.
8. footprint و bounds metadata.
9. preview render و thumbnail موبایل.
10. manifest provenance و SHA-256.
11. تست import و prefab validation.
12. نسخه، changelog و وابستگی‌ها.

### 8.1 قرارداد محور و transform
- محور up و forward مطابق قرارداد پروژه/موتور و در import pipeline یکسان باشد.
- pivot اصلی در نقطه منطقی پایه ساختمان باشد؛ pivot نباید با مرکز هندسی تصادفی تعیین شود.
- scale و unit conversion در یک مرحله مشخص انجام شود و در runtime اصلاح دستی تکراری نداشته باشد.
- نام nodeها، materialها و socketها پایدار و قابل جست‌وجو باشد.
- collider gameplay از collider لمس/انتخاب و mesh نمایشی جدا باشد.

### 8.2 Naming convention
الگوی پیشنهادی: B_<FAMILY>_<ROLE>_T<TIER>_<VARIANT>_<LOD>.
نمونه: B_RES_LOW_HOUSE_T02_A_LOD1.
برای prefab: PF_B_RES_LOW_HOUSE_T02_A.
برای material: M_BLDG_BRICK_WARM_01.
برای texture: T_BLDG_BRICK_WARM_01_BC و suffixهای استاندارد Normal/Roughness/Mask.
شناسه gameplay مانند res.low.house.01 از نام فایل هنری جدا بماند.

## 9. Modular construction و variation

- قطعات modular فقط وقتی استفاده شوند که اتصال seam، مقیاس، UV و نور قابل کنترل باشد.
- kitهای نما شامل wall, corner, window, door, roof edge, roof module, balcony, signage, trim و ground contact هستند.
- از combinatorial explosion جلوگیری شود؛ variationها در registry صریح و محدود تعریف شوند.
- random seed باید برای هر instance پایدار باشد تا ظاهر پس از reload بی‌دلیل عوض نشود.
- variation تصادفی نباید collision، doorway، service socket یا footprint را تغییر دهد.
- اجزای gameplay-critical نباید صرفاً از ترکیب آزاد ماژول‌ها ساخته شوند مگر validator تمام اتصال‌ها را بررسی کند.

## 10. مصالح و palette

| ماده | ویژگی بصری | ملاحظات موبایل |
|---|---|---|
| آجر | rough، variation کم‌رنگ | tiling و normal کنترل‌شده |
| بتن | roughness بالا و لکه محدود | جزئیات بزرگ‌تر از نویز ریز |
| شیشه | بازتاب/شفافیت محدود | از شفافیت تمام‌نما و overdraw اجتناب |
| فلز | highlight کنترل‌شده | metallic فقط در بخش واقعی |
| آسفالت | سطح تیره و خوانا | خط‌کشی جدا و واضح |
| چوب | variation گرم و کم‌دامنه | texture کوچک و تکرارپذیر |
| پوشش گیاهی | چند طیف سبز و silhouette متفاوت | atlas/instancing و LOD |

رنگ family باید از palette system بیاید. رنگ وضعیت نباید با رنگ زیبایی‌شناختی ساختمان اشتباه شود. از استفاده بیش از حد emissive، bloom، reflection و normal detail اجتناب شود.

## 11. نما، سقف و جزئیات قابل مشاهده

- Roofline در Far باید فرم family را تعریف کند.
- HVAC، پنل خورشیدی، مخزن، آنتن و تجهیزات سقفی فقط در صورت تناسب نقش و tier اضافه شوند.
- پنجره‌ها باید ریتم داشته باشند؛ از تکرار بی‌منطق و نور تصادفی اجتناب شود.
- درها و loading dockها باید با path/access simulation منطبق باشند.
- تابلوها باید متن بومی‌سازی‌شده و فونت دارای مجوز داشته باشند؛ متن داخل texture تا حد ممکن ممنوع.
- جزئیات کوچک در Far حذف شوند تا aliasing و visual noise کاهش یابد.
- آبجکت‌های تزئینی که از camera zoom قابل مشاهده نیستند حذف شوند.

## 12. نور، روز/شب و آب‌وهوا

- روز: مصالح و فرم ساختمان در نور خنثی قابل خواندن باشند.
- غروب: رنگ گرم کنترل‌شده؛ UI و نشانه‌های state ثابت و خوانا بمانند.
- شب: emissive پنجره‌ها/تابلوها محدود و وابسته به occupancy/schedule مجاز باشد.
- باران/برف/گردوغبار فقط در صورت پشتیبانی climate system؛ فعلاً می‌تواند به‌عنوان preset بصری آزمایش شود، نه gameplay.
- اثر آب‌وهوا روی production، traffic یا service تا زمان وجود simulation logic ممنوع است.
- نورپردازی baked یا ساده‌شده برای props ثابت ترجیح دارد؛ dynamic shadow فقط برای عناصر لازم.

## 13. VFX، انیمیشن و صدای ساختمان

| خانواده | نمونه انیمیشن | شرط فعال‌شدن |
|---|---|---|
| مسکونی | نور محدود پنجره، حرکت آرام محیط | occupancy/schedule معتبر |
| تجاری | نور ویترین، باز/بسته شدن کرکره | opening schedule معتبر |
| صنعتی | conveyor، indicator، بخار/دود محدود | production process فعال |
| انبار | در dock، چراغ بارگیری | dispatch واقعی یا sample label |
| خدمات امدادی | beacon/درگاه خودرو | incident/dispatch معتبر |
| زیرساخت | fan/indicator/pump | utility process فعال |
| پارک | حرکت آرام foliage/آب | محیط فعال و quality tier مناسب |

- animation state-driven و قابل قطع باشد.
- VFX pooling و سقف emitterها لازم است؛ مقدار سقف پس از profiling تعیین شود.
- صدا spatial و لایه‌بندی‌شده باشد؛ mute و volume مستقل رعایت شود.
- هر صدا و VFX خارجی provenance و مجوز مستقل دارد.
- انیمیشن تزئینی نباید مسیر خودرو، ظرفیت تولید یا زمان عملیات را تغییر دهد.

## 14. LOD، occlusion و سطح جزئیات

LODها بر اساس silhouette و screen-space contribution طراحی می‌شوند، نه صرفاً کاهش polygon درصدی.
- LOD0: نزدیک؛ جزئیات کلیدی و اجزای قابل مشاهده.
- LOD1: میانه؛ حفظ پنجره، roofline، ورودی و هویت family.
- LOD2: دور؛ حجم اصلی، palette و نشانه کاربری.
- Billboard/impostor فقط برای عناصر دور و ثابت، با تست زاویه دوربین.
- collider مستقل از LOD visual باشد.
- Hysteresis برای جلوگیری از رفت‌وبرگشت سریع LOD لازم است.
- occlusion و culling باید از render کردن جزئیات پشت ساختمان‌های بلند جلوگیری کنند.
- آستانه distance، screen size و polygon budget تا profiling واقعی TBD است.

## 15. Footprint، جانمایی و تعامل

- footprint منطقی و access envelope از mesh render جدا هستند.
- preview placement باید valid/invalid/blocked states را با رنگ + pattern + متن نمایش دهد.
- selection outline از silhouette و base marker استفاده کند؛ outline نباید با نور محیط ناپدید شود.
- ساختمان بلند باید از بالا قابل لمس باشد؛ انتخاب از طریق base proxy یا hit region پایدار.
- panel موبایل باید اطلاعات کلیدی را بدون پوشاندن نقطه جانمایی نمایش دهد.
- rotate/move/upgrade/demolish دستورات صریح و قابل لغو پیش از commit باشند.
- demolition پیامدهای اتصال خدمات، مسیر، ظرفیت و بازپرداخت را پیش‌نمایش کند.

## 16. Thumbnail، icon و preview

برای هر building definition:
- آیکون دسته‌بندی ساده و قابل تشخیص در اندازه کوچک؛
- thumbnail ایزومتریک با پس‌زمینه خنثی؛
- preview tierها در زاویه، نور و مقیاس یکسان؛
- silhouette sheet برای مقایسه سریع خانواده؛
- state sheet برای Operational/Idle/Disabled/Damaged/Maintenance؛
- مقایسه قبل/بعد ارتقا؛
- تصویر نمای نزدیک از مصالح و ورودی؛
- تصویر موبایل واقعی با HUD و safe area.

از renderهای تبلیغاتی غیرواقعی که درون بازی قابل دستیابی نیستند به‌عنوان مرجع نهایی استفاده نشود.

## 17. Accessibility و خوانایی

- رنگ تنها حامل معنا نباشد.
- متن پنل‌ها قابل بزرگ‌نمایی و ترجمه باشد.
- contrast ساختمان منتخب و outline با پس‌زمینه سنجیده شود.
- motion intensity قابل کاهش/خاموش‌کردن باشد.
- صدای هشدار با نشان بصری همراه باشد.
- نشانه‌ها در صفحه کوچک و نور روز قابل تشخیص باشند.
- پیام خطا به اقدام اصلاحی قابل فهم منتهی شود.

## 18. تست‌های اجباری

### Art QA
- silhouette در Far/Mid/Near؛
- family recognition در grayscale و paletteهای مختلف؛
- tier differentiation؛
- material consistency؛
- day/night readability؛
- clipping، z-fighting، seams، UV stretching و texture shimmer؛
- تکرارپذیری variation و عدم overlap؛
- thumbnail و icon legibility.

### Technical QA
- import/export در pipeline؛
- prefab reference integrity؛
- missing texture/material detection؛
- collider و footprint؛
- LOD transition و culling؛
- memory/draw calls/triangles/frame time؛
- load/unload و fallback؛
- Android build و سپس iOS build؛
- device interruption و بازگشت.

### Simulation-to-visual QA
- تولید متوقف: انیمیشن تولید متوقف.
- ورودی ناکافی: نشان کمبود و خروجی متناسب.
- قطع utility: وضعیت وابسته به نوع ساختمان.
- تعمیر: downtime و scaffold هماهنگ.
- damage: شدت بصری با severity واقعی هم‌خوان.
- load/reload: state بصری پس از بازیابی دقیقاً از simulation بازسازی شود.

## 19. Asset provenance و مجوز

هر asset source و derivative باید:
- URL صفحه دقیق، نام سازنده، مجوز و نسخه داشته باشد؛
- license file داخل archive نگهداری شود؛
- archive و imported file دارای SHA-256 باشند؛
- attribution و محدودیت‌ها ثبت شوند؛
- مشتق‌ها به فایل اصلی قابل ردیابی باشند؛
- هیچ asset با NC/ND/مجوز مبهم وارد release نشود؛
- font، sound، icon، decal، HDRI و texture هم جداگانه بررسی شوند.

## 20. معیار تکمیل هر ساختمان

یک building فقط زمانی Complete است که:
1. تعریف gameplay و شناسه پایدار دارد.
2. footprint/access/service sockets تأیید شده‌اند.
3. همه tierهای برنامه‌ریزی‌شده تفاوت معماری واضح دارند.
4. asset source و مجوز کامل‌اند.
5. prefab، material، collider و LODها سالم‌اند.
6. preview، icon و thumbnail حاضرند.
7. state visuals به simulation وصل و تست شده‌اند.
8. Day/Night و Low/Medium/High قابل قبول‌اند.
9. روی دستگاه کف هدف آزمایش شده است.
10. هیچ blocker/critical art یا gameplay defect باقی نمانده است.

## 21. موارد باز و تصمیم‌های ممنوع از حدس

- تعداد tier نهایی هر building family؛
- ابعاد footprint و ارتفاع واقعی؛
- grid scale و camera projection نهایی؛
- تعداد variationها؛
- target device floor؛
- بودجه polygon/texture/memory/draw calls؛
- فاصله LOD؛
- هزینه و زمان ارتقا و نرخ تولید؛
- climate و چرخه شبانه‌روز gameplay.

این موارد باید با blockout، تست روی گوشی، شبیه‌سازی و تصمیم محصول تعیین شوند. هیچ عدد نمونه‌ای در این سند نباید به‌عنوان مقدار production تعبیر شود.


## Building occupancy, exposure and emergency risk

Emergency demand and risk depend on actual occupancy, building use, construction/condition and access as defined in [Capital Region Emergency Services, Fire, Police, Healthcare & Disaster Response](CAPITAL_REGION_EMERGENCY_SERVICES_FIRE_POLICE_HEALTH_AND_DISASTER_RESPONSE_SPEC.md). Nominal housing capacity and house count do not equal residents or exposure. A building's visual state cannot independently create fire, burglary or damage; authoritative incident and condition events are required.
