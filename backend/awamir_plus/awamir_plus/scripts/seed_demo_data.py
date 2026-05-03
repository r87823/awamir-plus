from __future__ import annotations

import re

import frappe
from frappe.utils import cint, flt

from awamir_plus.constants import AWAMIR_ROLES
from awamir_plus.install import create_custom_fields, create_default_settings, create_roles
from awamir_plus.utils import extract_coordinates_from_google_maps_url


DEMO_BRANCHES = ["فرع المروج", "فرع الشرائع", "فرع العزيزية"]

DEMO_DEPARTMENTS = [
    {"name": "مصنع الحلويات", "code": "SWEETS_FACTORY", "branch": "فرع المروج"},
    {"name": "المطبخ", "code": "KITCHEN", "branch": "فرع الشرائع"},
    {"name": "قسم البوفيه", "code": "BUFFET", "branch": "فرع العزيزية"},
    {"name": "قسم الطلبات الخاصة", "code": "SPECIAL_ORDERS", "branch": "فرع المروج"},
]

DEMO_ITEM_GROUPS = ["طلبات خاصة", "طلبات البوفيه", "الحلويات", "المطبخ", "الضيافة"]

DEMO_PRODUCTS = [
    {"code": "AWAMIR-CUSTOM-CAKE", "name": "كيكة مخصصة", "group": "طلبات خاصة", "rate": 350},
    {"code": "AWAMIR-VIP-GIFT-BOX", "name": "بوكس ضيافة فاخر", "group": "طلبات خاصة", "rate": 220},
    {"code": "AWAMIR-SPECIAL-DESSERT", "name": "طبق حلى خاص", "group": "طلبات خاصة", "rate": 180},
    {"code": "AWAMIR-BUFFET-20", "name": "بوفيه 20 شخص", "group": "طلبات البوفيه", "rate": 1200},
    {"code": "AWAMIR-BUFFET-50", "name": "بوفيه 50 شخص", "group": "طلبات البوفيه", "rate": 2750},
    {"code": "AWAMIR-MINI-BUFFET", "name": "بوفيه مصغر", "group": "طلبات البوفيه", "rate": 650},
    {"code": "AWAMIR-KUNAFA", "name": "كنافة", "group": "الحلويات", "rate": 95},
    {"code": "AWAMIR-CHOCOLATE-TRAY", "name": "صينية شوكولاتة", "group": "الحلويات", "rate": 160},
    {"code": "AWAMIR-MAMOUL-BOX", "name": "معمول فاخر", "group": "الحلويات", "rate": 85},
    {"code": "AWAMIR-MIX-PASTRIES", "name": "فطائر مشكلة", "group": "المطبخ", "rate": 140},
    {"code": "AWAMIR-MINI-SANDWICH", "name": "ساندويتشات ميني", "group": "المطبخ", "rate": 110},
    {"code": "AWAMIR-HOT-APPETIZERS", "name": "مقبلات ساخنة", "group": "المطبخ", "rate": 125},
    {"code": "AWAMIR-COFFEE-DATES", "name": "قهوة وتمر", "group": "الضيافة", "rate": 75},
    {"code": "AWAMIR-HOSPITALITY-SET", "name": "طقم ضيافة", "group": "الضيافة", "rate": 190},
    {"code": "AWAMIR-ARABIC-COFFEE-THERMOS", "name": "ترمس قهوة عربية", "group": "الضيافة", "rate": 60},
]

DEPARTMENT_MAPPING = {
    "الحلويات": "مصنع الحلويات",
    "طلبات البوفيه": "قسم البوفيه",
    "المطبخ": "المطبخ",
    "طلبات خاصة": "قسم الطلبات الخاصة",
    "الضيافة": "قسم الطلبات الخاصة",
}

DEMO_USERS = [
    {
        "email": "employee@awamir.plus",
        "full_name": "موظف فرع أوامر",
        "role": "Awamir Branch Employee",
        "branch": "فرع المروج",
    },
    {
        "email": "supervisor@awamir.plus",
        "full_name": "مشرف فرع أوامر",
        "role": "Awamir Branch Supervisor",
        "branch": "فرع المروج",
    },
    {
        "email": "distribution@awamir.plus",
        "full_name": "مسؤول توزيع أوامر",
        "role": "Awamir Distribution Manager",
        "branch": "فرع المروج",
    },
    {
        "email": "production@awamir.plus",
        "full_name": "موظف إنتاج أوامر",
        "role": "Awamir Production User",
        "branch": "فرع المروج",
        "production_department": "مصنع الحلويات",
    },
    {
        "email": "driver@awamir.plus",
        "full_name": "سائق أوامر",
        "role": "Awamir Driver",
        "branch": "فرع المروج",
    },
    {
        "email": "cashier@awamir.plus",
        "full_name": "أمين صندوق أوامر",
        "role": "Awamir Cashier",
        "branch": "فرع المروج",
    },
    {
        "email": "accountant@awamir.plus",
        "full_name": "محاسب أوامر",
        "role": "Awamir Accountant",
        "branch": "فرع المروج",
    },
    {
        "email": "admin@awamir.plus",
        "full_name": "مدير نظام أوامر",
        "role": "Awamir System Admin",
        "branch": "فرع المروج",
    },
]

DEMO_CUSTOMERS = [
    {
        "customer_name": "عميل أوامر التجريبي",
        "customer_type": "Individual",
        "mobile_no": "0500000001",
    },
    {
        "customer_name": "شركة أوامر التجريبية",
        "customer_type": "Company",
        "mobile_no": "0500000002",
        "tax_id": "300000000000003",
    },
]

DEMO_MAPS_URL = "https://maps.google.com/?q=21.488775,39.930210"


def run(reset_passwords=False, demo_password=None):
    """Seed safe Awamir Plus demo data.

    This function is idempotent: it creates missing demo records and leaves
    existing records in place. Existing users keep their password unless
    reset_passwords is true.
    """

    reset_passwords = cint(reset_passwords)
    demo_password = demo_password or frappe.conf.get("awamir_demo_password") or "Awamir@123456"
    summary = _new_summary()

    create_roles()
    create_custom_fields()
    create_default_settings()

    defaults = _resolve_defaults(summary)
    _ensure_branches(defaults, summary)
    _ensure_production_departments(summary)
    _ensure_item_groups(summary)
    _ensure_items_and_prices(defaults, summary)
    _ensure_department_mappings(summary)
    _deactivate_duplicate_demo_mappings(summary)
    _ensure_users(demo_password, reset_passwords, summary)
    _ensure_customers_and_addresses(summary)

    frappe.db.commit()
    return summary


def _new_summary():
    return {
        "created": {},
        "existing": {},
        "updated": {},
        "defaults": {},
        "demo_users": [row["email"] for row in DEMO_USERS],
        "demo_customer_phones": [row["mobile_no"] for row in DEMO_CUSTOMERS],
    }


def _bump(summary, bucket, key):
    summary.setdefault(bucket, {})
    summary[bucket][key] = summary[bucket].get(key, 0) + 1


def _resolve_defaults(summary):
    settings = frappe.get_single("Awamir App Settings")
    company = settings.default_company or frappe.defaults.get_user_default("Company") or frappe.defaults.get_global_default("company")
    if not company:
        company = frappe.db.get_value("Company", {}, "name")

    currency = settings.default_currency or frappe.defaults.get_global_default("currency") or "SAR"
    price_list = settings.default_price_list or _get_or_create_price_list(currency, summary)
    warehouse = settings.default_warehouse or frappe.db.get_value("Warehouse", {"disabled": 0}, "name")

    updates = {}
    if company and not settings.default_company:
        updates["default_company"] = company
    if price_list and not settings.default_price_list:
        updates["default_price_list"] = price_list
    if warehouse and not settings.default_warehouse:
        updates["default_warehouse"] = warehouse
    if currency and not settings.default_currency:
        updates["default_currency"] = currency

    if updates:
        settings.update(updates)
        settings.save(ignore_permissions=True)
        _bump(summary, "updated", "Awamir App Settings")

    summary["defaults"] = {
        "company": company,
        "currency": currency,
        "price_list": price_list,
        "warehouse": warehouse,
    }
    return summary["defaults"]


def _get_or_create_price_list(currency, summary):
    existing = (
        frappe.db.get_value("Price List", {"selling": 1, "enabled": 1}, "name")
        or frappe.db.get_value("Price List", {"selling": 1}, "name")
    )
    if existing:
        return existing

    name = "Awamir Demo Selling"
    if not frappe.db.exists("Price List", name):
        frappe.get_doc(
            {
                "doctype": "Price List",
                "price_list_name": name,
                "enabled": 1,
                "selling": 1,
                "buying": 0,
                "currency": currency or "SAR",
            }
        ).insert(ignore_permissions=True)
        _bump(summary, "created", "Price List")
    else:
        _bump(summary, "existing", "Price List")
    return name


def _doctype_has_field(doctype, fieldname):
    try:
        return frappe.get_meta(doctype).has_field(fieldname)
    except Exception:
        return False


def _ensure_branches(defaults, summary):
    has_company = _doctype_has_field("Branch", "company")
    for branch in DEMO_BRANCHES:
        if frappe.db.exists("Branch", branch):
            _bump(summary, "existing", "Branch")
            continue
        doc = {"doctype": "Branch", "branch": branch}
        if has_company and defaults.get("company"):
            doc["company"] = defaults["company"]
        frappe.get_doc(doc).insert(ignore_permissions=True)
        _bump(summary, "created", "Branch")


def _ensure_production_departments(summary):
    for department in DEMO_DEPARTMENTS:
        existing = frappe.db.get_value(
            "Awamir Production Department",
            {"department_code": department["code"]},
            "name",
        )
        if existing:
            _bump(summary, "existing", "Awamir Production Department")
            continue
        doc = frappe.get_doc(
            {
                "doctype": "Awamir Production Department",
                "department_name": department["name"],
                "department_code": department["code"],
                "branch": department["branch"] if frappe.db.exists("Branch", department["branch"]) else None,
                "is_active": 1,
            }
        ).insert(ignore_permissions=True)
        _bump(summary, "created", "Awamir Production Department")


def _ensure_item_groups(summary):
    parent = _get_or_create_root_item_group(summary)
    for group in DEMO_ITEM_GROUPS:
        if frappe.db.exists("Item Group", group):
            _bump(summary, "existing", "Item Group")
            continue
        frappe.get_doc(
            {
                "doctype": "Item Group",
                "item_group_name": group,
                "parent_item_group": parent,
                "is_group": 0,
            }
        ).insert(ignore_permissions=True)
        _bump(summary, "created", "Item Group")


def _get_or_create_root_item_group(summary):
    if frappe.db.exists("Item Group", "All Item Groups"):
        return "All Item Groups"

    root = frappe.db.get_value("Item Group", {"is_group": 1}, "name")
    if root:
        return root

    frappe.get_doc(
        {
            "doctype": "Item Group",
            "item_group_name": "All Item Groups",
            "is_group": 1,
        }
    ).insert(ignore_permissions=True)
    _bump(summary, "created", "Item Group")
    return "All Item Groups"


def _get_stock_uom():
    return (
        frappe.db.get_value("UOM", "Nos", "name")
        or frappe.db.get_value("UOM", "وحدة", "name")
        or frappe.db.get_value("UOM", {}, "name")
        or "Nos"
    )


def _ensure_items_and_prices(defaults, summary):
    stock_uom = _get_stock_uom()
    for product in DEMO_PRODUCTS:
        if not frappe.db.exists("Item", product["code"]):
            item = {
                "doctype": "Item",
                "item_code": product["code"],
                "item_name": product["name"],
                "description": product["name"],
                "item_group": product["group"],
                "stock_uom": stock_uom,
                "disabled": 0,
                "is_stock_item": 0,
                "include_item_in_manufacturing": 1,
            }
            frappe.get_doc(item).insert(ignore_permissions=True)
            _bump(summary, "created", "Item")
        else:
            _bump(summary, "existing", "Item")

        _ensure_item_price(product, defaults, summary)


def _ensure_item_price(product, defaults, summary):
    price_list = defaults.get("price_list")
    if not price_list:
        _bump(summary, "existing", "Item Price skipped without Price List")
        return

    exists = frappe.db.exists(
        "Item Price",
        {"item_code": product["code"], "price_list": price_list},
    )
    if exists:
        _bump(summary, "existing", "Item Price")
        return

    frappe.get_doc(
        {
            "doctype": "Item Price",
            "item_code": product["code"],
            "price_list": price_list,
            "price_list_rate": flt(product["rate"]),
            "currency": defaults.get("currency") or "SAR",
            "selling": 1,
        }
    ).insert(ignore_permissions=True)
    _bump(summary, "created", "Item Price")


def _ensure_department_mappings(summary):
    for item_group, department in DEPARTMENT_MAPPING.items():
        _ensure_mapping(
            name=f"AWAMIR-DEMO-MAP-GROUP-{_slug(item_group)}",
            item_group=item_group,
            item_code=None,
            department=department,
            summary=summary,
        )

    for product in DEMO_PRODUCTS:
        department = DEPARTMENT_MAPPING.get(product["group"])
        if not department:
            continue
        _ensure_mapping(
            name=f"AWAMIR-DEMO-MAP-ITEM-{product['code']}",
            item_group=product["group"],
            item_code=product["code"],
            department=department,
            summary=summary,
        )


def _ensure_mapping(name, item_group, item_code, department, summary):
    department_name = _get_production_department_name(department)
    if not department_name:
        _bump(summary, "existing", "Awamir Product Department Mapping skipped without Department")
        return

    if _find_active_mapping(item_group, item_code, department_name):
        _bump(summary, "existing", "Awamir Product Department Mapping")
        return

    frappe.get_doc(
        {
            "doctype": "Awamir Product Department Mapping",
            "name": name,
            "item_group": item_group,
            "item_code": item_code,
            "production_department": department_name,
            "requires_work_order": 1,
            "is_active": 1,
        }
    ).insert(ignore_permissions=True)
    _bump(summary, "created", "Awamir Product Department Mapping")


def _find_active_mapping(item_group, item_code, department):
    rows = frappe.get_all(
        "Awamir Product Department Mapping",
        filters={
            "item_group": item_group,
            "production_department": department,
            "is_active": 1,
        },
        fields=["name", "item_code"],
    )
    if item_code:
        return next((row.name for row in rows if row.item_code == item_code), None)
    return next((row.name for row in rows if not row.item_code), None)


def _deactivate_duplicate_demo_mappings(summary):
    combinations = []
    for item_group, department in DEPARTMENT_MAPPING.items():
        combinations.append((item_group, None, department))
    for product in DEMO_PRODUCTS:
        department = DEPARTMENT_MAPPING.get(product["group"])
        if department:
            combinations.append((product["group"], product["code"], department))

    for item_group, item_code, department in combinations:
        department_name = _get_production_department_name(department)
        if not department_name:
            continue
        rows = frappe.get_all(
            "Awamir Product Department Mapping",
            filters={
                "item_group": item_group,
                "production_department": department_name,
                "is_active": 1,
            },
            fields=["name", "item_code", "creation"],
            order_by="creation asc",
        )
        if item_code:
            matching = [row for row in rows if row.item_code == item_code]
        else:
            matching = [row for row in rows if not row.item_code]
        for duplicate in matching[1:]:
            frappe.db.set_value("Awamir Product Department Mapping", duplicate.name, "is_active", 0)
            _bump(summary, "updated", "Awamir Product Department Mapping duplicate")


def _get_production_department_name(label_or_name):
    return (
        frappe.db.get_value("Awamir Production Department", label_or_name, "name")
        or frappe.db.get_value("Awamir Production Department", {"department_name": label_or_name}, "name")
        or frappe.db.get_value("Awamir Production Department", {"department_code": label_or_name}, "name")
    )


def _ensure_users(demo_password, reset_passwords, summary):
    for role in AWAMIR_ROLES:
        if not frappe.db.exists("Role", role):
            frappe.get_doc({"doctype": "Role", "role_name": role, "desk_access": 1}).insert(ignore_permissions=True)
            _bump(summary, "created", "Role")

    for row in DEMO_USERS:
        is_new = not frappe.db.exists("User", row["email"])
        if is_new:
            first_name, last_name = _split_full_name(row["full_name"])
            frappe.get_doc(
                {
                    "doctype": "User",
                    "email": row["email"],
                    "first_name": first_name,
                    "last_name": last_name,
                    "enabled": 1,
                    "user_type": "System User",
                    "send_welcome_email": 0,
                }
            ).insert(ignore_permissions=True)
            _set_password(row["email"], demo_password)
            _bump(summary, "created", "User")
        else:
            if reset_passwords:
                _set_password(row["email"], demo_password)
                _bump(summary, "updated", "User password")
            _ensure_user_display_name(row["email"], row["full_name"], summary)
            _bump(summary, "existing", "User")

        _ensure_user_role(row["email"], row["role"], summary)
        _set_user_default(row["email"], "Branch", row.get("branch"), summary)
        _ensure_user_permission(row["email"], "Branch", row.get("branch"), summary)
        if row.get("production_department"):
            production_department = _get_production_department_name(row["production_department"])
            _set_user_default(
                row["email"],
                "Awamir Production Department",
                production_department,
                summary,
            )
            _ensure_user_permission(
                row["email"],
                "Awamir Production Department",
                production_department,
                summary,
            )


def _set_password(user, password):
    from frappe.utils.password import update_password

    update_password(user, password, logout_all_sessions=False)


def _split_full_name(full_name):
    parts = full_name.split(" ", 1)
    return parts[0], parts[1] if len(parts) > 1 else ""


def _ensure_user_display_name(user, full_name, summary):
    doc = frappe.get_doc("User", user)
    first_name, last_name = _split_full_name(full_name)
    if doc.first_name == first_name and (doc.last_name or "") == last_name:
        _bump(summary, "existing", "User Name")
        return
    doc.first_name = first_name
    doc.last_name = last_name
    doc.save(ignore_permissions=True)
    _bump(summary, "updated", "User Name")


def _ensure_user_role(user, role, summary):
    doc = frappe.get_doc("User", user)
    roles = {row.role for row in doc.roles}
    if role in roles:
        _bump(summary, "existing", "User Role")
        return
    doc.append("roles", {"role": role})
    doc.save(ignore_permissions=True)
    _bump(summary, "updated", "User Role")


def _set_user_default(user, key, value, summary):
    if not value:
        return
    if key == "Branch" and not frappe.db.exists("Branch", value):
        return
    if key == "Awamir Production Department":
        value = _get_production_department_name(value)
        if not value:
            return

    if _user_default_exists(user, key, value):
        _bump(summary, "existing", "User Default")
        return
    frappe.defaults.set_user_default(key, value, user=user)
    _bump(summary, "updated", "User Default")


def _user_default_exists(user, key, value):
    return bool(
        frappe.db.exists(
            "DefaultValue",
            {
                "parent": user,
                "defkey": key,
                "defvalue": value,
            },
        )
    )


def _ensure_user_permission(user, allow, for_value, summary):
    if not for_value:
        return
    if not frappe.db.exists(allow, for_value):
        return

    if frappe.db.exists("User Permission", {"user": user, "allow": allow, "for_value": for_value}):
        _bump(summary, "existing", "User Permission")
        return

    doc = {
        "doctype": "User Permission",
        "user": user,
        "allow": allow,
        "for_value": for_value,
    }
    if _doctype_has_field("User Permission", "apply_to_all_doctypes"):
        doc["apply_to_all_doctypes"] = 1
    frappe.get_doc(doc).insert(ignore_permissions=True)
    _bump(summary, "created", "User Permission")


def _ensure_customers_and_addresses(summary):
    customers = {}
    for row in DEMO_CUSTOMERS:
        customer = frappe.db.get_value("Customer", {"mobile_no": row["mobile_no"]}, "name")
        if not customer:
            customer = frappe.get_doc(
                {
                    "doctype": "Customer",
                    "customer_name": row["customer_name"],
                    "customer_type": row["customer_type"],
                    "mobile_no": row["mobile_no"],
                    "tax_id": row.get("tax_id"),
                }
            ).insert(ignore_permissions=True).name
            _bump(summary, "created", "Customer")
        else:
            _bump(summary, "existing", "Customer")
        customers[row["mobile_no"]] = customer

    for phone, customer in customers.items():
        _ensure_customer_address(customer, phone, summary)


def _ensure_customer_address(customer, phone, summary):
    existing = frappe.get_all(
        "Dynamic Link",
        filters={"link_doctype": "Customer", "link_name": customer, "parenttype": "Address"},
        pluck="parent",
        limit=1,
    )
    if existing:
        _bump(summary, "existing", "Address")
        return

    coordinates = extract_coordinates_from_google_maps_url(DEMO_MAPS_URL)
    address = {
        "doctype": "Address",
        "address_title": frappe.db.get_value("Customer", customer, "customer_name") or customer,
        "address_type": "Shipping",
        "address_line1": "حي المروج - شارع التجربة",
        "address_line2": "بيانات تجريبية لتطبيق أوامر بلس",
        "city": "مكة",
        "pincode": "24231",
        "country": _get_country(),
        "phone": phone,
        "links": [{"link_doctype": "Customer", "link_name": customer}],
    }
    if _doctype_has_field("Address", "custom_google_maps_url"):
        address["custom_google_maps_url"] = DEMO_MAPS_URL
    if coordinates and _doctype_has_field("Address", "custom_latitude"):
        address["custom_latitude"] = coordinates["latitude"]
    if coordinates and _doctype_has_field("Address", "custom_longitude"):
        address["custom_longitude"] = coordinates["longitude"]

    frappe.get_doc(address).insert(ignore_permissions=True)
    _bump(summary, "created", "Address")


def _get_country():
    return (
        frappe.db.get_value("Country", "Saudi Arabia", "name")
        or frappe.db.get_value("Country", "السعودية", "name")
        or frappe.db.get_value("Country", {}, "name")
    )


def _slug(value):
    cleaned = re.sub(r"[^A-Za-z0-9]+", "-", value.encode("ascii", "ignore").decode() or value)
    cleaned = cleaned.strip("-").upper()
    if cleaned:
        return cleaned[:80]
    return str(abs(hash(value)))[:12]
