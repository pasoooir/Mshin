# اطلس جامع حمل‌ونقل عمومی و زیرساخت جاده‌ای منطقه پایتخت
**Capital Region Public Transport & Road Infrastructure Atlas**

- وضعیت: سند طراحی تفصیلی و پیشنهاد توسعه مرحله‌ای؛ مجوز پیاده‌سازی یا تغییر دامنه V1 نیست.
- موتور هدف: Cocos Creator 3.8.6 / TypeScript
- پلتفرم: Android و iOS؛ Mobile-first
- مراجع حاکم: `CAPITAL_REGION_V1_CONTENT_CATALOG.md`، `CAPITAL_REGION_WORLD_SPATIAL_SPEC.md`، `VEHICLE_FLEET_FREIGHT_TRAFFIC_SPEC.md`، `CAPITAL_REGION_VEHICLE_AND_MOBILITY_VISUAL_ATLAS.md` و اطلس محیط شهری.
- قاعده: وضعیت Deferred/Candidate در کاتالوگ بدون تصمیم رسمی ارتقا نمی‌یابد؛ این اطلس شناسه عملیاتی جدیدی را به کاتالوگ تحمیل نمی‌کند.

---

## 1. مأموریت و اصول غیرقابل مذاکره

هدف، تعریف یک شبکه حمل‌ونقل شهری قابل فهم، قابل توسعه و سازگار با شبیه‌سازی است؛ شبکه‌ای که خیابان محلی، محور اصلی، حمل‌ونقل عمومی، پایانه، پارکینگ، پل و تقاطع را در قالب یک جهان فضایی واحد به هم متصل کند.

1. شبکه جاده‌ای یک گراف authoritative است؛ مدل سه‌بعدی، خطوط رنگی و انیمیشن منبع اتصال یا ظرفیت نیستند.
2. هر سرویس حمل‌ونقل عمومی باید مسیر، ایستگاه، ناوگان، ظرفیت، زمان‌بندی/فاصله حرکت، تقاضا و هزینه عملیاتی تعریف‌شده داشته باشد.
3. هیچ اتوبوس، مسافر، صف، قطار/خط یا وسیله پارک‌شده تزئینی نباید آمار مسافر، ترافیک، اشتغال، درآمد یا رضایت را تغییر دهد.
4. حمل‌ونقل عمومی در کاتالوگ V1 فعلی **Deferred** است؛ طراحی این اطلس برای فاز آینده است، نه فعال‌سازی ناخواسته در V1.
5. پل در کاتالوگ فعلی **Deferred** و جاده ارتقایافته **Candidate** است. بزرگراه، پارکینگ عمومی، ایستگاه و پایانه نیز هنوز شناسه عملیاتی تأییدشده در کاتالوگ ندارند.
6. تقاطع‌های V1 فعلی گره گراف با تأخیر و گردش قانونی‌اند؛ «چراغ هوشمند تطبیقی» قابلیت جدیدی است و باید جداگانه تصویب شود.
7. ظرفیت، طول، عرض، سرعت، هزینه، headway، زمان چراغ، شیب مجاز، شعاع گردش و بودجه عملکرد تا آزمون واقعی **TBD** می‌مانند.
8. تمام جلوه‌های بصری، از تابلو تا چراغ، باید وضعیت معتبر شبکه و simulation را بازتاب دهند.
9. ابزارهای تخصصی باید خروجی قابل ویرایش mesh، material، prefab، data و test بسازند؛ تصویر کانسپت تحویل production نیست.

## 2. وضعیت دامنه و حاکمیت محتوا

### 2.1 اقلام موجود در کاتالوگ

| قلم | وضعیت فعلی کاتالوگ | آنچه اکنون مجاز است |
|---|---|---|
| `INF-ROAD-LOCAL` | V1-Required | قطعه راه محلی و edge معتبر در گراف |
| `INF-ROAD-INTERSECTION` | V1-Required | گره تقاطع، تأخیر و گردش‌های قانونی |
| `INF-ROAD-UPGRADED` | Candidate | فقط طراحی مفهومی؛ ارتقای ظرفیت/هزینه نیازمند تعریف |
| `INF-ROAD-BRIDGE` | Deferred | مطالعه معماری و فنی؛ بدون پل عملیاتی V1 |
| `VEH-BUS` | Deferred | فقط مرجع بصری/معماری آینده؛ بدون خط یا مسافر واقعی |
| `LOG-FREIGHT-TERMINAL` | Candidate | لجستیک منطقه‌ای آینده؛ نه پایانه مسافری |
| Public transport | Deferred | خارج از حلقه اصلی V1 |
| Airport/port | Deferred | خارج از دامنه V1 |

### 2.2 قابلیت‌هایی که هنوز کاتالوگ canonical ندارند

موارد زیر در این اطلس به‌عنوان **پیشنهاد مفهومی** بررسی می‌شوند و شناسه‌های جدول‌های این سند صرفاً برچسب بحث‌اند، نه ID قابل استفاده در کد یا save:
- ایستگاه اتوبوس و ایستگاه تبادلی؛
- پایانه و پارکینگ ناوگان اتوبوس؛
- پارکینگ عمومی و پارک‌وسوار؛
- بزرگراه، رمپ، تقاطع غیرهمسطح و عوارضی؛
- پل جاده‌ای و پل عابر؛
- خط، ایستگاه، برنامه حرکت و بلیت حمل‌ونقل عمومی؛
- کنترل چراغ تطبیقی و اولویت‌دهی اتوبوس؛
- خطوط ویژه اتوبوس و کریدور حمل‌ونقل.

پیش از implementation باید هر مورد در کاتالوگ با status، definition، placement، access، lifecycle، operation، economy، save migration و acceptance suite ثبت شود.

## 3. معماری شبکه جاده‌ای

### 3.1 سلسله‌مراتب راه

| کلاس مفهومی | نقش | دسترسی و محدودیت | نمایش |
|---|---|---|---|
| Local street | دسترسی خانه‌ها و خیابان‌های محلی | سرعت/ظرفیت پایین‌تر، دسترسی frontage | مقطع انسانی، پیاده‌رو و ورودی |
| Collector | جمع‌آوری سفر از چند خیابان | اتصال local به محور اصلی | عرض و نشانه تقاطع خواناتر |
| Arterial | اتصال نواحی شهری | کنترل دسترسی و تقاطع‌های تعریف‌شده | محور شاخص و چندخطی در صورت پشتیبانی |
| Highway / Expressway | جابه‌جایی سریع میان نواحی | دسترسی محدود، ورودی/خروجی کنترل‌شده | جداسازی مسیر و رمپ |
| Industrial access | دسترسی به کارخانه/انبار | محدودیت کلاس خودرو و مانور بار | مسیر freight و حریم dock |
| Service lane | دسترسی خدمات و تعمیر | دسترسی محدود و محلی | مقطع ساده |
| Transit corridor | مسیر اولویت‌دار حمل‌ونقل عمومی | فقط برای کلاس‌های مجاز | رنگ/نشان ویژه و مرزبندی خوانا |
| Pedestrian path | مسیر پیاده | بدون ترافیک موتوری مگر تعریف صریح | سطح پیاده و اتصال امن |

این نام‌ها طبقه‌بندی طراحی‌اند؛ کلاس‌های canonical edge باید در مدل داده واحد تعریف شوند. تعداد lane، سرعت، ظرفیت و هزینه از ظاهر راه استنتاج نمی‌شود.

### 3.2 تعریف edge و node

هر edge باید حداقل این مفاهیم را در schema نهایی پوشش دهد:
- شناسه پایدار و graph version؛
- کلاس راه، مالکیت/مسئول نگهداری و وضعیت ساخت؛
- جهت حرکت، تعداد lane و turn/vehicle restrictions؛
- اتصال ابتدا/انتها و اتصال‌های مجاز؛
- ظرفیت، سرعت مرجع و مدل هزینه سفر؛
- محدودیت ارتفاع/عرض/وزن در صورت نیاز؛
- وضعیت باز، بسته، تعمیر، انسداد و علت آن؛
- دسترسی پیاده/دوچرخه/اتوبوس فقط در صورت پشتیبانی هر mode؛
- هزینه ساخت و upkeep به‌عنوان پروفایل داده مستقل.

هر node تقاطع یا اتصال باید turn matrix، priority، crossing connections، کنترل signal در صورت وجود، queue policy و امکان U-turn را صریح تعریف کند. اتصال تصویری دو قطعه بدون edge/node معتبر ممنوع است.

### 3.3 قطعه‌بندی، اتصال و ارتقا

- قطعه جاده از node تا node تعریف می‌شود؛ تقسیم یا ادغام edge باید ID و route invalidation قابل پیش‌بینی داشته باشد.
- تغییر کلاس راه، جهت یا ظرفیت، graph version را افزایش می‌دهد.
- routeهای فعال با نسخه قدیمی باید طبق policy معتبر بازبینی شوند.
- ارتقا باید پیش‌نمایش اثر روی زمان سفر، محدودیت دسترسی، upkeep، مسیر امدادی و freight را نشان دهد.
- ارتقای بصری بدون delta عملیاتی صریح، cosmetic-only است.
- حذف راه نباید ساختمان‌ها، دسترسی اضطراری یا مقصدهای فعال را بی‌هشدار منزوی کند.
- ساخت راه باید atomic باشد؛ یا تمام قطعات و اتصال‌ها معتبر ثبت شوند یا هیچ‌کدام.

## 4. بزرگراه‌ها و راه‌های پرسرعت

### 4.1 اجزای طراحی
- carriagewayهای جداشده در صورت نیاز simulation؛
- میانه، guardrail و barrier؛
- رمپ ورود/خروج با merge و diverge؛
- شانه/حریم ایمنی در صورت پشتیبانی مدل؛
- signage پیش‌آگاهی و جهت‌یابی؛
- پل یا تونل در صورت عبور از مانع؛
- اتصال کنترل‌شده به arterial و نه اتصال مستقیم نامعتبر به هر خیابان محلی.

### 4.2 رفتار و محدودیت
بزرگراه نباید صرفاً یک road skin سریع‌تر باشد. تعریف عملیاتی آن نیازمند قواعد ورود/خروج، ممنوعیت گردش/توقف، سازگاری vehicle class، مدل merge، ظرفیت و هزینه نگهداری است. عابر، پارکینگ curbside و دسترسی ساختمان به بزرگراه مستقیم ممنوع است مگر طراحی ایمن و معتبر جداگانه تعریف شود.

### 4.3 وضعیت فازبندی
Highway در کاتالوگ فعلی ID یا status مستقل ندارد. پیشنهاد می‌شود پس از تثبیت road graph پایه، به‌عنوان Candidate برای نقشه توسعه آینده ارزیابی شود؛ هیچ speed multiplier یا هزینه‌ای در این سند تعیین نمی‌شود.

## 5. پل‌ها و عبور از موانع طبیعی

### 5.1 انواع مفهومی
- پل جاده‌ای کوتاه روی آبراه؛
- پل اصلی با دهانه بلند؛
- پل چنددهانه روی دره/مانع؛
- پل عابر پیاده مستقل؛
- اتصال مرتفع یا viaduct در مسیرهای توسعه‌ای.

هیچ‌یک از این انواع به معنی پشتیبانی فنی قطعی از سازه چندسطحی در V1 نیست.

### 5.2 داده‌های موردنیاز
- دو یا چند landing anchor معتبر؛
- span، ارتفاع و profile سطح عبور؛
- clearance زیر پل برای آب/مسیر/وسیله در صورت نیاز؛
- شیب و اتصال قابل عبور برای کلاس وسیله؛
- محدودیت بار/ارتفاع/عرض؛
- پایداری terrain و foundation constraint؛
- هزینه ساخت، نگهداری، آسیب‌پذیری و تعمیر؛
- مسدودشدن/تعطیلی و route fallback؛
- برخورد، انتخاب و selection proxy مستقل از mesh.

### 5.3 قوانین placement
- پل باید دو سوی مانع را به صورت graph connectivity معتبر متصل کند.
- landing باید روی سلول/نقطه مجاز باشد؛ عبور بصری از رودخانه بدون اتصال ممنوع است.
- طول، دهانه، ارتفاع، شیب و clearance تا بررسی greybox و فیزیک TBD هستند.
- ساخت/تخریب پل باید دسترسی محله‌ها و سفرهای فعال را preview کند.
- اگر چند سطح راه پشتیبانی نمی‌شود، از تقاطع بصری فریبنده اجتناب و دامنه پل ساده شود.

### 5.4 مرز V1
`INF-ROAD-BRIDGE` در کاتالوگ **Deferred** است. پل تنها پس از تصویب فاز، تست terrain/graph/save/load و اثبات عملکرد موبایل وارد بازی می‌شود.

## 6. تقاطع‌ها و کنترل هوشمند ترافیک

### 6.1 انواع تقاطع
- اتصال ساده دو راه؛
- T-junction؛
- چهارراه؛
- تقاطع چندشاخه فقط با کنترل و خوانایی کافی؛
- roundabout به‌عنوان گزینه Candidate؛
- grade-separated interchange برای highway آینده.

شکل هندسی تقاطع، turn connectivity را تعیین نمی‌کند؛ turn matrix داده مرجع است.

### 6.2 کنترل پایه
تقاطع V1 حداقل باید:
- گردش‌های مجاز و ممنوع را نگه دارد؛
- اولویت و تأخیر عبور را در مدل ترافیک اعمال کند؛
- وضعیت blockage و road closure را منتشر کند؛
- مسیر عبور اضطراری و freight را مطابق restrictions بسنجد؛
- crossing پیاده را فقط در صورت وجود pedestrian controller فعال کند.

### 6.3 چراغ راهنمایی
چراغ بصری فقط در node دارای signal controller معتبر نصب می‌شود. هر signal group شامل فازهای مجاز، گروه حرکت، زمان انتقال ایمن، all-red/clearance در صورت نیاز و state جاری است. مدت فازها TBD است. چراغ‌های خاموش/خراب/درحال تعمیر باید state معتبر داشته باشند.

### 6.4 چراغ هوشمند تطبیقی
Adaptive signal یک قابلیت جدید Candidate پیشنهادی است، نه قابلیت V1 تأییدشده. الگوریتم احتمالی می‌تواند از queue length، arrival rate، pedestrian call و emergency priority استفاده کند؛ اما باید:
- محدودیت حداقل/حداکثر سبز و clearance ایمن داشته باشد؛
- starvation یک جهت را با fairness bound کنترل کند؛
- در sensor failure به fixed-time/fail-safe plan برگردد؛
- رفتار deterministic و قابل replay داشته باشد؛
- داده مشاهده‌شده را با تخمین اشتباه نگیرد؛
- بدون evidence از بهبود travel time/throughput فعال نشود.

### 6.5 اولویت اتوبوس و امداد
Transit signal priority فقط پس از وجود bus trip و controller واقعی فعال می‌شود. اولویت می‌تواند درخواست extension/early green محدود باشد؛ چراغ قرمز متضاد یا عبور ناایمن هرگز با جلوه ویژه توجیه نمی‌شود. Emergency preemption نیز باید در dispatch و intersection controller تعریف شود، نه فقط با siren.

## 7. حمل‌ونقل عمومی — معماری مفهومی آینده

### 7.1 وضعیت
Public transport در کاتالوگ V1 فعلی **Deferred** و `VEH-BUS` نیز Deferred است. این فصل معماری قابل بررسی برای فاز آینده را مشخص می‌کند؛ هیچ اتوبوس عملیاتی، مسافر، درآمد بلیت یا رضایت ناشی از حمل‌ونقل عمومی برای V1 فرض نمی‌شود.

### 7.2 اجزای سیستم
یک سیستم کامل در آینده نیازمند این زیرسیستم‌هاست:
1. Transit network و route definition؛
2. stop/station registry و platform access؛
3. line direction، stop sequence و service calendar؛
4. fleet assignment، depot و vehicle availability؛
5. passenger demand model بر پایه household cohorts و مقصدهای معتبر؛
6. waiting, boarding, alighting و transfer؛
7. capacity, crowding و denied boarding؛
8. headway/schedule و reliability؛
9. operating cost، workforce، maintenance و fare policy در صورت تصویب؛
10. accessibility، disruption، detour و service recovery؛
11. passenger information و mobile UI؛
12. save/load، analytics و acceptance tests.

### 7.3 مدل خط
هر خط آینده باید lineId پایدار، نسخه، نام localization، mode، مسیر جهت رفت/برگشت، stop sequence، زمان سرویس، الگوی headway/schedule، ساعات خدمت، ناوگان سازگار، ظرفیت، هزینه، policy توقف و suite آزمون داشته باشد. خط فقط یک polyline رنگی نیست؛ هر segment باید به شبکه معتبر و هر توقف به node/edge قابل دسترسی متصل باشد.

### 7.4 مسیر و توقف
- مسیر اتوبوس از road graph و محدودیت bus-compatible edge استخراج می‌شود.
- مسیر رفت و برگشت جداگانه اعتبارسنجی می‌شود.
- توقف در هر سمت خیابان باید جهت و curb/platform صحیح داشته باشد.
- دوربرگردان، گردش و توقف در تقاطع فقط با turn/access rules مجاز است.
- تغییر road graph نسخه مسیر را invalidate می‌کند و باید reroute یا service disruption قابل مشاهده ایجاد کند.
- توقف موقت در محل نامعتبر ممنوع است.

### 7.5 تقاضای مسافر
تقاضا از household cohort، مقصدهای فعال، دسترسی پیاده، زمان سفر و policy واقعی تولید می‌شود. جمعیت نمایشی یا تعداد spriteها مبنای تقاضا نیست. اگر تقاضای فردی برای موبایل پرهزینه باشد، cohort/aggregate demand مرجع است و فقط نمونه‌ای از مسافران رندر می‌شود.

### 7.6 ظرفیت و ازدحام
ظرفیت اتوبوس، ظرفیت سکو، صف انتظار و نرخ سوار/پیاده شدن باید در schema واحد و با واحد مشخص ثبت شوند. ظرفیت بیش از حد یا ازدحام فقط با state واقعی نمایش داده شود. مسافر جا مانده باید به‌عنوان denied boarding یا انتظار در trip/demand record باقی بماند؛ حذف بصری صف به معنی انتقال مسافر نیست.

### 7.7 زمان‌بندی و headway
Schedule دقیق و headway-based دو policy متفاوت‌اند. یکی باید به‌عنوان مدل سرویس انتخاب شود یا ترکیبشان صریح باشد. تأخیر از traffic cost و dwell/boarding time محاسبه می‌شود. UI باید scheduled/estimated/actual را از هم جدا کند. مقدار دقیقه، ساعات فعالیت و فاصله حرکت تا simulation calibration TBD است.

### 7.8 انتقال بین خطوط
Transfer معتبر نیازمند مسیر پیاده بین platformها، زمان انتقال، دسترسی‌پذیری و هماهنگی زمان سرویس است. ایستگاه تبادلی نباید صرفاً دو icon نزدیک باشد. اگر مسیر پیاده امن وجود ندارد، transfer link نامعتبر است.

## 8. ایستگاه‌ها و پایانه‌ها

### 8.1 خانواده‌های مفهومی
| نوع | نقش | عناصر بصری | وابستگی عملیاتی |
|---|---|---|---|
| Stop pole | توقف ساده خیابانی | pole، route plate، شناسه توقف | خط و توقف معتبر |
| Sheltered stop | ایستگاه دارای سرپناه | سقف، نیمکت، نور و تابلو | platform و دسترسی پیاده |
| Accessible stop | سکوی دسترس‌پذیر | curb ramp، سطح tactile، فضای گردش | مسیر دسترس‌پذیر end-to-end |
| Interchange station | تبادل چند خط | چند platform، wayfinding، فضای انتظار | transfer graph |
| Bus terminal | آغاز/پایان چند خط | bays، dispatch، layover، passenger hall | depot/dispatch و کنترل ظرفیت |
| Bus depot | نگهداری ناوگان | پارک، شارژ/سوخت در صورت تعریف، تعمیرگاه | fleet, maintenance, workforce |
| Park-and-ride | اتصال خودرو به حمل‌ونقل عمومی | ورودی خودرو، پارکینگ و مسیر پیاده | parking allocation و transit service |

### 8.2 Stop placement
- توقف در محل قانونی و قابل دسترسی قرار می‌گیرد، نه روی تقاطع، گذرگاه یا ورودی ساختمان.
- طول curb، فضای platform، عرض پیاده‌رو و فاصله تقاطع باید با envelope واقعی تطبیق یابد.
- stop باید به یک یا چند line pattern و جهت حرکت متصل باشد.
- فاصله توقف‌ها، پوشش پیاده و اثر dwell بر ظرفیت راه باید با simulation و UX ارزیابی شود؛ مقدار ثابت حدس زده نمی‌شود.
- stop فاقد سرویس فعال نباید UI arrival یا مسافر منتظر نمایش دهد.

### 8.3 Terminal operations
پایانه عملیاتی به bay allocation، arrival/departure state، layover، vehicle dispatch، passenger circulation، capacity، maintenance access و emergency egress نیاز دارد. اتوبوس نباید در bay اشغال‌شده ظاهر شود. اشغال پایانه و تعداد اتوبوس پارک‌شده باید از ناوگان واقعی پیروی کند.

### 8.4 معماری و ظاهر
ایستگاه کوچک باید در نمای دور با silhouette و رنگ roof قابل تشخیص باشد؛ در نمای نزدیک تابلو، شماره توقف، نقشه مسیر، نیمکت، نور، سطل و مسیر دسترس‌پذیر خوانا باشند. پایانه باید ورودی، platform/bay، سالن و حریم عملیاتی متمایز داشته باشد. نام‌ها و تابلوها localization-ready و فاقد برند واقعی باشند.

## 9. پارکینگ عمومی و مدیریت توقف

### 9.1 تفکیک انواع
- curbside legal parking؛
- public surface lot؛
- structured parking garage؛
- residential/private lot؛
- service/loading bay؛
- accessible parking؛
- park-and-ride؛
- depot/station fleet yard.

این دسته‌ها پیشنهاد طراحی‌اند و هنوز building/infra IDs تأییدشده نیستند.

### 9.2 قرارداد ظرفیت
هر facility باید تعداد جایگاه معتبر، ابعاد/کلاس جایگاه، دسترسی، ساعات/قواعد استفاده، ظرفیت قابل رزرو، occupancy، نرخ ورود/خروج، قیمت/هزینه در صورت وجود و policy ذخیره را تعریف کند. تعداد جایگاه از mesh یا تعداد خطوط نقاشی‌شده محاسبه نمی‌شود.

### 9.3 تخصیص و رزرو
- هر پارک عملیاتی به allocation یا parking token معتبر نیاز دارد.
- تخصیص باید atomic و idempotent باشد.
- هنگام پر بودن، وسیله باید جایگزین قانونی پیدا کند یا trip را با علت روشن متوقف کند.
- حذف یا تغییر پارکینگ باید خودروهای رزروشده را قبل از commit بررسی کند.
- خودروهای decorative در slotهای جداگانه‌اند و ظرفیت عملیاتی را مصرف نمی‌کنند.
- parking occupancy و congestion از یکدیگر جدا هستند؛ پارکینگ پر به‌تنهایی مساوی ترافیک نیست.

### 9.4 پارکینگ طبقاتی
پارکینگ سازه‌ای نیازمند طبقات، ramp، گردش داخلی، clearance، pedestrian path، ventilation/fire safety representation و ظرفیت per-level است. تا زمانی که چندسطحی و pathfinding داخلی پشتیبانی نشده، نمای بیرونی پارکینگ چندطبقه نباید سیستم پارکینگ چندطبقه را القا کند.

## 10. خطوط ویژه و شبکه چندوجهی

### 10.1 حالت‌های مفهومی
- bus lane دائمی؛
- bus lane زمان‌مند؛
- transit-only corridor؛
- shared lane با priority؛
- pedestrian-only street؛
- bicycle lane در صورت تصویب چرخه دوچرخه.

هر mode باید edge access policy مستقل داشته باشد. رنگ pavement به‌تنهایی مجوز حرکت نیست.

### 10.2 محدودیت‌ها و تداخل‌ها
- bus lane با freight loading و emergency access باید قواعد تداخل داشته باشد.
- خطوط ویژه در تقاطع به phase/priority اتصال معتبر نیاز دارند.
- مسیرهای پیاده و توقف اتوبوس باید بدون conflict هندسی و منطقی باشند.
- حذف یا مسدود شدن یک edge باید service impact و reroute را محاسبه کند.
- modeهای پشتیبانی‌نشده نباید در legend یا UI به‌عنوان قابلیت فعال عرضه شوند.

### 10.3 گسترش شبکه
پیش از ساخت خط جدید، ابزار planning باید جمعیت/مقصد تحت پوشش، walking access، زمان سفر، transfer، ظرفیت ناوگان، هزینه راه‌اندازی، هزینه جاری، ازدحام، اثر بر traffic و شکاف پوشش را preview کند. تخمین‌ها باید با برچسب forecast و عدم قطعیت نمایش داده شوند.

## 11. توسعه شبکه جاده‌ای و مدیریت پروژه عمرانی

### 11.1 فازهای توسعه فضایی
- **Phase A — Local access:** اتصال خانه‌ها، خدمات و کارگاه‌های آغازین با گراف معتبر.
- **Phase B — Collector links:** کاهش dead-endهای ناخواسته و ایجاد اتصال میان بلوک‌ها.
- **Phase C — Arterial structure:** ایجاد محورهای شهری با نقاط اتصال و محدودیت دسترسی.
- **Phase D — Freight corridors:** دسترسی صنعتی و مسیرهای سازگار با کلاس کامیون.
- **Phase E — Transit corridors:** فقط پس از تصویب public transport و demand model.
- **Phase F — Highway/bridge expansion:** فقط پس از terrain, grade separation, ramp, bridge و performance validation.

این فازها ترتیب طراحی‌اند، نه unlock یا progression قطعی بازی.

### 11.2 Road planning preview
پیش از commit ساخت/ارتقا/حذف، پیش‌نمایش باید نشان دهد:
- اتصال‌های جدید و حذف‌شده؛
- ساختمان‌های بدون frontage/access؛
- مسیرهای سفر و سرویس تحت تأثیر؛
- کلاس وسایل مجاز/ممنوع؛
- تغییر هزینه سفر و ظرفیت؛
- هزینه ساخت، نگهداری و زمان انسداد؛
- تغییر دسترسی امداد، freight و transit؛
- زمین/آب/شیب و حریم‌های ممنوع؛
- گزینه undo یا recovery در محدوده policy مجاز.

### 11.3 عملیات ساخت
Roadwork state می‌تواند planned, construction, open, restricted, maintenance, blocked و retired باشد. انیمیشن ماشین‌آلات و موانع فقط با construction job معتبر فعال شوند. اگر در V1 ماشین‌آلات اجرایی وجود ندارد، ساخت می‌تواند abstraction زمان‌دار باشد اما باید صریحاً abstraction معرفی شود.

## 12. UI/UX موبایل

### 12.1 حالت‌های اصلی
- Road build؛
- Road inspect؛
- Junction inspect؛
- Traffic overlay؛
- Transit planning (فقط پس از فعال‌شدن سیستم)؛
- Parking inspect؛
- Network disruption/repair.

حالت‌ها باید با رنگ، عنوان و ابزار واضح از هم جدا شوند؛ gesture تنها روش تغییر حالت نباشد.

### 12.2 کنترل لمسی
- قطعه جاده با drag ساده و snap معتبر؛
- نمایش پیش‌نمایش مسیر، curvature و nodeهای ایجادشده؛
- امکان لغو/بازگشت قبل از هزینه؛
- انتخاب تقاطع با hit target مستقل از چراغ و prop؛
- بزرگ‌نمایی جزئیات ایستگاه بدون کوچک شدن دکمه‌های اصلی؛
- safe-area و دسترسی یک‌دستی برای کنترل‌های پرکاربرد؛
- عدم اتکا به hover، right-click یا دقت پیکسلی.

### 12.3 Overlayهای تشخیصی
- road class/direction؛
- connectivity و dead-end؛
- congestion و travel-time estimate؛
- vehicle restrictions؛
- service reachability؛
- bridge clearance/grade در صورت فعال بودن؛
- parking occupancy؛
- transit lines/stops/headway/capacity فقط در نسخه فعال.

Legend باید واحد، زمان به‌روزرسانی و تفاوت actual/forecast را نشان دهد. رنگ تنها حامل معنا نیست؛ الگو، icon و متن کمکی لازم است.

## 13. اطلس بصری و assetهای زیرساخت

### 13.1 Road kit
ماژول‌های موردنیاز: straight، curve، T، cross، merge، diverge، ramp، bridge deck، approach، sidewalk، curb، median، barrier، guardrail، drainage، sign، lamp، signal mast و maintenance marker. هر قطعه باید seam و UV سازگار داشته باشد.

### 13.2 Bus/Transit kit
برای آینده: چند silhouette اتوبوس عمومی، stop pole، shelter، platform، route board، terminal bay، depot، passenger wayfinding، accessibility elements و generic ticket/information kiosk. هیچ طرح برند واقعی استفاده نشود.

### 13.3 Parking kit
برای آینده: marking، curb signage، entry/exit gate، payment kiosk در صورت وجود، ramp، bay number، accessible bay marking و pedestrian access. نشان‌های دسترس‌پذیری باید واضح و مطابق استاندارد هدف پس از بررسی حقوقی/منطقه‌ای باشند.

### 13.4 Bridge/Highway kit
Deck، pier، abutment، expansion joint، railing، barrier، retaining wall، ramp transition، signage، lane marking و underside clearance. اتصال terrain و shadow باید در نماهای نزدیک و دور بررسی شود.

### 13.5 نور و شب
چراغ خیابان و ایستگاه فقط در شعاع/LOD لازم روشن شوند. چراغ signal state واقعی را نمایش دهد. تابلوهای شب‌تاب نباید رنگ هشدار یا contrast HUD را مختل کنند. روشنایی پایانه و پارکینگ از وضعیت باز/بسته و occupancy معتبر پیروی می‌کند یا decorative-only علامت می‌خورد.

## 14. ابزارها و پلاگین‌های تخصصی؛ pipeline اجباری

1. **GIS/reference study:** نقشه و مقطع مرجع با منبع، تاریخ، مجوز و annotation؛ استفاده از نقشه واقعی فقط با حقوق روشن.
2. **Road graph authoring:** ابزار قابل ویرایش برای node/edge، turn matrix، access envelope و validation؛ نه خطوط نقاشی‌شده در تصویر.
3. **Blender blockout:** مدل‌سازی قطعات ماژولار، bridge/road profile، vehicle clearance و مقطع.
4. **Procedural tools:** تولید variation کنترل‌شده راه، خط‌کشی، guardrail و street furniture؛ seed و نسخه باید reproducible باشد.
5. **UV/material workflow:** trim sheets، texture atlases، roughness/normal، texel density و mobile compression.
6. **Traffic/transit data tooling:** editor یا پلاگین قابل ویرایش برای route, stop sequence, schedule, signal phase و validation.
7. **Cocos Creator integration:** prefabهای ماژولار، LOD، collider، selection proxy، data binding و overlay.
8. **Automated validation:** اتصال graph، مسیر مجاز، تقاطع، footprint، clearance، duplicate ID، missing asset و license manifest.
9. **Device profiling:** تست Android و iOS واقعی در تراکم‌های تعریف‌شده، با frame-time، memory، thermal و touch responsiveness.
10. **Evidence package:** فایل منبع، خروجی runtime، manifest، مجوز، hash، test report و screenshots/video از گوشی.

تصویر AI یا moodboard فقط ورودی ideation است. ابزار تخصصی باید artifact قابل ویرایش و قابل import/export تولید کند. هر plugin/tool باید نسخه، مجوز، محدودیت و فرمت خروجی مشخص داشته باشد.

## 15. مدل داده مفهومی پیشنهادی

این interface صرفاً برای بحث schema است و تا تصویب و هماهنگی با schema اصلی نباید به کد production تبدیل شود:

```ts
interface RoadEdgeDefinition {
  edgeId: string;
  graphVersion: number;
  roadClass: string;
  fromNodeId: string;
  toNodeId: string;
  directionPolicyId: string;
  vehicleAccessProfileId: string;
  pedestrianAccessProfileId?: string;
  capacityProfileId: string;
  travelCostProfileId: string;
  constructionState: string;
  maintenanceProfileId?: string;
}

interface TransitLineDefinition {
  lineId: string;
  schemaVersion: number;
  status: "draft" | "candidate" | "active" | "suspended" | "retired";
  mode: string;
  directionPatterns: string[];
  stopSequenceIds: string[];
  serviceCalendarId: string;
  headwayOrScheduleProfileId: string;
  compatibleVehicleClassIds: string[];
  capacityProfileId: string;
  operatingCostProfileId: string;
  acceptanceSuiteId: string;
}

interface MobilityFacilityDefinition {
  facilityId: string;
  facilityType: string;
  accessNodeIds: string[];
  footprintDefinitionId: string;
  capacityProfileId?: string;
  accessibilityProfileId: string;
  operatingStateProfileId: string;
  visualPrefabKey: string;
  provenanceManifestKey: string;
}
```

قواعد validation: ID یکتا و پایدار؛ referenceها resolve شوند؛ status و mode معتبر باشند؛ ظرفیت/هزینه با واحد تعریف شوند؛ facility عملیاتی بدون access معتبر رد شود؛ Decorative هیچ اثر عملیاتی نداشته باشد؛ schema migration و backward compatibility الزامی است.

## 16. ذخیره‌سازی، تغییر گراف و بازیابی

- Save باید graph version، node/edge IDs، facility IDs، route/line versions، allocations و operational states را حفظ کند.
- تغییر graph باید به صورت command/versioned event ثبت شود؛ route cacheهای قدیمی invalid شوند.
- Save/load نباید توقف، اتوبوس، پارک یا مسافر را تکثیر کند.
- حذف ایستگاه/پارکینگ/پل باید رزروها و سرویس‌های وابسته را پیش از commit بررسی کند.
- اگر تعریف asset یا line در نسخه جدید حذف شد، migration باید fallback ایمن داشته باشد؛ داده فعال بی‌صدا دور ریخته نشود.
- Offline progression در صورت فعال بودن باید deterministic و از render FPS مستقل باشد.

## 17. معیارهای پذیرش و آزمون

| حوزه | آزمون لازم | شرط قبولی |
|---|---|---|
| Road graph | اتصال node/edge و graph version | بدون edge dangling غیرمجاز |
| Road construction | placement، split، merge و undo | command atomic و save-safe |
| Access | frontage و مسیر ساختمان | مقصد عملیاتی بدون دسترسی پنهان نماند |
| Vehicle restrictions | مسیر برای کلاس‌های مختلف | کلاس غیرمجاز وارد edge نشود |
| Intersections | turn matrix و priority | هیچ حرکت غیرمجاز از mesh عبور نکند |
| Adaptive signals | fairness، fail-safe و replay | starvation/unsafe phase رخ ندهد |
| Bridges | terrain, landing, grade, clearance | اتصال و عبور معتبر در تمام حالت‌ها |
| Highway | ramps, merges, access control | ورود/خروج غیرمجاز و teleport وجود نداشته باشد |
| Transit line | stop sequence و route continuity | تمام توقف‌ها به مسیر معتبر متصل باشند |
| Transit demand | household-to-destination demand | تقاضای تزئینی در آمار واقعی وارد نشود |
| Boarding | capacity و denied boarding | مسافر/ظرفیت دوبار ثبت نشود |
| Headway/schedule | delay و recovery | actual و forecast تفکیک شوند |
| Stop access | پیاده‌روی و accessibility | مسیر امن و قابل استفاده پیوسته باشد |
| Parking | reserve/release/idempotency | overbooking و اشغال جعلی رخ ندهد |
| Network expansion | اثر روی route/service | قطع دسترسی بدون هشدار/تأیید نباشد |
| Save/load | graph و active service | وضعیت دقیقاً یک‌بار بازیابی شود |
| Visual truth | چراغ، تابلو، صف و اتوبوس | نمایش با state authoritative سازگار باشد |
| License | منبع و مجوز هر فایل | asset فاقد مدرک وارد build نشود |
| Mobile | تراکم، zoom، background/resume | budget مصوب دستگاه رعایت شود |

هر قابلیت فقط پس از عبور از تست‌های مربوطه Approved می‌شود. Design complete، model approved، Cocos integrated و device verified وضعیت‌های مستقل‌اند.

## 18. عملکرد موبایل و راهبرد fidelity

- گراف و simulation از render chunk مستقل می‌مانند.
- در فاصله دور، جریان ترافیک aggregate نمایش داده می‌شود؛ ناوگان کامل رندر نمی‌شود.
- در نمای نزدیک، فقط agentهای منتخب و موردنیاز نمایش داده می‌شوند.
- اتوبوس‌های فعال فقط از ناوگان واقعی و tripهای معتبر می‌آیند.
- ایستگاه خالی نباید صف مسافر مصنوعی بسازد.
- signal animation و چراغ‌ها pooled/instanced یا emissive کم‌هزینه باشند.
- سایه و نور پویا فقط در نقاط و کیفیت لازم فعال شوند.
- route calculation در هر frame اجرا نمی‌شود؛ graph version و policy زمان‌بندی‌شده کنترلش می‌کنند.
- بودجه draw calls، triangle count، texture memory، visible agents، update interval و frame time تا profiling روی دستگاه واقعی TBD است.

## 19. Accessibility و ایمنی

- دسترسی پیاده تا platform باید پیوسته و قابل عبور باشد.
- curb ramp، شیب، فضای گردش و ارتفاع platform نیازمند معیار استاندارد هدف و بررسی تخصصی‌اند؛ مقادیر هنوز TBD هستند.
- اطلاعات مسیر با رنگ تنها ارائه نشود؛ متن، نماد و شکل خط نیز استفاده شود.
- هشدار disruption و تغییر platform باید با متن/آیکون و اعلان قابل تنظیم همراه باشد.
- صدای وسیله/آژیر تنها کانال هشدار نیست.
- عبور پیاده در تقاطع باید با signal/priority controller سازگار باشد.
- مسیر اضطراری و خروج اضطراری facility نباید با prop یا پارکینگ مسدود شود.

## 20. ریسک‌ها و تصمیم‌های باز

1. آیا حمل‌ونقل عمومی پس از V1 به‌عنوان سیستم کامل وارد scope می‌شود یا فقط bus service محدود؟
2. آیا مدل تقاضا household-based، مقصد-محور یا ترکیبی خواهد بود؟
3. آیا زمان‌بندی ثابت لازم است یا headway ساده برای نسخه اول کافی است؟
4. آیا پارکینگ عمومی در V1 لازم است یا فقط parking allocation برای خودروهای عملیاتی؟
5. آیا bridge/grade separation در نقشه اول ضروری است؟
6. آیا highway ارزش هزینه فنی و فضای نقشه را دارد؟
7. آیا adaptive signals نسبت به fixed-time واقعاً بهبود قابل اندازه‌گیری ایجاد می‌کنند؟
8. آیا bus lane و transit priority از ابتدا ضروری‌اند؟
9. کدام standards منطقه‌ای برای دسترس‌پذیری، signage و road marking مبنا خواهند بود؟
10. حداقل مشخصات گوشی و budget عملکردی چیست؟

هیچ‌یک از این تصمیم‌ها در این سند به صورت قطعی پاسخ داده نشده‌اند؛ هر تصمیم باید با owner، rationale، هزینه، شواهد و acceptance test تصویب شود.

## 21. وضعیت تکمیل

این اطلس قرارداد طراحی و handoff آینده است. در این مرحله هیچ اتوبوس، ایستگاه، پایانه، پارکینگ عمومی، پل، بزرگراه، چراغ تطبیقی، خط حمل‌ونقل، گراف جدید، prefab، asset دانلودشده یا simulation عملیاتی ساخته/تست نشده است. وضعیت Public transport و BUS همچنان Deferred، پل Deferred، road upgrade Candidate و freight terminal Candidate باقی می‌ماند. گیت عدم شروع پیاده‌سازی سیستم اصلی شهرسازی تا تکمیل طراحی و تأیید صریح پابرجاست.
