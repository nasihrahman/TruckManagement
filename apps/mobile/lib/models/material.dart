/// Named `CargoMaterial`, not `Material`/`MaterialType` — Flutter's own widget
/// library already exports both of those names (the `Material` widget and its
/// `MaterialType` enum), and this gets imported alongside `package:flutter/material.dart`.
class CargoMaterial {
  final String id;
  final String name;

  CargoMaterial({required this.id, required this.name});

  factory CargoMaterial.fromJson(Map<String, dynamic> json) {
    return CargoMaterial(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
