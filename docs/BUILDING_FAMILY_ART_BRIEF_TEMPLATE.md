# قالب برگه طراحی و تحویل هر خانواده ساختمان — Mshin

> از این قالب برای هر family و سپس هر buildingId استفاده شود. خانه خالی یا TBD نشانه تصمیم باز است؛ مقدار ساختگی وارد نکنید.

## A. هویت و مالکیت
- familyId:
- buildingId:
- نام نمایشی (کلید localization):
- دسته: Residential / Commercial / Industrial / Civic / Infrastructure / Recreation / Landmark
- operationalClass: Operational / Decorative / Hybrid
- design owner:
- gameplay owner:
- art version:
- definition/schema version:

## B. نقش و هویت بصری
- هدف و حس موردنظر:
- شخصیت معماری:
- silhouette از Far:
- عناصر شناسایی از Mid:
- جزئیات نزدیک:
- roofline:
- ورودی اصلی:
- palette پایه:
- accent:
- مصالح:
- مواردی که نباید شبیه آن شود:
- reference board و provenance تصاویر:

## C. footprint و فضا
- logical footprint:
- render bounds:
- height envelope:
- access envelope:
- pedestrian access:
- vehicle/loading access:
- service sockets:
- camera focus:
- selection proxy:
- placement restrictions:
- neighbor clearance:
- collision profile:

## D. ماتریس tierها

| Tier ID | تغییر حجم/سیلوئت | تغییر نما/پنجره | سقف/تجهیزات | محوطه/نور | functional delta | هزینه/مواد | downtime |
|---|---|---|---|---|---|---|---|
| T01 | TBD | TBD | TBD | TBD | فقط از simulation | TBD | TBD |
| T02 | TBD | TBD | TBD | TBD | فقط از simulation | TBD | TBD |
| T03 | TBD | TBD | TBD | TBD | فقط از simulation | TBD | TBD |

- تعداد tierهای این ساختمان:
- شرط unlock:
- شرط upgrade:
- تغییرات ممنوع یا غیرواقعی:
- رفتار در rollback/save migration:

## E. ماتریس stateهای بصری

| Simulation state | visual variant | animation/VFX | UI indicator | fallback |
|---|---|---|---|---|
| Preview | TBD | none/preview | valid/invalid | base ghost |
| Construction | TBD | scaffold/progress | progress واقعی | static stage |
| Operational | TBD | state-driven | healthy | static healthy |
| Idle | TBD | idle only | idle | static idle |
| Input shortage | TBD | reduced/stopped | shortage | warning icon |
| Output blocked | TBD | blocked activity | blocked | warning icon |
| Utility disconnected | TBD | type-specific off | disconnected | icon/text |
| Damaged | TBD | severity-based | damage | damaged static |
| Maintenance | TBD | repair crew optional | maintenance | static scaffold |
| Disabled | TBD | no operation | disabled | static off |

## F. Asset inventory و provenance

| assetId | filename/source | role | license | archive SHA-256 | imported SHA-256 | status |
|---|---|---|---|---|---|---|
| TBD | TBD | mesh/material/texture/audio/VFX | TBD | TBD | TBD | Candidate |

- منبع اصلی و URL دقیق:
- نام سازنده:
- نسخه بسته:
- فایل license نگهداری‌شده:
- اجازه استفاده تجاری:
- اجازه اصلاح:
- اجازه توزیع در بازی:
- attribution:
- derivative mapping:
- rejection notes:

## G. قرارداد فنی
- source format:
- runtime format:
- coordinate convention:
- pivot:
- unit scale:
- prefab path:
- material count:
- texture inventory:
- LOD0/1/2:
- collider:
- sockets:
- batching/instancing:
- occlusion/culling:
- fallback asset:
- import validation:
- build compatibility:

## H. کیفیت و خروجی هنری
- preview neutral:
- thumbnail:
- icon:
- silhouette sheet:
- tier comparison:
- state sheet:
- Day/Golden Hour/Night:
- Low/Medium/High:
- mobile screenshot:
- RTL/LTR UI context:
- accessibility review:

## I. تست و پذیرش
- art review:
- tech art review:
- gameplay/state mapping test:
- placement/access test:
- save/load test:
- missing asset fallback:
- performance profile:
- device/build identifiers:
- unresolved defects:
- evidence links:
- final status: Candidate / In Review / Approved / Integrated / Device Verified / Rejected

## J. امضای تکمیل
- Art approval:
- Technical approval:
- Gameplay approval:
- License approval:
- Device QA approval:
- date/version:

**قاعده:** Approved به معنی Integrated نیست؛ Integrated به معنی Device Verified نیست. هر مرحله مدرک مستقل می‌خواهد.
