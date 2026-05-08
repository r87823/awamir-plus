import frappe

from awamir_plus.constants import PERMISSION_ADMIN_MANAGE_SETTINGS
from awamir_plus.permissions import require_permissions
from awamir_plus.scripts.seed_demo_data import run


@frappe.whitelist()
def seed_demo_data(reset_passwords=False, demo_password=None):
    require_permissions(PERMISSION_ADMIN_MANAGE_SETTINGS)
    return run(reset_passwords=reset_passwords, demo_password=demo_password)
