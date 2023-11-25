class OutputFormat {
  static const int

      /// get all layers in json
      json = 0x1,

      /// get merged layer in heic
      heic = 0x2,

      /// get merged layer in jpeg
      jpeg = 0x4,

      /// get merged layer in png
      png = 0x8,

      /// get merged layer in webp
      webp = 0x10;
}

class AspectRatio {
  final String title;
  final double? ratio;

  const AspectRatio({required this.title, this.ratio});
}

class CropOption {
  final bool reversible;

  /// List of availble ratios
  final List<AspectRatio> ratios;

  const CropOption({
    this.reversible = true,
    this.ratios = const [
      AspectRatio(title: 'Freeform'),
      AspectRatio(title: '1:1', ratio: 1),
      AspectRatio(title: '4:3', ratio: 4 / 3),
      AspectRatio(title: '5:4', ratio: 5 / 4),
      AspectRatio(title: '7:5', ratio: 7 / 5),
      AspectRatio(title: '16:9', ratio: 16 / 9),
      AspectRatio(title: '9:16', ratio: 9 / 16),
    ],
  });
}

class FlipOption {
  const FlipOption();
}

class RotateOption {
  const RotateOption();
}

class ImagePickerOption {
  final bool pickFromGallery, captureFromCamera;
  final int maxLength;

  const ImagePickerOption({
    this.pickFromGallery = false,
    this.captureFromCamera = false,
    this.maxLength = 99,
  });
}
