import frappe
from frappe import _
from frappe.model.document import Document

from awamir_plus.constants import PAYMENT_STATUS_RECORDED


class AwamirOrderPayment(Document):
    def before_insert(self):
        self.status = self.status or PAYMENT_STATUS_RECORDED
        self.created_at = self.created_at or frappe.utils.now_datetime()

    def validate(self):
        if self.cash_closure:
            closure_status = frappe.db.get_value("Awamir Daily Cash Closure", self.cash_closure, "status")
            if closure_status in ("Submitted To Cashier", "Accepted", "Closed", "Has Difference"):
                frappe.throw(_("Payment cannot be edited after cash closure submission."))

