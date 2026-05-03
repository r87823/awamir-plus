import frappe
from frappe.model.document import Document

from awamir_plus.constants import ERP_SYNC_NOT_SYNCED, ORDER_STATUS_DRAFT, PAYMENT_STATUS_RETURNED
from awamir_plus.permissions import get_user_branch
from awamir_plus.utils import generate_series


class AwamirOrderRequest(Document):
    def autoname(self):
        if not self.order_number:
            self.order_number = generate_series("ORD")
        self.name = self.order_number

    def before_insert(self):
        self.created_by_user = self.created_by_user or frappe.session.user
        self.status = self.status or ORDER_STATUS_DRAFT
        self.erp_sync_status = self.erp_sync_status or ERP_SYNC_NOT_SYNCED
        if self.delivery_type == "Pickup" and not self.pickup_branch:
            self.pickup_branch = self.created_branch or get_user_branch()

    def validate(self):
        total = sum(frappe.utils.flt(item.amount) for item in self.items)
        if not self.total_amount:
            self.total_amount = total
        if frappe.utils.flt(self.deposit_amount) > frappe.utils.flt(self.total_amount) + frappe.utils.flt(self.delivery_fee):
            frappe.throw("Deposit cannot exceed order total plus delivery fee.")
        paid_amount = frappe.utils.flt(self.deposit_amount)
        if not self.is_new():
            recorded_payments = frappe.db.sql(
                """
                select coalesce(sum(amount), 0)
                from `tabAwamir Order Payment`
                where `order` = %s and ifnull(status, '') != %s
                """,
                (self.name, PAYMENT_STATUS_RETURNED),
            )[0][0]
            paid_amount = max(paid_amount, frappe.utils.flt(recorded_payments))
        self.remaining_amount = max(
            frappe.utils.flt(self.total_amount) + frappe.utils.flt(self.delivery_fee) - paid_amount,
            0,
        )
