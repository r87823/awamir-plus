# أوامر بلس Mobile

تطبيق Flutter Native لواجهات موظف الفرع في أوامر بلس. التطبيق حالياً يعمل على بيانات تجريبية، ومجهز بطبقات واضحة للربط لاحقاً مع ERPNext/Frappe API بدون تغيير الشاشات.

## التشغيل

```bash
cd /Users/minii/2awamir/awamir_plus_mobile
flutter pub get
flutter run
```

## التحقق

```bash
flutter analyze
flutter test
```

## تسجيل الدخول التجريبي

كل الحسابات تستخدم كلمة المرور:

```text
123456
```

| الدور | اسم المستخدم |
| --- | --- |
| موظف فرع | `employee` |
| مشرف فرع | `supervisor` |
| مسؤول توزيع | `distribution` |
| موظف مصنع | `production` |
| سائق | `driver` |
| أمين صندوق | `cashier` |
| محاسب | `accountant` |
| مدير نظام | `admin` |

في وضع mock يتم حفظ اسم المستخدم محلياً عبر `shared_preferences` لاستعادة الجلسة مؤقتاً أثناء التطوير.

## مصدر البيانات

الإعداد الحالي موجود في:

`lib/core/constants/environment.dart`

```dart
static const useMockData = true;
```

عند تجهيز الربط الحقيقي مع ERPNext لاحقاً، يتم تغييرها إلى `false` بعد تنفيذ دوال `ErpnextService`.

## البنية

- `lib/core/constants`: إعدادات البيئة والثوابت العامة.
- `lib/core/theme`: الهوية البصرية والثيم.
- `lib/core/utils`: أدوات عامة مثل التنسيق وحالات العرض.
- `lib/core/errors`: أخطاء موحدة للتعامل مع الخدمات والمستودعات.
- `lib/core/permissions`: الصلاحيات وربط الأدوار بالصفحات.
- `lib/models`: نماذج البيانات المشتركة.
- `lib/services`: مصادر البيانات، حالياً `MockService` وجاهزاً `ErpnextService`.
- `lib/repositories`: طبقة وسيطة تختار Mock أو ERPNext حسب الإعداد.
- `lib/controllers`: منطق الحالة والتحميل والتعامل مع الواجهات.
- `lib/screens`: شاشات التطبيق.
- `lib/widgets`: مكونات UI قابلة لإعادة الاستخدام.

## ملاحظات الربط القادم

الشاشات لا تقرأ `mock_data` مباشرة. التدفق الحالي:

`Screens -> Controllers -> Repositories -> MockService/ErpnextService`

هذا يسمح بإبقاء التصميم الحالي يعمل، ثم استبدال المصدر لاحقاً بدوال Frappe API داخل `ErpnextService`.
