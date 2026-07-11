enum GridMode { off, grid8, grid16, crosshair, margins }

class OverlayStateEntity {
  final double? top;
  final double? left;
  final bool positionInit;
  final bool isExpanded;
  final GridMode gridMode;
  final bool isTucked;
  final bool tuckedLeft;
  final bool wasExpandedBeforeTuck;

  const OverlayStateEntity({
    this.top,
    this.left,
    this.positionInit = false,
    this.isExpanded = false,
    this.gridMode = GridMode.off,
    this.isTucked = false,
    this.tuckedLeft = false,
    this.wasExpandedBeforeTuck = false,
  });

  OverlayStateEntity copyWith({
    double? top,
    double? left,
    bool? positionInit,
    bool? isExpanded,
    GridMode? gridMode,
    bool? isTucked,
    bool? tuckedLeft,
    bool? wasExpandedBeforeTuck,
  }) {
    return OverlayStateEntity(
      top: top ?? this.top,
      left: left ?? this.left,
      positionInit: positionInit ?? this.positionInit,
      isExpanded: isExpanded ?? this.isExpanded,
      gridMode: gridMode ?? this.gridMode,
      isTucked: isTucked ?? this.isTucked,
      tuckedLeft: tuckedLeft ?? this.tuckedLeft,
      wasExpandedBeforeTuck:
          wasExpandedBeforeTuck ?? this.wasExpandedBeforeTuck,
    );
  }
}
