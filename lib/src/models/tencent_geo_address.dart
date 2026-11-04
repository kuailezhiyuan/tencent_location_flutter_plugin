/// 逆地理信息。
///
/// **映射来源**：
/// - Android `TencentLocation.getNation/Province/City/District/...`
/// - iOS `TencentLBSLocation.nation/province/city/...`
/// - Harmony `TencentGeoAddress`
class TencentGeoAddress {
  /// 位置名称。
  final String? name;

  /// 完整地址。
  final String? address;

  /// 国家。
  final String? nation;

  /// 国家编码（如中国 = 156）。**仅 Android 有**。
  ///
  /// 需要在 [TencentLocationRequestAndroidExtension.reGeoCodingKey] 设置后才能拿到。
  final int? nationCode;

  /// 省。
  final String? province;

  /// 市。
  final String? city;

  /// 区 / 县。
  final String? district;

  /// 镇。
  final String? town;

  /// 村。
  final String? village;

  /// 街道。
  final String? street;

  /// 街道门牌。
  final String? streetNo;

  /// 城市 adcode（6 位数字）。
  final String? cityCode;

  /// 城市电话区号。
  final String? cityPhoneCode;

  /// **仅 Android / iOS 有**，Harmony 为 `null`。
  final int? areaStat;

  const TencentGeoAddress({
    this.name,
    this.address,
    this.nation,
    this.nationCode,
    this.province,
    this.city,
    this.district,
    this.town,
    this.village,
    this.street,
    this.streetNo,
    this.cityCode,
    this.cityPhoneCode,
    this.areaStat,
  });

  factory TencentGeoAddress.fromMap(Map map) {
    return TencentGeoAddress(
      name: map['name'] as String?,
      address: map['address'] as String?,
      nation: map['nation'] as String?,
      nationCode: map['nationCode'] as int?,
      province: map['province'] as String?,
      city: map['city'] as String?,
      district: map['district'] as String?,
      town: map['town'] as String?,
      village: map['village'] as String?,
      street: map['street'] as String?,
      streetNo: map['streetNo'] as String?,
      cityCode: map['cityCode'] as String?,
      cityPhoneCode: map['cityPhoneCode'] as String?,
      areaStat: map['areaStat'] as int?,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'name': name,
        'address': address,
        'nation': nation,
        'nationCode': nationCode,
        'province': province,
        'city': city,
        'district': district,
        'town': town,
        'village': village,
        'street': street,
        'streetNo': streetNo,
        'cityCode': cityCode,
        'cityPhoneCode': cityPhoneCode,
        'areaStat': areaStat,
      };

  @override
  String toString() =>
      'TencentGeoAddress(nation=$nation, province=$province, city=$city, '
      'district=$district, address=$address)';
}
