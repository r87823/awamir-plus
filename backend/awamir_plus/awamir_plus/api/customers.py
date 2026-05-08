import frappe
from frappe import _

from awamir_plus.permissions import require_login
from awamir_plus.utils import (
    assert_required,
    extract_coordinates_from_google_maps_url as _extract_coordinates_from_google_maps_url,
    normalize_phone_input,
)


@frappe.whitelist()
def search_customer_by_phone(phone):
    require_login()
    phone = normalize_phone_input(phone)
    assert_required(phone, "Phone is required.")
    return frappe.get_all(
        "Customer",
        filters=[["Customer", "mobile_no", "like", f"%{phone}%"]],
        fields=["name", "customer_name", "customer_type", "mobile_no", "tax_id"],
        limit=10,
    )


@frappe.whitelist()
def search_customer_by_name(customer_name):
    require_login()
    assert_required(customer_name, "Customer name is required.")
    return frappe.get_all(
        "Customer",
        filters=[["Customer", "customer_name", "like", f"%{customer_name}%"]],
        fields=["name", "customer_name", "customer_type", "mobile_no", "tax_id"],
        limit=10,
    )


@frappe.whitelist()
def create_customer(customer_name, phone=None, customer_type="Individual", tax_id=None):
    require_login()
    assert_required(customer_name, "Customer name is required.")
    phone = normalize_phone_input(phone)

    if phone:
        existing = frappe.db.get_value("Customer", {"mobile_no": phone}, "name")
        if existing:
            return frappe.get_doc("Customer", existing).as_dict()

    doc = frappe.get_doc(
        {
            "doctype": "Customer",
            "customer_name": customer_name,
            "customer_type": "Company" if customer_type == "Company" else "Individual",
            "mobile_no": phone,
            "tax_id": tax_id,
        }
    ).insert()
    return doc.as_dict()


@frappe.whitelist()
def get_customer_addresses(customer):
    require_login()
    links = frappe.get_all(
        "Dynamic Link",
        filters={"link_doctype": "Customer", "link_name": customer, "parenttype": "Address"},
        pluck="parent",
    )
    return [frappe.get_doc("Address", address).as_dict() for address in links]


@frappe.whitelist()
def create_customer_address(customer, address_line1, city=None, district=None, pincode=None, location_url=None):
    require_login()
    assert_required(customer, "Customer is required.")
    assert_required(address_line1, "Address is required.")
    coordinates = _extract_coordinates_from_google_maps_url(location_url)

    doc = frappe.get_doc(
        {
            "doctype": "Address",
            "address_title": frappe.db.get_value("Customer", customer, "customer_name") or customer,
            "address_type": "Shipping",
            "address_line1": address_line1,
            "city": city or district or _("Unknown"),
            "pincode": pincode,
            "custom_google_maps_url": location_url,
            "custom_latitude": coordinates["latitude"] if coordinates else None,
            "custom_longitude": coordinates["longitude"] if coordinates else None,
            "links": [{"link_doctype": "Customer", "link_name": customer}],
        }
    ).insert()
    return doc.as_dict()


@frappe.whitelist()
def update_customer_address(address, **kwargs):
    require_login()
    doc = frappe.get_doc("Address", address)
    for field in ["address_line1", "city", "pincode", "custom_google_maps_url"]:
        if field in kwargs:
            doc.set(field, kwargs[field])
    coordinates = _extract_coordinates_from_google_maps_url(kwargs.get("custom_google_maps_url") or kwargs.get("location_url"))
    if coordinates:
        doc.custom_latitude = coordinates["latitude"]
        doc.custom_longitude = coordinates["longitude"]
    doc.save()
    return doc.as_dict()


@frappe.whitelist()
def extract_coordinates_from_google_maps_url(location_url):
    require_login()
    return _extract_coordinates_from_google_maps_url(location_url)
