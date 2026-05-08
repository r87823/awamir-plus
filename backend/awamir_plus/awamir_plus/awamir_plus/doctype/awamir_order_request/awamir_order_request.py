import frappe
from frappe.model.document import Document

from awamir_plus.constants import (
    ACCOUNTING_FLOW_STATUS_ACCOUNTING_POSTED,
    ACCOUNTING_FLOW_STATUS_DRAFT_INVOICE_CREATED,
    ACCOUNTING_FLOW_STATUS_NOT_POSTED,
    ACCOUNTING_FLOW_STATUS_PAYMENT_SUBMITTED,
    ACCOUNTING_FLOW_STATUS_SALES_ORDER_CREATED,
    DELIVERY_FLOW_STATUS_ASSIGNED_TO_DRIVER,
    DELIVERY_FLOW_STATUS_DELIVERED,
    DELIVERY_FLOW_STATUS_NOT_REQUIRED,
    DELIVERY_FLOW_STATUS_OUT_FOR_DELIVERY,
    DELIVERY_FLOW_STATUS_PICKED_UP,
    DELIVERY_FLOW_STATUS_RETURNED,
    DELIVERY_FLOW_STATUS_WAITING_BATCH,
    ERP_SYNC_NOT_SYNCED,
    ERP_SYNC_SYNCED,
    ORDER_FLOW_STATUS_APPROVED,
    ORDER_FLOW_STATUS_CANCELLED,
    ORDER_FLOW_STATUS_DELIVERED,
    ORDER_FLOW_STATUS_DRAFT,
    ORDER_FLOW_STATUS_IN_FULFILLMENT,
    ORDER_FLOW_STATUS_PENDING_APPROVAL,
    ORDER_FLOW_STATUS_READY,
    ORDER_FLOW_STATUS_REJECTED,
    ORDER_FLOW_STATUS_RETURNED_FOR_EDIT,
    ORDER_PAYMENT_FLOW_STATUS_PAID,
    ORDER_PAYMENT_FLOW_STATUS_PARTIALLY_PAID,
    ORDER_PAYMENT_FLOW_STATUS_UNPAID,
    ORDER_STATUS_ASSIGNED_TO_DRIVER,
    ORDER_STATUS_CANCELLED,
    ORDER_STATUS_DELIVERED,
    ORDER_STATUS_DELIVERY_FAILED,
    ORDER_STATUS_DRAFT,
    ORDER_STATUS_DRIVER_PICKED_UP,
    ORDER_STATUS_IN_PRODUCTION,
    ORDER_STATUS_OUT_FOR_DELIVERY,
    ORDER_STATUS_PENDING_APPROVAL,
    ORDER_STATUS_PRODUCTION_COMPLETED,
    ORDER_STATUS_READY_FOR_DELIVERY,
    ORDER_STATUS_READY_FOR_PICKUP,
    ORDER_STATUS_REJECTED,
    ORDER_STATUS_RETURNED,
    ORDER_STATUS_SENT_TO_DISTRIBUTION,
    ORDER_STATUS_SENT_TO_PRODUCTION,
    PAYMENT_STATUS_RETURNED,
    PRODUCTION_FLOW_STATUS_IN_PRODUCTION,
    PRODUCTION_FLOW_STATUS_NOT_STARTED,
    PRODUCTION_FLOW_STATUS_PARTIALLY_READY,
    PRODUCTION_FLOW_STATUS_READY,
    PRODUCTION_FLOW_STATUS_WORK_ORDERS_CREATED,
)
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
        self._sync_split_status_fields()
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
        self._sync_split_status_fields()

    def _sync_split_status_fields(self):
        order_status, production_status, delivery_status = _derive_split_statuses(self.status, self.delivery_type)
        if not self.is_new():
            production_status = _derive_production_status_from_work_orders(self.name, production_status)
        self.order_status = order_status
        self.production_status = production_status
        self.delivery_status = delivery_status
        self.payment_status = _derive_payment_status(self.deposit_amount, getattr(self, "remaining_amount", 0))
        self.accounting_status = _derive_accounting_status(self)


def _derive_split_statuses(status, delivery_type):
    delivery_required = delivery_type == "Delivery"
    if status == ORDER_STATUS_DRAFT:
        return ORDER_FLOW_STATUS_DRAFT, PRODUCTION_FLOW_STATUS_NOT_STARTED, DELIVERY_FLOW_STATUS_NOT_REQUIRED
    if status == ORDER_STATUS_PENDING_APPROVAL:
        return ORDER_FLOW_STATUS_PENDING_APPROVAL, PRODUCTION_FLOW_STATUS_NOT_STARTED, DELIVERY_FLOW_STATUS_NOT_REQUIRED
    if status == ORDER_STATUS_RETURNED:
        return ORDER_FLOW_STATUS_RETURNED_FOR_EDIT, PRODUCTION_FLOW_STATUS_NOT_STARTED, DELIVERY_FLOW_STATUS_NOT_REQUIRED
    if status == ORDER_STATUS_REJECTED:
        return ORDER_FLOW_STATUS_REJECTED, PRODUCTION_FLOW_STATUS_NOT_STARTED, DELIVERY_FLOW_STATUS_NOT_REQUIRED
    if status == ORDER_STATUS_CANCELLED:
        return ORDER_FLOW_STATUS_CANCELLED, PRODUCTION_FLOW_STATUS_NOT_STARTED, DELIVERY_FLOW_STATUS_NOT_REQUIRED
    if status == ORDER_STATUS_SENT_TO_DISTRIBUTION:
        return ORDER_FLOW_STATUS_APPROVED, PRODUCTION_FLOW_STATUS_NOT_STARTED, DELIVERY_FLOW_STATUS_NOT_REQUIRED
    if status == ORDER_STATUS_SENT_TO_PRODUCTION:
        return ORDER_FLOW_STATUS_IN_FULFILLMENT, PRODUCTION_FLOW_STATUS_WORK_ORDERS_CREATED, DELIVERY_FLOW_STATUS_NOT_REQUIRED
    if status == ORDER_STATUS_IN_PRODUCTION:
        return ORDER_FLOW_STATUS_IN_FULFILLMENT, PRODUCTION_FLOW_STATUS_IN_PRODUCTION, DELIVERY_FLOW_STATUS_NOT_REQUIRED
    if status == ORDER_STATUS_PRODUCTION_COMPLETED:
        return ORDER_FLOW_STATUS_IN_FULFILLMENT, PRODUCTION_FLOW_STATUS_READY, DELIVERY_FLOW_STATUS_NOT_REQUIRED
    if status == ORDER_STATUS_READY_FOR_PICKUP:
        return ORDER_FLOW_STATUS_READY, PRODUCTION_FLOW_STATUS_READY, DELIVERY_FLOW_STATUS_NOT_REQUIRED
    if status == ORDER_STATUS_READY_FOR_DELIVERY:
        return ORDER_FLOW_STATUS_READY, PRODUCTION_FLOW_STATUS_READY, DELIVERY_FLOW_STATUS_WAITING_BATCH
    if status == ORDER_STATUS_ASSIGNED_TO_DRIVER:
        return ORDER_FLOW_STATUS_READY, PRODUCTION_FLOW_STATUS_READY, DELIVERY_FLOW_STATUS_ASSIGNED_TO_DRIVER
    if status == ORDER_STATUS_DRIVER_PICKED_UP:
        return ORDER_FLOW_STATUS_READY, PRODUCTION_FLOW_STATUS_READY, DELIVERY_FLOW_STATUS_PICKED_UP
    if status == ORDER_STATUS_OUT_FOR_DELIVERY:
        return ORDER_FLOW_STATUS_READY, PRODUCTION_FLOW_STATUS_READY, DELIVERY_FLOW_STATUS_OUT_FOR_DELIVERY
    if status == ORDER_STATUS_DELIVERY_FAILED:
        return ORDER_FLOW_STATUS_READY, PRODUCTION_FLOW_STATUS_READY, DELIVERY_FLOW_STATUS_RETURNED
    if status == ORDER_STATUS_DELIVERED:
        delivery_status = DELIVERY_FLOW_STATUS_DELIVERED if delivery_required else DELIVERY_FLOW_STATUS_NOT_REQUIRED
        return ORDER_FLOW_STATUS_DELIVERED, PRODUCTION_FLOW_STATUS_READY, delivery_status
    return ORDER_FLOW_STATUS_DRAFT, PRODUCTION_FLOW_STATUS_NOT_STARTED, DELIVERY_FLOW_STATUS_NOT_REQUIRED


def _derive_payment_status(deposit_amount, remaining_amount):
    if frappe.utils.flt(remaining_amount) <= 0:
        return ORDER_PAYMENT_FLOW_STATUS_PAID
    if frappe.utils.flt(deposit_amount) > 0:
        return ORDER_PAYMENT_FLOW_STATUS_PARTIALLY_PAID
    return ORDER_PAYMENT_FLOW_STATUS_UNPAID


def _derive_production_status_from_work_orders(order, fallback):
    if not frappe.db.exists("DocType", "Awamir Department Work Order"):
        return fallback
    rows = frappe.get_all(
        "Awamir Department Work Order",
        filters={"order": order},
        pluck="status",
    )
    if not rows:
        return fallback
    statuses = set(rows)
    if statuses == {"ready"}:
        return PRODUCTION_FLOW_STATUS_READY
    if "ready" in statuses:
        return PRODUCTION_FLOW_STATUS_PARTIALLY_READY
    if "in_production" in statuses:
        return PRODUCTION_FLOW_STATUS_IN_PRODUCTION
    return PRODUCTION_FLOW_STATUS_WORK_ORDERS_CREATED


def _derive_accounting_status(order):
    if getattr(order, "erp_sync_status", None) == ERP_SYNC_SYNCED:
        return ACCOUNTING_FLOW_STATUS_ACCOUNTING_POSTED
    if getattr(order, "erpnext_sales_invoice", None):
        return ACCOUNTING_FLOW_STATUS_DRAFT_INVOICE_CREATED
    if getattr(order, "erpnext_payment_entry_ids", None):
        return ACCOUNTING_FLOW_STATUS_PAYMENT_SUBMITTED
    if getattr(order, "erpnext_sales_order", None):
        return ACCOUNTING_FLOW_STATUS_SALES_ORDER_CREATED
    return ACCOUNTING_FLOW_STATUS_NOT_POSTED
