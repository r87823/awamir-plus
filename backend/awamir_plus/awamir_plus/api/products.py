import frappe

from awamir_plus.permissions import require_login
from awamir_plus.utils import get_awamir_settings


@frappe.whitelist()
def get_categories():
    require_login()
    return frappe.get_all(
        "Item Group",
        filters={"is_group": 0},
        fields=["name", "item_group_name", "parent_item_group"],
        order_by="item_group_name asc",
    )


@frappe.whitelist()
def get_products_by_category(category):
    require_login()
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
    filters = {"is_active": 1}
    if item_code:
        filters["item_code"] = item_code
    elif item_group:
        filters["item_group"] = item_group
    else:
        return None

    mapping = frappe.get_all(
        "Awamir Product Department Mapping",
        filters=filters,
        fields=["name", "item_group", "item_code", "production_department", "requires_work_order"],
        limit=1,
    )
    return mapping[0] if mapping else None

