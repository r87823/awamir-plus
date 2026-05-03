import frappe

from awamir_plus.permissions import require_login
from awamir_plus.utils import get_awamir_settings


@frappe.whitelist()
def get_categories():
    require_login()
    category_names = _get_awamir_category_names()
    if not category_names:
        return []

    return frappe.get_all(
        "Item Group",
        filters={"name": ["in", sorted(category_names)], "is_group": 0},
        fields=["name", "item_group_name", "parent_item_group"],
        order_by="item_group_name asc",
    )


@frappe.whitelist()
def get_products_by_category(category):
    require_login()
    if category not in _get_awamir_category_names():
        return []

    return frappe.get_all(
        "Item",
        filters={"item_group": category, "disabled": 0},
        fields=["name as item_code", "item_name", "description", "item_group", "image"],
        order_by="item_name asc",
    )


@frappe.whitelist()
def get_product_price(item_code, price_list=None):
    require_login()
    settings = get_awamir_settings()
    price_list = price_list or settings.default_price_list
    price = frappe.db.get_value(
        "Item Price",
        {"item_code": item_code, "price_list": price_list},
        "price_list_rate",
    )
    return {"item_code": item_code, "price_list": price_list, "rate": frappe.utils.flt(price)}


@frappe.whitelist()
def get_product_department_mapping(item_code=None, item_group=None):
    require_login()
    if item_code:
        mapping = _get_item_department_mapping(item_code)
        if mapping:
            return mapping
        item_group = item_group or frappe.db.get_value("Item", item_code, "item_group")

    if item_group:
        return _get_group_department_mapping(item_group)

    return None


def _get_item_department_mapping(item_code):
    mapping = frappe.get_all(
        "Awamir Product Department Mapping",
        filters={"is_active": 1, "item_code": item_code},
        fields=["name", "item_group", "item_code", "production_department", "requires_work_order"],
        limit=1,
    )
    return _with_department_name(mapping[0]) if mapping else None


def _get_group_department_mapping(item_group):
    mappings = frappe.get_all(
        "Awamir Product Department Mapping",
        filters={"is_active": 1, "item_group": item_group},
        fields=["name", "item_group", "item_code", "production_department", "requires_work_order"],
        order_by="creation asc",
    )
    mapping = next((row for row in mappings if not row.item_code), None)
    return _with_department_name(mapping) if mapping else None


def _with_department_name(mapping):
    mapping["production_department_name"] = frappe.db.get_value(
        "Awamir Production Department",
        mapping.production_department,
        "department_name",
    )
    return mapping


def _get_awamir_category_names():
    names = set()
    if frappe.get_meta("Item Group").has_field("custom_is_awamir_category"):
        names.update(
            frappe.get_all(
                "Item Group",
                filters={"is_group": 0, "custom_is_awamir_category": 1},
                pluck="name",
            )
        )

    names.update(
        row.item_group
        for row in frappe.get_all(
            "Awamir Product Department Mapping",
            filters={"is_active": 1},
            fields=["item_group"],
        )
        if row.item_group and frappe.db.exists("Item Group", row.item_group)
    )
    return names
