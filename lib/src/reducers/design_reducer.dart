import 'package:redux/redux.dart';
import 'package:built_collection/built_collection.dart';

import '../state/app_state.dart';
import '../reducers/util_reducer.dart';
import '../state/design.dart';
import '../state/photoproduct_junction.dart';
import '../actions/actions.dart' as actions;
import 'groups_reducer.dart';
import 'helices_reducer.dart';
import 'helix_group_move_reducer.dart';
import 'inline_insertions_deletions_reducer.dart';
import 'strands_reducer.dart';
import '../util.dart' as util;

////////////////////////////////////////////////////////////////////////////////////////////////////////////
// reducer composition

Design? design_reducer(Design? design, action) {
  if (design != null) {
    design = design_composed_local_reducer(design, action);
    design = design_whole_local_reducer(design, action);
  }
  return design;
}

Design? design_global_reducer(Design? design, AppState state, action) {
  design = design_composed_global_reducer(design, state, action);
  design = design_whole_global_reducer(design, state, action);
  return design;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
// composed/whole and local/global distinctions explained below

// composed: operate on slices of the DNADesign
// local: don't need the whole AppState
Design? design_composed_local_reducer(Design? design, action) => design?.rebuild(
  (d) =>
      d
        ..groups.replace(groups_local_reducer(design.groups, action))
        ..helices.replace(helices_local_reducer(design.helices, action))
        ..strands.replace(strands_local_reducer(design.strands, action))
        ..photoproduct_junctions.replace(
          photoproduct_junctions_reducer(design.photoproduct_junctions, action),
        ),
);

// composed: operate on slices of the DNADesign
// global: need the whole AppState
Design? design_composed_global_reducer(Design? design, AppState state, action) => design?.rebuild(
  (d) =>
      d
        ..groups.replace(groups_global_reducer(design.groups, state, action))
        ..helices.replace(helices_global_reducer(design.helices, state, action))
        ..strands.replace(strands_global_reducer(design.strands, state, action)),
);

// whole: operate on the whole DNADesign
// local: don't need the whole AppState
Reducer<Design?> design_whole_local_reducer = combineReducers([
  TypedReducer<Design?, actions.ErrorMessageSet>(design_error_message_set_reducer),
  TypedReducer<Design?, actions.InlineInsertionsDeletions>(inline_insertions_deletions_reducer),
  TypedReducer<Design?, actions.NewDesignSet>(new_design_set_reducer),
]);

// This isn't strictly necessary, but it would be nice for debugging if, whenever there is an error,
// the DNADesign in the Model is null.
Design? design_error_message_set_reducer(Design? design, actions.ErrorMessageSet action) =>
    action.error_message == null || action.error_message!.length == 0 ? design : null;

// whole: operate on the whole DNADesign
// global: need the whole AppState
GlobalReducer<Design?, AppState> design_whole_global_reducer = combineGlobalReducers([
  TypedGlobalReducer<Design?, AppState, actions.GeometrySet>(design_geometry_set_reducer),
  TypedGlobalReducer<Design?, AppState, actions.HelixIdxsChange>(helix_idx_change_reducer),
  TypedGlobalReducer<Design?, AppState, actions.HelixAdd>(helix_add_design_reducer),
  TypedGlobalReducer<Design?, AppState, actions.HelixRemove>(helix_remove_design_global_reducer),
  TypedGlobalReducer<Design?, AppState, actions.HelixRemoveAllSelected>(
    helix_remove_all_selected_design_global_reducer,
  ),
  TypedGlobalReducer<Design?, AppState, actions.HelixGroupMoveCommit>(helix_group_move_commit_global_reducer),
]);

// need to operate on Design so we can re-set helix svg coordinates
Design? design_geometry_set_reducer(Design? design, AppState state, actions.GeometrySet action) {
  if (design == null) {
    return null;
  }
  var new_helices = design.helices.toMap();

  return design.rebuild(
    (b) =>
        b
          ..helices.replace(new_helices)
          ..geometry.replace(action.geometry),
  );
}

Design? new_design_set_reducer(Design? design, actions.NewDesignSet action) => action.design;

BuiltList<PhotoproductJunction> photoproduct_junctions_reducer(
  BuiltList<PhotoproductJunction> junctions,
  action,
) {
  if (action is actions.MarkAsPhotoproductJunction) {
    // Avoid duplicates (same t1+t2 pair already marked).
    bool already_exists = junctions.any(
      (j) =>
          j.t1_stable_id == action.junction.t1_stable_id &&
          j.t2_stable_id == action.junction.t2_stable_id,
    );
    if (already_exists) return junctions;
    return junctions.rebuild((b) => b.add(action.junction));
  }
  if (action is actions.UnmarkPhotoproductJunction) {
    return junctions.rebuild(
      (b) => b.removeWhere(
        (j) =>
            j.t1_stable_id == action.t1_stable_id && j.t2_stable_id == action.t2_stable_id,
      ),
    );
  }
  return junctions;
}
