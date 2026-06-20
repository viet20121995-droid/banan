import 'package:equatable/equatable.dart';

/// A production kitchen — where orders are prepared. One kitchen serves one or
/// more branches (a Store points at its `defaultKitchenId`). `capacityPerHour`
/// is a soft cap used by the capacity planner.
class Kitchen extends Equatable {
  const Kitchen({
    required this.id,
    required this.name,
    required this.address,
    this.capacityPerHour = 40,
  });

  final String id;
  final String name;
  final String address;
  final int capacityPerHour;

  @override
  List<Object?> get props => [id, name, address, capacityPerHour];
}
