import 'package:flutter/material.dart';
import 'package:my_editor_plus/data/layer.dart';
import 'package:my_editor_plus/layers/background_layer.dart';
import 'package:my_editor_plus/layers/image_layer.dart';

/// View stacked layers (unbounded height, width)
class LayersViewer extends StatelessWidget {
  final List<Layer> layers;
  final Function()? onUpdate;
  final bool editable;

  const LayersViewer({
    super.key,
    required this.layers,
    required this.editable,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: layers.map((layerItem) {
        // Background layer
        if (layerItem is BackgroundLayerData) {
          return BackgroundLayer(
            layerData: layerItem,
            onUpdate: onUpdate,
            editable: editable,
          );
        }

        // Image layer
        if (layerItem is ImageLayerData) {
          return ImageLayer(
            layerData: layerItem,
            onUpdate: onUpdate,
            editable: editable,
          );
        }

    

        // Blank layer
        return Container();
      }).toList(),
    );
  }
}
