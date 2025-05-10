import 'dart:html';
import 'dart:math' as math;
import 'dart:svg' hide Point;

import 'package:tuple/tuple.dart';

import '../state/app_state.dart';
import '../state/domain.dart';
import '../state/helix.dart';
import '../state/loopout.dart';
import '../state/strand.dart';
import '../state/substrand.dart';
import '../state/extension.dart';
import '../middleware/cpd_rule_helpers.dart';

// Data structure to hold detailed structural information before encoding
class StructuralIdentificationData {
  final String strand_id;
  final String substrand_type; // e.g., 'Domain', 'Loopout', 'Extension'
  final String sequence_element_id; // ID of the Domain, Loopout, etc.
  final bool forward; // Strand direction
  final int logical_index; // Index in the full strand sequence
  final int precise_offset; // Offset within the specific substrand
  final int? helix_idx; // Helix index, if applicable (mainly for domains)
  final int? helix_offset; // Offset on the helix, if applicable (mainly for domains)
  final String? stable_id; // Used by calculateGridAnchorCoords function

  StructuralIdentificationData({
    required this.strand_id,
    required this.substrand_type,
    required this.sequence_element_id,
    required this.forward,
    required this.logical_index,
    required this.precise_offset,
    this.helix_idx,
    this.helix_offset,
    this.stable_id,
  });

  @override
  String toString() {
    return 'StructuralIdentificationData('
        'strand_id: $strand_id, '
        'substrand_type: $substrand_type, '
        'sequence_element_id: $sequence_element_id, '
        'forward: $forward, '
        'logical_index: $logical_index, '
        'precise_offset: $precise_offset, '
        'helix_idx: $helix_idx, '
        'helix_offset: $helix_offset, '
        'stable_id: $stable_id'
        ')';
  }
}

/// Calculates detailed structural identification data for a T-base.
/// Needs access to AppState to look up strand, substrand, domain details, etc.
StructuralIdentificationData calculateStructuralIdentificationData({
  required AppState state,
  required String strand_id,
  required Substrand substrand,
  required int sequence_position,
}) {
  Strand strand = state.design.strands.firstWhere((s) => s.id == strand_id);
  // Default forward to true, override specifically for Domains below
  bool forward = true;
  int logical_index = -1;
  int precise_offset = -1;
  int? helix_idx;
  int? helix_offset;
  late String substrand_type;

  // Calculate logical index by summing lengths of preceding substrands
  int current_logical_index_start = 0;
  for (var ss in strand.substrands) {
    if (ss.id == substrand.id) {
      logical_index = current_logical_index_start + sequence_position;
      break;
    }
    // Use dna_length() which returns int
    current_logical_index_start += ss.dna_length();
  }

  // Calculate precise offset and helix info based on substrand type
  if (substrand is Domain) {
    helix_idx = substrand.helix;
    // Determine forward direction *from the domain itself*
    forward = substrand.forward;
    precise_offset = sequence_position; // Start with sequence position
    substrand_type = SubstrandTypeEnum.DOMAIN.toString();

    // Adjust precise_offset for insertions/deletions *within this domain*
    // Needs to be updated to work with insertions and deletions.
    // Currently assumes sequence_position is relative to the start of the domain's *rendered* sequence.

    // Calculate helix_offset (base index on the helix grid)
    // This depends on the domain's start/end and strand direction.
    if (forward) {
      helix_offset = substrand.start + precise_offset;
    } else {
      helix_offset = substrand.end - 1 - precise_offset;
    }

    // TODO: Need to precisely handle insertions/deletions effect on precise_offset
    // and how it relates to helix_offset. The current helix_offset calculation
    // assumes precise_offset directly maps to helix bases, which isn't true
    // if insertions/deletions exist *within* the domain.
  } else if (substrand is Loopout) {
    // For loopouts, precise offset is just the index within the loopout sequence.
    precise_offset = sequence_position;
    helix_idx = null;
    helix_offset = null;
    substrand_type = SubstrandTypeEnum.LOOPOUT.toString();
  } else if (substrand is Extension) {
    precise_offset = sequence_position;
    helix_idx = null;
    helix_offset = null;
    substrand_type = SubstrandTypeEnum.EXTENSION.toString();
  } else {
    // Fallback for any other future types or unexpected types
    precise_offset = sequence_position;
    helix_idx = null;
    helix_offset = null;
    substrand_type = substrand.runtimeType.toString(); // Fallback to runtimeType
    print("T-BASE UTIL WARNING: Unknown substrand type encountered: ${substrand_type}");
  }

  // Ensure we have a valid sequence_element_id (should exist on all substrands)
  String sequence_element_id = substrand.id;

  return StructuralIdentificationData(
    strand_id: strand_id,
    substrand_type: substrand_type,
    sequence_element_id: sequence_element_id,
    forward: forward,
    logical_index: logical_index,
    precise_offset: precise_offset,
    helix_idx: helix_idx,
    helix_offset: helix_offset,
    stable_id: null,
  );
}

/// Generates a stable ID string from structural data.
String generateStableId(StructuralIdentificationData data) {
  // Format: tb-strand<ID>-<substrandType>-<elementID>-h<helix_idx>-o<helix_offset>-l<logical_idx>-p<precise_offset>-<fwd|rev>
  // Using descriptive prefixes for clarity during debugging.
  // Use 'na' for null helix/offset values.
  String helixPart = data.helix_idx != null ? 'h${data.helix_idx}' : 'hna';
  String offsetPart = data.helix_offset != null ? 'o${data.helix_offset}' : 'ona';
  String direction = data.forward ? 'fwd' : 'rev';

  // Ensure element ID doesn't contain '-' which would break parsing.
  // Replace hyphens in IDs if necessary, though ideally IDs shouldn't have them.
  String safeElementId = data.sequence_element_id.replaceAll('-', '_');
  String safeStrandId = data.strand_id.replaceAll('-', '_');

  return 'tb-strand${safeStrandId}-${data.substrand_type}-${safeElementId}-${helixPart}-${offsetPart}-l${data.logical_index}-p${data.precise_offset}-${direction}';
}

/// Decodes a stable ID string back into its structural data components.
StructuralIdentificationData decodeStableId(String stable_id) {
  if (!stable_id.startsWith('tb-')) {
    throw ArgumentError('Invalid stable_id format: does not start with tb-');
  }

  // Check if this is an insertion-marked ID (contains -INS#-)
  bool is_insertion = stable_id.contains('-INS');
  int? insertion_offset;

  if (is_insertion) {
    // Extract the insertion offset from the ID
    RegExp insertionRegex = RegExp(r'-INS(\d+)-');
    Match? match = insertionRegex.firstMatch(stable_id);
    if (match != null && match.groupCount >= 1) {
      insertion_offset = int.parse(match.group(1)!);
    }
  }

  // Remove the tb- prefix and split by hyphens
  List<String> parts = stable_id.substring(3).split('-');

  try {
    // Handle insertion-tagged ID format (which has an extra part)
    if (is_insertion && parts.length > 8) {
      // Remove the INS part to have consistent part positions
      parts.removeAt(1);
    }

    if (parts.length != 8) {
      throw ArgumentError(
          'Invalid stable_id format: incorrect number of parts (${parts.length}). ID: $stable_id');
    }

    String strand_id = parts[0].startsWith('strand')
        ? parts[0].substring(6).replaceAll('_', '-')
        : throw ArgumentError('Invalid strand ID part');
    String substrand_type = parts[1];
    String sequence_element_id = parts[2].replaceAll('_', '-'); // Restore original hyphens
    int? helix_idx = parts[3].startsWith('h') && parts[3] != 'hna' ? int.parse(parts[3].substring(1)) : null;
    int? helix_offset =
        parts[4].startsWith('o') && parts[4] != 'ona' ? int.parse(parts[4].substring(1)) : null;
    int logical_index = parts[5].startsWith('l')
        ? int.parse(parts[5].substring(1))
        : throw ArgumentError('Invalid logical index part');
    int precise_offset = parts[6].startsWith('p')
        ? int.parse(parts[6].substring(1))
        : throw ArgumentError('Invalid precise offset part');
    bool forward = parts[7] == 'fwd';

    if (!forward && parts[7] != 'rev') {
      throw ArgumentError('Invalid direction part: must be fwd or rev');
    }

    // For insertions, override the helix_offset with the insertion_offset if available
    if (is_insertion && insertion_offset != null && helix_idx != null) {
      // Use the extracted insertion offset for positioning
      helix_offset = insertion_offset;
    }

    return StructuralIdentificationData(
      strand_id: strand_id,
      substrand_type: substrand_type,
      sequence_element_id: sequence_element_id,
      forward: forward,
      logical_index: logical_index,
      precise_offset: precise_offset,
      helix_idx: helix_idx,
      helix_offset: helix_offset,
      stable_id: stable_id,
    );
  } catch (e) {
    print("T-BASE UTIL ERROR: Failed to decode stable ID '$stable_id': $e");
    // Re-throw or return a default/error state depending on desired handling
    throw ArgumentError('Failed to parse stable_id parts: $e. ID: $stable_id');
  }
}

/// Calculates grid anchor coordinates based on structural data.
/// For domains, uses helix grid position.
/// For loopouts, uses the *upstream* (5'-connected) domain's anchor point.
/// For insertions/extensions, uses adjacent domain connection offset.
Tuple2<double, double> calculateGridAnchorCoords(
    StructuralIdentificationData structuralData, AppState state) {
  // Primary strategy for Insertions: check stable_id for "-INS" marker.
  // decodeStableId populates structuralData.helix_idx with the parent domain's helix
  // and structuralData.helix_offset with the insertion's attachment offset from the -INS<val>- tag.
  if (structuralData.stable_id != null && structuralData.stable_id!.contains("-INS")) {
    // Directly use structuralData.helix_idx and structuralData.helix_offset
    // as populated by decodeStableId for insertions.
    int? helixIdx = structuralData.helix_idx;
    int? attachmentOffsetOnHelix = structuralData.helix_offset; // This is the key value

    if (helixIdx != null && attachmentOffsetOnHelix != null) {
      Point<num>? pos = state.helix_idx_to_svg_position_map[helixIdx];
      if (pos != null) {
        var helixObj = state.design.helices[helixIdx];
        if (helixObj != null) {
          var group = state.design.groups[helixObj.group];
          var geometry = group?.geometry ?? state.design.geometry;
          math.Point<double> basePos = helixObj.svg_base_pos(
              attachmentOffsetOnHelix, structuralData.forward, pos.y.toDouble(), geometry);
          return Tuple2(basePos.x, basePos.y);
        }
      }
      // Fall through if helix/pos/helixObj not found, to general error print at the end.
    }
    // Fall through if helixIdx or attachmentOffsetOnHelix is null for an INS-marked ID (data issue).
  }

  // Logic for Domain, Loopout, Extension (assuming substrand_type is reliable)
  // Note: structuralData.substrand_type is now standardized.
  
  String typeName = structuralData.substrand_type;

  if (typeName == SubstrandTypeEnum.DOMAIN.toString() && structuralData.helix_idx != null) {
    Point<num>? pos = state.helix_idx_to_svg_position_map[structuralData.helix_idx];
    if (pos != null) {
      if (structuralData.helix_offset != null) {
        var helixObj = state.design.helices[structuralData.helix_idx!];
        if (helixObj != null) {
          var group = state.design.groups[helixObj.group];
          var geometry = group?.geometry ?? state.design.geometry;
          math.Point<double> basePos = helixObj.svg_base_pos(
              structuralData.helix_offset!, structuralData.forward, pos.y.toDouble(), geometry);
          return Tuple2(basePos.x, basePos.y);
        }
      }
      return Tuple2(pos.x.toDouble(), pos.y.toDouble()); // Fallback to helix center
    } else {
      print(
          "T-BASE UTIL ERROR: Helix position not found in map for Domain with helix idx: ${structuralData.helix_idx}");
      return Tuple2(0.0, 0.0);
    }
  } else if (typeName == SubstrandTypeEnum.LOOPOUT.toString()) {
    Strand? strand = state.design.strands_by_id[structuralData.strand_id];
    if (strand == null) {
      print("T-BASE UTIL ERROR: Strand not found for Loopout: ${structuralData.strand_id}");
      return Tuple2(0.0, 0.0);
    }
    int substrandIndex = strand.substrands.indexWhere((ss) => ss.id == structuralData.sequence_element_id);
    if (substrandIndex > 0) {
      Substrand prevSubstrand = strand.substrands[substrandIndex - 1];
      if (prevSubstrand is Domain) {
        var helixIdx = prevSubstrand.helix;
        Point<num>? pos = state.helix_idx_to_svg_position_map[helixIdx];
        if (pos != null) {
          var helixObj = state.design.helices[helixIdx];
          if (helixObj != null) {
            var group = state.design.groups[helixObj.group];
            var geometry = group?.geometry ?? state.design.geometry;
            int offset = prevSubstrand.forward ? prevSubstrand.end -1 : prevSubstrand.start;
            math.Point<double> basePos =
                helixObj.svg_base_pos(offset, prevSubstrand.forward, pos.y.toDouble(), geometry);
            return Tuple2(basePos.x, basePos.y);
          }
          return Tuple2(pos.x.toDouble(), pos.y.toDouble());
        } else {
          print(
              "T-BASE UTIL ERROR: Helix position not found for Loopout's previous domain helix idx: ${prevSubstrand.helix}");
          return Tuple2(0.0, 0.0);
        }
      } else {
        print(
            "T-BASE UTIL ERROR: Loopout's previous substrand is not a Domain: ${prevSubstrand.runtimeType}");
        return Tuple2(0.0, 0.0);
      }
    } else {
      print("T-BASE UTIL ERROR: Loopout is the first substrand? Cannot find previous domain.");
      return Tuple2(0.0, 0.0);
    }
  } else if (typeName == SubstrandTypeEnum.EXTENSION.toString()) {
    Strand? strand = state.design.strands_by_id[structuralData.strand_id];
     if (strand == null) {
      print("T-BASE UTIL ERROR: Strand not found for Extension: ${structuralData.strand_id}");
      return Tuple2(0.0, 0.0);
    }
    Substrand? adjacentDomainSubstrand;
    bool is5pExtension = false;

    var currentSubstrand = strand.substrands.firstWhere((ss) => ss.id == structuralData.sequence_element_id, orElse: () => throw Exception('Substrand not found'));
    if (currentSubstrand is Extension) {
        is5pExtension = currentSubstrand.is_5p;
        adjacentDomainSubstrand = currentSubstrand.adjacent_domain;
    }

    if (adjacentDomainSubstrand != null && adjacentDomainSubstrand is Domain) {
      Domain adjacentDomain = adjacentDomainSubstrand;
      int helixIdx = adjacentDomain.helix;
      Point<num>? helixSvgPos = state.helix_idx_to_svg_position_map[helixIdx];
      Helix? helixObj = state.design.helices[helixIdx];

      if (helixSvgPos != null && helixObj != null) {
        var group = state.design.groups[helixObj.group];
        var geometry = group?.geometry ?? state.design.geometry;
        math.Point<double> domainConnectionPos;
        if (is5pExtension) {
          var offset = adjacentDomain.forward ? adjacentDomain.start : adjacentDomain.end - 1;
          domainConnectionPos =
              helixObj.svg_base_pos(offset, adjacentDomain.forward, helixSvgPos.y.toDouble(), geometry);
        } else { // 3' extension
          var offset = adjacentDomain.forward ? adjacentDomain.end - 1 : adjacentDomain.start;
          domainConnectionPos =
              helixObj.svg_base_pos(offset, adjacentDomain.forward, helixSvgPos.y.toDouble(), geometry);
        }
        return Tuple2(domainConnectionPos.x.toDouble(), domainConnectionPos.y.toDouble());
      } else {
        print(
            "T-BASE UTIL ERROR: Helix SVG position or Helix object not found for Extension's adjacent domain helix idx: ${adjacentDomain.helix}");
        return Tuple2(0.0, 0.0);
      }
    } else {
      // This might happen if it's an insertion identified by "Extension" string in substrand_type
      // but the stable_id didn't have "-INS-"
      print("T-BASE UTIL ERROR: Could not find valid adjacent Domain for Extension, or it's an unhandled insertion type: ${typeName}");
      return Tuple2(0.0, 0.0);
    }
  }
  
  // Catch for any unhandled cases or if data issues prevented coordinate calculation above.
  print(
      "T-BASE UTIL ERROR: calculateGridAnchorCoords falling back for unrecognized type or missing data. Type: ${structuralData.substrand_type}, Stable ID: ${structuralData.stable_id}, Helix: ${structuralData.helix_idx}");
  return Tuple2(0.0, 0.0);
}

// -----------------------------------------------------------------------------
// Visual Coordinate Calculation
// -----------------------------------------------------------------------------

/// Calculates visual coordinates (pink dot) for a character within its parent SVG element.
/// Uses parent's text metrics and transformations.
math.Point<double>? calculateVisualCoords(Element element, int charIndex) {
  try {
    // First, we need to find the proper text element to use for position calculation
    TextElement? textElement;
    int indexToUse = charIndex;

    // If this is a tspan, we need to find its text or textPath parent
    if (element.tagName.toLowerCase() == 'tspan') {
      Element? parent = element.parent;

      // If parent is textPath, we need to go up one more level to find the text element
      if (parent != null && parent.tagName.toLowerCase() == 'textpath') {
        var textPathParent = parent.parent;
        if (textPathParent != null && textPathParent is TextElement) {
          textElement = textPathParent;
          // For textPath, we need the index within the textPath, not the tspan
          String fullText = parent.text ?? '';
          String beforeText = fullText.substring(0, charIndex);
          indexToUse = beforeText.length;
        } else {
          print('T-BASE UTIL ERROR: TextPath parent is not a TextElement: ${textPathParent?.tagName}');
          return null;
        }
      }
      // If parent is directly a text element
      else if (parent != null && parent is TextElement) {
        textElement = parent;
        // For direct text child, we need to calculate the actual index in the full text
        int tspanPosition = -1;
        for (int i = 0; i < textElement.childNodes.length; i++) {
          if (textElement.childNodes[i] == element) {
            tspanPosition = i;
            break;
          }
        }

        if (tspanPosition >= 0) {
          // Calculate how many characters come before this tspan
          int charsBeforeTspan = 0;
          for (int i = 0; i < tspanPosition; i++) {
            charsBeforeTspan += textElement.childNodes[i].text?.length ?? 0;
          }
          indexToUse = charsBeforeTspan + charIndex;
        } else {
          print('T-BASE UTIL ERROR: Could not find tspan in parent\'s children');
          indexToUse = charIndex; // fallback
        }
      } else {
        print('T-BASE UTIL ERROR: Tspan parent is not text or textPath: ${parent?.tagName}');
        return null;
      }
    }
    // If this is a textPath, get its parent text element
    else if (element.tagName.toLowerCase() == 'textpath') {
      Element? parent = element.parent;
      if (parent != null && parent is TextElement) {
        textElement = parent;
      } else {
        print('T-BASE UTIL ERROR: TextPath has no valid parent text element');
        return null;
      }
    }
    // If this is already a text element
    else if (element is TextElement) {
      textElement = element;
    } else {
      print('T-BASE UTIL ERROR: Element is not a TextElement, TextPath, or Tspan: ${element.tagName}');
      return null;
    }

    // Now use the textElement to get character position
    // Check if index is in range
    String text = textElement.text ?? '';
    if (indexToUse < 0 || indexToUse >= text.length) {
      print(
          'T-BASE UTIL ERROR: Character index $indexToUse out of bounds for text element (length: ${text.length})');
      return null;
    }

    // Use SVG text metrics to get character position
    var startPoint = textElement.getStartPositionOfChar(indexToUse);
    var endPoint = textElement.getEndPositionOfChar(indexToUse);

    // Calculate character center in local coordinates
    double localX = ((startPoint.x ?? 0) + (endPoint.x ?? 0)) / 2;
    double localY = ((startPoint.y ?? 0) + (endPoint.y ?? 0)) / 2;

    // Get the transform attribute from the text element
    String? transform = textElement.getAttribute('transform');

    // First apply the text element's own transformations
    var transformedPoint = localX != 0 || localY != 0
        ? _applyTextTransform(transform, localX, localY)
        : math.Point(localX, localY);

    // Then apply any parent translations recursively
    var parentTranslation = _getParentTranslation(textElement);
    if (parentTranslation != null) {
      transformedPoint =
          math.Point(transformedPoint.x + parentTranslation.x, transformedPoint.y + parentTranslation.y);
    }

    return transformedPoint;
  } catch (e, stackTrace) {
    print('T-BASE UTIL ERROR: Error calculating visual coordinates: $e\n$stackTrace');
    return null;
  }
}

/// Apply text element's transform (especially rotation) to a point
math.Point<double> _applyTextTransform(String? transform, double x, double y) {
  if (transform == null || transform.isEmpty) {
    return math.Point(x, y);
  }

  // Handle rotation transform - format: rotate(angle cx cy)
  // where cx,cy is the rotation center point (optional)
  var rotateMatch = RegExp(r'rotate\(\s*([-\d.]+)(?:\s+([-\d.]+)\s+([-\d.]+))?\s*\)').firstMatch(transform);
  if (rotateMatch != null) {
    double angle = double.parse(rotateMatch.group(1)!);
    double cx = 0.0;
    double cy = 0.0;

    // Get rotation center if specified
    if (rotateMatch.group(2) != null && rotateMatch.group(3) != null) {
      cx = double.parse(rotateMatch.group(2)!);
      cy = double.parse(rotateMatch.group(3)!);
    }

    // Convert angle to radians and compute rotation
    double radians = angle * (math.pi / 180.0);
    double sinVal = math.sin(radians);
    double cosVal = math.cos(radians);

    // Translate to origin, rotate, translate back
    double dx = x - cx;
    double dy = y - cy;
    double newX = dx * cosVal - dy * sinVal + cx;
    double newY = dx * sinVal + dy * cosVal + cy;

    return math.Point(newX, newY);
  }

  // Handle translation transform if present
  var translateMatch = RegExp(r'translate\(\s*([-\d.]+)(?:[\s,]+([-\d.]+))?\s*\)').firstMatch(transform);
  if (translateMatch != null) {
    double tx = double.parse(translateMatch.group(1)!);
    double ty = translateMatch.group(2) != null ? double.parse(translateMatch.group(2)!) : 0.0;

    return math.Point(x + tx, y + ty);
  }

  // No recognized transform found
  return math.Point(x, y);
}

/// Get accumulated translation from all parent elements
math.Point<double>? _getParentTranslation(Element? element) {
  if (element == null) return null;

  double tx = 0.0;
  double ty = 0.0;
  bool foundTransform = false;

  Element? current = element.parent;
  while (current != null) {
    String? transform = current.getAttribute('transform');
    if (transform != null) {
      // Handle translation transform
      var translateMatch = RegExp(r'translate\(\s*([-\d.]+)(?:[\s,]+([-\d.]+))?\s*\)').firstMatch(transform);
      if (translateMatch != null) {
        tx += double.parse(translateMatch.group(1)!);
        if (translateMatch.group(2) != null) {
          ty += double.parse(translateMatch.group(2)!);
        }
        foundTransform = true;
      }
    }
    current = current.parent;
  }

  return foundTransform ? math.Point<double>(tx, ty) : null;
}
