# Awamir Plus Frappe App

تطبيق Frappe مستقل باسم `awamir_plus` لتشغيل باكند أوامر بلس داخل ERPNext بدون تعديل ERPNext Core.

## التثبيت

انسخ هذا المجلد إلى مجلد `apps` داخل bench أو اجلبه كمستودع مستقل، ثم نفذ:

```bash
bench get-app /path/to/awamir_plus
bench --site your-site.local install-app awamir_plus
bench --site your-site.local migrate
```

إذا كان التطبيق موجوداً داخل `apps/awamir_plus` مباشرة:

```bash
bench --site your-site.local install-app awamir_plus
bench --site your-site.local migrate
```

## الأدوار

- `Awamir Branch Employee`
- `Awamir Branch Supervisor`
- `Awamir Distribution Manager`
- `Awamir Production User`
- `Awamir Driver`
- `Awamir Cashier`
- `Awamir Accountant`
- `Awamir System Admin`

تُنشأ الأدوار عبر fixtures و `after_install`.

## DocTypes

- `Awamir Order Request`
- `Awamir Order Request Item`
- `Awamir Order Attachment`
- `Awamir Order Status Log`
- `Awamir Order Payment`
- `Awamir Daily Cash Closure`
- `Awamir Cash Closure Log`
- `Awamir Delivery Assignment`
- `Awamir Notification`
- `Awamir Production Department`
- `Awamir Product Department Mapping`
- `Awamir App Settings`

التطبيق يربط مع DocTypes الأصلية في ERPNext مثل `Customer`, `Address`, `Item`, `Item Group`, `Sales Order`, `Work Order`, `Payment Entry`, و `Sales Invoice`.

## إعدادات Awamir App Settings

اضبط القيم التالية قبل التشغيل الفعلي:

- `default_company`
- `default_price_list`
- `default_warehouse`
- `default_currency`
- `require_deposit_before_production`
- `create_sales_order_on_approval`
- `create_work_order_on_distribution`
- `create_invoice_on_delivery`
- `allow_delivery_without_full_payment`
- `enable_driver_cash_closure`

## APIs

كل APIs موجودة داخل:

```text
awamir_plus/api/
```

أهم المسارات:

- `awamir_plus.api.auth.get_current_user`
- `awamir_plus.api.products.get_categories`
- `awamir_plus.api.products.get_products_by_category`
- `awamir_plus.api.customers.search_customer_by_phone`
- `awamir_plus.api.customers.create_customer`
- `awamir_plus.api.orders.save_order_as_draft`
- `awamir_plus.api.orders.submit_order_for_approval`
- `awamir_plus.api.approvals.approve_order`
- `awamir_plus.api.approvals.reject_order`
- `awamir_plus.api.distribution.assign_production_department`
- `awamir_plus.api.production.update_production_status`
- `awamir_plus.api.delivery.assign_driver_to_order`
- `awamir_plus.api.delivery.update_delivery_status`
- `awamir_plus.api.cash_closure.submit_cash_closure`
- `awamir_plus.api.cash_closure.accept_cash_closure`
- `awamir_plus.api.accounting.create_sales_order_for_order`
- `awamir_plus.api.accounting.create_payment_entry_for_payment`
- `awamir_plus.api.accounting.create_sales_invoice_for_order`
- `awamir_plus.api.accounting.allocate_advance_payment_to_invoice`
- `awamir_plus.api.notifications.get_notifications`

## أمثلة API

استدعاء المستخدم الحالي:

```http
GET /api/method/awamir_plus.api.auth.get_current_user
```

إنشاء طلب كمسودة:

```http
POST /api/method/awamir_plus.api.orders.save_order_as_draft
Content-Type: application/json

{
  "order_data": {
    "customer_name": "عميل تجريبي",
    "customer_phone": "0500000000",
    "customer_type": "Individual",
    "created_branch": "Main Branch",
    "delivery_type": "Pickup",
    "required_date": "2026-05-10",
    "required_time": "18:00:00",
    "deposit_amount": 100,
    "payment_method": "Cash",
    "items": [
      {
        "item_code": "ITEM-001",
        "item_name": "منتج تجريبي",
        "qty": 2,
        "rate": 150,
        "amount": 300,
        "product_category": "Products",
        "requires_work_order": 1
      }
    ]
  }
}
```

اعتماد طلب:

```http
POST /api/method/awamir_plus.api.approvals.approve_order

{
  "order": "ORD-2026-00001"
}
```

ترحيل دفعة:

```http
POST /api/method/awamir_plus.api.accounting.create_payment_entry_for_payment

{
  "payment": "PAY-0001"
}
```

## الربط مع Flutter

في Flutter يتم تبديل `useMockData` إلى `false` لاحقاً، ثم تجعل `ErpnextService` يستدعي:

```text
/api/method/awamir_plus.api.<module>.<function>
```

تسجيل الدخول يمكن أن يبقى عبر جلسة Frappe القياسية، وبعدها يستدعي Flutter:

```text
awamir_plus.api.auth.get_current_user
```

للحصول على المستخدم، الأدوار، الفرع، قسم الإنتاج، وبيانات السائق.

## الاختبارات والتحقق

فحص البنية محلياً بدون bench:

```bash
python3 scripts/verify_structure.py
python3 -m compileall awamir_plus
```

داخل bench:

```bash
bench --site your-site.local run-tests --app awamir_plus
```

## ملاحظات الأمان

- كل API تتحقق من الجلسة والدور في الباكند.
- لا يعتمد التطبيق على إخفاء الأزرار في Flutter فقط.
- موظف الفرع مقيد بفرعه وطلباته.
- المشرف مقيد بطلبات فرعه.
- السائق مقيد بالطلبات المسندة له.
- موظف الإنتاج مقيد بجهة التنفيذ التابعة له.
- المحاسب لا يدير الحالات التشغيلية.
- أمين الصندوق لا يعدل بيانات الطلبات.
- العمليات المحاسبية idempotent قدر الإمكان: لا تنشئ Sales Order أو Work Order أو Payment Entry أو Sales Invoice مرتين إذا كان الرقم محفوظاً مسبقاً.

## ملاحظات تنفيذية

- هذا التطبيق لا يعدل ERPNext Core.
- التخصيص الوحيد على ERPNext القياسي هو Custom Fields على `Address` لحفظ رابط Google Maps والإحداثيات.
- APIs المحاسبية تنشئ مستندات ERPNext الأصلية عند استدعائها داخل بيئة ERPNext مضبوطة.
- يجب ضبط الحسابات الافتراضية المطلوبة من ERPNext مثل حسابات الدفع وطرق الدفع قبل التشغيل الإنتاجي.

