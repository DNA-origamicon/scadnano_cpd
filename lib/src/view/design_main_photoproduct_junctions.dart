import 'package:over_react/over_react.dart';
import 'package:over_react/over_react_redux.dart';
import 'package:built_collection/built_collection.dart';
import '../app.dart';
import '../middleware/detect_cpd_sites.dart' show get_loaded_cpd_params;
import '../state/app_state.dart';
import '../state/photoproduct_junction.dart';
import '../state/t_base_location.dart';
import '../state/geometry.dart';
import '../actions/actions.dart' as actions;

part 'design_main_photoproduct_junctions.over_react.g.dart';

UiFactory<DesignMainPhotoproductJunctionsProps> ConnectedDesignMainPhotoproductJunctions =
    connect<AppState, DesignMainPhotoproductJunctionsProps>(
  mapStateToProps: (state) {
    return DesignMainPhotoproductJunctions()
      ..photoproduct_junctions = state.design?.photoproduct_junctions ?? BuiltList()
      ..t_base_locations = state.ui_state.t_base_locations
      ..geometry = state.design?.geometry
      ..show_photoproduct_junctions = state.ui_state.show_photoproduct_junctions;
  },
)(DesignMainPhotoproductJunctions);

UiFactory<DesignMainPhotoproductJunctionsProps> DesignMainPhotoproductJunctions =
    _$DesignMainPhotoproductJunctions;

mixin DesignMainPhotoproductJunctionsProps on UiProps {
  BuiltList<PhotoproductJunction>? photoproduct_junctions;
  TBaseLocations? t_base_locations;
  Geometry? geometry;
  bool? show_photoproduct_junctions;
}

class DesignMainPhotoproductJunctionsComponent
    extends UiComponent2<DesignMainPhotoproductJunctionsProps> {
  @override
  render() {
    if (!(props.show_photoproduct_junctions ?? true)) return null;

    final junctions = props.photoproduct_junctions;
    if (junctions == null || junctions.isEmpty) return null;

    final t_locs = props.t_base_locations;
    if (t_locs == null) return null;

    // Build a quick lookup: stable_id → visual position
    final Map<String, _VisualPos> pos_map = {};
    for (var t in t_locs.t_bases) {
      if (t.visual_x != null && t.visual_y != null) {
        pos_map[t.stable_id] = _VisualPos(t.visual_x!, t.visual_y!);
      }
    }

    double half_size =
        props.geometry?.base_width_svg != null ? props.geometry!.base_width_svg * 0.40 : 4.0;

    List<ReactElement> elements = [];

    for (var j in junctions) {
      final p1 = pos_map[j.t1_stable_id];
      final p2 = pos_map[j.t2_stable_id];

      if (p1 == null || p2 == null) continue;

      // Midpoint between the two T bases.
      double mx = (p1.x + p2.x) / 2.0;
      double my = (p1.y + p2.y) / 2.0;

      // Color from loaded cpd parameters; fall back to goldenrod.
      final params = get_loaded_cpd_params();
      String color = 'goldenrod';
      if (params != null) {
        color = params.photoproduct(j.photoproduct_id)?.color ?? 'goldenrod';
      }

      // Diamond (rotated square) rendered as a <polygon>.
      // Four vertices: top, right, bottom, left relative to midpoint.
      String points =
          '${mx},${my - half_size} '
          '${mx + half_size},${my} '
          '${mx},${my + half_size} '
          '${mx - half_size},${my}';

      // Capture stable IDs for closure.
      final t1_id = j.t1_stable_id;
      final t2_id = j.t2_stable_id;
      String key = 'pp-junction-${t1_id}-${t2_id}';

      elements.add((Dom.polygon()
        ..points = points
        ..fill = color
        ..fillOpacity = 0.85
        ..stroke = 'black'
        ..strokeWidth = 0.8
        ..key = key
        ..title = '${j.photoproduct_id}: ${t1_id} / ${t2_id}\nClick to remove'
        ..onClick = ((_) => app.dispatch(actions.UnmarkPhotoproductJunction(t1_id, t2_id))))());
    }

    return (Dom.g()
      ..key = 'photoproduct-junctions-layer'
      ..className = 'photoproduct-junctions-layer')(
      elements,
    );
  }
}

class _VisualPos {
  final double x;
  final double y;
  const _VisualPos(this.x, this.y);
}
