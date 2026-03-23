@extends('layouts.admin')
@section('title', 'Usuários')
@section('page-title', 'Gerenciar Usuários')

@section('content')
<div class="mt-2">
    <!-- Barra de ferramentas -->
    <div class="flex flex-col sm:flex-row gap-3 mb-5">
        <form method="GET" class="flex flex-1 gap-2">
            <input type="text" name="search" value="{{ request('search') }}"
                placeholder="Buscar por usuário, nome, e-mail..."
                class="flex-1 border rounded-lg px-4 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none">
            <select name="plan_id" class="border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none">
                <option value="">Todos os planos</option>
                @foreach($plans as $plan)
                    <option value="{{ $plan->id }}" {{ request('plan_id') == $plan->id ? 'selected' : '' }}>{{ $plan->name }}</option>
                @endforeach
            </select>
            <select name="status" class="border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none">
                <option value="">Todos os status</option>
                <option value="active"    {{ request('status') == 'active'    ? 'selected' : '' }}>Ativo</option>
                <option value="suspended" {{ request('status') == 'suspended' ? 'selected' : '' }}>Suspenso</option>
                <option value="expired"   {{ request('status') == 'expired'   ? 'selected' : '' }}>Expirado</option>
            </select>
            <button type="submit" class="bg-gray-100 hover:bg-gray-200 border rounded-lg px-4 py-2 text-sm font-medium transition">
                <i class="fas fa-search"></i>
            </button>
            @if(request()->hasAny(['search','plan_id','status']))
                <a href="{{ route('admin.users.index') }}" class="bg-gray-100 hover:bg-gray-200 border rounded-lg px-4 py-2 text-sm transition">
                    <i class="fas fa-times"></i>
                </a>
            @endif
        </form>
        <a href="{{ route('admin.users.create') }}"
            class="inline-flex items-center bg-blue-600 hover:bg-blue-700 text-white rounded-lg px-4 py-2 text-sm font-medium transition flex-shrink-0">
            <i class="fas fa-plus mr-2"></i> Novo Usuário
        </a>
    </div>

    <!-- Tabela -->
    <div class="bg-white rounded-xl border shadow-sm overflow-hidden">
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead class="bg-gray-50 text-xs text-gray-500 uppercase border-b">
                    <tr>
                        <th class="px-4 py-3 text-left">Usuário</th>
                        <th class="px-4 py-3 text-left">Nome / Contato</th>
                        <th class="px-4 py-3 text-left">Plano</th>
                        <th class="px-4 py-3 text-left">Validade</th>
                        <th class="px-4 py-3 text-left">Status</th>
                        <th class="px-4 py-3 text-right">Ações</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-50">
                    @forelse($users as $user)
                    <tr class="hover:bg-gray-50">
                        <td class="px-4 py-3">
                            <a href="{{ route('admin.users.show', $user) }}" class="font-medium text-blue-600 hover:underline">
                                {{ $user->username }}
                            </a>
                        </td>
                        <td class="px-4 py-3 text-gray-600">
                            <div>{{ $user->full_name ?: '—' }}</div>
                            @if($user->email)
                                <div class="text-xs text-gray-400">{{ $user->email }}</div>
                            @endif
                        </td>
                        <td class="px-4 py-3">
                            @if($user->plan)
                                <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                                    {{ $user->plan->name }}
                                </span>
                            @else
                                <span class="text-gray-400 text-xs">Sem plano</span>
                            @endif
                        </td>
                        <td class="px-4 py-3 text-gray-600 text-xs">
                            @if($user->expires_at)
                                <span class="{{ $user->expires_at->isPast() ? 'text-red-600 font-medium' : '' }}">
                                    {{ $user->expires_at->format('d/m/Y') }}
                                    @if($user->expires_at->isPast())
                                        <span class="block text-red-500">Expirado</span>
                                    @else
                                        <span class="block text-gray-400">{{ $user->expires_at->diffForHumans() }}</span>
                                    @endif
                                </span>
                            @else
                                <span class="text-gray-400">Ilimitado</span>
                            @endif
                        </td>
                        <td class="px-4 py-3">
                            @php
                            $badges = [
                                'active'    => 'bg-green-100 text-green-800',
                                'suspended' => 'bg-yellow-100 text-yellow-800',
                                'expired'   => 'bg-red-100 text-red-800',
                                'pending'   => 'bg-gray-100 text-gray-600',
                            ];
                            $labels = ['active'=>'Ativo','suspended'=>'Suspenso','expired'=>'Expirado','pending'=>'Pendente'];
                            @endphp
                            <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium {{ $badges[$user->status] ?? 'bg-gray-100' }}">
                                {{ $labels[$user->status] ?? $user->status }}
                            </span>
                        </td>
                        <td class="px-4 py-3 text-right">
                            <div class="flex justify-end gap-1">
                                <a href="{{ route('admin.users.show', $user) }}"
                                    class="inline-flex items-center px-2 py-1 text-xs rounded border hover:bg-gray-50 transition" title="Ver">
                                    <i class="fas fa-eye text-gray-500"></i>
                                </a>
                                <a href="{{ route('admin.users.edit', $user) }}"
                                    class="inline-flex items-center px-2 py-1 text-xs rounded border hover:bg-gray-50 transition" title="Editar">
                                    <i class="fas fa-edit text-blue-500"></i>
                                </a>
                                @if($user->status === 'active')
                                    <form action="{{ route('admin.users.suspend', $user) }}" method="POST" class="inline">
                                        @csrf
                                        <button type="submit" class="inline-flex items-center px-2 py-1 text-xs rounded border hover:bg-gray-50 transition" title="Suspender"
                                            onclick="return confirm('Suspender {{ $user->username }}?')">
                                            <i class="fas fa-ban text-yellow-500"></i>
                                        </button>
                                    </form>
                                @else
                                    <form action="{{ route('admin.users.reactivate', $user) }}" method="POST" class="inline">
                                        @csrf
                                        <button type="submit" class="inline-flex items-center px-2 py-1 text-xs rounded border hover:bg-gray-50 transition" title="Reativar">
                                            <i class="fas fa-check-circle text-green-500"></i>
                                        </button>
                                    </form>
                                @endif
                                <form action="{{ route('admin.users.destroy', $user) }}" method="POST" class="inline">
                                    @csrf @method('DELETE')
                                    <button type="submit" class="inline-flex items-center px-2 py-1 text-xs rounded border hover:bg-red-50 transition" title="Excluir"
                                        onclick="return confirm('Excluir permanentemente {{ $user->username }}?')">
                                        <i class="fas fa-trash text-red-500"></i>
                                    </button>
                                </form>
                            </div>
                        </td>
                    </tr>
                    @empty
                    <tr>
                        <td colspan="6" class="px-4 py-12 text-center text-gray-400">
                            <i class="fas fa-users-slash text-4xl mb-3 block"></i>
                            Nenhum usuário encontrado.
                            <a href="{{ route('admin.users.create') }}" class="text-blue-600 hover:underline ml-1">Criar o primeiro</a>
                        </td>
                    </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        @if($users->hasPages())
        <div class="px-4 py-3 border-t">
            {{ $users->links() }}
        </div>
        @endif
    </div>
</div>
@endsection
