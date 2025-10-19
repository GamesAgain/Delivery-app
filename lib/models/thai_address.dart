class Province {
  Province({
    required this.id,
    required this.nameTh,
    required this.nameEn,
  });

  final int id;
  final String nameTh;
  final String nameEn;

  factory Province.fromJson(Map<String, dynamic> json) {
    return Province(
      id: _parseId(json['id']),
      nameTh: json['name_th'] as String,
      nameEn: json['name_en'] as String,
    );
  }
}

class District {
  District({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.provinceId,
  });

  final int id;
  final String nameTh;
  final String nameEn;
  final int provinceId;

  factory District.fromJson(Map<String, dynamic> json) {
    final provinceIdValue =
        json['province_id'] ?? json['provinceId'] ?? json['province_code'];
    if (provinceIdValue == null) {
      throw const FormatException('Missing province id in district payload');
    }
    return District(
      id: _parseId(json['id']),
      nameTh: json['name_th'] as String,
      nameEn: json['name_en'] as String,
      provinceId: _parseId(provinceIdValue),
    );
  }
}

class SubDistrict {
  SubDistrict({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.zipCode,
    required this.districtId,
  });

  final int id;
  final String nameTh;
  final String nameEn;
  final String zipCode;
  final int districtId;

  factory SubDistrict.fromJson(Map<String, dynamic> json) {
    final districtIdValue = json['amphure_id'] ??
        json['district_id'] ??
        json['districtId'] ??
        json['amphure_code'] ??
        json['district_code'];
    if (districtIdValue == null) {
      throw const FormatException('Missing district id in sub-district payload');
    }
    return SubDistrict(
      id: _parseId(json['id']),
      nameTh: json['name_th'] as String,
      nameEn: json['name_en'] as String,
      zipCode: json['zip_code'].toString(),
      districtId: _parseId(districtIdValue),
    );
  }
}

int _parseId(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.parse(value);
  }
  throw FormatException('Invalid identifier value: $value');
}
