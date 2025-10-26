/// Verschiedene Kartenstile für die Navigatio App
class MapStyle {
  final String name;
  final String urlTemplate;
  final List<String>? subdomains;
  final String description;

  const MapStyle({
    required this.name,
    required this.urlTemplate,
    this.subdomains,
    required this.description,
  });

  static const List<MapStyle> availableStyles = [
    MapStyle(
      name: 'CartoDB Hell',
      urlTemplate:
          'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      description: 'Helle, moderne Karte - ideal für den Tag',
    ),
    MapStyle(
      name: 'CartoDB Dunkel',
      urlTemplate:
          'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      description: 'Dunkle Karte - augenschonend für die Nacht',
    ),
  ];
}
