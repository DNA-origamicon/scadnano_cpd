import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:js';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:quiver/iterables.dart' as quiver;
import 'package:react/react.dart';
import 'package:built_collection/built_collection.dart';

import 'package:redux/redux.dart';
import 'package:scadnano/src/state/design.dart';
import 'package:scadnano/src/state/domain.dart';
import 'package:scadnano/src/state/extension.dart';
import 'package:scadnano/src/state/geometry.dart';
import 'package:scadnano/src/state/grid.dart';
import 'package:scadnano/src/state/loopout.dart';
import 'package:scadnano/src/state/position3d.dart';
import 'package:scadnano/src/state/strand.dart';
import 'package:tuple/tuple.dart';
import '../state/app_state.dart';
import '../state/photoproduct_junction.dart';
import '../state/t_base_location.dart';
import '../actions/actions.dart' as actions;
import '../state/helix.dart';
import '../util.dart' as util;
import '../util.dart';
import 'export_cadnano_file.dart' as export_cadnano;
import '../constants.dart' as constants;
import 'oxdna_export.dart';
import '../app.dart';

// This middleware handles sending the new design to the oxview viewer,
// as well as updating whether it is shown, since it is wired to the
// view outside of React.
oxview_update_view_middleware(Store<AppState> store, dynamic action, NextDispatcher next) {
  next(action);

  if (action is actions.OxviewShowSet) {
    app.view.update_showing_oxview();
  }

  bool show = store.state.ui_state.show_oxview;
  if (show &&
      (action is actions.DesignChangingAction ||
          action is actions.MarkAsPhotoproductJunction ||
          action is actions.UnmarkPhotoproductJunction)) {
    _update_oxview_with_state(store.state);
  }
  if (show &&
      (action is actions.LoopoutFwdXOffsetSet ||
          action is actions.LoopoutRevXOffsetSet ||
          action is actions.LoopoutFwdZOffsetSet ||
          action is actions.LoopoutRevZOffsetSet ||
          action is actions.LoopoutFwdThetaSet ||
          action is actions.LoopoutRevThetaSet)) {
    _update_oxview_with_state(store.state);
  }
}

// Helper that extracts all loopout params from state and calls update_oxview_view.
void _update_oxview_with_state(AppState state) {
  update_oxview_view(
    state.design,
    null,
    state.ui_state.loopout_fwd_x_offset,
    state.ui_state.loopout_rev_x_offset,
    state.ui_state.loopout_fwd_z_offset,
    state.ui_state.loopout_rev_z_offset,
    state.ui_state.loopout_fwd_theta,
    state.ui_state.loopout_rev_theta,
    state.design.photoproduct_junctions.toList(),
    state.ui_state.t_base_locations,
  );
}

// `frame` argument is optional because usually we get it from app.view.oxview_view.frame,
// but on startup, `app.view` is not yet initialized (we're in the View constructor
// the first time we call `update_oxview_view`), so from that constructor, we send the frame explicitly
// to this function just after creating it, but before it can be accessed via `app.view.oxview_view?.frame`.
void update_oxview_view(Design design,
    [IFrameElement? frame = null,
    double fwd_x_offset = 0.5,
    double rev_x_offset = 0.5,
    double fwd_z_offset = 0.0,
    double rev_z_offset = 0.0,
    double fwd_theta = 0.0,
    double rev_theta = 0.0,
    List<PhotoproductJunction>? cpd_junctions,
    TBaseLocations? cpd_t_base_locations]) {
  if (frame == null) {
    frame = app.view.oxview_view.frame;
  }

  // reset oxview in case it has nucleotides already
  Blob blob_js_reset_commands = new Blob([
    'resetScene(resetCamera = false);',
  ], blob_type_to_string(BlobType.text));
  Map<String, dynamic> message = {
    'message': 'iframe_drop',
    'files': [blob_js_reset_commands],
    'ext': ['js'],
  };
  frame.contentWindow?.postMessage(message, constants.OXVIEW_URL);

  // send current exported design
  List<Strand> strands_to_export = design.strands.toList();

  Tuple2<String, String> dat_top = to_oxdna_format(design, strands_to_export,
      fwd_x_offset, rev_x_offset, fwd_z_offset, rev_z_offset, fwd_theta, rev_theta,
      cpd_junctions, cpd_t_base_locations);
  String dat = dat_top.item1;
  String top = dat_top.item2;

  Blob blob_dat = new Blob([dat], blob_type_to_string(BlobType.text));
  Blob blob_top = new Blob([top], blob_type_to_string(BlobType.text));

  message = {
    'message': 'iframe_drop',
    'files': [blob_top, blob_dat],
    'ext': ['top', 'dat'],
    'inbox_settings': ["Monomer", "Origin"],
  };
  frame.contentWindow?.postMessage(message, constants.OXVIEW_URL);
}
