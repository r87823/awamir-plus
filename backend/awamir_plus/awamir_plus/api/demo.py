import frappe

from awamir_plus.constants import ROLE_SYSTEM_ADMIN
from awamir_plus.permissions import require_roles
from awamir_plus.scripts.seed_demo_data import run


@frappe.whitelist()
def seed_demo_data(reset_passwords=False, demo_password=None):
    require_roles([ROLE_SYSTEM_ADMIN])
    return run(reset_passwords=reset_passwords, demo_password=demo_password)
