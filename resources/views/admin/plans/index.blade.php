@extends('layouts.admin')
@section('title', 'Planos')
@section('page-title', 'Gerenciar Planos')

@section('content')
<div class="mt-2">
    <div class="flex justify-between items-center mb-5">
        <p class="text-sm text-gray-500">Cada plano cria um grupo no RADIUS com o atributo <code class="bg-gray-100 px-1 py-0.5 rounded text-xs">Mikrotik-Rate-Limit</code>.</p>
        <a href="{{ route('admin.plans.create') }}"
            class="inline-flex items-center bg-blue-600 hover:bg-blue-700 text-white rounded-lg px-4 py-2 text-sm font-medium transition">
            <i class="fas fa-plus mr-2"></i> Novo Plano
        </a>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        @forelse($plans as $plan)
        <div class="bg-white rounded-xl border shadow-sm overflow-hidden hover:shadow-md transition {{ !$plan->active ? 'opacity-60' : '' }}">
            <div class="p-5">
                <div class="flex items-start justify-between mb-3">
                    <div>
                        <h3 class="font-bold text-gray-800 text-lg">{{ $plan->name }}</h3>
                        <p class="text-xs text-gray-400 font-mono">grupo: {{ $plan->group_name }}</p>
                    </div>
                    <div class="flex items-center gap-1">
                        @if($plan->is_default)
                            <span class="inline-flex px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-700">Padrão</span>
                        @endif
                        @if(!$plan->active)
                            <span class="inline-flex px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-500">Inativo</span>
                        @endif
                    </div>
                </div>

                @if($plan->description)
                    <p class="text-sm text-gray-500 mb-4">{{ $plan->description }}</p>
                @endif

                <!-- Velocidade -->
                <div class="flex items-center justify-center bg-gradient-to-r from-blue-50 to-indigo-50 rounded-lg p-4 mb-4">
                    <div class="text-center">
                        <div class="text-2xl font-bold text-blue-700">{{ $plan->download_rate }}</div>
                        <div class="text-xs text-gray-400 flex items-center justify-center gap-1">
                            <i class="fas fa-arrow-down text-blue-400"></i> Download
                        </div>
                    </div>
                    <div class="mx-4 text-gray-300 text-xl">/</div>
                    <div class="text-center">
                        <div class="text-2xl font-bold text-indigo-700">{{ $plan->upload_rate }}</div>
                        <div class="text-xs text-gray-400 flex items-center justify-center gap-1">
                            <i class="fas fa-arrow-up text-indigo-400"></i> Upload
                        </div>
                    </div>
                </div>

                <!-- Detalhes -->
                <div class="grid grid-cols-3 gap-2 text-center text-sm mb-4">
                    <div class="bg-gray-50 rounded-lg p-2">
                        <p class="text-gray-400 text-xs">Duração</p>
                        <p class="font-semibold text-gray-700">{{ $plan->duration_days > 0 ? $plan->duration_days.'d' : '∞' }}</p>
                    </div>
                    <div class="bg-gray-50 rounded-lg p-2">
                        <p class="text-gray-400 text-xs">Usuários</p>
                        <p class="font-semibold text-gray-700">{{ $plan->users_count }}</p>
                    </div>
                    <div class="bg-gray-50 rounded-lg p-2">
                        <p class="text-gray-400 text-xs">Ativos</p>
                        <p class="font-semibold text-green-600">{{ $plan->active_count }}</p>
                    </div>
                </div>

                <div class="text-center mb-4">
                    <span class="text-2xl font-bold text-gray-800">{{ $plan->price_formatted }}</span>
                    <span class="text-xs text-gray-400">/mês</span>
                </div>

                <!-- Rate-Limit RADIUS -->
                <div class="bg-gray-900 rounded-lg px-3 py-2 text-xs font-mono text-green-400 mb-4">
                    Mikrotik-Rate-Limit = "{{ $plan->upload_rate }}/{{ $plan->download_rate }}"
                </div>
            </div>

            <div class="border-t px-4 py-3 bg-gray-50 flex items-center justify-between">
                <div class="flex gap-1">
                    <a href="{{ route('admin.plans.edit', $plan) }}"
                        class="inline-flex items-center px-2.5 py-1.5 text-xs rounded border bg-white hover:bg-gray-50 transition">
                        <i class="fas fa-edit mr-1 text-blue-500"></i> Editar
                    </a>

                    <form action="{{ route('admin.plans.toggle', $plan) }}" method="POST">
                        @csrf
                        <button type="submit"
                            class="inline-flex items-center px-2.5 py-1.5 text-xs rounded border bg-white hover:bg-gray-50 transition">
                            @if($plan->active)
                                <i class="fas fa-eye-slash mr-1 text-yellow-500"></i> Desativar
                            @else
                                <i class="fas fa-eye mr-1 text-green-500"></i> Ativar
                            @endif
                        </button>
                    </form>
                </div>

                <form action="{{ route('admin.plans.destroy', $plan) }}" method="POST">
                    @csrf @method('DELETE')
                    <button type="submit" onclick="return confirm('Excluir plano {{ $plan->name }}?')"
                        class="inline-flex items-center px-2.5 py-1.5 text-xs rounded border bg-white hover:bg-red-50 transition text-red-500">
                        <i class="fas fa-trash"></i>
                    </button>
                </form>
            </div>
        </div>
        @empty
        <div class="col-span-3 py-12 text-center text-gray-400">
            <i class="fas fa-layer-group text-4xl mb-3 block"></i>
            Nenhum plano cadastrado.
            <a href="{{ route('admin.plans.create') }}" class="text-blue-600 hover:underline ml-1">Criar o primeiro</a>
        </div>
        @endforelse
    </div>
</div>
@endsection
