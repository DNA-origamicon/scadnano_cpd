import '../actions/actions.dart' as actions;
import '../state/t_base_location.dart';

/// Reducer for handling T-base locations updates.
TBaseLocations t_bases_reducer(TBaseLocations? t_base_locations, dynamic action) {
  // Ensure t_base_locations is initialized if null
  t_base_locations ??= TBaseLocations((b) => b);

  if (action is actions.CPDDetectionResult) {
    // Replace T-bases with the new list from the consolidated action.
    return action.t_base_locations;
  } else if (action is actions.ShowCPDSitesContinuouslySet && !action.show) {
    // Clear when CPD sites are turned off (implies T bases also not needed for CPD calculation)
    return TBaseLocations((b) => b..t_bases.clear());
  } else if (action is actions.ShowDNASet && !action.show) {
    // Clear when DNA sequences are turned off (required for T bases)
    return TBaseLocations((b) => b..t_bases.clear());
  } else if (
      // Clear T-base locations when actions that change the sequence order or values occur
      // DNA sequence assignment or removal
      action is actions.AssignDNA ||
          action is actions.RemoveDNA ||
          // Modifications to the strand structure that would affect sequences
          action is actions.ConvertCrossoverToLoopout ||
          // Insertions and deletions that modify sequence length/position
          action is actions.InsertionAdd ||
          action is actions.InsertionRemove ||
          action is actions.InsertionLengthChange ||
          action is actions.DeletionAdd ||
          action is actions.DeletionRemove ||
          action is actions.DeleteAllSelected ||
          // DNA ends movement that would affect sequences
          action is actions.DNAEndsMoveCommit ||
          action is actions.DNAExtensionsMoveCommit ||
          action is actions.ExtensionDisplayLengthAngleSet ||
          // Loading new DNA file
          action is actions.LoadDNAFile) {
    // Clear T-base locations when sequence structure changes since they're no longer valid
    return TBaseLocations((b) => b..t_bases.clear());
  } else {
    // For any other action, just return the current state
    return t_base_locations;
  }
}
