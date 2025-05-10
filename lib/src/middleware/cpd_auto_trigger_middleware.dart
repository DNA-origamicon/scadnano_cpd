import 'package:redux/redux.dart';
import 'dart:async'; // Import for Future.delayed

import '../actions/actions.dart' as actions;
import '../state/app_state.dart';

/// Middleware to automatically trigger CPD site detection or clearing based on UI toggles and design changes.
void cpd_auto_trigger_middleware(Store<AppState> store, dynamic action, NextDispatcher next) {
  // Default behavior: pass action along first
  next(action);

  bool state_show_cpd_sites = store.state.ui_state.show_cpd_sites_continuously;

  // Check for actions related to toggling CPD/T-base visibility
  if (action is actions.ShowCPDSitesContinuouslySet) {
    if (action.show) {
      // If turning CPD sites ON, trigger a detection scan
      // No delay needed here as it's a direct user toggle
      store.dispatch(actions.DetectCPDSites());
    } else {
      // If turning CPD sites OFF, also ensure "Show All T Bases" is turned OFF
      if (store.state.ui_state.show_all_t_bases) {
        // Check if it's not already off
        store.dispatch(actions.ShowAllTBasesSet.set(false));
      }
    }
  } else if (action is actions.ShowDNASet) {
    // If DNA sequences are turned OFF, CPD sites must also be turned OFF
    if (!action.show && state_show_cpd_sites) {
      store.dispatch(actions.ShowCPDSitesContinuouslySet.set(false));
    }
  }

  // Check for design-modifying actions that should trigger a re-scan if CPD sites are visible
  bool should_rescan = (action is actions.Undo ||
          action is actions.Redo ||
          action is actions.StrandsMoveCommit ||
          action is actions.DNAEndsMoveCommit ||
          action is actions.DNAExtensionsMoveCommit ||
          action is actions.DeleteAllSelected ||
          action is actions.AssignDNA ||
          action is actions.RemoveDNA ||
          action is actions.ConvertCrossoverToLoopout ||
          action is actions.InsertionAdd ||
          action is actions.InsertionRemove ||
          action is actions.InsertionLengthChange ||
          action is actions.DeletionAdd ||
          action is actions.DeletionRemove ||
          action is actions.LoopoutLengthChange ||
          action is actions.ExtensionNumBasesChange ||
          action is actions.ExtensionDisplayLengthAngleSet ||
          action is actions.LoadDNAFile // Rescan after loading a new file if CPDs are on
      );

  if (should_rescan && state_show_cpd_sites) {
    // If CPD sites are set to be shown, trigger a re-scan AFTER relevant modifications complete
    // Use Future.delayed to allow the current action's reducer logic to finish first
    Future.delayed(Duration.zero, () => store.dispatch(actions.DetectCPDSites()));
  }
}
