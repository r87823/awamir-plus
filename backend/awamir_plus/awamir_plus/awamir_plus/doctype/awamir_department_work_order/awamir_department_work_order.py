import frappe
from frappe.model.document import Document

from awamir_plus.constants import DEPARTMENT_WORK_ORDER_STATUS_PENDING
from awamir_plus.utils import generate_series


class AwamirDepartmentWorkOrder(Document):
    def autoname(self):
        if not self.work_order_number:
            self.work_order_number = generate_series("DWO")
        self.name = self.work_order_number

    def before_insert(self):
        self.status = self.status or DEPARTMENT_WORK_ORDER_STATUS_PENDING
        self.created_by = self.created_by or frappe.session.user

    def validate(self):
        if not self.production_center and self.department:
            self.production_center = frappe.db.get_value(
                "Awamir Production Department",
                self.department,
                "production_center",
            )

