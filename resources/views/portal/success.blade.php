@extends('layouts.portal')
@section('title', 'Conta Criada!')
@section('header-title', 'Tudo pronto!')
@section('header-subtitle', 'Sua conta foi criada com sucesso')

@section('content')
<div class="p-6">
    <div class="text-center mb-6">
        <div class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <i class="fas fa-check text-green-500 text-2xl"></i>
        </div>
        <h2 class="text-lg font-bold text-gray-800">Conta criada!</h2>
        <p class="text-gray-500 text-sm">Use as credenciais abaixo para se conectar</p>
    </div>

    <!-- Credenciais -->
    <div class="bg-gray-50 border rounded-xl p-5 mb-5">
        <div class="grid grid-cols-2 gap-4 text-sm">
            <div>
                <p class="text-xs text-gray-400 uppercase tracking-wide mb-1">Username</p>
                <p class="font-bold text-gray-800 text-lg font-mono">{{ $user->username }}</p>
            </div>
            <div>
                <p class="text-xs text-gray-400 uppercase tracking-wide mb-1">Plano</p>
                <p class="font-semibold text-blue-600">{{ $user->plan?->name ?? 'Padrão' }}</p>
            </div>
            @if($user->plan)
            <div>
                <p class="text-xs text-gray-400 uppercase tracking-wide mb-1">Velocidade</p>
                <p class="font-semibold text-gray-700">
                    <i class="fas fa-arrow-down text-blue-400 mr-1"></i>{{ $user->plan->download_rate }}
                    /
                    <i class="fas fa-arrow-up text-indigo-400 mr-1"></i>{{ $user->plan->upload_rate }}
                </p>
            </div>
            @endif
            @if($user->expires_at)
            <div>
                <p class="text-xs text-gray-400 uppercase tracking-wide mb-1">Válido até</p>
                <p class="font-semibold text-gray-700">{{ $user->expires_at->format('d/m/Y') }}</p>
            </div>
            @endif
        </div>
    </div>

    <!-- Botão de login no MikroTik -->
    @if($linkLogin)
    <a href="{{ $linkLogin }}" class="block w-full bg-blue-600 hover:bg-blue-700 text-white text-center font-semibold py-3 rounded-lg transition mb-3">
        <i class="fas fa-wifi mr-2"></i> Conectar Agora
    </a>
    <p class="text-xs text-center text-gray-400">Você será redirecionado para a página de login do Hotspot</p>
    @else
    <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-sm text-blue-700">
        <p class="font-semibold mb-1"><i class="fas fa-info-circle mr-1"></i>Como conectar:</p>
        <ol class="list-decimal ml-5 space-y-1 text-xs">
            <li>Abra o navegador e tente acessar qualquer site</li>
            <li>Você será redirecionado para a página de login</li>
            <li>Use o username <strong>{{ $user->username }}</strong> e a senha que você criou</li>
        </ol>
    </div>
    @endif
</div>
@endsection
