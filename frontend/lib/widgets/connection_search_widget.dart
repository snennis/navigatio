import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../models/station_models.dart';
import '../services/station_service.dart';

class ConnectionSearchWidget extends StatefulWidget {
  final ConnectionSearch initialSearch;
  final Function(ConnectionSearch) onSearchChanged;
  final VoidCallback? onSearchPressed;

  const ConnectionSearchWidget({
    super.key,
    required this.initialSearch,
    required this.onSearchChanged,
    this.onSearchPressed,
  });

  @override
  State<ConnectionSearchWidget> createState() => _ConnectionSearchWidgetState();
}

class _ConnectionSearchWidgetState extends State<ConnectionSearchWidget> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  late ConnectionSearch _currentSearch;

  @override
  void initState() {
    super.initState();
    _currentSearch = widget.initialSearch;
    _fromController.text = _currentSearch.fromStation?.name ?? '';
    _toController.text = _currentSearch.toStation?.name ?? '';
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _updateFromStation(Station? station) {
    setState(() {
      _currentSearch = _currentSearch.copyWith(fromStation: station);
      _fromController.text = station?.name ?? '';
    });
    widget.onSearchChanged(_currentSearch);
  }

  void _updateToStation(Station? station) {
    setState(() {
      _currentSearch = _currentSearch.copyWith(toStation: station);
      _toController.text = station?.name ?? '';
    });
    widget.onSearchChanged(_currentSearch);
  }

  void _swapStations() {
    setState(() {
      final temp = _currentSearch.fromStation;
      _currentSearch = ConnectionSearch(
        fromStation: _currentSearch.toStation,
        toStation: temp,
      );
      _fromController.text = _currentSearch.fromStation?.name ?? '';
      _toController.text = _currentSearch.toStation?.name ?? '';
    });
    widget.onSearchChanged(_currentSearch);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.route_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Verbindung suchen',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // From Station Input
          _buildStationTypeAhead(
            controller: _fromController,
            hintText: 'Startstation eingeben...',
            icon: Icons.radio_button_checked,
            iconColor: Colors.green,
            onStationSelected: _updateFromStation,
          ),

          const SizedBox(height: 8),

          // Swap Button
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _swapStations,
                icon: const Icon(Icons.swap_vert_rounded),
                iconSize: 20,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                tooltip: 'Start und Ziel tauschen',
              ),
            ),
          ),

          const SizedBox(height: 8),

          // To Station Input
          _buildStationTypeAhead(
            controller: _toController,
            hintText: 'Zielstation eingeben...',
            icon: Icons.location_on,
            iconColor: Colors.red,
            onStationSelected: _updateToStation,
          ),

          const SizedBox(height: 16),

          // Search Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _currentSearch.isComplete
                  ? widget.onSearchPressed
                  : null,
              icon: const Icon(Icons.search),
              label: const Text('Verbindung suchen'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationTypeAhead({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required Color iconColor,
    required Function(Station?) onStationSelected,
  }) {
    return TypeAheadField<Station>(
      controller: controller,
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: iconColor, size: 20),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                      onStationSelected(null);
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        );
      },
      suggestionsCallback: (pattern) async {
        if (pattern.length < 2) return [];
        return await StationService.searchStations(pattern);
      },
      itemBuilder: (context, station) {
        return ListTile(
          leading: Icon(
            _getStationIcon(station.type),
            color: _getStationColor(station.type),
            size: 20,
          ),
          title: Text(station.name, style: const TextStyle(fontSize: 14)),
          subtitle: Text(
            _getStationTypeText(station.type),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          trailing: station.similarity != null
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${(station.similarity! * 100).round()}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                )
              : null,
        );
      },
      onSelected: onStationSelected,
      emptyBuilder: (context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Keine Haltestellen gefunden',
          style: TextStyle(fontSize: 14),
        ),
      ),
      loadingBuilder: (context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Suche...', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      errorBuilder: (context, error) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Fehler beim Suchen: $error',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
  }

  IconData _getStationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'station':
      case 'railway':
        return Icons.train;
      case 'subway_entrance':
      case 'platform':
        return Icons.subway;
      case 'bus_stop':
        return Icons.directions_bus;
      case 'tram_stop':
        return Icons.tram;
      case 'stop_position':
        return Icons.location_on;
      default:
        return Icons.location_on;
    }
  }

  Color _getStationColor(String type) {
    switch (type.toLowerCase()) {
      case 'station':
      case 'railway':
        return Colors.green;
      case 'subway_entrance':
      case 'platform':
        return Colors.blue;
      case 'bus_stop':
        return Colors.purple;
      case 'tram_stop':
        return Colors.pink;
      case 'stop_position':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStationTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'station':
        return 'Bahnhof';
      case 'railway':
        return 'Bahnstation';
      case 'subway_entrance':
        return 'U-Bahn Eingang';
      case 'platform':
        return 'Bahnsteig';
      case 'bus_stop':
        return 'Bushaltestelle';
      case 'tram_stop':
        return 'Straßenbahn';
      case 'stop_position':
        return 'Haltestelle';
      case 'halt':
        return 'Haltepunkt';
      default:
        return type;
    }
  }
}
