import frappe
from frappe.model.document import Document


class AwamirNotification(Document):
    def before_insert(self):
        self.created_at = self.created_at or frappe.utils.now_datetime()

