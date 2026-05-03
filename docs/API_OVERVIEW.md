# Awamir Plus API Overview

Base URL:

```text
https://awamirplus.r8787m.cc/api/method
```

Authentication uses Frappe session cookies. The Flutter app must call `/api/method/login` first, then call protected Awamir APIs with the same cookie jar.

## Auth

- `awamir_plus.api.auth.get_current_user`

Returns the current user, Awamir roles, branch, production department, and driver profile.

## Products

- `awamir_plus.api.products.get_categories`
- يرجع فقط Item Groups التابعة لأوامر بلس، إما عبر الحقل `custom_is_awamir_category` أو عبر `Awamir Product Department Mapping` النشط.
- `awamir_plus.api.products.get_products_by_category`
- `awamir_plus.api.products.get_product_price`
- `awamir_plus.api.products.get_product_department_mapping`

## Customers

- `awamir_plus.api.customers.search_customer_by_phone`
- `awamir_plus.api.customers.search_customer_by_name`
- `awamir_plus.api.customers.create_customer`
- `awamir_plus.api.customers.get_customer_addresses`
- `awamir_plus.api.customers.create_customer_address`
- `awamir_plus.api.customers.update_customer_address`

## Orders

- `awamir_plus.api.orders.save_order_as_draft`
- `awamir_plus.api.orders.submit_order_for_approval`
- `awamir_plus.api.orders.get_my_orders`
- `awamir_plus.api.orders.get_order_detail`
- `awamir_plus.api.orders.upload_order_attachment`

The order payload supports customer data, company fields, items, pickup/delivery details, dates, notes, deposit, and payment method.

## Approvals

- `awamir_plus.api.approvals.get_pending_supervisor_approvals`
- `awamir_plus.api.approvals.approve_order`
- `awamir_plus.api.approvals.reject_order`
- `awamir_plus.api.approvals.return_order_for_edit`

Supervisor approval moves orders to `Sent To Distribution`.

## Distribution And Production

- `awamir_plus.api.distribution.get_distribution_orders`
- `awamir_plus.api.distribution.get_production_departments`
- `awamir_plus.api.distribution.get_default_department_for_order`
- `awamir_plus.api.distribution.assign_production_department`
- `awamir_plus.api.production.get_production_orders`
- `awamir_plus.api.production.update_production_status`

Production transitions are strict: `Sent To Production -> In Production -> Production Completed -> Ready For Pickup/Ready For Delivery`.

## Delivery

- `awamir_plus.api.delivery.get_pickup_orders`
- `awamir_plus.api.delivery.mark_pickup_order_delivered`
- `awamir_plus.api.delivery.collect_remaining_payment`
- `awamir_plus.api.delivery.get_available_drivers`
- `awamir_plus.api.delivery.assign_driver_to_order`
- `awamir_plus.api.delivery.get_driver_orders`
- `awamir_plus.api.delivery.update_delivery_status`
- `awamir_plus.api.delivery.mark_delivery_failed`
- `awamir_plus.api.delivery.collect_delivery_payment`

Payments collected at pickup or delivery enter daily cash closure. They are not posted to ERPNext immediately.

## Cash Closure

- `awamir_plus.api.cash_closure.get_my_daily_cash_closure`
- `awamir_plus.api.cash_closure.submit_cash_closure`
- `awamir_plus.api.cash_closure.get_submitted_cash_closures`
- `awamir_plus.api.cash_closure.get_cash_closure_detail`
- `awamir_plus.api.cash_closure.accept_cash_closure`
- `awamir_plus.api.cash_closure.return_cash_closure`
- `awamir_plus.api.cash_closure.close_cash_closure`

Cashier acceptance makes payments eligible for ERPNext posting.

## Accounting

- `awamir_plus.api.accounting.create_sales_order_for_order`
- `awamir_plus.api.accounting.create_work_order_for_order`
- `awamir_plus.api.accounting.post_accepted_payments_to_erpnext`
- `awamir_plus.api.accounting.create_payment_entry_for_payment`
- `awamir_plus.api.accounting.create_sales_invoice_for_order`
- `awamir_plus.api.accounting.allocate_advance_payment_to_invoice`
- `awamir_plus.api.accounting.get_customer_invoices`
- `awamir_plus.api.accounting.sync_order_accounting_status`

All accounting APIs are idempotent. If a document already exists, the same document number is returned instead of creating a duplicate.

## Notifications

- `awamir_plus.api.notifications.get_notifications`
- `awamir_plus.api.notifications.mark_notification_as_read`
- `awamir_plus.api.notifications.mark_all_notifications_as_read`

Notifications are scoped to the current user unless the user is an Awamir System Admin.
