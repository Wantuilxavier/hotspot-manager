@extends('layouts.admin')
@section('title', 'Usuário: '.$user->username)
@section('page-title', 'Detalhes do Usuário')

@section('content')
<div class="mt-2 max-w-5xl">
    <!-- Header do usuário -->
    <div class="bg-white rounded-xl border shadow-sm p-6 mb-6">
        <div class="flex items-start justify-between flex-wrap gap-4">
            <div class="flex items-center gap-4">
                <div class="w-16 h-16 rounded-full bg-blue-100 flex items-center justify-center text-2xl font-bold text-blue-600">
                    {{ strtoupper(substr($user->username, 0, 1)) }}
                </div>
                <div>
                    <h2 class="text-xl font-bold text-gray-900">{{ $user->username }}</h2>
                    <p class="text-gray-500 text-sm">{{ $user->full_name ?: 'Sem nome cadastrado' }}</p>
                    @if($user->plan)
                        <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800 mt-1">
                            <i class="fas fa-layer-group mr-1"></i>{{ $user->plan->name }}
                        </span>
                    @endif
                </div>
            </div>

            <!-- Ações -->
            <div class="flex flex-wrap gap-2">
                <a href="{{ route('admin.users.edit', $user) }}"
                    class="inline-flex items-center px-3 py-2 text-sm font-medium rounded-lg border hover:bg-gray-50 transition">
                    <i class="fas fa-edit mr-2 text-blue-500"></i> Editar
                </a>

                @if($user->status === 'active')
                    <form action="{{ route('admin.users.suspend', $user) }}" method="POST">
                        @csrf
                        <button type="submit" onclick="return confirm('Suspender acesso de {{ $user->username }}?')"
                            class="inline-flex items-center px-3 py-2 text-sm font-medium rounded-lg border hover:bg-yellow-50 transition text-yellow-700">
                            <i class="fas fa-ban mr-2"></i> Suspender
                        </button>
                    </form>
                @else
                    <form action="{{ route('admin.users.reactivate', $user) }}" method="POST">
                        @csrf
                        <button type="submit"
                            class="inline-flex items-center px-3 py-2 text-sm font-medium rounded-lg border hover:bg-green-50 transition text-green-700">
                            <i class="fas fa-check-circle mr-2"></i> Reativar
                        </button>
                    </form>
                @endif

                <form action="{{ route('admin.users.disconnect', $user) }}" method="POST">
                    @csrf
                    <button type="submit"
                        class="inline-flex items-center px-3 py-2 text-sm font-medium rounded-lg border hover:bg-orange-50 transition text-orange-700">
                        <i class="fas fa-plug mr-2"></i> Desconectar
                    </button>
                </form>
            </div>
        </div>

        <!-- Detalhes -->
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mt-6 pt-6 border-t text-sm">
            <div>
                <p class="text-xs text-gray-400 uppercase tracking-wide mb-1">Status</p>
                @php $badges = ['active'=>'bg-green-100 text-green-800','suspended'=>'bg-yellow-100 text-yellow-800','expired'=>'bg-red-100 text-red-800']; @endphp
                <span class="inline-flex px-2 py-0.5 rounded text-xs font-medium {{ $badges[$user->status] ?? 'bg-gray-100' }}">
                    {{ ucfirst($user->status) }}
                </span>
            </div>
            <div>
                <p class="text-xs text-gray-400 uppercase tracking-wide mb-1">Validade</p>
                <p class="font-medium {{ $user->expires_at?->isPast() ? 'text-red-600' : 'text-gray-800' }}">
                    {{ $user->expires_at ? $user->expires_at->format('d/m/Y') : 'Ilimitado' }}
                </p>
            </div>
            <div>
                <p class="text-xs text-gray-400 uppercase tracking-wide mb-1">Cadastrado em</p>
                <p class="font-medium text-gray-800">{{ $user->created_at->format('d/m/Y H:i') }}</p>
            </div>
            <div>
                <p class="text-xs text-gray-400 uppercase tracking-wide mb-1">IP de Cadastro</p>
                <p class="font-mono text-gray-800 text-sm">{{ $user->registered_ip ?: '—' }}</p>
            </div>
            @if($user->email)
            <div>
                <p class="text-xs text-gray-400 uppercase tracking-wide mb-1">E-mail</p>
                <p class="text-gray-800">{{ $user->email }}</p>
            </div>
            @endif
            @if($user->phone)
            <div>
                <p class="text-xs text-gray-400 uppercase tracking-wide mb-1">Telefone</p>
                <p class="text-gray-800">{{ $user->phone }}</p>
            </div>
            @endif
            @if($user->mac_address)
            <div>
                <p class="text-xs text-gray-400 uppercase tracking-wide mb-1">MAC Address</p>
                <p class="font-mono text-gray-800 text-sm uppercase">{{ $user->mac_address }}</p>
            </div>
            @endif
        </div>

        @if($user->notes)
        <div class="mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded-lg text-sm text-yellow-800">
            <i class="fas fa-sticky-note mr-2"></i>{{ $user->notes }}
        </div>
        @endif
    </div>

    <!-- Sessões Ativas -->
    @if($activeSessions->isNotEmpty())
    <div class="bg-white rounded-xl border border-green-200 shadow-sm overflow-hidden mb-6">
        <div class="px-5 py-4 border-b border-green-200 bg-green-50">
            <h3 class="font-semibold text-green-800 flex items-center">
                <span class="w-2 h-2 bg-green-400 rounded-full mr-2 animate-pulse"></span>
                Sessão Online ({{ $activeSessions->count() }})
            </h3>
        </div>
        <table class="w-full text-sm">
            <thead class="bg-gray-50 text-xs text-gray-500 uppercase">
                <tr>
                    <th class="px-4 py-2 text-left">IP</th>
                    <th class="px-4 py-2 text-left">NAS</th>
                    <th class="px-4 py-2 text-left">MAC</th>
                    <th class="px-4 py-2 text-left">Início</th>
                    <th class="px-4 py-2 text-right">Download</th>
                    <th class="px-4 py-2 text-right">Upload</th>
                </tr>
            </thead>
            <tbody>
                @foreach($activeSessions as $s)
                <tr>
                    <td class="px-4 py-2 font-mono text-xs">{{ $s->framedipaddress }}</td>
                    <td class="px-4 py-2 text-xs">{{ $s->nasipaddress }}</td>
                    <td class="px-4 py-2 font-mono text-xs uppercase">{{ $s->callingstationid }}</td>
                    <td class="px-4 py-2 text-xs">{{ \Carbon\Carbon::parse($s->acctstarttime)->format('d/m H:i') }}</td>
                    <td class="px-4 py-2 text-right text-xs">{{ $s->download_formatted }}</td>
                    <td class="px-4 py-2 text-right text-xs">{{ $s->upload_formatted }}</td>
                </tr>
                @endforeach
            </tbody>
        </table>
    </div>
    @endif

    <!-- Histórico de Sessões -->
    <div class="bg-white rounded-xl border shadow-sm overflow-hidden">
        <div class="px-5 py-4 border-b">
            <h3 class="font-semibold text-gray-800">Histórico de Sessões (últimas 20)</h3>
        </div>
        @if($sessions->isEmpty())
            <div class="px-5 py-8 text-center text-gray-400 text-sm">Nenhuma sessão registrada ainda.</div>
        @else
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead class="bg-gray-50 text-xs text-gray-500 uppercase">
                    <tr>
                        <th class="px-4 py-2 text-left">Início</th>
                        <th class="px-4 py-2 text-left">Fim</th>
                        <th class="px-4 py-2 text-left">Duração</th>
                        <th class="px-4 py-2 text-left">IP</th>
                        <th class="px-4 py-2 text-right">↓ Down</th>
                        <th class="px-4 py-2 text-right">↑ Up</th>
                        <th class="px-4 py-2 text-left">Término</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-50">
                    @foreach($sessions as $s)
                    <tr class="hover:bg-gray-50 {{ is_null($s->acctstoptime) ? 'bg-green-50' : '' }}">
                        <td class="px-4 py-2 text-xs">{{ \Carbon\Carbon::parse($s->acctstarttime)->format('d/m/Y H:i') }}</td>
                        <td class="px-4 py-2 text-xs text-gray-500">
                            {{ $s->acctstoptime ? \Carbon\Carbon::parse($s->acctstoptime)->format('d/m/Y H:i') : '—' }}
                        </td>
                        <td class="px-4 py-2 text-xs font-mono">{{ $s->session_duration }}</td>
                        <td class="px-4 py-2 text-xs font-mono">{{ $s->framedipaddress }}</td>
                        <td class="px-4 py-2 text-xs text-right">{{ $s->download_formatted }}</td>
                        <td class="px-4 py-2 text-xs text-right">{{ $s->upload_formatted }}</td>
                        <td class="px-4 py-2 text-xs text-gray-500">{{ $s->acctterminatecause ?: (is_null($s->acctstoptime) ? '<online>' : '—') }}</td>
                    </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
        @endif
    </div>
</div>
@endsection
