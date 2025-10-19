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
      id: (json['id'] as num).toInt(),
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
    return District(
      id: (json['id'] as num).toInt(),
      nameTh: json['name_th'] as String,
      nameEn: json['name_en'] as String,
      provinceId: (json['province_id'] as num).toInt(),
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
    return SubDistrict(
      id: (json['id'] as num).toInt(),
      nameTh: json['name_th'] as String,
      nameEn: json['name_en'] as String,
      zipCode: json['zip_code'] as String,
      districtId: (json['amphure_id'] as num).toInt(),
    );
  }
}
