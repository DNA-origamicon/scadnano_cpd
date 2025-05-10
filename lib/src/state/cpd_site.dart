library cpd_site;

import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import '../serializers.dart';
import 't_base_location.dart';

part 'cpd_site.g.dart';

abstract class CPDSite implements Built<CPDSite, CPDSiteBuilder> {
  TBaseLocation get t1;
  TBaseLocation get t2;
  bool get is_conflicted;
  
  // toMap() method used for console logging
  Map<String, dynamic> toMap() {
    return {
      't1_stable_id': t1.stable_id,
      't2_stable_id': t2.stable_id,
      'is_conflicted': is_conflicted,
    };
  }

  /************************ Boilerplate ************************/
  factory CPDSite({required TBaseLocation t1, required TBaseLocation t2, bool is_conflicted = false}) =>
      _$CPDSite((b) => b
        ..t1.replace(t1)
        ..t2.replace(t2)
        ..is_conflicted = is_conflicted);

  factory CPDSite.from([void Function(CPDSiteBuilder) updates]) = _$CPDSite;

  CPDSite._();

  static Serializer<CPDSite> get serializer => _$cPDSiteSerializer;

  Map<String, dynamic> toJson() =>
      serializers.serializeWith(CPDSite.serializer, this) as Map<String, dynamic>;

  static CPDSite fromJson(Map<String, dynamic> json) =>
      serializers.deserializeWith(CPDSite.serializer, json)!;
}
