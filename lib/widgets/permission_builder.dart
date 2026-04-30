import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class PermissionBuilder extends StatelessWidget {
  final String resource;
  final String action;
  final Widget child;
  final Widget fallback;

  const PermissionBuilder({
    super.key,
    required this.resource,
    required this.action,
    required this.child,
    this.fallback =
        const SizedBox.shrink(), // By default, it shows nothing if denied
  });

  @override
  Widget build(BuildContext context) {
    // Grab the current user from our provider
    final user = Provider.of<AuthProvider>(context).user;

    // If no user is logged in, or they don't have the specific permission, hide it!
    if (user == null || !user.hasPermission(resource, action)) {
      return fallback;
    }

    // If they HAVE the permission, render the widget normally
    return child;
  }
}
