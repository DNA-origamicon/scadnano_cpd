import 'dart:html';

import 'package:redux/redux.dart';

import '../actions/actions.dart' as actions;
import '../constants.dart' as constants;
import '../state/app_state.dart';
import '../state/cpd_parameters.dart';

/// Middleware that handles [ReloadCpdParameters].
///
/// Forces a fresh fetch of `cpd_parameters.json`, dispatches
/// [CpdParametersLoaded] on success, then re-triggers CPD detection if the
/// "Show CPD Sites" toggle is active.
Middleware<AppState> cpd_parameters_reload_middleware =
    (Store<AppState> store, dynamic action, NextDispatcher next) {
  if (action is actions.ReloadCpdParameters) {
    next(action);
    HttpRequest.getString(constants.CPD_PARAMETERS_PATH).then((content) {
      final CpdParameters params = CpdParameters.from_json_string(content);
      store.dispatch(actions.CpdParametersLoaded(params));
      // Re-run detection so existing CPD sites reflect the new weights.
      if (store.state.ui_state.show_cpd_sites_continuously) {
        store.dispatch(actions.DetectCPDSites());
      }
    }).catchError((e) {
      print('CPD parameter reload failed: $e');
    });
  } else {
    next(action);
  }
};
