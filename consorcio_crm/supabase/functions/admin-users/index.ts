import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Cabeçalho ausente.')
    const token = authHeader.replace('Bearer ', '')

    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token)
    if (userError || !user) throw new Error('Não autenticado.')

    // Lendo a ROLE e também a REGIAO do usuário que está chamando a função
    const { data: profile } = await supabaseAdmin.from('profiles').select('role, regiao').eq('id', user.id).single()
    
    const allowedRoles = ['gerente', 'administrador', 'diretor', 'administrativo'];
    if (!profile || !allowedRoles.includes(profile.role)) {
      throw new Error('Acesso negado. Nível de permissão insuficiente.')
    }

    const body = await req.json()
    const { action, email, password, fullName, userRole, targetUserId, teamId, regionName, teamName, targetTeamId, oldRegionName, newRegionName, managedTeams } = body

    // ==========================================
    // 1. GERENCIAMENTO DE USUÁRIOS
    // ==========================================

    if (action === 'invite_user') {
      if (profile.role === 'administrativo' && ['diretor', 'administrativo', 'administrador'].includes(userRole)) {
        throw new Error('Permissão negada: Administrativos não podem convidar contas de alto nível.')
      }
      if (profile.role === 'gerente' && ['gerente', 'diretor', 'administrativo', 'administrador'].includes(userRole)) {
        throw new Error('Permissão negada: Gerentes só podem convidar contas de Vendedor e Supervisor.')
      }

      // 1. Dispara o e-mail de convite do Supabase
      const { data: authData, error: authError } = await supabaseAdmin.auth.admin.inviteUserByEmail(email)
      if (authError) throw authError

      // 2. Insere os dados na tabela profiles (incluindo o e-mail para acesso via frontend)
      if (authData && authData.user) {
        const { error: profileError } = await supabaseAdmin.from('profiles').insert({ 
          id: authData.user.id, full_name: fullName, role: userRole, team_id: null, regiao: null, email: email
        })
        if (profileError) throw profileError
      }

      return new Response(JSON.stringify({ success: true, message: 'Convite enviado para o e-mail!' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    if (action === 'delete_user') {
      const { error } = await supabaseAdmin.auth.admin.deleteUser(targetUserId)
      if (error) throw error
      return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    if (action === 'reset_password') {
      const { error } = await supabaseAdmin.auth.admin.updateUserById(targetUserId, { password: password })
      if (error) throw error
      return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // --- NOVA AÇÃO: DISPARO DE LINK DE RECUPERAÇÃO VIA BACKEND ---
    if (action === 'send_reset_link') {
      // Busca o registro do usuário na tabela oculta do sistema de autenticação
      const { data: userData, error: fetchError } = await supabaseAdmin.auth.admin.getUserById(targetUserId)
      if (fetchError || !userData?.user) throw new Error('Usuário não encontrado no sistema de autenticação.')
      
      const targetEmail = userData.user.email
      if (!targetEmail) throw new Error('O usuário não possui um e-mail oficial cadastrado.')

      // Dispara o e-mail nativo de redefinição de senha
      const { error: resetError } = await supabaseAdmin.auth.resetPasswordForEmail(targetEmail)
      if (resetError) throw resetError

      return new Response(JSON.stringify({ success: true, message: 'Link de recuperação enviado com sucesso!' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    if (action === 'update_user') {
      if (profile.role === 'administrativo' && ['diretor', 'administrativo', 'administrador'].includes(userRole)) {
        throw new Error('Permissão negada: Administrativos não podem promover para este cargo.')
      }
      if (profile.role === 'gerente' && ['gerente', 'diretor', 'administrativo', 'administrador'].includes(userRole)) {
        throw new Error('Permissão negada: Gerentes não podem promover usuários a cargos de gerência ou diretoria.')
      }

      let profileUpdatePayload: any = { full_name: fullName, role: userRole }

      if (email && email.trim() !== '') {
        // ATENÇÃO AQUI: email_confirm: false força o envio do e-mail de confirmação em vez de alterar direto.
        const { error: authError } = await supabaseAdmin.auth.admin.updateUserById(targetUserId, { email: email, email_confirm: false })
        if (authError) throw authError
        
        // Adiciona o e-mail ao payload para refletir a alteração na tabela de visualização
        profileUpdatePayload.email = email
      }

      const { error: profileError } = await supabaseAdmin.from('profiles').update(profileUpdatePayload).eq('id', targetUserId)
      if (profileError) throw profileError
      
      return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    if (action === 'assign_user_team') {
      const { error } = await supabaseAdmin.from('profiles').update({ team_id: teamId, regiao: null }).eq('id', targetUserId)
      if (error) throw error
      return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    if (action === 'assign_user_region') {
      const { error } = await supabaseAdmin.from('profiles').update({ regiao: regionName, team_id: null }).eq('id', targetUserId)
      if (error) throw error
      return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // ==========================================
    // 2. GERENCIAMENTO DE EQUIPES E REGIÕES
    // ==========================================

    if (action === 'create_team' || action === 'update_team_entity') {
      const finalRegion = profile.role === 'gerente' ? profile.regiao : regionName;
      
      if (action === 'create_team') {
        const { error } = await supabaseAdmin.from('teams').insert({ name: teamName, regiao: finalRegion })
        if (error) throw error
        return new Response(JSON.stringify({ success: true, message: 'Equipe criada!' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
      } else {
        const { error } = await supabaseAdmin.from('teams').update({ name: teamName, regiao: finalRegion }).eq('id', targetTeamId)
        if (error) throw error
        return new Response(JSON.stringify({ success: true, message: 'Equipe atualizada!' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
      }
    }

    if (action === 'delete_team') {
      const { error: unlinkProfilesError } = await supabaseAdmin.from('profiles').update({ team_id: null }).eq('team_id', targetTeamId)
      if (unlinkProfilesError) throw new Error("Erro ao desvincular membros: " + JSON.stringify(unlinkProfilesError))
      const { error: unlinkClientsError } = await supabaseAdmin.from('clients').update({ team_id: null }).eq('team_id', targetTeamId)
      if (unlinkClientsError && unlinkClientsError.code !== 'PGRST204') throw new Error("Erro ao desvincular clientes: " + JSON.stringify(unlinkClientsError))

      const { error } = await supabaseAdmin.from('teams').delete().eq('id', targetTeamId)
      if (error) throw error
      return new Response(JSON.stringify({ success: true, message: 'Equipe excluída com segurança!' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // --- BLOQUEIO PARA GERENTES NAS AÇÕES DE REGIÃO OFICIAL ---
    if (['create_region', 'rename_region', 'delete_region', 'update_region_teams'].includes(action)) {
      if (profile.role === 'gerente') {
        throw new Error('Acesso negado. Apenas diretores e administradores podem gerenciar regiões globais.')
      }
    }

    if (action === 'create_region') {
      const { error } = await supabaseAdmin.from('regions').insert({ name: regionName })
      if (error && error.code !== '23505') throw error 
      return new Response(JSON.stringify({ success: true, message: 'Região salva no banco!' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    if (action === 'rename_region') {
      await supabaseAdmin.from('regions').update({ name: newRegionName }).eq('name', oldRegionName)
      await supabaseAdmin.from('teams').update({ regiao: newRegionName }).eq('regiao', oldRegionName)
      await supabaseAdmin.from('profiles').update({ regiao: newRegionName }).eq('regiao', oldRegionName)
      return new Response(JSON.stringify({ success: true, message: 'Região renomeada em todo o sistema!' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    if (action === 'delete_region') {
      await supabaseAdmin.from('regions').delete().eq('name', oldRegionName)
      await supabaseAdmin.from('teams').update({ regiao: null }).eq('regiao', oldRegionName)
      await supabaseAdmin.from('profiles').update({ regiao: null }).eq('regiao', oldRegionName)
      return new Response(JSON.stringify({ success: true, message: 'Região excluída com segurança!' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    if (action === 'update_region_teams') {
      try {
        const targetRegion = body.regionName;
        const targetTeams = body.managedTeams; 
        const { error: clearError } = await supabaseAdmin.from('teams').update({ regiao: null }).eq('regiao', targetRegion);
        if (clearError) throw clearError;
        if (targetTeams && Array.isArray(targetTeams) && targetTeams.length > 0) {
          const teamIds = targetTeams.map((id: any) => isNaN(Number(id)) ? id : Number(id));
          const { error: updateError } = await supabaseAdmin.from('teams').update({ regiao: targetRegion }).in('id', teamIds);
          if (updateError) throw updateError;
        }
        return new Response(JSON.stringify({ success: true, message: 'Equipes atualizadas com sucesso!' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
      } catch (err: any) {
        throw new Error("Falha ao salvar equipes: " + (err.message || JSON.stringify(err)));
      }
    }

    throw new Error('Ação desconhecida.')

  } catch (error: any) {
    const errorMessage = error?.message || JSON.stringify(error) || String(error)
    return new Response(JSON.stringify({ error: errorMessage }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
  }
})