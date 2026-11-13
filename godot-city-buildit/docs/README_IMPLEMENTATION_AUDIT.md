# ممیزی واقعیت‌سنجی README — 2026-11-13

## دامنه
- مرجع: شاخه `main`، commit `d3460716356e32a409acda3ed6f2b273e8415fcf`.
- checkboxهای README با کد Godot، UI، داده‌های ساختمان/محصول، تست‌ها و workflowها تطبیق داده شدند.
- `[x]` یعنی پیاده‌سازی قابل ردیابی؛ `[~]` یعنی ناقص/محدود/داده جایگزین؛ `[ ]` یعنی انجام‌نشده یا نیازمند آزمون مستقل.
- وجود نام ساختمان یا Unlock flag به‌تنهایی به معنی تکمیل گیم‌پلی آن نیست. وجود UI به‌تنهایی نیز به معنی فعال بودن دکمه نیست.

## نتیجه کلان

| حوزه | نتیجه واقعی |
|---|---|
| Save/Load | پیاده‌سازی شده؛ README قبلاً به‌اشتباه unchecked بود |
| Factory | هسته صف موازی، تایمر، جمع‌آوری و Tierها وجود دارد |
| Commercial | فروشگاه‌ها و بخشی از زنجیره‌ها فعال؛ برخی محصولات فقط کاتالوگی‌اند و Recipe آن‌ها غیرفعال است |
| Residential | پنل، مواد، کمبود، تأمین‌کننده، تحویل مواد و تایمر وجود دارد؛ داده‌های plan/population دقیق SCBI نیست |
| Storage | نمایش موجودی/ظرفیت وجود دارد؛ دکمه افزایش ظرفیت در UI غیرفعال است |
| Services | برق/آب و Fire پایه فعال؛ Sewage/Waste و برخی Tierهای Police/Health ناقص‌اند |
| Trade | فروش و سفارش پایه وجود دارد؛ Trade Depot و Global Trade مستقل وجود ندارند |
| Move/Demolish | جابه‌جایی ساختمان، تخریب ساختمان و حذف جاده وجود دارند |
| Responsive UI | در main تطبیق کامل همه پنل‌های عمیق برای سه فرم‌فاکتور تأیید نشده؛ PR #396 هنگام ممیزی Draft و خارج از main بود |
| Web | workflow خروجی مرورگر و Pages وجود دارد |
| Android/iOS | خروجی نصب‌شدنی و آزمون دستگاه واقعی تأیید نشده |

## شواهد فنی

### HUD، کنترل و ظاهر
- `godot-city-buildit/scripts/ui/HUD.gd::_build_top_hud`: HUD سطح، جمعیت، رضایت، XP، انبار و ارزها.
- `HUD.gd::_build_catalog_info_panel` و `_show_building_info`: پنل اطلاعات کاتالوگ؛ به‌تنهایی جزئیات کامل هر ساختمان ساخته‌شده نیست.
- `HUD.gd::_show_residential_upgrade_panel`: مواد، مقدار موردنیاز، موجودی، کمبود، تولید در جریان، جمع‌آوری آماده، تأمین‌کننده و دکمه تحویل.
- `HUD.gd::_show_storage_panel`: ظرفیت، نوار پیشرفت، فهرست آیتم‌ها و ScrollContainer.
- `HUD.gd::_refresh_storage_panel`: دکمه افزایش ظرفیت با `disabled = true` ساخته می‌شود و tooltip می‌گوید خرید ظرفیت تنظیم نشده است.
- `CameraController.gd`: Pan تک‌pointer، Zoom با فاصله دو انگشت و Orbit با تغییر زاویه دو انگشت؛ اینرسی مشاهده نشد.
- `GhostPreview.gd`: Ghost سبز/قرمز و پیش‌نمایش محدوده خدمات اضطراری؛ چرخش ساختمان در preview وجود ندارد.
- `CityInput.gd`: نگه‌داشتن و Drag برای جابه‌جایی ساختمان، و دو حالت تخریب ساختمان/جاده. Haptic در مسیرهای بررسی‌شده یافت نشد.

### Factory و Commercial
- `BuildManager.gd`: پنج Tier کارخانه و چندین فروشگاه تجاری تعریف شده‌اند.
- `ProductionComponent.gd`: صف چنداسلاتی، شروع تولید/Craft، جمع‌آوری، ذخیره و بازیابی Slotها.
- `ProductionManager.gd`: کاتالوگ متمرکز، مواد خام، Recipe، dependency chain و کنترل unlock.
- Recipe نامشخص عمداً غیرفعال می‌شود؛ نباید برای پرکردن چک‌لیست داده ساختگی اضافه شود.
- `GameplaySmoke.gd`: تست مواد خام، زمان‌ها، Recipeها، فروشگاه‌ها، Tier کارخانه و صف تولید.
- Implementation Tracker تعداد ۱۱ ماده خام، ۳۲ محصول قابل ساخت و ۴۲ هویت کاتالوگی را گزارش می‌کند؛ تعداد کاتالوگ با Recipe فعال برابر نیست.

### Residential
- `ProductionManager.gd` تصریح می‌کند جدول مواد ارتقا Mshin fallback است، نه جدول دقیق/تصادفی SimCity BuildIt.
- جمعیت فعلی مرحله‌ها: `{1:15, 2:30, 3:50, 4:90, 5:160, 6:280}`؛ با اعداد هدف README (۵۲ تا ۱۸۳۶) تطابق ندارد.
- دکمه `DELIVER MATERIALS & UPGRADE` در HUD وجود دارد و `Building.try_upgrade()` مواد را بررسی و زمان ساخت را آغاز می‌کند.
- `HappinessManager.gd`: آستانه رهاشدن ۲۵ و مهلت ۹۰ ثانیه دارد.

### Services
- `ServiceManager.gd`: ظرفیت، تقاضا، شعاع و فهرست خانه‌های برخوردار از برق/آب را محاسبه می‌کند.
- `FireHazardManager.gd`: شعاع آتش‌نشانی و ارزیابی خطر آتش را انجام می‌دهد.
- `GhostPreview.gd`: پیش‌نمایش محدوده Fire/Police/Health دارد؛ Power/Water/Sewage/Waste کامل نیست.
- `HappinessManager.gd`: برق، آب، پارک، آلودگی صنعتی و بعضی خدمات روی رضایت اثر می‌گذارند.
- **شکاف مشخص:** تابع رضایت شناسه `sewage_pipe` را بررسی می‌کند، اما کاتالوگ `sewage_small`، `sewage_basic` و `sewage_deluxe` دارد؛ این عدم تطابق باید رفع و تست شود.
- Waste در تابع محاسبه رضایت/ظرفیت خدمت خانه مشاهده نشد.
- بررسی مستقیم Police/Health فقط شناسه‌های پایه `police_station` و `hospital` را می‌شناسد؛ همه Tierها پوشش داده نمی‌شوند.

### Trade و Progression
- `TradeManager.gd`: چهار slot فروش و سفارش‌های ساده مبتنی بر آیتم دارد؛ این با Trade Depot و Global Trade HQ مستقل برابر نیست.
- `LevelProgression.gd`: جمعیت ۸۰۰۰ و ۱۰۰۰۰ را به‌عنوان Unlock ثبت می‌کند؛ ثبت Unlock به معنی وجود ساختمان/بازار کامل نیست.
- `GameManager.gd`: هنگام Level Up سکه و Golden Key می‌دهد.
- `LevelProgression.gd`: جدول XP تا سطح ۲۰ صریح است و برای سطوح بالاتر fallback دارد.
- `HUD.gd`: فقط گروه Parks در specialization ساختمان قابل انتخاب دارد؛ گروه‌های Education/Transportation/Entertainment و غیره خالی‌اند.

### Save/Load و ساخت‌وساز
- `SaveManager.gd`: JSON version 2، ذخیره خودکار هر ۳۰ ثانیه و ذخیره جاده، ساختمان‌ها، مرحله خانه، تولید، صف، انبار، اقتصاد، XP، جمعیت و رضایت.
- `BuildManager.gd::begin_move/finish_move` و `CityInput.gd`: جابه‌جایی با نگه‌داشتن و کشیدن.
- `CityInput.gd::_handle_bulldoze_cell`: تخریب ساختمان با تأیید دوباره و حذف قطعه جاده.
- دسترسی جاده هنگام جانمایی بررسی می‌شود؛ قطع اتصال پس از ساخت به‌عنوان قاعده سراسری همه ساختمان‌ها ثابت نشده است.

## مواردی که عمداً کامل علامت نخوردند
1. جمعیت مرحله‌ای با هدف README ناسازگار است.
2. طرح مواد ارتقای خانه، داده جایگزین Mshin است نه داده دقیق SCBI.
3. بعضی محصولات کاتالوگی‌اند و Recipe ندارند/غیرفعال‌اند.
4. دکمه افزایش ظرفیت انبار غیرفعال است.
5. Trade Depot و Global Trade فقط Unlock flag دارند.
6. Sewage/Waste و بعضی Tierهای Police/Health رفتار کامل ندارند.
7. Android/iOS و 60 FPS روی دستگاه واقعی اندازه‌گیری نشده‌اند.
8. آموزش، دستاورد، Regions و Epic Projects پیاده‌سازی نشده‌اند.

## آزمون‌های لازم بعدی
- Android landscape روی گوشی کوچک و بزرگ، و تبلت در landscape/portrait.
- دسکتاپ در 1280×720 و 1920×1080.
- Screenshot و تست تعامل Factory، Store، Product detail، Queue، City Needs، Residential Upgrade، Storage و Building Info.
- رفع mismatch شناسه Sewage و افزودن تست Waste و همه Tierهای Police/Health.
- فعال‌سازی واقعی یا حذف/برچسب‌گذاری صادقانه دکمه افزایش ظرفیت انبار.
- بنچمارک FPS روی دستگاه هدف.

## جمع‌بندی
README با سه وضعیت انجام‌شده/ناقص/انجام‌نشده اصلاح شده است. موارد ناقص عمداً تیک کامل نگرفته‌اند. این ممیزی ادعای تکمیل کل بازی یا تأیید کیفیت بصری روی دستگاه فیزیکی نیست.
