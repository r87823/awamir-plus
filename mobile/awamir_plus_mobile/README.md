# أوامر بلس Mobile

تطبيق Flutter Native عربي RTL لعمليات أوامر بلس. التطبيق يدعم وضعين:

- Mock mode للتطوير بدون ERPNext.
- Real mode للاتصال بـ `awamir_plus` داخل ERPNext/Frappe.

## التشغيل Mock

```bash
cd /Users/minii/2awamir/awamir-plus/mobile/awamir_plus_mobile
flutter pub get
flutter run --dart-define=USE_MOCK_DATA=true
```

حسابات mock:

| الدور | اسم المستخدم | كلمة المرور |
| --- | --- | --- |
| موظف فرع | `employee` | `123456` |
| مشرف فرع | `supervisor` | `123456` |
| مسؤول توزيع | `distribution` | `123456` |
| موظف إنتاج | `production` | `123456` |
| سائق | `driver` | `123456` |
| أمين صندوق | `cashier` | `123456` |
| محاسب | `accountant` | `123456` |
| مدير نظام | `admin` | `123456` |

## التشغيل Real ERPNext

```bash
flutter run \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=ERPNEXT_BASE_URL=https://awamirplus.r8787m.cc
```

تسجيل الدخول يتم عبر جلسة Frappe القياسية:

```text
POST /api/method/login
GET /api/method/awamir_plus.api.auth.get_current_user
```

لا تضع API Key أو API Secret داخل تطبيق Flutter.

## التحقق

```bash
flutter analyze
flutter test
```

## البنية

- `lib/core/constants`: إعدادات البيئة والثوابت.
- `lib/core/network`: ApiClient موحد لجلسات Frappe.
- `lib/core/errors`: أخطاء موحدة.
- `lib/core/permissions`: صلاحيات الأدوار.
- `lib/models`: نماذج الطلبات، الدفعات، العهد، المحاسبة.
- `lib/services`: `MockService` و `ErpnextService`.
- `lib/repositories`: اختيار مصدر البيانات حسب `USE_MOCK_DATA`.
- `lib/controllers`: منطق الشاشات وحالات التحميل.
- `lib/screens`: الواجهات.
- `lib/widgets`: مكونات قابلة لإعادة الاستخدام.

## تدفق MVP

التدفق المدعوم حالياً:

إنشاء طلب -> موافقة مشرف -> توزيع -> إنتاج -> استلام/توصيل -> تحصيل متبقي -> تسليم -> عهدة -> قبول أمين الصندوق -> Sales Order -> Payment Entry -> Sales Invoice -> ربط دفعات داخل Awamir.

## ملاحظات محاسبية

في نسخة MVP تظهر المستندات المحاسبية كـ Draft بوضوح داخل `AccountingScreen`. لا يتم عمل ledger posting في ERPNext حتى يتم تفعيل إعدادات submit لاحقاً من `Awamir App Settings`.
