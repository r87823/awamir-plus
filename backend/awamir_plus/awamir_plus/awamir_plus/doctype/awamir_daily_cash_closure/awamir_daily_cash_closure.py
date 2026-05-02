import frappe
from frappe.model.document import Document

from awamir_plus.constants import CLOSURE_STATUS_OPEN
from awamir_plus.permissions import get_user_branch
from awamir_plus.utils import generate_series


class AwamirDailyCashClosure(Document):
    def autoname(self):
        if not self.closure_number:
            self.closure_number = generate_series("CASH")
        self.name = self.closure_number

    def before_insert(self):
        self.user = self.user or frappe.session.user
        self.branch = self.branch or get_user_branch(self.user)
        self.date = self.date or frappe.utils.today()
        self.status = self.status or CLOSURE_STATUS_OPEN

    def validate(self):
        self.total_amount = sum(
            frappe.utils.flt(value)
            for value in [self.total_cash, self.total_card, self.total_transfer, self.total_other]
        )
        self.actual_total = sum(
            frappe.utils.flt(value)
            for value in [self.actual_cash, self.actual_card, self.actual_transfer, self.actual_other]
        )
        self.difference_amount = frappe.utils.flt(self.actual_total) - frappe.utils.flt(self.total_amount)

