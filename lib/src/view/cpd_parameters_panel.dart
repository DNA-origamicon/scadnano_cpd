// Read-only inspector for the currently-loaded CpdParameters.
//
// Exposed as a plain render function (not an over_react component) so it can be
// embedded directly inside the CPD Sites submenu without code generation.

import 'package:over_react/over_react.dart';

import '../state/cpd_parameters.dart';

/// Renders a read-only summary of [params] as a series of menu-compatible
/// `<div>` elements.
///
/// Returns `null` if [params] is null (not yet loaded).
ReactElement? render_cpd_parameters_panel(CpdParameters? params) {
  if (params == null) return null;

  final List<ReactElement> rows = [];

  // ── Header: schema version and last_updated ────────────────────────────────
  rows.add((Dom.div()
    ..className = 'cpd-params-header'
    ..style = {
      'padding': '4px 16px',
      'fontSize': '11px',
      'color': '#888',
      'borderTop': '1px solid #e0e0e0',
      'marginTop': '4px',
    }
    ..key = 'params-header')(
    'Parameters v${params.schema_version}  ·  ${params.last_updated}',
  ));

  // ── Per-photoproduct rows ──────────────────────────────────────────────────
  for (final p in params.photoproducts) {
    final String status = p.enabled ? 'enabled' : 'disabled';

    // Structural weights summary string.
    final List<String> weight_strs = [];
    for (final entry in p.structural_context_weights.entries) {
      final label = _short_context_label(entry.key);
      final w = entry.value.weight.toStringAsFixed(2);
      weight_strs.add('$label: $w');
    }
    final String weights_text = weight_strs.join('  ');

    final List<dynamic> product_children = [
      (Dom.span()
        ..style = {
          'display': 'inline-block',
          'width': '10px',
          'height': '10px',
          'borderRadius': '50%',
          'backgroundColor': p.enabled ? p.color : '#ccc',
          'marginRight': '6px',
          'verticalAlign': 'middle',
        }
        ..key = 'swatch-${p.id}')(),
      (Dom.span()
        ..style = {'fontWeight': p.enabled ? 'bold' : 'normal'}
        ..key = 'name-${p.id}')(
        '${p.abbreviation} ($status)',
      ),
    ];
    if (p.enabled) {
      product_children.add(
        (Dom.div()
          ..style = {'paddingLeft': '16px', 'color': '#666', 'fontSize': '10px'}
          ..key = 'weights-${p.id}')(weights_text),
      );
    }

    rows.add((Dom.div()
      ..className = 'cpd-params-product'
      ..style = {
        'padding': '2px 16px 2px 20px',
        'fontSize': '11px',
        'lineHeight': '1.5',
        'color': p.enabled ? '#333' : '#aaa',
      }
      ..key = 'product-${p.id}')(product_children));
  }

  return (Dom.div()
    ..className = 'cpd-parameters-panel'
    ..key = 'cpd-params-panel')(rows);
}

/// Maps a structural context key to a short display label.
String _short_context_label(String key) {
  switch (key) {
    case 'adjacent_domain_ds':
      return 'adj-ds';
    case 'extension_extension':
      return 'ext-ext';
    case 'loopout_loopout':
      return 'loop-loop';
    case 'extension_loopout':
      return 'ext-loop';
    default:
      return key;
  }
}
