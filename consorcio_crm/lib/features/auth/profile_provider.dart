import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Estrutura de dados que representa o perfil do nosso usuário
class UserProfile {
  final String id;
  final String fullName;
  final String role;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
  });

  // Converte a resposta do banco de dados (Map) para o nosso objeto no Flutter
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      fullName: map['full_name'],
      role: map['role'],
    );
  }
}

// Provedor que faz a busca no banco de dados de forma assíncrona (Future)
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  
  // Se não houver usuário logado no momento, retorna nulo
  if (user == null) return null;

  // Busca na tabela 'profiles' a linha onde o ID é igual ao do usuário logado
  final response = await Supabase.instance.client
      .from('profiles')
      .select()
      .eq('id', user.id)
      .single();

  return UserProfile.fromMap(response);
});