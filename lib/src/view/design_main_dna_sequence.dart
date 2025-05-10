import 'dart:math';

import 'package:over_react/over_react.dart';
import 'package:built_collection/built_collection.dart';
import 'package:platform_detect/platform_detect.dart';
import 'package:scadnano/src/state/group.dart';
import 'package:scadnano/src/view/transform_by_helix_group.dart';
import 'package:tuple/tuple.dart';

import '../state/helix.dart';
import 'package:scadnano/src/state/geometry.dart';
import '../state/strand.dart';
import '../state/domain.dart';
import '../state/loopout.dart';
import '../state/extension.dart';
import 'pure_component.dart';
import '../util.dart' as util;
import 'package:scadnano/src/state/app_state.dart'; // Store needed to dispatch t-base updates
import 'package:redux/redux.dart';
import 'package:scadnano/src/util/t_base_util.dart' as t_base_util;

part 'design_main_dna_sequence.over_react.g.dart';

UiFactory<DesignMainDNASequenceProps> DesignMainDNASequence = _$DesignMainDNASequence;

mixin DesignMainDNASequenceProps on UiProps implements TransformByHelixGroupPropsMixin {
  late Strand strand;
  late BuiltSet<int> side_selected_helix_idxs;
  late bool only_display_selected_helices;
  late bool display_reverse_DNA_right_side_up;

  late BuiltMap<int, Helix> helices;
  late BuiltMap<String, HelixGroup> groups;
  late Geometry geometry;
  late BuiltMap<int, Point<double>> helix_idx_to_svg_position_map;

  // Scanning for T-bases in the DNA sequence
  bool? scan_for_t_bases;
  Store<AppState>? store;
}

bool should_draw_domain(
  Domain ss,
  BuiltSet<int> side_selected_helix_idxs,
  bool only_display_selected_helices,
) => !only_display_selected_helices || side_selected_helix_idxs.contains(ss.helix);

class DesignMainDNASequenceComponent extends UiComponent2<DesignMainDNASequenceProps> with PureComponent {
  @override
  Map get defaultProps => (newProps()
    ..scan_for_t_bases = false
    ..store = null
  );

  @override
  render() {
    BuiltSet<int> side_selected_helix_idxs = props.side_selected_helix_idxs;

    List<ReactElement> dna_sequence_elts = [];
    for (int i = 0; i < this.props.strand.substrands.length; i++) {
      var substrand = this.props.strand.substrands[i];
      if (substrand is Domain) {
        if (should_draw_domain(substrand, side_selected_helix_idxs, props.only_display_selected_helices)) {
          Domain domain = substrand;
          List<ReactElement> domain_elts = [];
          domain_elts.add(this._dna_sequence_on_domain(domain));
          for (var insertion in domain.insertions) {
            int offset = insertion.offset;
            int length = insertion.length;
            domain_elts.add(this._dna_sequence_on_insertion(domain, offset, length));
          }
          dna_sequence_elts.add(
            (Dom.g()
              ..transform = transform_of_helix2(props, domain.helix)
              ..className = 'dna-seq-on-domain-group'
              ..key = util.id_domain(domain))(domain_elts),
          );
        }
      } else if (substrand is Loopout) {
        assert(0 < i);
        assert(i < this.props.strand.substrands.length - 1);
        Loopout loopout = substrand;
        Domain prev_dom = this.props.strand.substrands[i - 1] as Domain;
        Domain next_dom = this.props.strand.substrands[i + 1] as Domain;
        if (should_draw_domain(prev_dom, side_selected_helix_idxs, props.only_display_selected_helices) &&
            should_draw_domain(next_dom, side_selected_helix_idxs, props.only_display_selected_helices)) {
          dna_sequence_elts.add(this._dna_sequence_on_loopout(loopout, prev_dom, next_dom));
        }
      } else if (substrand is Extension) {
        assert(i == 0 || i == props.strand.substrands.length - 1);
        Extension ext = substrand;
        if (should_draw_domain(
          ext.adjacent_domain,
          side_selected_helix_idxs,
          props.only_display_selected_helices,
        )) {
          dna_sequence_elts.add(this._dna_sequence_on_extension(ext));
        }
      } else {
        throw AssertionError('unrecognized substrand type: ${substrand}');
      }
    }
    return (Dom.g()
      ..className = 'strand-dna-sequence'
      ..id = 'dna-sequence-${this.props.strand.id}')(dna_sequence_elts);
  }

  static const classname_dna_sequence = 'dna-seq';
  static const charWidth = 6.59375;

  ReactElement _dna_sequence_on_domain(Domain domain) {
    var helix = props.helices[domain.helix]!;
    var group = props.groups[helix.group]!;
    var geometry = group.geometry ?? props.geometry;
    var seq_to_draw = domain.dna_sequence_deletions_insertions_to_spaces(
      reverse: props.display_reverse_DNA_right_side_up && !domain.forward,
    );

    var rotate_degrees = 0;
    int offset = domain.offset_5p;
    Point<double> pos = helix.svg_base_pos(
      offset,
      domain.forward,
      props.helix_idx_to_svg_position_map[domain.helix]!.y,
      props.geometry,
    );
    var rotate_x = pos.x;
    var rotate_y = pos.y;

    // this is needed to make complementary DNA bases line up more nicely (still not perfect)
    var x_adjust = -geometry.base_width_svg * 0.32;
    var dy, x, y;
    var text_length = geometry.base_width_svg * (domain.visual_length - 0.342);

    //extension, loopout,

    if (domain.forward) {
      //rotation and displacement for forward text
      rotate_degrees = 0;
      dy = -geometry.base_height_svg * 0.25;
      x = pos.x + x_adjust;
      y = pos.y;
    } else {
      if (props.display_reverse_DNA_right_side_up) {
        rotate_degrees = 0;
        //displacement for reverse text
        dy = geometry.base_height_svg * 0.75;
        x = pos.x - x_adjust - text_length;
        y = pos.y + geometry.base_height_svg;
      } else {
        rotate_degrees = 180;
        //displacement for reverse text if option not enabled
        dy = -geometry.base_height_svg * 0.25;
        x = pos.x + x_adjust;
        y = pos.y;
      }
    }

    // Generate a unique ID for the sequence element
    var id = 'seq-domain-${props.strand.id}-h${domain.helix}-o${domain.offset_5p}';

    // If there's no sequence to draw, return the empty element
    if (seq_to_draw.isEmpty) {
      return (Dom.text()
        ..key = id
        ..id = id
        ..className = classname_dna_sequence
        ..x = '$x'
        ..y = '$y'
        ..textLength = '$text_length'
        ..transform = 'rotate(${rotate_degrees} ${rotate_x} ${rotate_y})'
        ..dy = '$dy')('');
    }

    // Process the sequence and wrap T characters in tspan elements
    var element_content = [];

    for (int i = 0; i < seq_to_draw.length; i++) {
      String base = seq_to_draw[i];
      if ((props.scan_for_t_bases ?? false) && base.toUpperCase() == 'T' && props.store != null) {
        try {
          var structural_data = t_base_util.calculateStructuralIdentificationData(
              state: props.store!.state,
              strand_id: props.strand.id,
              substrand: domain,
              sequence_position: i);
          var stable_id = t_base_util.generateStableId(structural_data);
          var tspan = Dom.tspan()
            ..key = 'tbase-domain-$i'
            ..id = stable_id
            ..addProps({'data-char-idx': '$i'});
          element_content.add(tspan(base));
        } catch (e) {
          print('T-BASE ERROR (domain): Failed to process T for ${domain.id} at pos $i: $e');
          element_content.add(base);
        }
      } else {
        // Add other base types as plain text
        element_content.add(base);
      }
    }

    // textLength is the more robust way to space out the letter than letterSpacing
    // (e.g., in Firefox it displays poorly with letterSpacing),
    // but it caused problems with exporting to SVG and then importing into Powerpoint.
    // So we provided an option to export SVG with each DNA base represented as its own text element
    // to avoid the problems with textLength in Powerpoint. Keeping the commented letterSpacing code
    // to remember why we don't want to use that anymore. :)
    // Return the text element with processed content
    return (Dom.text()
      ..key = id
      ..id = id
      ..className = classname_dna_sequence
      ..x = '$x'
      ..y = '$y'
      ..textLength = '$text_length'
      // ..letterSpacing = '${(text_length - charWidth * seq_to_draw.length) / (seq_to_draw.length - 1)}'
      ..transform = 'rotate(${rotate_degrees} ${rotate_x} ${rotate_y})'
      ..dy = '$dy')(element_content);
  }

  ReactElement _dna_sequence_on_insertion(Domain domain, int offset, int length) {
    var helix = props.helices[domain.helix]!;
    var group = props.groups[helix.group]!;
    var geometry = group.geometry ?? props.geometry;
    var reverse_right_side_up = props.display_reverse_DNA_right_side_up && !domain.forward;

    var subseq = domain.dna_sequence_in(offset, offset, reverse: reverse_right_side_up);
    //XXX: path_length appears to return different results depending on the computer (probably resolution??)
    // don't rely on it. This caused Firefox for example to render different on the same version.
    //    num path_length = insertion_path_elt.getTotalLength();

    var start_offset = '50%';
    var dy = '${0.1 * geometry.base_width_svg}';

    Tuple2<double?, int> ls_fs = _calculate_letter_spacing_and_font_size_insertion(length);
    double? letter_spacing = ls_fs.item1;
    int font_size = ls_fs.item2;

    Map<String, dynamic> style_map;
    if (letter_spacing != null) {
      style_map = {'letterSpacing': '${letter_spacing}em', 'fontSize': '${font_size}px'};
    } else {
      style_map = {'fontSize': '${font_size}px'};
    }

    if (reverse_right_side_up) {
      style_map['dominantBaseline'] = 'hanging';
    }

    // Generate unique ID for the insertion sequence
    String text_path_id = 'seq-insertion-${props.strand.id}-h${domain.helix}-o${offset}';

    // Process sequence to wrap T characters in tspans
    if (subseq != null) {
      var element_content = [];

      for (int i = 0; i < subseq.length; i++) {
        String base = subseq[i];
        if ((props.scan_for_t_bases ?? false) && base.toUpperCase() == 'T' && props.store != null) {
          try {
            var structural_data = t_base_util.calculateStructuralIdentificationData(
                state: props.store!.state,
                strand_id: props.strand.id,
                substrand: domain,
                sequence_position: i);
            var stable_id = t_base_util.generateStableId(structural_data);
            int insertion_point = offset;
            stable_id = stable_id.replaceFirst('-', '-INS$insertion_point-');
            var tspan = Dom.tspan()
              ..key = 'tbase-insertion-$i'
              ..id = stable_id
              ..addProps({'data-char-idx': '$i'});
            element_content.add(tspan(base));
          } catch (e) {
            print('T-BASE ERROR (insertion): Failed to process T for ${domain.id} at ins offset $offset, pos $i: $e');
            element_content.add(base);
          }
        } else {
          // Add other base types as plain text
          element_content.add(base);
        }
      }

      // For textPath we need to create the element directly
      var text_path = Dom.textPath()
        ..key = text_path_id
        ..id = text_path_id
        ..className = classname_dna_sequence + '-insertion'
        //XXX: xlink:href is deprecated, but this is needed for exporting SVG, due to a bug in Inkscape
        // https://gitlab.com/inkscape/inbox/issues/1763
        ..xlinkHref = '#${util.id_insertion(domain, offset)}'
        ..startOffset = start_offset
        ..style = style_map;

      // Add the processed content to the textPath
      ReactElement text_path_element = text_path(element_content);

      // Create the text element with the text path as a child
      var text_element_id = 'textelt-insertion-${props.strand.id}-h${domain.helix}-o${offset}';
      return (Dom.text()
        ..key = text_element_id
        ..id = text_element_id
        ..dy = dy)([text_path_element]);
    } else {
      // Handle the case where there's no sequence data
      // For textPath we need to create the element directly
      var text_path = Dom.textPath()
        ..key = text_path_id
        ..id = text_path_id
        ..className = classname_dna_sequence + '-insertion'
        ..xlinkHref = '#${util.id_insertion(domain, offset)}'
        ..startOffset = start_offset
        ..style = style_map;

      // Create the text element with the text path as a child
      var text_element_id = 'textelt-insertion-${props.strand.id}-h${domain.helix}-o${offset}';
      return (Dom.text()
        ..key = text_element_id
        ..id = text_element_id
        ..dy = dy)([text_path('')]);
    }
  }

  ReactElement _dna_sequence_on_loopout(Loopout loopout, Domain prev_domain, Domain next_domain) {
    var helix = props.helices[prev_domain.helix]!;
    var group = props.groups[helix.group]!;
    var geometry = group.geometry ?? props.geometry;
    String subseq = loopout.dna_sequence!;
    var length = subseq.length;

    var start_offset = '50%';
    var dy = '${0.1 * geometry.base_height_svg}';

    Tuple2<double?, int> ls_fs;
    if (util.is_hairpin(prev_domain, next_domain)) {
      ls_fs = _calculate_letter_spacing_and_font_size_hairpin(length);
    } else {
      ls_fs = _calculate_letter_spacing_and_font_size_loopout(length);
    }
    double? letter_spacing = ls_fs.item1;
    int font_size = ls_fs.item2;

    Map<String, dynamic> style_map;
    if (letter_spacing != null) {
      style_map = {'letterSpacing': '${letter_spacing}em', 'fontSize': '${font_size}px'};
    } else {
      style_map = {'fontSize': '${font_size}px'};
    }

    // Generate unique ID for the loopout sequence
    String text_path_id = 'seq-loopout-${props.strand.id}-${loopout.prev_domain_idx}';

    // Process sequence to wrap T-bases in tspans
    var element_content = [];

    for (int i = 0; i < subseq.length; i++) {
      String base = subseq[i];
      if ((props.scan_for_t_bases ?? false) && base.toUpperCase() == 'T' && props.store != null) {
        try {
          var structural_data = t_base_util.calculateStructuralIdentificationData(
              state: props.store!.state,
              strand_id: props.strand.id,
              substrand: loopout,
              sequence_position: i);
          var stable_id = t_base_util.generateStableId(structural_data);
          var tspan = Dom.tspan()
            ..key = 'tbase-loopout-$i'
            ..id = stable_id
            ..addProps({'data-char-idx': '$i'});
          element_content.add(tspan(base));
        } catch (e) {
          print('T-BASE ERROR (loopout): Failed to process T for ${loopout.id} at pos $i: $e');
          element_content.add(base);
        }
      } else {
        // Add other base types as plain text
        element_content.add(base);
      }
    }

    // Create the textPath element with processed content
    var text_path = Dom.textPath()
      ..key = text_path_id
      ..id = text_path_id
      ..className = classname_dna_sequence + '-loopout'
      ..xlinkHref = '#${loopout.id}'
      ..startOffset = start_offset
      ..style = style_map;

    // Add the processed content to the textPath
    ReactElement text_path_element = text_path(element_content);

    // Create a unique ID for the text element
    String text_element_id = 'textelt-loopout-${props.strand.id}-${loopout.prev_domain_idx}';

    // Create the text element with the text path as a child
    return (Dom.text()
      ..key = text_element_id
      ..id = text_element_id
      ..dy = dy)([text_path_element]);
  }

  ReactElement _dna_sequence_on_extension(Extension ext) {
    Tuple2<double, int> ls_fs = _calculate_letter_spacing_and_font_size_extension(ext);
    double letter_spacing = ls_fs.item1;
    int font_size = ls_fs.item2;

    var domain = ext.adjacent_domain;
    var dna_sequence = ext.dna_sequence!;

    var start_offset = '50%';
    var dy = '${0.1 * props.geometry.base_height_svg}';
    Map<String, dynamic> style_map = {'letterSpacing': '${letter_spacing}em', 'fontSize': '${font_size}px'};

    // Generate unique ID for the extension sequence
    String text_path_id = 'seq-extension-${props.strand.id}-e${ext.is_5p ? "5p" : "3p"}';

    // Process sequence to wrap T-bases in tspans
    var element_content = [];

    for (int i = 0; i < dna_sequence.length; i++) {
      String base = dna_sequence[i];
      if ((props.scan_for_t_bases ?? false) && base.toUpperCase() == 'T' && props.store != null) {
        try {
          var structural_data = t_base_util.calculateStructuralIdentificationData(
              state: props.store!.state,
              strand_id: props.strand.id,
              substrand: ext,
              sequence_position: i);
          var stable_id = t_base_util.generateStableId(structural_data);
          var tspan = Dom.tspan()
            ..key = 'tbase-ext-$i'
            ..id = stable_id
            ..addProps({'data-char-idx': '$i'});
          element_content.add(tspan(base));
        } catch (e) {
          print('T-BASE ERROR (extension): Failed to process T for ${ext.id} at pos $i: $e');
          element_content.add(base);
        }
      } else {
        // Add other base types as plain text
        element_content.add(base);
      }
    }

    // Create the textPath element with processed content
    var text_path = Dom.textPath()
      ..key = text_path_id
      ..id = text_path_id
      ..className = classname_dna_sequence + '-extension'
      ..xlinkHref = '#${ext.id}'
      ..startOffset = start_offset
      ..style = style_map;

    // Add the processed content to the textPath
    ReactElement text_path_element = text_path(element_content);

    // Create a unique ID for the text element
    String text_element_id = 'textelt-extension-${props.strand.id}-e${ext.is_5p ? "5p" : "3p"}';

    // Create the text element with the text path as a child
    return (Dom.text()
      ..key = text_element_id
      ..id = text_element_id
      ..dy = dy)([text_path_element]);
  }
}

Tuple2<double, int> _calculate_letter_spacing_and_font_size_loopout(int len) {
  double letter_spacing = 0;
  int font_size = 12;
  return Tuple2<double, int>(letter_spacing, font_size);
}

Tuple2<double, int> _calculate_letter_spacing_and_font_size_extension(Extension ext) {
  double letter_spacing = 0;
  int font_size = 12;
  return Tuple2<double, int>(letter_spacing, font_size);
}

Tuple2<double?, int> _calculate_letter_spacing_and_font_size_hairpin(int len) {
  double? letter_spacing;
  int font_size = max(6, 12 - max(0, len - 6));
  if (browser.isChrome) {
    if (len == 1) {
      letter_spacing = 0;
    } else if (len == 2) {
      letter_spacing = -0.1;
    } else if (len == 3) {
      letter_spacing = -0.1;
    } else if (len == 4) {
      letter_spacing = -0.1;
    } else if (len == 5) {
      letter_spacing = -0.15;
    } else if (len == 6) {
      letter_spacing = -0.18;
    } else {
      letter_spacing = null;
    }
  }
  if (browser.isFirefox) {
    // Firefox ignores the "letter-spacing" property so we only have font-size to play with
    font_size = max(6, 12 - (len - 1));
    if (len > 3 && font_size > 6) {
      font_size -= 1;
    }
    letter_spacing = null;
  }
  return Tuple2<double?, int>(letter_spacing, font_size);
}

Tuple2<double?, int> _calculate_letter_spacing_and_font_size_insertion(int num_insertions) {
  // UGGG
  double? letter_spacing;
  int font_size = max(6, 12 - (num_insertions - 1));
  if (browser.isChrome) {
    if (num_insertions == 1) {
      letter_spacing = 0;
    } else if (num_insertions == 2) {
      letter_spacing = -0.1;
    } else if (num_insertions == 3) {
      letter_spacing = -0.1;
    } else if (num_insertions == 4) {
      letter_spacing = -0.1;
    } else if (num_insertions == 5) {
      letter_spacing = -0.15;
    } else if (num_insertions == 6) {
      letter_spacing = -0.18;
    } else {
      letter_spacing = null;
    }
  }
  if (browser.isFirefox) {
    // Firefox ignores the "letter-spacing" property so we only have font-size to play with
    font_size = max(6, 12 - (num_insertions - 1));
    if (num_insertions > 3 && font_size > 6) {
      font_size -= 1;
    }
    letter_spacing = null;
  }
  return Tuple2<double?, int>(letter_spacing, font_size);
}

// keep this around in case this is how we want to export to an SVG file and it doesn't do textLength well
//  draw_dna_sequence_old(Substrand substrand) {
//    var seq_group = svg.GElement();
//    seq_group.attributes = {'class': 'dna-subsequence'};
//    element.children.add(seq_group);
//    String dna_sequence = substrand.dna_sequence();
//    for (int i = 0; i < substrand.dna_length && i < dna_sequence.length; i++) {
//      String base = dna_sequence[i];
//      var base_elt = svg.TextElement();
//      base_elt.innerHtml = base;
//      var offset_from_start = i;
//      var rotate_degrees = 0;
//      if (substrand.direction == Direction.left) {
//        offset_from_start = -i;
//      }
//      int offset = substrand.offset_5p + offset_from_start;
//      Point<double> pos = Helix.svg_base_pos(substrand.helix_idx, offset, substrand.direction);
//      var rotate_x = pos.x;
//      var rotate_y = pos.y;
//      if (substrand.direction == Direction.left) {
//        rotate_degrees = 180;
//      }
//      var dy = '0.75px';
//      if (browser.isFirefox) {
//        dy = '0px';
//      }
//      base_elt.attributes = {
//        'class': 'dna-base',
//        'x': '${pos.x}',
//        'y': '${pos.y}',
//        'transform': 'rotate(${rotate_degrees} ${rotate_x} ${rotate_y})',
//        'dy': dy,
//      };
//      seq_group.children.add(base_elt);
//    }
//  }
