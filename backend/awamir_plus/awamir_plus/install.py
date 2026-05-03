import frappe

from awamir_plus.constants import AWAMIR_ROLES


def after_install():
    create_roles()
    create_custom_fields()
    create_default_settings()


def create_roles():
    for role in AWAMIR_ROLES:
        if not frappe.db.exists("Role", role):
            frappe.get_doc(
                {
                    "doctype": "Role",
                    "role_name": role,
                    "desk_access": 1,
                    "disabled": 0,
                }
            ).insert(ignore_permissions=True)


def create_default_settings():
    if frappe.db.exists("Awamir App Settings", "Awamir App Settings"):
        return

    settings = frappe.get_doc(
        {
            "doctype": "Awamir App Settings",
            "default_currency": frappe.defaults.get_global_default("currency") or "SAR",
            "require_deposit_before_production": 0,
            "create_sales_order_on_approval": 0,
            "create_work_order_on_distribution": 0,
            "create_invoice_on_delivery": 0,
            "allow_delivery_without_full_payment": 0,
            "enable_driver_cash_closure": 1,
        }
    )
    settings.insert(ignore_permissions=True)


def create_custom_fields():
    from frappe.custom.doctype.custom_field.custom_field import create_custom_fields

    create_custom_fields(
        {
            "Address": [
                {
                    "fieldname": "custom_google_maps_url",
                    "label": "Google Maps URL",
                    "fieldtype": "Data",
                    "insert_after": "address_line2",
                },
                {
                    "fieldname": "custom_latitude",
                    "label": "Latitude",
                    "fieldtype": "Float",
                    "insert_after": "custom_google_maps_url",
                },
                {
                    "fieldname": "custom_longitude",
                    "label": "Longitude",
                    "fieldtype": "Float",
                    "insert_after": "custom_latitude",
                },
            ],
            "Item Group": [
                {
                    "fieldname": "custom_is_awamir_category",
                    "label": "Is Awamir Plus Category",
                    "fieldtype": "Check",
                    "insert_after": "is_group",
                    "description": "Show this item group in Awamir Plus mobile category selection.",
                },
            ],
        },
        ignore_validate=True,
    )


def after_migrate():
    create_custom_fields()
