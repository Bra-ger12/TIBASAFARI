from rest_framework.routers import DefaultRouter

from apps.billing.views import InvoiceViewSet, PaymentViewSet, SavedPaymentMethodViewSet

router = DefaultRouter()
router.register("invoices", InvoiceViewSet, basename="invoice")
router.register("payments", PaymentViewSet, basename="payment")
router.register("payment-methods", SavedPaymentMethodViewSet, basename="saved-payment-method")

urlpatterns = router.urls
