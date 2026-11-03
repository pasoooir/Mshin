# رجیستری اولیه Assetهای رایگان Mshin

- وضعیت کلی: Candidate / License evidence collected; هیچ موردی هنوز Downloaded، Hash-verified یا Integrated اعلام نمی‌شود.
- دامنه: نمونه مرجع بصری منطقه پایتخت و آزمایش pipeline
- اصل: تنها دارایی‌هایی که رکورد provenance کامل و بررسی فنی دارند می‌توانند وارد build انتشار شوند.

## 1. وضعیت و واژگان

| وضعیت | معنی |
|---|---|
| Candidate | منبع و کاربرد احتمالی شناسایی شده |
| LicenseEvidenceCollected | صفحه رسمی منبع و مجوز عمومی بررسی شده؛ هنوز فایل/بسته دانلودی تطبیق داده نشده |
| Downloaded | فایل خام واقعاً دریافت شده و مسیر/تاریخ ثبت است |
| HashVerified | SHA-256 محاسبه و در manifest ثبت شده |
| TechnicalReviewed | ساختار، فرمت، اندازه، UV، متریال، pivot و کیفیت بررسی شده |
| ArtApproved | با هویت بصری و مقیاس بازی تأیید شده |
| Integrated | در Cocos وارد شده و smoke test موفق دارد |
| DeviceVerified | روی دستگاه واقعی و build مشخص آزموده شده |
| Rejected | به علت فنی، هنری یا حقوقی رد شده |

**وضعیت فعلی رکوردهای زیر حداکثر LicenseEvidenceCollected است.** صفحات رسمی، مجوز کلی را پشتیبانی می‌کنند؛ اما این به معنی دانلود یا بررسی بایت‌های فایل نیست.

## 2. کاندیدهای منتخب برای Visual Benchmark

| Asset ID داخلی | منبع و بسته | نقش در نمونه | مجوز اعلام‌شده | وضعیت |
|---|---|---|---|---|
| KNY-CITY-ROADS-001 | Kenney — City Kit (Roads) | جاده، تقاطع، علائم و چراغ راهنمایی | CC0 در صفحه بسته | LicenseEvidenceCollected |
| KNY-CITY-SUBURBAN-001 | Kenney — City Kit (Suburban) | خانه‌ها و props محله مسکونی | CC0 در صفحه بسته | LicenseEvidenceCollected |
| KNY-CITY-INDUSTRIAL-001 | Kenney — City Kit (Industrial) | کارخانه/انبار و عناصر صنعتی | CC0 در صفحه بسته | LicenseEvidenceCollected |
| KNY-BUILDING-KIT-001 | Kenney — Building Kit | اجزای ساختمان و variationهای معماری | CC0 در صفحه بسته | LicenseEvidenceCollected |
| KNY-CAR-KIT-001 | Kenney — Car Kit | خودروهای سبک/خدماتی؛ انتخاب مدل دقیق پس از بررسی محتوا | نیازمند بازبینی صفحه بسته و فایل license پیش از دریافت | Candidate |
| PH-URBAN-STREET-HDRI-001 | Poly Haven — Urban Street 01 | مرجع نور و محیط شهری؛ اولویت برای authoring/baking، نه الزاماً runtime | CC0 در صفحه دارایی | LicenseEvidenceCollected |
| ACG-ASPHALT-010 | ambientCG — Asphalt010 | آسفالت خیابان | CC0 عمومی منبع؛ صفحه دقیق و archive باید دوباره بررسی شود | Candidate |
| ACG-ASPHALT-031 | ambientCG — Asphalt031 | variation آسفالت/پارکینگ | CC0 عمومی منبع؛ صفحه دقیق و archive باید دوباره بررسی شود | Candidate |
| ACG-CONCRETE-034 | ambientCG — Concrete034 | پیاده‌رو، جدول و بتن | CC0 عمومی منبع؛ صفحه دقیق و archive باید دوباره بررسی شود | Candidate |
| ACG-GRASS-004 | ambientCG — Grass004 | چمن و فضای سبز | CC0 عمومی منبع؛ صفحه دقیق و archive باید دوباره بررسی شود | Candidate |
| PH-STREET-LAMP-01 | Poly Haven — Street Lamp 01 | چراغ خیابان/مرجع prop | CC0 در سیاست دارایی Poly Haven؛ صفحه مدل و فایل دقیق باید تطبیق شود | Candidate |
| PH-ROAD-BARRIER-01 | Poly Haven — Concrete Road Barrier | مانع بتنی جاده | CC0 در سیاست دارایی Poly Haven؛ صفحه مدل و فایل دقیق باید تطبیق شود | Candidate |

## 3. شواهد منابع رسمی

- Kenney، City Kit (Roads): https://kenney.nl/assets/city-kit-roads
- Kenney، City Kit (Suburban): https://kenney.nl/assets/city-kit-suburban
- Kenney، City Kit (Industrial): https://kenney.nl/assets/city-kit-industrial
- Kenney، Building Kit: https://kenney.nl/assets/building-kit
- Kenney، پشتیبانی و توضیح مجوز CC0: https://kenney.nl/support
- Poly Haven، Urban Street 01: https://polyhaven.com/a/urban_street_01
- Poly Haven، مجوز CC0 و اجازه استفاده تجاری/توزیع: https://polyhaven.com/license
- ambientCG: https://ambientcg.com/
- ambientCG، مستندات مجوز: https://docs.ambientcg.com/license/

منابع مرجع وب برای وضعیت صفحات هنگام تدوین:
- Kenney City Kit Roads / Suburban / Industrial / Building Kit
- Kenney Support
- Poly Haven Urban Street 01 و License
- هر رکورد باید هنگام دانلود دوباره از صفحه رسمی بازبینی شود؛ تاریخ این بررسی در manifest ثبت شود.

## 4. قواعد دریافت و ثبت provenance

برای هر بسته:
1. صفحه رسمی بسته را باز و عنوان/سازنده/مجوز/نسخه/تاریخ را ثبت کن.
2. فایل license داخل archive را استخراج و عیناً نگه‌داری کن.
3. نام فایل، اندازه بایت، فرمت، archive checksum و فایل‌های داخل بسته را ثبت کن.
4. SHA-256 برای archive و هر فایل واردشده محاسبه شود.
5. هیچ فایل اجرایی، installer، اسکریپت ناشناس یا فایل خارج از نیاز وارد pipeline نشود.
6. دارایی‌ها ابتدا در quarantine/inbox قرار گیرند؛ مستقیماً در پوشه production نروند.
7. مدل و texture به‌صورت جداگانه از نظر مجوز و dependency بررسی شوند.
8. تغییر نام فایل منبع نباید provenance را از بین ببرد؛ mapping نام اصلی به assetId داخلی حفظ شود.
9. از نگهداری preview image صفحه وب به‌جای فایل واقعی asset خودداری شود.
10. فایل خام read-only نگهداری و نسخه بهینه‌شده در مسیر مشتق‌شده ذخیره شود.

## 5. قالب رکورد کامل هر Asset

هر رکورد پس از دریافت باید این فیلدها را تکمیل کند:

- asset_id:
- display_name:
- provider:
- pack_name:
- source_page_url:
- download_url_or_method:
- creator:
- provider_asset_version:
- license_id:
- license_version:
- license_file_path:
- license_evidence_url:
- downloaded_at_utc:
- original_filename:
- archive_bytes:
- archive_sha256:
- imported_file_sha256:
- file_inventory:
- source_resolution:
- runtime_resolution:
- source_format:
- runtime_format:
- commercial_use: verified / not_verified / prohibited
- modification_allowed: verified / not_verified / prohibited
- redistribution_in_game: verified / not_verified / prohibited
- attribution_text:
- transformations:
- blender_version:
- cocos_creator_version:
- target_platforms:
- asset_role:
- scene_usage:
- technical_review:
- art_review:
- device_test_build:
- status:
- reviewer_notes:

تا زمانی که فیلدهای حقوقی و hash ضروری تکمیل نشده‌اند، وضعیت بالاتر از Candidate/LicenseEvidenceCollected ممنوع است.

## 6. سیاست انتخاب نسخه مناسب موبایل

- برای textureهای tiling، از 1K یا 2K شروع شود؛ 4K فقط برای asset نزدیک و با اثبات نیاز.
- برای HDRI فقط در authoring/baking نسخه باکیفیت استفاده شود؛ runtime از skybox کم‌حجم یا texture فشرده استفاده کند.
- مدل‌های محیطی تکراری باید instance/batch شوند؛ mesh مستقل برای هر نمونه ممنوع مگر ضرورت.
- مدل‌های نزدیک دوربین با LOD و collider مستقل؛ مدل دوردست با LOD ساده یا impostor.
- تعداد material slotها کاهش یابد؛ atlas فقط در صورت حفظ کیفیت و عدم ایجاد مشکلات mip/bleeding.
- Normal map و roughness فقط اگر در نور و نمای واقعی اثر قابل مشاهده دارند وارد شوند.
- textureهای height/displacement سنگین به normal/baked detail تبدیل شوند مگر geometry واقعی لازم باشد.

## 7. موارد رد خودکار

- صفحه یا فایل مجوز نامعلوم/متناقض
- NonCommercial یا NoDerivatives ناسازگار با محصول
- لوگو/برند/شخصیت یا طراحی اختصاصی بازی دیگر
- archive خراب، فایل مشکوک یا dependency غیرقابل دریافت
- مدل بدون UV معتبر یا با normalهای خراب
- texture بزرگ و نامتناسب با نقش
- asset دارای watermark یا preview-only
- مدل ناسازگار با مقیاس، سبک یا بودجه موبایل
- عدم امکان ثبت hash و منبع اصلی

## 8. خروجی مورد انتظار مرحله Registry

- فایل manifest ماشین‌خوان در کنار این سند ایجاد شود.
- هر Asset انتخاب‌شده یک رکورد provenance داشته باشد.
- یک credits/notices file از manifest تولید شود؛ حتی اگر CC0 انتساب اجباری ندارد، provenance داخلی حفظ شود.
- release pipeline باید نبود فیلدهای الزامی یا hash را به‌عنوان خطا گزارش کند.
- حذف یا تعویض Asset باید history و نسخه‌های build مصرف‌کننده را حفظ کند.

## 9. محدودیت وضعیت فعلی

این سند انتخاب اولیه و بررسی صفحات منبع است. هنوز هیچ archive در این مخزن commit نشده، hash فایل واقعی محاسبه نشده، Asset در Blender باز نشده و import یا تست Cocos انجام نشده است. این موارد به‌عنوان کارهای بعدی و معیار تکمیل ثبت می‌شوند.
