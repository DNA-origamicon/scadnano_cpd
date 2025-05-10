import 'dart:math';
import 'package:over_react/over_react.dart';
import 'package:over_react/over_react_redux.dart';
import 'package:built_collection/built_collection.dart';
import '../state/app_state.dart';
import '../state/cpd_site.dart';
import '../state/t_base_location.dart';
import '../state/geometry.dart';

part 'design_main_cpd_highlights.over_react.g.dart';

// Define the connected component factory inline
UiFactory<DesignMainCPDHighlightsProps> ConnectedDesignMainCPDHighlights =
    connect<AppState, DesignMainCPDHighlightsProps>(
  mapStateToProps: (state) {
    return DesignMainCPDHighlights()
      ..cpd_sites = state.ui_state.cpd_sites
      ..t_base_locations = state.ui_state.t_base_locations
      ..geometry = state.design.geometry
      ..show_all_t_bases = state.ui_state.show_all_t_bases
      ..show_cpd_sites_continuously = state.ui_state.show_cpd_sites_continuously;
  },
)(DesignMainCPDHighlights);

// Base component factory
UiFactory<DesignMainCPDHighlightsProps> DesignMainCPDHighlights = _$DesignMainCPDHighlights;

mixin DesignMainCPDHighlightsProps on UiProps {
  BuiltList<CPDSite>? cpd_sites;
  TBaseLocations? t_base_locations;
  Geometry? geometry;
  bool? show_all_t_bases;
  bool? show_cpd_sites_continuously;
}

class DesignMainCPDHighlightsComponent extends UiComponent2<DesignMainCPDHighlightsProps> {
  @override
  render() {
    if (!(props.show_all_t_bases ?? false) && !(props.show_cpd_sites_continuously ?? false)) {
      return null;
    }

    List<ReactElement> elements = [];
    double radius = props.geometry?.base_width_svg != null ? props.geometry!.base_width_svg * 0.35 : 3.5;

    // Render light blue circles for ALL T-bases that have visual coordinates
    // (We draw these first so pink circles/lines draw on top)
    if (props.show_all_t_bases ?? false) {
      if (props.t_base_locations != null) {
        for (var t_base in props.t_base_locations!.t_bases) {
          if (t_base.visual_x != null && t_base.visual_y != null) {
            elements.add((Dom.circle()
              ..cx = t_base.visual_x!
              ..cy = t_base.visual_y!
              ..r = radius
              ..fill = 'lightblue' // Use light blue for all T's initially
              ..fillOpacity = 0.5
              ..key = 'tbase-all-${t_base.stable_id}')());
          }
        }
      }
    }

    // Render highlights for CPD sites (pink circles and connecting lines)
    // These will draw *over* the light blue circles for paired T's
    if (props.show_cpd_sites_continuously ?? false) {
      if (props.cpd_sites != null) {
        for (var cpd_site in props.cpd_sites!) {
          TBaseLocation t1 = cpd_site.t1;
          TBaseLocation t2 = cpd_site.t2;
          bool is_conflicted_site = cpd_site.is_conflicted;

          String circle_fill_color = is_conflicted_site ? 'red' : 'pink';
          String line_stroke_color = is_conflicted_site ? 'red' : 'pink';

          Point<double>? visual_pos_t1;
          Point<double>? visual_pos_t2;

          if (t1.visual_x != null && t1.visual_y != null) {
            visual_pos_t1 = Point<double>(t1.visual_x!, t1.visual_y!);
          }
          if (t2.visual_x != null && t2.visual_y != null) {
            visual_pos_t2 = Point<double>(t2.visual_x!, t2.visual_y!);
          }

          String base_key_t1 = 'tbase-cpd-${t1.stable_id}';
          String base_key_t2 = 'tbase-cpd-${t2.stable_id}';
          String pair_key = 'cpd-${t1.stable_id}-${t2.stable_id}';

          // Add visual position highlight for t1 (pink/red circle)
          if (visual_pos_t1 != null) {
            elements.add((Dom.circle()
              ..cx = visual_pos_t1.x
              ..cy = visual_pos_t1.y
              ..r = radius
              ..fill = circle_fill_color
              ..fillOpacity = 0.8
              ..key = 'tbase-cpd-circle-${t1.stable_id}-from-${pair_key}')());
          }

          // Add visual position highlight for t2 (pink/red circle)
          if (visual_pos_t2 != null) {
            elements.add((Dom.circle()
              ..cx = visual_pos_t2.x
              ..cy = visual_pos_t2.y
              ..r = radius
              ..fill = circle_fill_color
              ..fillOpacity = 0.8
              ..key = 'tbase-cpd-circle-${t2.stable_id}-from-${pair_key}')());
          }

          // Add connecting lines if we have both visual positions
          if (visual_pos_t1 != null && visual_pos_t2 != null) {
            double dx = visual_pos_t2.x - visual_pos_t1.x;
            double dy = visual_pos_t2.y - visual_pos_t1.y;
            double dist = sqrt(dx * dx + dy * dy);

            // Only draw lines if the points are distinct enough
            // If dist is very small (or zero), drawing connecting lines might cause issues.
            if (dist > 1e-6) { 
              // Normalized perpendicular vector components
              // This vector points "to the left" if you are looking from t1 towards t2
              double perp_dx_norm = -dy / dist;
              double perp_dy_norm = dx / dist;

              // Define the offset for each line from the original centerline.
              // The total gap between the two lines will be 2 * line_offset.
              // Using radius * 0.25 means the gap is radius * 0.5.
              double line_offset = radius * 0.30;
              double line_stroke_width = 1.5;

              // Line 1
              elements.add((Dom.line()
                ..x1 = visual_pos_t1.x + perp_dx_norm * line_offset
                ..y1 = visual_pos_t1.y + perp_dy_norm * line_offset
                ..x2 = visual_pos_t2.x + perp_dx_norm * line_offset
                ..y2 = visual_pos_t2.y + perp_dy_norm * line_offset
                ..stroke = line_stroke_color
                ..strokeWidth = line_stroke_width
                ..key = '${pair_key}-line1')());

              // Line 2
              elements.add((Dom.line()
                ..x1 = visual_pos_t1.x - perp_dx_norm * line_offset
                ..y1 = visual_pos_t1.y - perp_dy_norm * line_offset
                ..x2 = visual_pos_t2.x - perp_dx_norm * line_offset
                ..y2 = visual_pos_t2.y - perp_dy_norm * line_offset
                ..stroke = line_stroke_color
                ..strokeWidth = line_stroke_width
                ..key = '${pair_key}-line2')());
            }
          }
        }
      }
    }

    return (Dom.g()
      ..key = 't-base-highlights-layer'
      ..className = 't-base-highlights-layer')(
      elements,
    );
  }

}
