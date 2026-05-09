# TXT Remaining Work

هذا الملف يسجل المتبقي من `txt.txt` بعد مراجعة النسخة الحالية من أوامر بلس.

## تم تنفيذه

- RBAC وصلاحيات مبنية على Permission Helpers.
- Compatibility layer للأدوار القديمة والجديدة.
- Seed للفروع الأساسية: الشرايع، الخضراء، العوالي، الستين، النوارية.
- Seed لمراكز وأقسام الإنتاج: المصنع، المطبخ، التورت، المعجنات، الشرقي، البيتي فور، الذبايح، السلطة، البوفيه.
- Product / Department Mapping.
- Department Work Orders.
- Delivery Batches.
- Cashbox / Daily Cash Closure.
- Audit Log.
- Idempotency Keys.
- Internal Notifications.
- Accounting flow مع Sales Order و Payment Entry و Sales Invoice.

## المتبقي حسب الأولوية

### 1. فصل حالات الطلب تشغيلياً

الـ backend يحتوي حقول الحالات المفصولة، لكن يجب تثبيت استخدامها في Flutter وكل الاستجابات:

- `order_status`
- `production_status`
- `packing_status`
- `delivery_status`
- `payment_status`
- `accounting_status`

الهدف: بقاء `status` كحقل توافق قديم، مع اعتماد الواجهات والتقارير على الحالات المفصولة تدريجياً.

### 2. جعل Delivery Batch هو مسار التوصيل الرسمي

يوجد Delivery Batch حالياً، لكن لا يزال يوجد مسار توافق قديم يربط السائق بالطلب مباشرة.

المطلوب النهائي:

- Driver -> Delivery Batch -> Orders
- عدم إسناد الطلبات مباشرة للسائق إلا كطبقة توافق مؤقتة.

تقدم التنفيذ:

- تم تحويل شاشة تفاصيل التوزيع للطلبات `Ready For Delivery` إلى زر تجهيز دفعة توصيل بدلاً من إسناد السائق مباشرة للطلب.
- إسناد السائق يتم من كروت `Delivery Batch`.
- بقي API الإسناد المباشر موجوداً كطبقة توافق مؤقتة للاختبارات وأي عميل قديم، لكنه الآن ينشئ/يستخدم `Delivery Batch` داخلياً ثم يسند الدفعة للسائق بدلاً من إنشاء مسار مستقل مباشر.
- تم تحديث Mock Service بحيث إسناد دفعة التوصيل يحدث الطلبات المرتبطة وينشئ Delivery Assignment، واستدعاء الإسناد المباشر القديم يمر عبر Delivery Batch.

### 3. Trip System لاحقاً

تصميم النظام يسمح لاحقاً بإضافة:

- Trip
- Trip يحتوي أكثر من Delivery Batch

لا يلزم تنفيذ Trip الآن.

### 4. Exception Reasons

إضافة أسباب جاهزة للاستثناءات:

- Production
- Delivery
- Payment
- Customer

مع إبقاء حقل الملاحظات الحر للحالات الخاصة.

تقدم التنفيذ:

- تم إضافة قاموس أسباب موحد في backend داخل `awamir_plus.constants`.
- تم إضافة API محمي:
  `awamir_plus.api.exceptions.get_exception_reasons`
- تم إضافة Model وmapping في Flutter للأسباب الجاهزة.
- تم إضافة Dialog موحد في Flutter يعرض أسباباً جاهزة مع حقل ملاحظات حر.
- تم ربطه مبدئياً في رفض/إرجاع موافقات المشرف، وتعذر التوصيل، وإرجاع العهدة.
- بقي ربطه لاحقاً في تأخير/رفض أوامر الإنتاج وفروقات العهدة التفصيلية.

### 5. Priority and Scheduling

الـ backend يحتوي حقول الأولوية والجدولة، والمتبقي إظهارها وضبطها في Flutter:

- `priority`
- `scheduled_at`
- `pickup_time`
- `delivery_window_start`
- `delivery_window_end`

تقدم التنفيذ:

- تم إضافة `OrderPriority` في Flutter مع labels عربية.
- تم ربط حقول الأولوية والجدولة في `CreateOrderRequest`.
- تم إرسال الحقول إلى API عند إنشاء/تعديل المسودة.
- تم قراءة الحقول من ERPNext داخل Order mapping.
- تم عرض الأولوية في تفاصيل المشرف/التوزيع/الإنتاج/استلام الفرع.
- تم إضافة عناصر اختيار مرئية في شاشة إنشاء الطلب للأولوية، موعد الجدولة، وقت الجاهزية، ونافذة التوصيل.

### 6. Production Capacity

يوجد `daily_capacity` على أقسام الإنتاج. المتبقي:

- حساب الطاقة اليومية المستخدمة.
- تحذير عند تجاوز الطاقة.
- تقرير/فلتر للطاقة حسب التاريخ والقسم.

تقدم التنفيذ:

- أوامر عمل الأقسام تحفظ snapshot للطاقة:
  `department_daily_capacity` و `department_open_work_orders_count`.
- شاشة الإنتاج تعرض الطاقة اليومية والتحذير إن وجد.
- تم تعديل حساب الطاقة ليحسب أوامر القسم المفتوحة لنفس `required_date` بدلاً من كل الأوامر المفتوحة.
- تم إضافة ملخص طاقة الإنتاج في شاشة الإنتاج مع progress واضح لكل جهة.
- بقي إنشاء تقرير إداري مستقل للطاقة حسب التاريخ والقسم.

### 7. Packing / Ready Area

إضافة مرحلة تغليف واضحة:

- `ready_for_packing`
- `packed`
- `ready`

ولا يدخل الطلب للتوصيل أو الاستلام إلا حسب إعدادات التغليف.

تقدم التنفيذ:

- تم عرض حالة التغليف في تفاصيل الإنتاج.
- تم تعديل أزرار الانتقال النهائي لتوضح أن التحويل إلى جاهز يعني "تم التغليف وجاهز".
- بقي فصل التغليف كصلاحية/شاشة مستقلة إذا قررنا تشغيل منطقة تغليف منفصلة عن الإنتاج.

### 8. Proof of Delivery

المتبقي توسيع إثبات التسليم:

- اسم المستلم.
- صورة.
- توقيع.
- QR scan.
- ملاحظات التسليم.

تقدم التنفيذ:

- حقول إثبات التسليم موجودة في backend وFlutter.
- شاشة الاستلام من الفرع وشاشة السائق تستخدم `DeliveryProofDialog`.
- يتم تمرير اسم المستلم، صورة/مسار الإثبات، التوقيع، QR، والملاحظات إلى APIs.
- بقي استبدال المسارات النصية برفع ملفات حقيقي عند تفعيل المرفقات.

### 9. Soft Delete and Cancellation

الإلغاء موجود للطلب، والمتبقي تعميم السياسة على الكيانات الحساسة:

- لا حذف نهائي.
- حفظ سبب الإلغاء.
- حفظ من ألغى ومتى.

تقدم التنفيذ:

- تم إضافة حقول الإلغاء الآمن للكيانات الحساسة:
  - `Awamir Delivery Batch`
  - `Awamir Department Work Order`
  - `Awamir Order Payment`
  - `Awamir Daily Cash Closure`
  - `Awamir Delivery Assignment`
- تم إضافة اختبار contract يتأكد من وجود حقول:
  `is_cancelled`, `cancelled_at`, `cancelled_by`, `cancellation_reason`.
- بقي لاحقاً إضافة APIs إلغاء متخصصة لكل كيان عند الحاجة التشغيلية، مع إبقاء عدم الحذف النهائي كقاعدة.

### 10. Accounting Automation

التدفق المحاسبي موجود، والمتبقي جعل الأتمتة حسب الإعدادات أوضح:

- إنشاء Sales Order تلقائياً عند الاعتماد إذا البيانات مكتملة.
- إنشاء Draft Sales Invoice عند Ready حسب الإعداد.
- إنشاء Draft Payment Entry عند قبول العهدة حسب الإعداد.

تقدم التنفيذ:

- تم ربط `create_sales_order_on_approval` بمسار موافقة المشرف:
  عند تفعيل الإعداد يحاول النظام إنشاء Sales Order تلقائياً، وأي خطأ يحفظ في `erp_sync_error` بدون كسر الموافقة التشغيلية.
- تم ربط `create_invoice_on_delivery` بمسار التسليم:
  عند تفعيل الإعداد يحاول النظام إنشاء Sales Invoice تلقائياً بعد تسليم الفرع أو تسليم السائق، وأي خطأ يحفظ في `erp_sync_error`.
- بقي لاحقاً تفعيل إنشاء Draft Payment Entry تلقائياً عند قبول العهدة إذا قررنا أن المحاسب لا يحتاج تشغيل زر الترحيل يدوياً.

### 11. Performance

مطلوب مراجعة نهائية لـ:

- pagination.
- indexes.
- filtering by branch/status/department.
- lazy loading في الشاشات الثقيلة.

تقدم التنفيذ:

- معظم APIs التشغيلية تستخدم `get_pagination` مع حد افتراضي آمن.
- تم إضافة pagination لقائمة Delivery Batches أيضاً حتى لا يتم جلب كل الدفعات دفعة واحدة.
- بقي لاحقاً مراجعة الفهارس داخل ERPNext حسب حجم البيانات الحقيقي بعد التشغيل، خصوصاً branch/status/department/date.

### 12. Documentation and Tests

إضافة توثيق واختبارات أكثر لمسارات:

- Department Work Orders.
- Delivery Batches.
- Audit Logs.
- Role migration.
- Split status model.

## خطة التنفيذ الحالية

الأولوية الحالية: تثبيت فصل الحالات المفصولة كطبقة توافق آمنة:

1. إضافة enums وحقول مقابلة في Flutter Order Model.
2. قراءة الحالات المفصولة من awamir_plus APIs.
3. إضافة fallback من `status` القديم إذا لم ترجع الحقول الجديدة.
4. مزامنة القيم الافتراضية في backend عند إنشاء/تعديل الطلب.
5. ترك `status` القديم فعالاً حتى لا ينكسر أي workflow.
