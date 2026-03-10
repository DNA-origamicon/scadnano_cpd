import 'dart:math';
import 'dart:html' show MouseEvent;
import 'package:over_react/over_react.dart';
import 'package:over_react/over_react_redux.dart';
import 'package:built_collection/built_collection.dart';
import '../app.dart';
import '../middleware/detect_cpd_sites.dart' show get_loaded_cpd_params;
import '../state/app_state.dart';
import '../state/context_menu.dart';
import '../state/cpd_site.dart';
import '../state/photoproduct_junction.dart';
import '../state/t_base_location.dart';
import '../state/geometry.dart';
import '../actions/actions.dart' as actions;
import '../util.dart' as util;

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
      ..show_cpd_sites_continuously = state.ui_state.show_cpd_sites_continuously
      ..cpd_score_threshold = state.ui_state.cpd_score_threshold;
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
  double? cpd_score_threshold;
}

class DesignMainCPDHighlightsComponent extends UiComponent2<DesignMainCPDHighlightsProps> {
  @override
  render() {
    if (!(props.show_all_t_bases ?? false) && !(props.show_cpd_sites_continuously ?? false)) {
      return null;
    }

    List<ReactElement> elements = [];
    double radius = props.geometry?.base_width_svg != null ? props.geometry!.base_width_svg * 0.35 : 3.5;
    double threshold = props.cpd_score_threshold ?? 0.0;

    // Render light blue circles for ALL T-bases that have visual coordinates.
    // Drawn first so CPD-site circles render on top.
    if (props.show_all_t_bases ?? false) {
      if (props.t_base_locations != null) {
        for (var t_base in props.t_base_locations!.t_bases) {
          if (t_base.visual_x != null && t_base.visual_y != null) {
            elements.add((Dom.circle()
              ..cx = t_base.visual_x!
              ..cy = t_base.visual_y!
              ..r = radius
              ..fill = 'lightblue'
              ..fillOpacity = 0.5
              ..key = 'tbase-all-${t_base.stable_id}')());
          }
        }
      }
    }

    // Render highlights for CPD sites (color by photoproduct, opacity by score).
    if (props.show_cpd_sites_continuously ?? false) {
      if (props.cpd_sites != null) {
        for (var cpd_site in props.cpd_sites!) {
          // Skip sites below the user-set score threshold.
          if (cpd_site.formation_score < threshold) continue;

          // Resolve fill color from loaded parameters; fall back to legacy pink.
          final params = get_loaded_cpd_params();
          final String? pid = cpd_site.photoproduct_id;
          String fill_color = 'pink';
          if (pid != null && params != null) {
            fill_color = params.photoproduct(pid)?.color ?? 'pink';
          }

          // Opacity is proportional to formation_score, clamped to [0.3, 1.0]
          // so even low-probability sites remain visible.
          double fill_opacity = cpd_site.formation_score.clamp(0.3, 1.0);

          TBaseLocation t1 = cpd_site.t1;
          TBaseLocation t2 = cpd_site.t2;
          bool is_conflicted = cpd_site.is_conflicted;

          String pair_key = 'cpd-${t1.stable_id}-${t2.stable_id}';

          // Build junction for use in context menu closure.
          final junction = PhotoproductJunction(
            t1_stable_id: t1.stable_id,
            t2_stable_id: t2.stable_id,
            photoproduct_id: cpd_site.photoproduct_id ?? 'TT-CPD',
          );

          on_context_menu_cpd(SyntheticMouseEvent event) {
            event.preventDefault();
            event.stopPropagation();
            app.dispatch(actions.ContextMenuShow(
              context_menu: ContextMenu(
                items: (ListBuilder<ContextMenuItem>()
                      ..add(ContextMenuItem(
                        title: 'Mark as photoproduct junction',
                        on_click: () =>
                            app.dispatch(actions.MarkAsPhotoproductJunction(junction)),
                      )))
                    .build(),
                position: util.from_point_num(event.nativeEvent.page),
              ),
            ));
          }

          Point<double>? visual_pos_t1;
          Point<double>? visual_pos_t2;

          if (t1.visual_x != null && t1.visual_y != null) {
            visual_pos_t1 = Point<double>(t1.visual_x!, t1.visual_y!);
          }
          if (t2.visual_x != null && t2.visual_y != null) {
            visual_pos_t2 = Point<double>(t2.visual_x!, t2.visual_y!);
          }

          // T1 circle
          if (visual_pos_t1 != null) {
            elements.add((Dom.circle()
              ..cx = visual_pos_t1.x
              ..cy = visual_pos_t1.y
              ..r = radius
              ..fill = fill_color
              ..fillOpacity = fill_opacity
              // Conflict indicator: red stroke ring instead of fill color change.
              ..stroke = is_conflicted ? 'red' : 'none'
              ..strokeWidth = is_conflicted ? 1.5 : 0
              ..onContextMenu = on_context_menu_cpd
              ..key = 'cpd-circle-t1-$pair_key')());
          }

          // T2 circle
          if (visual_pos_t2 != null) {
            elements.add((Dom.circle()
              ..cx = visual_pos_t2.x
              ..cy = visual_pos_t2.y
              ..r = radius
              ..fill = fill_color
              ..fillOpacity = fill_opacity
              ..stroke = is_conflicted ? 'red' : 'none'
              ..strokeWidth = is_conflicted ? 1.5 : 0
              ..onContextMenu = on_context_menu_cpd
              ..key = 'cpd-circle-t2-$pair_key')());
          }

          // Connecting double-line if both positions are available.
          if (visual_pos_t1 != null && visual_pos_t2 != null) {
            double dx = visual_pos_t2.x - visual_pos_t1.x;
            double dy = visual_pos_t2.y - visual_pos_t1.y;
            double dist = sqrt(dx * dx + dy * dy);

            if (dist > 1e-6) {
              double perp_dx_norm = -dy / dist;
              double perp_dy_norm = dx / dist;
              double line_offset = radius * 0.30;
              double line_stroke_width = 1.5;
              String line_color = is_conflicted ? 'red' : fill_color;

              elements.add((Dom.line()
                ..x1 = visual_pos_t1.x + perp_dx_norm * line_offset
                ..y1 = visual_pos_t1.y + perp_dy_norm * line_offset
                ..x2 = visual_pos_t2.x + perp_dx_norm * line_offset
                ..y2 = visual_pos_t2.y + perp_dy_norm * line_offset
                ..stroke = line_color
                ..strokeOpacity = fill_opacity
                ..strokeWidth = line_stroke_width
                ..key = '$pair_key-line1')());

              elements.add((Dom.line()
                ..x1 = visual_pos_t1.x - perp_dx_norm * line_offset
                ..y1 = visual_pos_t1.y - perp_dy_norm * line_offset
                ..x2 = visual_pos_t2.x - perp_dx_norm * line_offset
                ..y2 = visual_pos_t2.y - perp_dy_norm * line_offset
                ..stroke = line_color
                ..strokeOpacity = fill_opacity
                ..strokeWidth = line_stroke_width
                ..key = '$pair_key-line2')());
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
