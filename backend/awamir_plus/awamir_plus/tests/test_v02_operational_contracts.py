import json
import unittest
from pathlib import Path

from awamir_plus.constants import (
    DEPARTMENT_WORK_ORDER_STATUSES,
    DELIVERY_BATCH_STATUSES,
    ORDER_PRIORITIES,
    ORDER_FLOW_STATUSES,
    PACKING_STATUSES,
    PERMISSION_ORDER_CANCEL,
    ROLE_BRANCH_EMPLOYEE,
    ROLE_DISTRIBUTION_MANAGER,
    ROLE_PERMISSION_MAPPING,
)


APP_ROOT = Path(__file__).resolve().parents[1]
DOCTYPE_ROOT = APP_ROOT / "awamir_plus" / "doctype"


class TestV02OperationalContracts(unittest.TestCase):
    def test_order_cancel_permission_is_assigned_to_operational_roles(self):
        self.assertIn(PERMISSION_ORDER_CANCEL, ROLE_PERMISSION_MAPPING[ROLE_BRANCH_EMPLOYEE])
        self.assertIn(PERMISSION_ORDER_CANCEL, ROLE_PERMISSION_MAPPING[ROLE_DISTRIBUTION_MANAGER])

    def test_split_order_status_fields_exist_on_order_request(self):
        doctype = _load_doctype("awamir_order_request")
        fieldnames = _fieldnames(doctype)

        for fieldname in [
            "order_status",
            "production_status",
            "packing_status",
            "delivery_status",
            "payment_status",
            "accounting_status",
        ]:
            self.assertIn(fieldname, fieldnames)

        status_options = _field(doctype, "order_status")["options"].splitlines()
        self.assertEqual(status_options, ORDER_FLOW_STATUSES)
        self.assertEqual(_field(doctype, "packing_status")["options"].splitlines(), PACKING_STATUSES)

    def test_order_operational_extension_fields_exist(self):
        doctype = _load_doctype("awamir_order_request")
        fieldnames = _fieldnames(doctype)

        for fieldname in [
            "priority",
            "scheduled_at",
            "pickup_time",
            "delivery_window_start",
            "delivery_window_end",
            "received_by_name",
            "proof_image_url",
            "signature_url",
            "qr_scanned",
            "delivered_at",
            "is_cancelled",
            "cancelled_at",
            "cancelled_by",
            "cancellation_reason",
        ]:
            self.assertIn(fieldname, fieldnames)

        self.assertEqual(_field(doctype, "priority")["options"].splitlines(), ORDER_PRIORITIES)

    def test_department_work_order_doctypes_have_required_contract(self):
        work_order = _load_doctype("awamir_department_work_order")
        item = _load_doctype("awamir_department_work_order_item")

        for fieldname in [
            "work_order_number",
            "order",
            "department",
            "status",
            "department_daily_capacity",
            "department_open_work_orders_count",
            "capacity_warning",
            "items",
        ]:
            self.assertIn(fieldname, _fieldnames(work_order))
        self.assertEqual(_field(work_order, "status")["options"].splitlines(), DEPARTMENT_WORK_ORDER_STATUSES)

        for fieldname in ["item_code", "item_name", "qty", "rate", "amount", "product_category"]:
            self.assertIn(fieldname, _fieldnames(item))

    def test_delivery_batch_doctypes_have_required_contract(self):
        batch = _load_doctype("awamir_delivery_batch")
        batch_order = _load_doctype("awamir_delivery_batch_order")

        for fieldname in ["batch_number", "destination_branch", "status", "driver", "orders"]:
            self.assertIn(fieldname, _fieldnames(batch))
        self.assertEqual(_field(batch, "status")["options"].splitlines(), DELIVERY_BATCH_STATUSES)

        for fieldname in ["order", "order_number", "customer_name", "customer_phone", "status"]:
            self.assertIn(fieldname, _fieldnames(batch_order))

    def test_delivery_assignment_supports_proof_of_delivery(self):
        assignment = _load_doctype("awamir_delivery_assignment")
        for fieldname in [
            "received_by_name",
            "proof_image",
            "signature_url",
            "qr_scanned",
            "driver_notes",
        ]:
            self.assertIn(fieldname, _fieldnames(assignment))

    def test_sensitive_operational_doctypes_support_soft_cancellation(self):
        for folder in [
            "awamir_order_request",
            "awamir_delivery_batch",
            "awamir_department_work_order",
            "awamir_order_payment",
            "awamir_daily_cash_closure",
            "awamir_delivery_assignment",
        ]:
            with self.subTest(folder=folder):
                doctype = _load_doctype(folder)
                for fieldname in [
                    "is_cancelled",
                    "cancelled_at",
                    "cancelled_by",
                    "cancellation_reason",
                ]:
                    self.assertIn(fieldname, _fieldnames(doctype))

    def test_audit_and_idempotency_doctypes_exist(self):
        audit = _load_doctype("awamir_audit_log")
        idempotency = _load_doctype("awamir_idempotency_key")

        for fieldname in ["event_type", "status", "user", "method", "request_hash", "payload", "response"]:
            self.assertIn(fieldname, _fieldnames(audit))

        for fieldname in ["key", "method", "request_hash", "status", "response", "error"]:
            self.assertIn(fieldname, _fieldnames(idempotency))


def _load_doctype(folder):
    path = DOCTYPE_ROOT / folder / f"{folder}.json"
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def _fieldnames(doctype):
    return {field["fieldname"] for field in doctype["fields"]}


def _field(doctype, fieldname):
    for field in doctype["fields"]:
        if field["fieldname"] == fieldname:
            return field
    raise AssertionError(f"Missing field {fieldname}")
