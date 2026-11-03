# ماتریس طراحی و تحویل ساختمان‌های منطقه پایتخت — Capital Region V1

این ماتریس مکمل CAPITAL_REGION_V1_CONTENT_CATALOG.md و BUILDING_VISUAL_PROGRESSION_ATLAS.md است. وضعیت V1 از کاتالوگ می‌آید؛ این سند status محصول را تغییر نمی‌دهد.

| ID | خانواده | کاربری | کلاس | هویت بصری/سیلوئت | عناصر اجباری نما | عناصر سقف/محوطه | نشانه‌های state | وابستگی عملکردی |
|---|---|---|---|---|---|---|---|---|
| INF-ROAD-LOCAL | Road | مسیر محلی | Network | قطعه خطی و قابل اتصال | لبه، آسفالت، اتصال قطعات | خط‌کشی/پیاده‌رو در صورت طراحی | ساخت/بسته/آسیب در صورت پشتیبانی | graph connectivity |
| INF-ROAD-INTERSECTION | Road | تقاطع | Network | گره واضح با گوشه‌های خوانا | curb و محل عبور | چراغ/خط‌کشی فقط با قواعد واقعی | کنترل ترافیک معتبر | junction graph |
| RES-HOUSE-STARTER | Residential | خانه آغازین | Operational | حجم کوچک و سقف مشخص | در، پنجره، نمای مسکونی | roof و محوطه محدود | occupancy/state معتبر | household + utilities |
| RES-HOUSE-FAMILY | Residential | خانه خانوادگی | Operational | حجم پهن‌تر/چندبخشی | ورودی و بازشوهای متمایز | محوطه و سقف توسعه‌یافته | occupancy/state معتبر | household + utilities |
| RES-APARTMENT-LOW | Residential | آپارتمان کم‌ارتفاع | Candidate | ریتم طبقات | ورودی مجتمع، بالکن، پنجره | تجهیزات سقفی | نور/وضعیت معتبر | household/service |
| RES-APARTMENT-MID | Residential | آپارتمان میان‌مرتبه | Deferred | silhouette عمودی | طبقات و podium | rooftop equipment | state معتبر | household/service |
| IND-FACTORY-BASIC | Industrial | کارخانه پایه | Operational | سالن و حجم صنعتی | dock، در کارکنان، پنل صنعتی | تهویه/نورگیر متناسب | running/idle/blocked/maintenance | recipe/workforce/utility |
| COM-WORKSHOP-BASIC | Workshop | کارگاه | Operational | حجم کارگاهی جمع‌وجور | ورودی خدمات، پنجره/تابلو | تهویه متناسب | running/shortage/blocked | recipes/inventory |
| IND-FACTORY-ADVANCED | Industrial | کارخانه پیشرفته | Candidate | چند حجم فرایندی | خطوط و کنترل | تجهیزات فرایندی | process states | multi-input production |
| COM-WORKSHOP-ADVANCED | Workshop | کارگاه پیشرفته | Deferred | حجم چندبخشی | loading/service access | تجهیزات تخصصی | process states | advanced recipes |
| UTL-POWER-PLANT-SMALL | Utility | نیروگاه کوچک | Operational | مجموعه تولید و کنترل | ورودی تعمیر/تابلو | اجزای فناوری پس از تصمیم | online/offline/maintenance | power network |
| UTL-WATER-PUMP | Utility | پمپ‌خانه | Operational | ساختمان + مخزن/لوله | لوله‌ها و دسترسی تعمیر | مخزن/پمپ | supplied/disconnected | water network |
| UTL-SEWAGE-PLANT | Utility | تصفیه‌خانه | Operational | مخزن/حوضچه و کنترل | لوله و بخش خدماتی | واحدهای تصفیه | process/overflow/maintenance | wastewater network |
| ENV-WASTE-DEPOT | Environmental | پسماند | Operational | مرکز خدماتی صنعتی | bay و ورودی ناوگان | فضای مانور | collection/blocked | fleet/road/storage |
| ENV-RECYCLING-YARD | Environmental | بازیافت | Candidate | yard و سالن پردازش | ورودی تفکیک | تجهیزات پردازش | process states | waste/inventory |
| SVC-FIRE-STATION-SMALL | Civic service | آتش‌نشانی | Operational | ورودی ناوگان برجسته | bay خودرو و ورودی | برج/محوطه | dispatch/idle | emergency route/staff |
| SVC-POLICE-POST | Civic service | پلیس | Operational | ساختمان مدنی کوچک | ورودی عمومی | فضای گشت در صورت نیاز | patrol/dispatch معتبر | service capacity |
| SVC-CLINIC | Civic service | درمانگاه | Operational | ساختمان عمومی قابل اعتماد | ورودی و نشانه پزشکی | دسترسی امدادی | service availability | health capacity |
| GOV-CITY-HALL | Civic | شهرداری | Operational | ورودی مرکزی و نمای رسمی عمومی | پله/ورودی/پنجره | plaza محدود | policy/budget state | city economy |
| GOV-CONSTRUCTION-OFFICE | Civic | دفتر ساخت | Operational | ساختمان اداری | ورودی و فضای تحویل | نقشه/نشانه پروژه | queue/project state | construction queue |
| LOG-WAREHOUSE-STARTER | Logistics | انبار | Operational | سالن پهن و dock | درگاه بارگیری | محوطه گردش | inventory/blocked | storage reservations |
| TRADE-DEPOT | Trade | مرکز تجارت | Operational | تجاری-لجستیکی | ورودی تحویل/دریافت | dock/محوطه | listing/dispatch | market/inventory |
| LOG-FREIGHT-TERMINAL | Logistics | پایانه بار | Candidate | مجموعه چندبخشی | dock/yard | زیرساخت انتقال | shipment state | regional logistics |
| PARK-* | Recreation | فضای سبز | Decoration by default | canopy و مسیر | مبلمان شهری | درخت/چراغ/مسیر | maintenance فقط در صورت تعریف | no hidden gameplay |
| LANDMARK-* | Landmark | بنای شاخص | Explicit per definition | silhouette منحصربه‌فرد | جزئیات شاخص | نورپردازی کنترل‌شده | فقط state تعریف‌شده | no implicit economy |

## قواعد سراسری ماتریس

1. هیچ family بدون family sheet، silhouette sheet و preview موبایل وارد production art نمی‌شود.
2. همه ساختمان‌های Operational باید ورودی/خروجی، capacity، workforce/utility demand، access و state transition مشخص داشته باشند.
3. تمام موارد Decorative باید فاقد modifierهای اقتصادی/جمعیتی/خدماتی باشند.
4. همه building IDs، tierها، recipes و asset refs باید با schema validator کنترل شوند.
5. tier بصری باید در silhouette یا massing و حداقل یک ویژگی معماری دیگر تفاوت داشته باشد.
6. نمای شب و VFX فقط state-driven هستند؛ چراغ، دود، کامیون و شهروند تزئینی نباید داده جعلی القا کنند.
7. Footprintهای provisional، ارتفاع‌ها، tier count و اعداد performance تا زمان blockout/profile TBD می‌مانند.
8. انتخاب Asset از رجیستری اولیه به معنی تأیید آن نیست؛ مجوز همان فایل و محتویات archive باید ثبت شود.
9. پلاگین‌های طراحی و مدل‌سازی برای ایجاد خروجی واقعی و قابل ویرایش استفاده می‌شوند؛ تصویر کانسپت به‌تنهایی asset قابل اجرا نیست.
10. این ماتریس سند طراحی است و به‌تنهایی مجوز شروع پیاده‌سازی سیستم اصلی شهرسازی نیست.

## وضعیت تحویل خانواده‌ها

| خانواده | Catalog IDها | Brief | Blockout | Approved model | Cocos prefab | Device verified |
|---|---|---|---|---|---|---|
| Residential | RES-* | Required | Not started | Not started | Not started | Not started |
| Industrial/workshop | IND-*, COM-* | Required | Not started | Not started | Not started | Not started |
| Utilities | UTL-* | Required | Not started | Not started | Not started | Not started |
| Civic services | SVC-*, GOV-* | Required | Not started | Not started | Not started | Not started |
| Logistics/trade | LOG-*, TRADE-* | Required | Not started | Not started | Not started | Not started |
| Recreation/landmarks | PARK-*, LANDMARK-* | Required | Not started | Not started | Not started | Not started |

وضعیت‌ها عمداً Not started هستند تا با نوشتن سند، تولید مدل یا تست انجام‌شده تلقی نشود.
