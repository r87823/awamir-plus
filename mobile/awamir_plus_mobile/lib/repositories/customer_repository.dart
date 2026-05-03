import '../core/constants/environment.dart';
import '../core/errors/app_exception.dart';
import '../models/app_models.dart';
import '../services/erpnext_service.dart';
import '../services/mock_service.dart';

class CustomerRepository {
  CustomerRepository({
    MockService? mockService,
    ErpnextService? erpnextService,
    bool useMockData = AppEnvironment.useMockData,
  }) : _mockService = mockService ?? MockService(),
       _erpnextService = erpnextService ?? ErpnextService(),
       _useMockData = useMockData;

  final MockService _mockService;
  final ErpnextService _erpnextService;
  final bool _useMockData;

  Future<Customer?> searchCustomerByPhone(String phone) async {
    try {
      return _useMockData
          ? _mockService.searchCustomerByPhone(phone)
          : _erpnextService.searchCustomerByPhone(phone);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر البحث عن العميل',
        code: 'customer_search_failed',
        cause: error,
      );
    }
  }

  Future<List<CustomerAddress>> getCustomerAddresses(String customerId) async {
    try {
      return _useMockData
          ? _mockService.getCustomerAddresses(customerId)
          : _erpnextService.getCustomerAddresses(customerId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل عناوين العميل',
        code: 'customer_addresses_failed',
        cause: error,
      );
    }
  }
}
