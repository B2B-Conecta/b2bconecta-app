import 'dart:typed_data';

typedef CatalogSourcePhoto = ({
  Uint8List bytes,
  String name,
  String extension,
  int? sourceRow,
  bool singleRow,
});

typedef CatalogPhotoSource = ({
  String? sheet,
  List<CatalogSourcePhoto> photos,
  List<String> issues,
});
