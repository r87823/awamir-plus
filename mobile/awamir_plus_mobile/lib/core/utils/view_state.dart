enum ViewStatus { loading, success, error, empty }

class ViewState<T> {
  const ViewState._({required this.status, this.data, this.message});

  const ViewState.loading() : this._(status: ViewStatus.loading);

  const ViewState.success(T data)
    : this._(status: ViewStatus.success, data: data);

  const ViewState.error(String message)
    : this._(status: ViewStatus.error, message: message);

  const ViewState.empty([String? message])
    : this._(status: ViewStatus.empty, message: message);

  final ViewStatus status;
  final T? data;
  final String? message;

  bool get isLoading => status == ViewStatus.loading;
  bool get isSuccess => status == ViewStatus.success;
  bool get isError => status == ViewStatus.error;
  bool get isEmpty => status == ViewStatus.empty;
}
