# Awamir Plus Pilot Release v0.1

Date: 2026-05-03
Tag: `v0.1-pilot`

## ملخص النسخة

هذه نسخة Pilot تشغيلية من أوامر بلس تربط تطبيق Flutter مع تطبيق Frappe المخصص `awamir_plus` داخل ERPNext. النسخة تغطي مسار الطلب التشغيلي الكامل من إنشاء الطلب حتى التسليم والمحاسبة، مع تفعيل submit المحاسبي بشكل مضبوط لـ Sales Order وPayment Entry وSales Invoice، وإبقاء Work Order في وضع الجاهزية فقط.

النسخة مخصصة للتجربة التشغيلية المحدودة والموسعة، وليست بعد نسخة تشغيل نهائي واسع.

## ما تم إنجازه

- تطبيق Flutter عربي RTL به mock mode وreal mode.
- Custom Frappe app باسم `awamir_plus` بدون تعديل ERPNext Core.
- أدوار وصلاحيات أوامر بلس داخل Frappe.
- DocTypes تشغيلية للطلبات، الدفعات، العهد، التوصيل، الإنتاج، الإشعارات، والتزامن المحاسبي.
- APIs حقيقية للربط مع Flutter:
  - تسجيل الدخول والمستخدم الحالي.
  - المنتجات والأقسام والعملاء والعناوين.
  - إنشاء الطلب.
  - موافقات مشرف الفرع.
  - التوزيع وجهات التنفيذ.
  - الإنتاج.
  - الاستلام من الفرع والتوصيل والسائقين.
  - العهد اليومية وأمين الصندوق.
  - المحاسبة داخل ERPNext.
- Seed/demo data للفروع، المنتجات، الأسعار، المستخدمين، جهات التنفيذ، العملاء، والعناوين.
- تقارير Pilot وتفعيل submit المرحلي.
- اختبار Work Order Readiness على منتج واحد فقط مع BOM.

## الإعدادات الحالية

| Setting | Current value |
| --- | ---: |
| `submit_sales_order` | `1` |
| `submit_payment_entry` | `1` |
| `submit_sales_invoice` | `1` |
| `submit_work_order` | `0` |

الإعدادات المحاسبية الفعلية تعتمد على `Awamir App Settings` داخل ERPNext، ويجب مراجعتها قبل أي تجربة جديدة.

## حالة Submit لكل مستند

| ERPNext document | Release behavior |
| --- | --- |
| Sales Order | يتم إنشاؤه ثم submit إذا كان `submit_sales_order = 1` |
| Payment Entry | يتم إنشاؤه ثم submit إذا كان `submit_payment_entry = 1` |
| Sales Invoice | يتم إنشاؤه ثم submit إذا كان `submit_sales_invoice = 1` |
| Work Order | يتم إنشاؤه Draft فقط، لأن `submit_work_order = 0` |

## مسار الطلب الكامل

المسار المدعوم في هذه النسخة:

1. موظف الفرع ينشئ الطلب ويرسله للموافقة.
2. مشرف الفرع يوافق، يرفض، أو يرجع الطلب للتعديل.
3. مسؤول التوزيع يحول الطلب إلى جهة التنفيذ.
4. موظف الإنتاج يحدث الحالات حتى `Ready For Pickup` أو `Ready For Delivery`.
5. موظف الفرع يسلم طلبات الاستلام من الفرع بعد تصفية المتبقي.
6. مسؤول التوزيع يسند طلبات التوصيل إلى السائق.
7. السائق يحدث حالات التوصيل حتى `Delivered` أو `Delivery Failed`.
8. الموظف أو السائق يرسل عهدته اليومية.
9. أمين الصندوق يقبل العهدة أو يرجعها أو يغلقها.
10. المحاسب ينشئ Sales Order وPayment Entry وSales Invoice.
11. أوامر بلس يسجل ربط الدفعات بالفاتورة داخلياً ويمنع التكرار.

## حالة Work Order

Work Order لم يتم تفعيل submit له في هذه النسخة.

نتيجة الجاهزية:

| Field | Value |
| --- | --- |
| Product | `AWAMIR-SPECIAL-DESSERT` |
| BOM | `BOM-AWAMIR-SPECIAL-DESSERT-001` |
| Test order | `ORD-2026-00052` |
| Work Order | `MFG-WO-2026-00001` |
| Work Order docstatus | `0` |
| Work Order status | `Draft` |

المنتجات التي لا تحتوي BOM لا تزال ترجع الخطأ الواضح:

```text
لا يمكن إنشاء Work Order لأن المنتج لا يحتوي BOM
```

## القيود الحالية

- هذه نسخة Pilot وليست نسخة تشغيل نهائي.
- Work Order submit غير مفعل.
- تم تجهيز BOM لمنتج واحد فقط.
- لا يوجد Payment Gateway خارجي.
- الإشعارات داخل النظام فقط، ولا توجد Push Notifications.
- ربط الدفعات بالفاتورة يتم بشكل آمن داخل أوامر بلس، ومع Payment Entry submitted لا يتم تعديل المستند submitted مباشرة.
- يجب مراجعة الحسابات، الضرائب، المخازن، وMode of Payment في ERPNext قبل التشغيل الفعلي.
- أي تفعيل جديد لـ Work Order submit يحتاج BOMs واقعية وإعداد Manufacturing كامل.

## خطوات الاختبار السريع

Backend:

```bash
python3 -m compileall backend/awamir_plus/awamir_plus
```

Flutter mock mode:

```bash
cd mobile/awamir_plus_mobile
flutter run --dart-define=USE_MOCK_DATA=true
```

Flutter real mode:

```bash
cd mobile/awamir_plus_mobile
flutter run \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=ERPNEXT_BASE_URL=https://awamirplus.r8787m.cc
```

Flutter checks:

```bash
cd mobile/awamir_plus_mobile
flutter analyze
flutter test
```

API smoke checks:

- Login through Frappe session.
- `awamir_plus.api.auth.get_current_user`
- `awamir_plus.api.products.get_categories`
- `awamir_plus.api.products.get_products_by_category`
- `awamir_plus.api.orders.create_order`
- `awamir_plus.api.accounting.create_sales_order_for_order`

## خطوات الرجوع للخلف إن لزم

1. إيقاف أي اختبار تشغيلي جديد مؤقتاً.
2. أخذ backup جديد للحالة الحالية قبل الرجوع، إن كانت هناك بيانات تحتاج حفظاً.
3. إرجاع submit flags في `Awamir App Settings` حسب الحاجة:
   - `submit_sales_order = 0`
   - `submit_payment_entry = 0`
   - `submit_sales_invoice = 0`
   - `submit_work_order = 0`
4. استخدام أحدث backup موثق لاستعادة الموقع إذا احتاجت البيئة إلى rollback كامل.
5. عدم تعديل ERPNext Core أثناء الرجوع.
6. توثيق رقم الطلب أو المستند الذي سبب الرجوع قبل إعادة الاختبار.

## توصيات التشغيل التجريبي

- تنفيذ Pilot على مستخدمين محددين فقط لكل دور.
- عدم تفعيل `submit_work_order` قبل مراجعة BOMs والمخازن والتصنيع.
- اختبار طلبات Pickup وDelivery يومياً مع أكثر من طريقة دفع.
- مراجعة العهد اليومية مع أمين الصندوق قبل الترحيل المحاسبي.
- مراجعة GL Entries بعد كل دفعة وفاتورة submitted في ERPNext.
- الاحتفاظ بنسخة backup قبل أي تغيير submit أو إعداد محاسبي.
- فتح سجل ملاحظات تشغيلية للواجهة، الصلاحيات، الفروقات النقدية، وأخطاء ERPNext validation.
