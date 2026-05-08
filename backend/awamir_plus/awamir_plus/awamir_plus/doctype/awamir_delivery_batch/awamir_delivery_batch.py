import frappe
from frappe.model.document import Document

from awamir_plus.constants import DELIVERY_BATCH_STATUS_DRAFT
from awamir_plus.utils import generate_series


class AwamirDeliveryBatch(Document):
    def autoname(self):
        if not self.batch_number:
            self.batch_number = generate_series("BATCH")
        self.name = self.batch_number

    def before_insert(self):
        self.status = self.status or DELIVERY_BATCH_STATUS_DRAFT
        self.created_by = self.created_by or frappe.session.user

    def validate(self):
        self.orders_count = len(self.orders or [])

