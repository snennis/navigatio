import 'package:flutter/material.dart';
import '../models/route_models.dart';

/// Widget zur Darstellung der GraphHopper Route-Details
class RouteDetailsSheet extends StatelessWidget {
  final GraphHopperRouteResponse routeResponse;
  final VoidCallback onClose;

  const RouteDetailsSheet({
    super.key,
    required this.routeResponse,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.directions_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Route Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        routeResponse.route.properties.source == 'graphhopper'
                            ? 'GraphHopper Routing'
                            : 'Direkte Verbindung',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 40),
            _buildSummaryCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final props = routeResponse.route.properties;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (props.duration != null) ...[
            Expanded(
              child: Column(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    props.getFormattedDuration(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Dauer',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (props.duration != null &&
              (props.profile != null ||
                  (props.transfers != null && props.transfers! > 0)))
            Container(
              width: 1,
              height: 50,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            ),
          if (props.profile != null) ...[
            Expanded(
              child: Column(
                children: [
                  Icon(
                    _getProfileIcon(props.profile!),
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getProfileName(props.profile!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (props.profile != null &&
              (props.transfers != null && props.transfers! > 0))
            Container(
              width: 1,
              height: 50,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            ),
          if (props.transfers != null && props.transfers! > 0) ...[
            Expanded(
              child: Column(
                children: [
                  Icon(
                    Icons.compare_arrows_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${props.transfers}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Umstiege',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStationInfo(BuildContext context) {
    final props = routeResponse.route.properties;
    return Column(
      children: [
        // From Station
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.place_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Von',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      props.from.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (props.from.type != null)
                      Text(
                        props.from.type!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // To Station
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nach',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      props.to.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (props.to.type != null)
                      Text(
                        props.to.type!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildLegsList(BuildContext context) {
    final legs = routeResponse.route.properties.legs!;

    return legs.map((leg) {
      // Farben für verschiedene Transport-Typen
      Color legColor = Colors.blue;
      IconData legIcon = Icons.directions_walk_rounded;

      switch (leg.type?.toLowerCase()) {
        case 'pt':
          legColor = Colors.green;
          legIcon = Icons.directions_transit_rounded;
          break;
        case 'walk':
          legColor = Colors.orange;
          legIcon = Icons.directions_walk_rounded;
          break;
        case 'bike':
          legColor = Colors.purple;
          legIcon = Icons.directions_bike_rounded;
          break;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: legColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: legColor.withOpacity(0.3), width: 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: legColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(legIcon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leg.getTypeLabel(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: legColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (leg.routeId != null)
                      Text(
                        '${leg.routeId}${leg.headsign != null ? ' → ${leg.headsign}' : ''}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (leg.departureLocation != null ||
                        leg.arrivalLocation != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${leg.departureLocation ?? ''} → ${leg.arrivalLocation ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (leg.distance != null) ...[
                          Icon(
                            Icons.straighten_rounded,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            leg.getFormattedDistance(),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (leg.duration != null) ...[
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            leg.getFormattedDuration(),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildInstructionItem(
    BuildContext context,
    GraphHopperInstruction instruction,
    int index,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Number
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Instruction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instruction.text.isNotEmpty
                      ? instruction.text
                      : instruction.getDirectionDescription(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.straighten_rounded,
                      size: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      instruction.getFormattedDistance(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      instruction.getFormattedTime(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getProfileIcon(String profile) {
    switch (profile.toLowerCase()) {
      case 'foot':
        return Icons.directions_walk_rounded;
      case 'car':
        return Icons.directions_car_rounded;
      case 'bike':
        return Icons.directions_bike_rounded;
      case 'pt':
        return Icons.directions_transit_rounded;
      default:
        return Icons.directions_rounded;
    }
  }

  String _getProfileName(String profile) {
    switch (profile.toLowerCase()) {
      case 'foot':
        return 'Zu Fuß';
      case 'car':
        return 'Auto';
      case 'bike':
        return 'Fahrrad';
      case 'pt':
        return 'ÖPNV';
      default:
        return profile;
    }
  }

  List<Widget> _buildHumanReadableSteps(BuildContext context) {
    final legs = routeResponse.route.properties.legs!;
    final List<Widget> steps = [];
    int stepIndex = 1;

    for (final leg in legs) {
      String description;

      if (leg.type == 'walk') {
        description =
            'Zu Fuß gehen: ${leg.departureLocation ?? ''} → ${leg.arrivalLocation ?? ''}';
      } else if (leg.type == 'pt') {
        final line = leg.routeId ?? 'Linie';
        final dir = leg.headsign != null ? 'Richtung ${leg.headsign}' : '';
        description =
            'Mit $line $dir fahren: ${leg.departureLocation ?? ''} → ${leg.arrivalLocation ?? ''}';
      } else {
        description =
            '${leg.type ?? 'Abschnitt'}: ${leg.departureLocation ?? ''} → ${leg.arrivalLocation ?? ''}';
      }

      steps.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$stepIndex',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );

      stepIndex++;
    }

    return steps;
  }
}
