import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  final String id;
  final String fullName;
  final String role;
  final String? teamId;
  final String? regiao; // <-- ADICIONAMOS A REGIÃO AQUI!
  final String? avatarUrl;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    this.teamId,
    this.regiao, // <-- ADICIONAMOS A REGIÃO AQUI!
    this.avatarUrl,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      fullName: map['full_name'] ?? 'Usuário',
      role: map['role'] ?? 'vendedor',
      teamId: map['team_id']?.toString(),
      regiao: map['regiao']?.toString(), // <-- ADICIONAMOS A LIDA DO BANCO DE DADOS AQUI!
      avatarUrl: map['avatar_url'],
    );
  }
}

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    return Stream.value(null);
  }

  return Supabase.instance.client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', user.id)
      .map((list) {
        if (list.isEmpty) return null;
        return UserProfile.fromMap(list.first);
      });
});