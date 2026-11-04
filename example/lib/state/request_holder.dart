import 'package:flutter/foundation.dart';
import 'package:tencent_location_flutter_plugin/tencent_location_flutter_plugin.dart';

/// Demo 侧持有 [TencentLocationRequest]，作为 [ChangeNotifier] 供 UI listen。
///
/// 这里用 "可变持有 + notifyListeners()" 而不是 `copyWith`，因为 Flutter Plugin 的
/// Request 对象本来就是 mutable 的（链式 setter 直接改当前对象）。
class RequestHolder extends ChangeNotifier {
  TencentLocationRequest _request = TencentLocationRequest.create();

  TencentLocationRequest get request => _request;

  /// 在闭包里修改 request，结束后通知 UI 重建。
  void edit(void Function(TencentLocationRequest r) updater) {
    updater(_request);
    notifyListeners();
  }

  /// 重置回默认值。
  void reset() {
    _request = TencentLocationRequest.create();
    notifyListeners();
  }
}
