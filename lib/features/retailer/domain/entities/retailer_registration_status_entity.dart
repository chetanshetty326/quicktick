import 'package:equatable/equatable.dart';

class RetailerCheckRegisteredEntity extends Equatable {
  final bool registered;
  final String? status;
  final String? shopName;
  final String? remarks;

  const RetailerCheckRegisteredEntity({
    required this.registered,
    this.status,
    this.shopName,
    this.remarks,
  });

  bool get isApproved => registered && (status?.toUpperCase() == 'APPROVED');
  bool get isPending => registered && (status?.toUpperCase() == 'PENDING');
  bool get isRejected => registered && (status?.toUpperCase() == 'REJECTED');
  bool get isSuspended => registered && (status?.toUpperCase() == 'SUSPENDED');
  bool get isNotRegistered => !registered;

  @override
  List<Object?> get props => [registered, status, shopName, remarks];
}

class RejectedDocumentEntity extends Equatable {
  final String type;
  final String remarks;

  const RejectedDocumentEntity({
    required this.type,
    required this.remarks,
  });

  @override
  List<Object?> get props => [type, remarks];
}

class RetailerRejectionEntity extends Equatable {
  final String status;
  final String? remarks;
  final String? reviewedAt;
  final List<RejectedDocumentEntity> rejectedDocuments;

  const RetailerRejectionEntity({
    required this.status,
    this.remarks,
    this.reviewedAt,
    this.rejectedDocuments = const [],
  });

  @override
  List<Object?> get props => [status, remarks, reviewedAt, rejectedDocuments];
}

class FileUploadEntity extends Equatable {
  final String url;
  final String publicId;
  final String format;
  final int bytes;

  const FileUploadEntity({
    required this.url,
    required this.publicId,
    required this.format,
    required this.bytes,
  });

  @override
  List<Object?> get props => [url, publicId, format, bytes];
}
