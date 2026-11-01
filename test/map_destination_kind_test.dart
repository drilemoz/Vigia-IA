import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_destination_search.dart';

void main() {
  test('cidade retornada como limite administrativo e selecionavel', () {
    expect(MapDestinationKindX.fromNominatim(
      category: 'boundary', type: 'administrative', addressType: 'municipality',
    ), MapDestinationKind.place);
    expect(MapDestinationKindX.fromNominatim(
      category: 'place', type: 'town', addressType: 'town',
    ), MapDestinationKind.town);
  });

  test('POI nao e aceito como cidade por engano', () {
    expect(MapDestinationKindX.fromNominatim(
      category: 'amenity', type: 'restaurant', addressType: 'amenity',
    ), MapDestinationKind.pointOfInterest);
  });
}
