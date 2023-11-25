library image_editor_plus;

import 'dart:async';
import 'dart:math' as math;
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:my_editor_plus/data/image_item.dart';
import 'package:my_editor_plus/layers_viewer.dart';
import 'package:my_editor_plus/loading_screen.dart';
import 'package:my_editor_plus/modules/layers_overlay.dart';
import 'package:my_editor_plus/utils.dart';

// import 'package:image_editor_plus/options.dart' as o;
import '../options.dart' as o;
import 'package:image_picker/image_picker.dart';
import 'package:my_editor_plus/data/layer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';

late Size viewportSize;
double viewportRatio = 1;

List<Layer> layers = [], undoLayers = [], removedLayers = [];
Map<String, String> _translations = {};

String i18n(String sourceString) =>
    _translations[sourceString.toLowerCase()] ?? sourceString;

/// Single endpoint for MultiImageEditor & SingleImageEditor
class ImageEditor extends StatelessWidget {
  final dynamic image;
  final List? images;
  final String? savePath;
  final int outputFormat;

  final o.ImagePickerOption imagePickerOption;
  final o.CropOption? cropOption;
  final o.FlipOption? flipOption;
  final o.RotateOption? rotateOption;

  const ImageEditor({
    super.key,
    this.image,
    this.images,
    this.savePath,
    this.imagePickerOption = const o.ImagePickerOption(),
    this.outputFormat = o.OutputFormat.jpeg,
    this.cropOption = const o.CropOption(),
    this.flipOption = const o.FlipOption(),
    this.rotateOption = const o.RotateOption(),
  });

  @override
  Widget build(BuildContext context) {
    if (image == null &&
        images == null &&
        !imagePickerOption.captureFromCamera &&
        !imagePickerOption.pickFromGallery) {
      throw Exception(
          'No image to work with, provide an image or allow the image picker.');
    }

    if (image != null) {
      return SingleImageEditor(
        image: image,
        savePath: savePath,
        imagePickerOption: imagePickerOption,
        outputFormat: outputFormat,
        cropOption: cropOption,
        flipOption: flipOption,
        rotateOption: rotateOption,
      );
    } else {
      return SingleImageEditor(
        image: image,
        savePath: savePath,
        imagePickerOption: imagePickerOption,
        outputFormat: outputFormat,
        cropOption: cropOption,
        flipOption: flipOption,
        rotateOption: rotateOption,
      );
    }
  }

  static i18n(Map<String, String> translations) {
    translations.forEach((key, value) {
      _translations[key.toLowerCase()] = value;
    });
  }

  /// Set custom theme properties default is dark theme with white text
  static ThemeData theme = ThemeData(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      background: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black87,
      iconTheme: IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      toolbarTextStyle: TextStyle(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.black,
    ),
    iconTheme: const IconThemeData(
      color: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white),
    ),
  );
}

/// Image editor with all option available
class SingleImageEditor extends StatefulWidget {
  final dynamic image;
  final String? savePath;
  final int outputFormat;

  final o.ImagePickerOption imagePickerOption;
  final o.CropOption? cropOption;

  final o.FlipOption? flipOption;
  final o.RotateOption? rotateOption;

  const SingleImageEditor({
    super.key,
    this.image,
    this.savePath,
    this.imagePickerOption = const o.ImagePickerOption(),
    this.outputFormat = o.OutputFormat.jpeg,
    this.cropOption = const o.CropOption(),
    this.flipOption = const o.FlipOption(),
    this.rotateOption = const o.RotateOption(),
  });

  @override
  createState() => _SingleImageEditorState();
}

class _SingleImageEditorState extends State<SingleImageEditor> {
  ImageItem currentImage = ImageItem();

  ScreenshotController screenshotController = ScreenshotController();

  PermissionStatus galleryPermission = PermissionStatus.permanentlyDenied,
      cameraPermission = PermissionStatus.permanentlyDenied;

  checkPermissions() async {
    if (widget.imagePickerOption.pickFromGallery) {
      galleryPermission = await Permission.photos.status;
    }

    if (widget.imagePickerOption.captureFromCamera) {
      cameraPermission = await Permission.camera.status;
    }

    if (widget.imagePickerOption.pickFromGallery ||
        widget.imagePickerOption.captureFromCamera) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    layers.clear();
    super.dispose();
  }

  List<Widget> get filterActions {
    return [
      const BackButton(),
      SizedBox(
        width: MediaQuery.of(context).size.width - 48,
        child: SingleChildScrollView(
          reverse: true,
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: Icon(Icons.undo,
                  color: layers.length > 1 || removedLayers.isNotEmpty
                      ? Colors.white
                      : Colors.grey),
              onPressed: () {
                if (removedLayers.isNotEmpty) {
                  layers.add(removedLayers.removeLast());
                  setState(() {});
                  return;
                }

                if (layers.length <= 1) return; // do not remove image layer

                undoLayers.add(layers.removeLast());

                setState(() {});
              },
            ),
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: Icon(Icons.redo,
                  color: undoLayers.isNotEmpty ? Colors.white : Colors.grey),
              onPressed: () {
                if (undoLayers.isEmpty) return;

                layers.add(undoLayers.removeLast());

                setState(() {});
              },
            ),
            if (widget.imagePickerOption.pickFromGallery)
              Opacity(
                opacity: galleryPermission.isPermanentlyDenied ? 0.5 : 1,
                child: IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  icon: const Icon(Icons.photo),
                  onPressed: () async {
                    if (await Permission.photos.isPermanentlyDenied) {
                      openAppSettings();
                    }

                    var image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );

                    if (image == null) return;

                    // loadImage(image);

                    layers.add(ImageLayerData(image: ImageItem(image)));
                    setState(() {});
                  },
                ),
              ),
            if (widget.imagePickerOption.captureFromCamera)
              Opacity(
                opacity: cameraPermission.isPermanentlyDenied ? 0.5 : 1,
                child: IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () async {
                    if (await Permission.camera.isPermanentlyDenied) {
                      openAppSettings();
                    }

                    var image = await picker.pickImage(
                      source: ImageSource.camera,
                    );

                    if (image == null) return;

                    // loadImage(image);

                    layers.add(ImageLayerData(image: ImageItem(image)));
                    setState(() {});
                  },
                ),
              ),
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: const Icon(Icons.check),
              onPressed: () async {
                resetTransformation();
                setState(() {});

                loadingScreen.show();

                if ((widget.outputFormat & 0x1) == o.OutputFormat.json) {
                  var json = layers.map((e) => e.toJson()).toList();

                  if ((widget.outputFormat & 0xFE) > 0) {
                    var editedImageBytes =
                        await getMergedImage(widget.outputFormat & 0xFE);

                    json.insert(0, {
                      'type': 'MergedLayer',
                      'image': editedImageBytes,
                    });
                  }

                  loadingScreen.hide();

                  if (mounted) Navigator.pop(context, json);
                } else {
                  var editedImageBytes =
                      await getMergedImage(widget.outputFormat & 0xFE);

                  loadingScreen.hide();

                  if (mounted) Navigator.pop(context, editedImageBytes);
                }
              },
            ),
          ]),
        ),
      ),
    ];
  }

  @override
  void initState() {
    if (widget.image != null) {
      loadImage(widget.image!);
    }

    checkPermissions();

    super.initState();
  }

  // double flipValue = 0;
  double flipValueVertical = 0;
  double flipValueHorizontal = 0;

  int rotateValue = 0;

  double x = 0;
  double y = 0;
  double z = 0;

  double lastScaleFactor = 1, scaleFactor = 1;
  double widthRatio = 1, heightRatio = 1, pixelRatio = 1;

  resetTransformation() {
    scaleFactor = 1;
    x = 0;
    y = 0;
    setState(() {});
  }

  /// obtain image Uint8List by merging layers
  Future<Uint8List?> getMergedImage([int format = o.OutputFormat.png]) async {
    Uint8List? image;

    if (layers.length == 1 && layers.first is BackgroundLayerData) {
      image = (layers.first as BackgroundLayerData).image.bytes;
    } else if (layers.length == 1 && layers.first is ImageLayerData) {
      image = (layers.first as ImageLayerData).image.bytes;
    } else {
      image = await screenshotController.capture(pixelRatio: pixelRatio);
    }

    // conversion for non-png
    if (image != null &&
        (format == o.OutputFormat.heic ||
            format == o.OutputFormat.jpeg ||
            format == o.OutputFormat.webp)) {
      var formats = {
        o.OutputFormat.heic: 'heic',
        o.OutputFormat.jpeg: 'jpeg',
        o.OutputFormat.webp: 'webp'
      };

      image = await ImageUtils.convert(image, format: formats[format]!);
    }

    return image;
  }

  @override
  Widget build(BuildContext context) {
    viewportSize = MediaQuery.of(context).size;
    pixelRatio = MediaQuery.of(context).devicePixelRatio;

    // widthRatio = currentImage.width / viewportSize.width;
    // heightRatio = currentImage.height / viewportSize.height;
    // pixelRatio = math.max(heightRatio, widthRatio);

    return Theme(
      data: ImageEditor.theme,
      child: Scaffold(
        key: scaffoldGlobalKey,
        body: Stack(children: [
          GestureDetector(
            onScaleUpdate: (details) {
              // print(details);

              // move
              if (details.pointerCount == 1) {
                // print(details.focalPointDelta);
                x += details.focalPointDelta.dx;
                y += details.focalPointDelta.dy;
                setState(() {});
              }

              // scale
              if (details.pointerCount == 2) {
                // print([details.horizontalScale, details.verticalScale]);
                if (details.horizontalScale != 1) {
                  scaleFactor = lastScaleFactor *
                      math.min(details.horizontalScale, details.verticalScale);

                  setState(() {});
                }

                // check for vertical flip
                // if (details.verticalScale < 0) {
                //   flipValue = flipValue == 0 ? math.pi : 0;
                //   setState(() {});
                // }
                // check for vertical flip
                if (details.verticalScale < 0) {
                  flipValueVertical = flipValueVertical == 0 ? math.pi : 0;
                  setState(() {});
                }

                // check for horizontal flip
                if (details.horizontalScale < 0) {
                  // Update the flipValue for horizontal flip
                  flipValueHorizontal = flipValueHorizontal == 0 ? math.pi : 0;
                  setState(() {});
                }
              }
            },
            onScaleEnd: (details) {
              lastScaleFactor = scaleFactor;
            },
            child: Center(
              child: SizedBox(
                height: currentImage.height / pixelRatio,
                width: currentImage.width / pixelRatio,
                child: Screenshot(
                  controller: screenshotController,
                  child: RotatedBox(
                    quarterTurns: rotateValue,
                    child: Transform(
                      transform: Matrix4(
                        1,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                        x,
                        y,
                        0,
                        1 / scaleFactor,
                      )
                        ..rotateY(flipValueHorizontal)
                        ..rotateX(flipValueVertical),
                      alignment: FractionalOffset.center,
                      child: LayersViewer(
                        layers: layers,
                        onUpdate: () {
                          setState(() {});
                        },
                        editable: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
              ),
              child: SafeArea(
                child: Row(
                  children: filterActions,
                ),
              ),
            ),
          ),
          if (layers.length > 1)
            Positioned(
              bottom: 64,
              left: 0,
              child: SafeArea(
                child: Container(
                  height: 48,
                  width: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(100),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(19),
                      bottomRight: Radius.circular(19),
                    ),
                  ),
                  child: IconButton(
                    iconSize: 20,
                    padding: const EdgeInsets.all(0),
                    onPressed: () {
                      showModalBottomSheet(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(10),
                            topLeft: Radius.circular(10),
                          ),
                        ),
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => SafeArea(
                          child: ManageLayersOverlay(
                            layers: layers,
                            onUpdate: () => setState(() {}),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.layers),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 64,
            right: 0,
            child: SafeArea(
              child: Container(
                height: 48,
                width: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(100),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(19),
                    bottomLeft: Radius.circular(19),
                  ),
                ),
                child: IconButton(
                  iconSize: 20,
                  padding: const EdgeInsets.all(0),
                  onPressed: () {
                    resetTransformation();
                  },
                  icon: Icon(
                    scaleFactor > 1 ? Icons.zoom_in_map : Icons.zoom_out_map,
                  ),
                ),
              ),
            ),
          ),
        ]),
        bottomNavigationBar: Container(
          // color: Colors.black45,
          alignment: Alignment.bottomCenter,
          height: 86 + MediaQuery.of(context).padding.bottom,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.black87,
            shape: BoxShape.rectangle,
            //   boxShadow: [
            //     BoxShadow(blurRadius: 1),
            //   ],
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (widget.cropOption != null)
                    BottomButton(
                      icon: Icons.crop,
                      text: i18n('Crop'),
                      onTap: () async {
                        resetTransformation();
                        LoadingScreen(scaffoldGlobalKey).show();
                        var mergedImage = await getMergedImage();
                        LoadingScreen(scaffoldGlobalKey).hide();

                        if (!mounted) return;

                        Uint8List? croppedImage = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImageCropper(
                              image: mergedImage!,
                              availableRatios: widget.cropOption!.ratios,
                            ),
                          ),
                        );

                        if (croppedImage == null) return;

                        // flipValue = 0;
                        rotateValue = 0;

                        await currentImage.load(croppedImage);
                        setState(() {});
                      },
                    ),
                  if (widget.flipOption != null)
                    BottomButton(
                      icon: Icons.flip,
                      text: i18n('H Flip'),
                      onTap: () {
                        setState(() {
                          // flipValue = flipValue == 0 ? math.pi : 0;
                          // print('flip value : $flipValue');
                          flipValueHorizontal =
                              flipValueHorizontal == 0 ? math.pi : 0;
                        });
                      },
                    ),
                  if (widget.flipOption != null)
                    BottomButton(
                      icon: Icons.flip,
                      text: i18n('V Flip'),
                      onTap: () {
                        setState(() {
                          // flipValue = flipValue == 0 ? math.pi : 0;
                          // print('flip value : $flipValue');
                          flipValueVertical =
                              flipValueVertical == 0 ? math.pi : 0;
                        });
                      },
                    ),
                  if (widget.rotateOption != null)
                    BottomButton(
                      icon: Icons.rotate_left,
                      text: i18n('Rotate left'),
                      onTap: () {
                        var t = currentImage.width;
                        currentImage.width = currentImage.height;
                        currentImage.height = t;

                        rotateValue--;
                        setState(() {});
                      },
                    ),
                  if (widget.rotateOption != null)
                    BottomButton(
                      icon: Icons.rotate_right,
                      text: i18n('Rotate right'),
                      onTap: () {
                        var t = currentImage.width;
                        currentImage.width = currentImage.height;
                        currentImage.height = t;

                        rotateValue++;
                        setState(() {});
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  final picker = ImagePicker();

  Future<void> loadImage(dynamic imageFile) async {
    await currentImage.load(imageFile);

    layers.clear();

    layers.add(BackgroundLayerData(
      image: currentImage,
    ));

    setState(() {});
  }
}

/// Button used in bottomNavigationBar in ImageEditor
class BottomButton extends StatelessWidget {
  final VoidCallback? onTap, onLongPress;
  final IconData icon;
  final String text;

  const BottomButton({
    super.key,
    this.onTap,
    this.onLongPress,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              i18n(text),
            ),
          ],
        ),
      ),
    );
  }
}

/// Crop given image with various aspect ratios
class ImageCropper extends StatefulWidget {
  final Uint8List image;
  final List<o.AspectRatio> availableRatios;

  const ImageCropper({
    super.key,
    required this.image,
    this.availableRatios = const [
      o.AspectRatio(title: 'Freeform'),
      o.AspectRatio(title: '1:1', ratio: 1),
      o.AspectRatio(title: '4:3', ratio: 4 / 3),
      o.AspectRatio(title: '5:4', ratio: 5 / 4),
      o.AspectRatio(title: '7:5', ratio: 7 / 5),
      o.AspectRatio(title: '16:9', ratio: 16 / 9),
      o.AspectRatio(title: '9:16', ratio: 9 / 16),
    ],
  });

  @override
  createState() => _ImageCropperState();
}

class _ImageCropperState extends State<ImageCropper> {
  final GlobalKey<ExtendedImageEditorState> _controller =
      GlobalKey<ExtendedImageEditorState>();

  double? currentRatio;
  bool isLandscape = true;
  int rotateAngle = 0;

  double? get aspectRatio => currentRatio == null
      ? null
      : isLandscape
          ? currentRatio!
          : (1 / currentRatio!);

  @override
  void initState() {
    if (widget.availableRatios.isNotEmpty) {
      currentRatio = widget.availableRatios.first.ratio;
    }
    _controller.currentState?.rotate(right: true);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.currentState != null) {
      // _controller.currentState?.
    }

    return Theme(
      data: ImageEditor.theme,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: const Icon(Icons.check),
              onPressed: () async {
                var state = _controller.currentState;

                if (state == null || state.getCropRect() == null) {
                  Navigator.pop(context);
                }

                var data = await cropImageWithThread(
                  imageBytes: state!.rawImageData,
                  rect: state.getCropRect()!,
                );

                if (mounted) Navigator.pop(context, data);
              },
            ),
          ],
        ),
        body: Container(
          color: Colors.black,
          child: ExtendedImage.memory(
            widget.image,
            cacheRawData: true,
            fit: BoxFit.contain,
            extendedImageEditorKey: _controller,
            mode: ExtendedImageMode.editor,
            initEditorConfigHandler: (state) {
              return EditorConfig(
                cropAspectRatio: aspectRatio,
              );
            },
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: SizedBox(
            height: 80,
            child: Column(
              children: [
                // Container(
                //   height: 48,
                //   decoration: const BoxDecoration(
                //     boxShadow: [
                //       BoxShadow(
                //         color: black,
                //         blurRadius: 10,
                //       ),
                //     ],
                //   ),
                //   child: ListView(
                //     scrollDirection: Axis.horizontal,
                //     children: <Widget>[
                //       IconButton(
                //         icon: Icon(
                //           Icons.portrait,
                //           color: isLandscape ? gray : white,
                //         ).paddingSymmetric(horizontal: 8, vertical: 4),
                //         onPressed: () {
                //           isLandscape = false;
                //
                //           setState(() {});
                //         },
                //       ),
                //       IconButton(
                //         icon: Icon(
                //           Icons.landscape,
                //           color: isLandscape ? white : gray,
                //         ).paddingSymmetric(horizontal: 8, vertical: 4),
                //         onPressed: () {
                //           isLandscape = true;
                //
                //           setState(() {});
                //         },
                //       ),
                //       Slider(
                //         activeColor: Colors.white,
                //         inactiveColor: Colors.grey,
                //         value: rotateAngle.toDouble(),
                //         min: 0.0,
                //         max: 100.0,
                //         onChangeEnd: (v) {
                //           rotateAngle = v.toInt();
                //           setState(() {});
                //         },
                //         onChanged: (v) {
                //           rotateAngle = v.toInt();
                //           setState(() {});
                //         },
                //       ),
                //     ],
                //   ),
                // ),
                Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        // if (currentRatio != null && currentRatio != 1)
                        //   IconButton(
                        //     padding: const EdgeInsets.symmetric(
                        //       horizontal: 8,
                        //       vertical: 4,
                        //     ),
                        //     icon: Icon(
                        //       Icons.portrait,
                        //       color: isLandscape ? Colors.grey : Colors.white,
                        //     ),
                        //     onPressed: () {
                        //       isLandscape = false;

                        //       setState(() {});
                        //     },
                        //   ),
                        // if (currentRatio != null && currentRatio != 1)
                        //   IconButton(
                        //     padding: const EdgeInsets.symmetric(
                        //       horizontal: 8,
                        //       vertical: 4,
                        //     ),
                        //     icon: Icon(
                        //       Icons.landscape,
                        //       color: isLandscape ? Colors.white : Colors.grey,
                        //     ),
                        //     onPressed: () {
                        //       isLandscape = true;

                        //       setState(() {});
                        //     },
                        //   ),
                        for (var ratio in widget.availableRatios)
                          TextButton(
                            onPressed: () {
                              currentRatio = ratio.ratio;

                              setState(() {});
                            },
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Text(
                                  i18n(ratio.title),
                                  style: TextStyle(
                                    color: currentRatio == ratio.ratio
                                        ? Colors.white
                                        : Colors.grey,
                                  ),
                                )),
                          )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> cropImageWithThread({
    required Uint8List imageBytes,
    required Rect rect,
  }) async {
    img.Command cropTask = img.Command();
    cropTask.decodeImage(imageBytes);

    cropTask.copyCrop(
      x: rect.topLeft.dx.ceil(),
      y: rect.topLeft.dy.ceil(),
      height: rect.height.ceil(),
      width: rect.width.ceil(),
    );

    img.Command encodeTask = img.Command();
    encodeTask.subCommand = cropTask;
    encodeTask.encodeJpg();

    return encodeTask.getBytesThread();
  }
}
