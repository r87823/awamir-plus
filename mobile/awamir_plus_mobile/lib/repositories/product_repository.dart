import '../core/constants/environment.dart';
import '../core/errors/app_exception.dart';
import '../models/app_models.dart';
import '../services/erpnext_service.dart';
import '../services/mock_service.dart';

class ProductRepository {
  ProductRepository({
    MockService? mockService,
    ErpnextService? erpnextService,
    bool useMockData = AppEnvironment.useMockData,
  }) : _mockService = mockService ?? MockService(),
       _erpnextService = erpnextService ?? const ErpnextService(),
       _useMockData = useMockData;

  final MockService _mockService;
  final ErpnextService _erpnextService;
  final bool _useMockData;

  Future<List<ProductDepartment>> getCategories() async {
    try {
      return _useMockData
          ? _mockService.getCategories()
          : _erpnextService.getCategories();
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل الأقسام',
        code: 'categories_load_failed',
        cause: error,
      );
    }
  }

  Future<List<Product>> getProductsByCategory(String categoryId) async {
    try {
      return _useMockData
          ? _mockService.getProductsByCategory(categoryId)
          : _erpnextService.getProductsByCategory(categoryId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تحميل المنتجات',
        code: 'products_load_failed',
        cause: error,
      );
    }
  }
}
