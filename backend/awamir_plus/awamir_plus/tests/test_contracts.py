import unittest

from awamir_plus.constants import ORDER_STATUSES, PAYMENT_STATUSES, CLOSURE_STATUSES, ERP_SYNC_STATUSES
from awamir_plus.utils import normalize_phone_input


class TestAwamirContracts(unittest.TestCase):
    def test_required_order_statuses_are_present(self):
        for status in [
            "Draft",
            "Pending Supervisor Approval",
            "Sent To Distribution",
            "Sent To Production",
            "Ready For Pickup",
            "Ready For Delivery",
            "Assigned To Driver",
            "Delivered",
        ]:
            self.assertIn(status, ORDER_STATUSES)

    def test_required_payment_statuses_are_present(self):
        self.assertIn("Cashier Accepted", PAYMENT_STATUSES)
        self.assertIn("Posted To ERPNext", PAYMENT_STATUSES)
        self.assertIn("Linked To Invoice", PAYMENT_STATUSES)

    def test_required_cash_closure_statuses_are_present(self):
        self.assertIn("Submitted To Cashier", CLOSURE_STATUSES)
        self.assertIn("Has Difference", CLOSURE_STATUSES)

    def test_required_erp_sync_statuses_are_present(self):
        self.assertIn("Not Synced", ERP_SYNC_STATUSES)
        self.assertIn("Partially Synced", ERP_SYNC_STATUSES)
        self.assertIn("Failed", ERP_SYNC_STATUSES)

    def test_localized_phone_digits_are_normalized(self):
        self.assertEqual(normalize_phone_input("٠٥٩٩٠٠٠٠٩٩"), "0599000099")
        self.assertEqual(normalize_phone_input("۰۵۰-۱۲۳-۴۵۶۷"), "0501234567")
