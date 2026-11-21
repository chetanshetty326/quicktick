import '../../domain/entities/retailer_registration_status_entity.dart';

class RetailerCheckRegisteredModel extends RetailerCheckRegisteredEntity {
  const RetailerCheckRegisteredModel({
    required super.registered,
    super.status,
    super.shopName,
    super.remarks,
  });

  factory RetailerCheckRegisteredModel.fromJson(Map<String, dynamic> json) {
    // Backend returns { success: true, data: { registered: true, status: "APPROVED", ... } }
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;

    return RetailerCheckRegisteredModel(
      registered: data['registered'] == true,
      status: data['status']?.toString(),
      shopName: data['shopName']?.toString(),
      remarks: data['remarks']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'registered': registered,
      if (status != null) 'status': status,
      if (shopName != null) 'shopName': shopName,
      if (remarks != null) 'remarks': remarks,
    };
  }
}

class RejectedDocumentModel extends RejectedDocumentEntity {
  const RejectedDocumentModel({
    required super.type,
    required super.remarks,
  });

  factory RejectedDocumentModel.fromJson(Map<String, dynamic> json) {
    return RejectedDocumentModel(
      type: json['type']?.toString() ?? 'DOCUMENT',
      remarks: json['remarks']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'remarks': remarks,
    };
  }
}

class RetailerRejectionModel extends RetailerRejectionEntity {
  const RetailerRejectionModel({
    required super.status,
    super.remarks,
    super.reviewedAt,
    super.rejectedDocuments = const [],
  });

  factory RetailerRejectionModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;

    final List<RejectedDocumentModel> docs = [];
    if (data['rejectedDocuments'] is List) {
      for (final item in (data['rejectedDocuments'] as List)) {
        if (item is Map<String, dynamic>) {
          docs.add(RejectedDocumentModel.fromJson(item));
        } else if (item is Map) {
          docs.add(RejectedDocumentModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return RetailerRejectionModel(
      status: data['status']?.toString() ?? 'REJECTED',
      remarks: data['remarks']?.toString(),
      reviewedAt: data['reviewedAt']?.toString(),
      rejectedDocuments: docs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      if (remarks != null) 'remarks': remarks,
      if (reviewedAt != null) 'reviewedAt': reviewedAt,
      'rejectedDocuments': rejectedDocuments
          .map((d) => (d as RejectedDocumentModel).toJson())
          .toList(),
    };
  }
}

class FileUploadModel extends FileUploadEntity {
  const FileUploadModel({
    required super.url,
    required super.publicId,
    required super.format,
    required super.bytes,
  });

  factory FileUploadModel.fromJson(Map<String, dynamic> json) {
    Map rawData = json;
    if (json['data'] is Map) {
      final d = json['data'] as Map;
      rawData = d['file'] is Map ? d['file'] as Map : (d['upload'] is Map ? d['upload'] as Map : d);
    } else if (json['file'] is Map) {
      rawData = json['file'] as Map;
    }
    final data = Map<String, dynamic>.from(rawData);

    final resolvedUrl = data['url']?.toString() ??
        data['secure_url']?.toString() ??
        data['imageUrl']?.toString() ??
        data['fileUrl']?.toString() ??
        data['file_url']?.toString() ??
        data['location']?.toString() ??
        data['path']?.toString() ??
        '';

    return FileUploadModel(
      url: resolvedUrl,
      publicId: data['publicId']?.toString() ?? data['filename']?.toString() ?? data['id']?.toString() ?? '',
      format: data['format']?.toString() ?? data['mimetype']?.toString() ?? '',
      bytes: (data['bytes'] as num?)?.toInt() ?? (data['size'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'publicId': publicId,
      'format': format,
      'bytes': bytes,
    };
  }
}
