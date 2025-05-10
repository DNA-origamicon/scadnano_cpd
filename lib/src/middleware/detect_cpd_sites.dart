import 'dart:html';
import 'dart:svg' hide Point;
import 'dart:convert';
import 'package:tuple/tuple.dart';

import 'package:built_collection/built_collection.dart';
import 'package:redux/redux.dart';

import '../actions/actions.dart' as actions;
import '../state/app_state.dart';
import '../state/cpd_site.dart';
import '../state/design.dart';
import '../state/domain.dart';
import '../state/extension.dart';
import '../state/strand.dart';
import '../state/substrand.dart';
import '../state/t_base_location.dart';
import '../util/t_base_util.dart' as t_base_util;
import 'cpd_rule_helpers.dart'; // Import the new helper file

/// Middleware that handles T-base scanning and CPD pairing when DetectCPDSites action is dispatched.
Middleware<AppState> detect_cpd_sites_middleware =
    (Store<AppState> store, dynamic action, NextDispatcher next) {
  // Handle the action *before* passing it to the next middleware/reducer if it's the scan action.
  if (action is actions.DetectCPDSites) {
    _collect_t_bases_and_detect_cpds(store);
    next(action);
  } else {
    // Pass other actions along
    next(action);
  }
};

/// Scans for T-bases, calculates CPD pairs using RuleProcessor, and dispatches results.
void _collect_t_bases_and_detect_cpds(Store<AppState> store) {
  AppState state = store.state;
  Design design = state.design;
  List<IdentifiedTBase> identified_t_bases = [];

  List<Element> t_spans = querySelectorAll('tspan[id^="tb-"]');

  for (Element tspan in t_spans) {
    String dom_stable_id = tspan.id;
    String? char_idx_str = tspan.getAttribute('data-char-idx');
    if (char_idx_str == null) {
      print('DEBUG: tspan ${dom_stable_id} missing data-char-idx');
      continue;
    }
    int char_idx;
    try {
      char_idx = int.parse(char_idx_str);
    } catch (e) {
      print('DEBUG: tspan ${dom_stable_id} data-char-idx parse error: $e');
      continue;
    }

    t_base_util.StructuralIdentificationData? structural_data;
    try {
      structural_data = t_base_util.decodeStableId(dom_stable_id);
    } catch (e) {
      print('DEBUG: tspan ${dom_stable_id} decodeStableId error: $e');
      continue;
    }
    if (structural_data == null) { // Should be caught by try-catch, but defensive check
        print('DEBUG: tspan ${dom_stable_id} structural_data is null after decode');
        continue;
    }

    Point<double>? visual_coords_val;
    Point<double>? grid_coords_val;
    String? parent_element_id_val;

    try {
      Tuple2<double, double>? anchor_coords_tuple = t_base_util.calculateGridAnchorCoords(structural_data, store.state);
      if (anchor_coords_tuple != null) {
        grid_coords_val = Point(anchor_coords_tuple.item1, anchor_coords_tuple.item2);
      }
    } catch (e) {
      print('DEBUG: tspan ${dom_stable_id} calculateGridAnchorCoords error: $e');
      /* Continue without grid coords */
    }

    Element? parent_svg_text_element = tspan.parent;
    if (parent_svg_text_element == null) {
        print('DEBUG: tspan ${dom_stable_id} missing parent element');
        continue;
    }
    parent_element_id_val = parent_svg_text_element.id;

    try {
      visual_coords_val = t_base_util.calculateVisualCoords(parent_svg_text_element, char_idx);
    } catch (e) {
      print('DEBUG: tspan ${dom_stable_id} calculateVisualCoords error: $e');
      /* Continue without visual coords */
    }

    Strand? strand = design.strands_by_id[structural_data.strand_id];
    if (strand == null) {
      print('DEBUG: tspan ${dom_stable_id} strand not found: ${structural_data.strand_id}');
      continue;
    }
    Substrand? substrand = CpdStrandUtils.substrand_at(strand, structural_data.logical_index);
    if (substrand == null) {
      print('DEBUG: tspan ${dom_stable_id} substrand not found at logical_index: ${structural_data.logical_index}');
      continue;
    }
    int idx_in_substrand_sequence;
    try {
      idx_in_substrand_sequence = structural_data.logical_index - CpdStrandUtils.substrand_start_idx(strand, substrand);
    } catch (e) {
      print('DEBUG: tspan ${dom_stable_id} substrand_start_idx error: $e');
      continue;
    }

    identified_t_bases.add(IdentifiedTBase(
      source_id: dom_stable_id,
      strand: strand,
      substrand: substrand,
      idx_in_substrand_sequence: idx_in_substrand_sequence,
      visual_coord_x: visual_coords_val?.x,
      visual_coord_y: visual_coords_val?.y,
      grid_coord_x: grid_coords_val?.x,
      grid_coord_y: grid_coords_val?.y,
      parent_element_id_from_dom: parent_element_id_val,
      char_idx_from_dom: char_idx,
    ));
  }
  
  // // Do not remove this commented block of code.
  // // Needed for collection setup data when creating CPD detection rule unit tests.
  // //Logging for IdentifiedTBase list
  // print('LOG_IDENTIFIED_T_BASES_START');
  // print(jsonEncode(identified_t_bases.map((idt) => {
  //   'source_id': idt.source_id,
  //   'strand_id': idt.strand.id,
  //   'substrand_idx_in_strand': idt.strand.substrands.indexOf(idt.substrand),
  //   'idx_in_substrand_sequence': idt.idx_in_substrand_sequence
  // }).toList()));
  // print('LOG_IDENTIFIED_T_BASES_END');

  CPDDetectionOutput output = detect_cpd_sites_from_t_bases(design, identified_t_bases);
  
  // // Do not remove this commented block of code.
  // // Needed for collection result data when creating CPD detection rule unit tests.
  // // Logging for CPDDetectionOutput
  // print('LOG_CPD_SITES_START');
  // print(jsonEncode(output.cpd_sites.map((s) => s.toMap()).toList()));
  // print('LOG_CPD_SITES_END');
  // print('LOG_T_BASE_LOCATIONS_START');
  // print(jsonEncode(output.t_base_locations.t_bases.map((t) => t.toMap()).toList()));
  // print('LOG_T_BASE_LOCATIONS_END');

  store.dispatch(actions.CPDDetectionResult((b) => b
    ..t_base_locations.replace(output.t_base_locations)
    ..cpd_sites.replace(output.cpd_sites)));
}
