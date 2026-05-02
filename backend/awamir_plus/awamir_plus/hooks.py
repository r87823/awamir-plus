app_name = "awamir_plus"
app_title = "Awamir Plus"
app_publisher = "Awamir Plus"
app_description = "Native Frappe/ERPNext backend for Awamir Plus order, production, delivery, cash closure, and accounting workflows."
app_email = "support@example.com"
app_license = "MIT"

required_apps = ["frappe", "erpnext"]

after_install = "awamir_plus.install.after_install"

fixtures = [
    {
        "dt": "Role",
        "filters": [["role_name", "like", "Awamir %"]],
    },
    {
        "dt": "Module Def",
        "filters": [["module_name", "=", "Awamir Plus"]],
    },
    {
        "dt": "Custom Field",
        "filters": [["name", "in", ["Address-custom_google_maps_url", "Address-custom_latitude", "Address-custom_longitude"]]],
    },
]

scheduler_events = {
    "daily": [
        "awamir_plus.api.cash_closure.ensure_daily_closures_for_active_users",
    ],
}

permission_query_conditions = {
    "Awamir Order Request": "awamir_plus.doctype_permissions.order_query_conditions",
    "Awamir Notification": "awamir_plus.doctype_permissions.notification_query_conditions",
    "Awamir Daily Cash Closure": "awamir_plus.doctype_permissions.cash_closure_query_conditions",
    "Awamir Delivery Assignment": "awamir_plus.doctype_permissions.delivery_assignment_query_conditions",
}

has_permission = {
    "Awamir Order Request": "awamir_plus.doctype_permissions.order_has_permission",
    "Awamir Notification": "awamir_plus.doctype_permissions.notification_has_permission",
    "Awamir Daily Cash Closure": "awamir_plus.doctype_permissions.cash_closure_has_permission",
    "Awamir Delivery Assignment": "awamir_plus.doctype_permissions.delivery_assignment_has_permission",
}
