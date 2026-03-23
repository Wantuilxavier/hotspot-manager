@extends('layouts.admin')
@section('title', 'Dashboard')
@section('page-title', 'Dashboard')

@section('content')
<!-- Stats Cards -->
<div class="grid grid-cols-2 lg:grid-cols-5 gap-4 mt-2 mb-6">
    @php
    $cards = [
        ['icon'=>'fa-users',         'label'=>'Total de Usuários', 'value'=>$stats['total_users'],   'color'=>'blue'],
        ['icon'=>'fa-user-check',    'label'=>'Usuários Ativos',   'value'=>$stats['active_users'],  'color'=>'green'],
        ['icon'=>'fa-signal',        'label'=>'Online Agora',      'value'=>$stats['online_now'],    'color'=>'yellow'],
        ['icon'=>'fa-layer-group',   'label'=>'Planos Ativos',     'value'=>$stats['total_plans'],   'color'=>'purple'],
        ['icon'=>'fa-user-clock',    'label'=>'Expirados',         'value'=>$stats['expired_users'], 'color'=>'red'],
    ];
    $palette = [
        'blue'   => 'bg-blue-50 border-blue-200 text-blue-700',
        'green'  => 'bg-green-50 border-green-200 text-green-700',
        'yellow' => 'bg-yellow-50 border-yellow-200 text-yellow-700',
        'purple' => 'bg-purple-50 border-purple-200 text-purple-700',
        'red'    => 'bg-red-50 border-red-200 text-red-700',
    ];
    @endphp

    @foreach($cards as $card)
    <div class="bg-white rounded-xl border shadow-sm p-4 flex items-center space-x-3">
        <div class="w-10 h-10 rounded-full {{ $palette[$card['color']] }} flex items-center justify-center flex-shrink-0">
            <i class="fas {{ $card['icon'] }}"></i>
        </div>
        <div>
            <p class="text-xs text-gray-500">{{ $card['label'] }}</p>
            <p class="text-2xl font-bold text-gray-800">{{ $card['value'] }}</p>
        </div>
    </div>
    @endforeach
</div>

<div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <!-- Usuários Online -->
    <div class="bg-white rounded-xl border shadow-sm overflow-hidden">
        <div class="flex items-center justify-between px-5 py-4 border-b">
            <h2 class="font-semibold text-gray-800 flex items-center">
                <span class="w-2 h-2 bg-green-400 rounded-full mr-2 animate-pulse"></span>
                Sessões Ativas ({{ $onlineUsers->count() }})
            </h2>
            <a href="{{ route('admin.users.index') }}?status=active" class="text-xs text-blue-600 hover:underline">Ver todos</a>
        </div>
        <div class="overflow-x-auto">
            @if($onlineUsers->isEmpty())
                <div class="px-5 py-8 text-center text-gray-400">
                    <i class="fas fa-plug text-3xl mb-2"></i>
                    <p class="text-sm">Nenhum usuário online</p>
                </div>
            @else
                <table class="w-full text-sm">
                    <thead class="bg-gray-50 text-xs text-gray-500 uppercase">
                        <tr>
                            <th class="px-4 py-2 text-left">Usuário</th>
                            <th class="px-4 py-2 text-left">IP</th>
                            <th class="px-4 py-2 text-left">NAS</th>
                            <th class="px-4 py-2 text-left">Início</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-50">
                        @foreach($onlineUsers->take(10) as $session)
                        <tr class="hover:bg-gray-50">
                            <td class="px-4 py-2 font-medium text-gray-800">{{ $session->username }}</td>
                            <td class="px-4 py-2 text-gray-500 font-mono text-xs">{{ $session->framedipaddress }}</td>
                            <td class="px-4 py-2 text-gray-500 text-xs">{{ $session->nasipaddress }}</td>
                            <td class="px-4 py-2 text-gray-500 text-xs">{{ \Carbon\Carbon::parse($session->acctstarttime)->diffForHumans() }}</td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
            @endif
        </div>
    </div>

    <!-- Últimas Autenticações -->
    <div class="bg-white rounded-xl border shadow-sm overflow-hidden">
        <div class="flex items-center justify-between px-5 py-4 border-b">
            <h2 class="font-semibold text-gray-800">
                <i class="fas fa-history text-gray-400 mr-2"></i>Últimas Autenticações
            </h2>
        </div>
        <div class="overflow-x-auto">
            @if($recentAuth->isEmpty())
                <div class="px-5 py-8 text-center text-gray-400 text-sm">Nenhum registro ainda</div>
            @else
                <table class="w-full text-sm">
                    <thead class="bg-gray-50 text-xs text-gray-500 uppercase">
                        <tr>
                            <th class="px-4 py-2 text-left">Usuário</th>
                            <th class="px-4 py-2 text-left">Resultado</th>
                            <th class="px-4 py-2 text-left">Data</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-50">
                        @foreach($recentAuth as $auth)
                        <tr class="hover:bg-gray-50">
                            <td class="px-4 py-2 font-medium text-gray-800">{{ $auth->username }}</td>
                            <td class="px-4 py-2">
                                @if(str_contains($auth->reply, 'Accept'))
                                    <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
                                        <i class="fas fa-check mr-1"></i>Aceito
                                    </span>
                                @else
                                    <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800">
                                        <i class="fas fa-times mr-1"></i>Rejeitado
                                    </span>
                                @endif
                            </td>
                            <td class="px-4 py-2 text-gray-500 text-xs">{{ $auth->authdate }}</td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
            @endif
        </div>
    </div>

    <!-- Top Consumidores -->
    <div class="bg-white rounded-xl border shadow-sm overflow-hidden lg:col-span-2">
        <div class="px-5 py-4 border-b">
            <h2 class="font-semibold text-gray-800">
                <i class="fas fa-chart-bar text-gray-400 mr-2"></i>Top Consumidores (últimas 24h)
            </h2>
        </div>
        @if($topUsers->isEmpty())
            <div class="px-5 py-8 text-center text-gray-400 text-sm">Nenhum dado disponível</div>
        @else
            <div class="overflow-x-auto">
                <table class="w-full text-sm">
                    <thead class="bg-gray-50 text-xs text-gray-500 uppercase">
                        <tr>
                            <th class="px-4 py-2 text-left">Usuário</th>
                            <th class="px-4 py-2 text-right">Download</th>
                            <th class="px-4 py-2 text-right">Upload</th>
                            <th class="px-4 py-2 text-right">Sessões</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-50">
                        @foreach($topUsers as $u)
                        @php
                            $dl = $u->download;
                            $ul = $u->upload;
                            $fmt = fn($b) => $b >= 1073741824 ? round($b/1073741824,2).' GB' : ($b >= 1048576 ? round($b/1048576,2).' MB' : round($b/1024,2).' KB');
                        @endphp
                        <tr class="hover:bg-gray-50">
                            <td class="px-4 py-2 font-medium text-gray-800">
                                <a href="{{ route('admin.users.index') }}?search={{ $u->username }}" class="hover:text-blue-600">
                                    {{ $u->username }}
                                </a>
                            </td>
                            <td class="px-4 py-2 text-right text-gray-600">{{ $fmt($dl) }}</td>
                            <td class="px-4 py-2 text-right text-gray-600">{{ $fmt($ul) }}</td>
                            <td class="px-4 py-2 text-right text-gray-600">{{ $u->sessions }}</td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        @endif
    </div>
</div>
@endsection
