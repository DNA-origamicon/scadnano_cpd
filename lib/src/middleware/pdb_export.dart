// Handles the PDB export action. Follows the steps:
// 1. Export the scadnano Design to the oxDNA format.
// 2. Convert from oxDNA to PDB (converter based on the tacoxdna implementation).
// 3. Download the resulting PDB file.

import 'dart:html';
import 'package:path/path.dart' as path;
import 'package:redux/redux.dart';
import 'package:scadnano/src/state/design.dart';
import 'package:tuple/tuple.dart';

import '../state/app_state.dart';
import '../actions/actions.dart' as actions;
import '../util.dart' as util;
import '../util/pdb_exporter.dart' as pdb_exporter;
import '../constants.dart' as constants;
import './oxdna_export.dart' as oxdna_export;

pdb_export_middleware(Store<AppState> store, dynamic action, NextDispatcher next) {
  if (action is actions.PdbExport) {
    AppState state = store.state;
    Design design = state.design;

    var strands_to_export =
        action.selected_strands_only
            ? store.state.ui_state.selectables_store.selected_strands.toList()
            : design.strands.toList();

    if (strands_to_export.isEmpty) {
      window.alert('No strands to export.');
      return;
    }

    // Convert design to oxDNA format
    Tuple2<String, String> dat_top = oxdna_export.to_oxdna_format(design, strands_to_export,
        state.ui_state.loopout_fwd_x_offset,
        state.ui_state.loopout_rev_x_offset,
        state.ui_state.loopout_fwd_z_offset,
        state.ui_state.loopout_rev_z_offset,
        state.ui_state.loopout_fwd_theta,
        state.ui_state.loopout_rev_theta);
    String dat_content = dat_top.item1;
    String top_content = dat_top.item2;

    // Fetch the PDB template file content
    HttpRequest.getString(constants.PDB_TEMPLATE_PATH)
        .then((pdb_template_content) {
          // Call the PDB exporter function (util/pdb_exporter.dart)
          pdb_exporter
              .export_pdb_from_oxdna_strings(
                top_content: top_content,
                dat_content: dat_content,
                pdb_template_content: pdb_template_content,
                oxDNA_direction: true,
                uniform_residue_names: false,
              )
              .then((pdb_content) {
                String default_filename = state.ui_state.loaded_filename;
                String default_filename_pdb = path.setExtension(default_filename, '.pdb');
                util.save_file(default_filename_pdb, pdb_content);
              })
              .catchError((error) {
                window.alert('Error exporting PDB file: \n${error}');
              });
        })
        .catchError((error) {
          window.alert('Error loading PDB template file: \n${error}');
        });
  }
  next(action);
}
