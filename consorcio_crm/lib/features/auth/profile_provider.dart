import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  final String id;
  final String fullName;
  final String role;
  final String? teamId;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    this.teamId,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      fullName: map['full_name'] ?? 'Usuário',
      role: map['role'] ?? 'vendedor', // Se não tiver, assume que é vendedor
      teamId: map['team_id'],
    );
  }
}

final userProfileProvider = StreamProvider.autoDispose<UserProfile?>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return Stream.value(null);

  return Supabase.instance.client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((data) {
        if (data.isEmpty) return null;
        return UserProfile.fromMap(data.first);
      });
});