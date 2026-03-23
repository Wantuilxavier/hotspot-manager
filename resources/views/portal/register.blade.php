@extends('layouts.portal')
@section('title', 'Cadastro — Hotspot')
@section('header-title', config('app.name', 'Hotspot'))
@section('header-subtitle', 'Crie sua conta para acessar a internet')

@section('content')
{{-- Erro da autenticação MikroTik --}}
@if($mikrotikParams['error'])
    <div class="bg-red-50 border-b border-red-200 px-6 py-3 text-sm text-red-700 flex items-center">
        <i class="fas fa-exclamation-circle mr-2"></i>
        @if($mikrotikParams['error'] == '1') Usuário ou senha incorretos.
        @elseif($mikrotikParams['error'] == '2') Usuário não possui permissão.
        @elseif($mikrotikParams['error'] == '4') Serviço temporariamente indisponível.
        @else Erro de autenticação (#{{ $mikrotikParams['error'] }}).
        @endif
    </div>
@endif

<div class="p-6">
    @if($errors->any())
        <div class="bg-red-50 border border-red-200 text-red-700 rounded-lg px-4 py-3 mb-5 text-sm">
            <p class="font-semibold mb-1"><i class="fas fa-times-circle mr-1"></i>Por favor, corrija os erros:</p>
            <ul class="list-disc ml-5 space-y-0.5">
                @foreach($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        </div>
    @endif

    <form action="{{ route('portal.register') }}" method="POST" id="registerForm">
        @csrf

        {{-- Campos ocultos do MikroTik --}}
        <input type="hidden" name="mac_address" value="{{ $mikrotikParams['mac'] }}">
        <input type="hidden" name="link_login" value="{{ $mikrotikParams['link_login'] }}">

        {{-- Seleção de Plano --}}
        @if($plans->count() > 1)
        <div class="mb-5">
            <label class="block text-sm font-semibold text-gray-700 mb-2">Escolha seu plano</label>
            <div class="grid grid-cols-1 gap-2" id="planSelector">
                @foreach($plans as $plan)
                <label class="flex items-start gap-3 p-3 border-2 rounded-lg cursor-pointer transition plan-option
                    {{ $plan->is_default ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:border-gray-300' }}"
                    data-plan="{{ $plan->id }}">
                    <input type="radio" name="plan_id" value="{{ $plan->id }}"
                        {{ old('plan_id', $plan->is_default ? $plan->id : '') == $plan->id ? 'checked' : '' }}
                        class="mt-0.5 text-blue-500" required>
                    <div class="flex-1 min-w-0">
                        <div class="flex items-center justify-between">
                            <span class="font-semibold text-gray-800 text-sm">{{ $plan->name }}</span>
                            <span class="text-sm font-bold text-blue-600">{{ $plan->price_formatted }}</span>
                        </div>
                        <div class="text-xs text-gray-500 mt-0.5">
                            <i class="fas fa-arrow-down text-blue-400 mr-1"></i>{{ $plan->download_rate }}
                            <span class="mx-1">·</span>
                            <i class="fas fa-arrow-up text-indigo-400 mr-1"></i>{{ $plan->upload_rate }}
                            @if($plan->duration_days > 0)
                                <span class="mx-1">·</span>
                                <i class="fas fa-clock text-gray-400 mr-1"></i>{{ $plan->duration_days }} dias
                            @endif
                        </div>
                        @if($plan->description)
                            <p class="text-xs text-gray-400 mt-0.5">{{ $plan->description }}</p>
                        @endif
                    </div>
                </label>
                @endforeach
            </div>
            @error('plan_id') <p class="mt-1 text-xs text-red-600">{{ $message }}</p> @enderror
        </div>
        @else
            {{-- Plano único: só envia o ID --}}
            <input type="hidden" name="plan_id" value="{{ $plans->first()?->id }}">
        @endif

        {{-- Credenciais --}}
        <div class="space-y-3 mb-5">
            <h3 class="text-sm font-semibold text-gray-700 border-b pb-2">Seus dados de acesso</h3>

            <div>
                <label class="block text-xs font-medium text-gray-600 mb-1">Nome Completo <span class="text-red-500">*</span></label>
                <input type="text" name="full_name" value="{{ old('full_name') }}"
                    class="w-full border rounded-lg px-3 py-2.5 text-sm focus:ring-2 focus:ring-blue-500 outline-none @error('full_name') border-red-400 @enderror"
                    placeholder="Seu nome completo" required autocomplete="name">
            </div>

            <div>
                <label class="block text-xs font-medium text-gray-600 mb-1">Username <span class="text-red-500">*</span></label>
                <input type="text" name="username" value="{{ old('username') }}"
                    class="w-full border rounded-lg px-3 py-2.5 text-sm focus:ring-2 focus:ring-blue-500 outline-none @error('username') border-red-400 @enderror"
                    placeholder="Ex: joao.silva" required autocomplete="username">
                @error('username') <p class="mt-1 text-xs text-red-600">{{ $message }}</p> @enderror
            </div>

            <div class="grid grid-cols-2 gap-3">
                <div>
                    <label class="block text-xs font-medium text-gray-600 mb-1">Senha <span class="text-red-500">*</span></label>
                    <input type="password" name="password" id="password"
                        class="w-full border rounded-lg px-3 py-2.5 text-sm focus:ring-2 focus:ring-blue-500 outline-none @error('password') border-red-400 @enderror"
                        placeholder="••••••" required minlength="6" autocomplete="new-password">
                </div>
                <div>
                    <label class="block text-xs font-medium text-gray-600 mb-1">Confirmar Senha <span class="text-red-500">*</span></label>
                    <input type="password" name="password_confirmation"
                        class="w-full border rounded-lg px-3 py-2.5 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                        placeholder="••••••" required autocomplete="new-password">
                </div>
            </div>

            <div>
                <label class="block text-xs font-medium text-gray-600 mb-1">E-mail (opcional)</label>
                <input type="email" name="email" value="{{ old('email') }}"
                    class="w-full border rounded-lg px-3 py-2.5 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                    placeholder="seu@email.com" autocomplete="email">
            </div>

            <div>
                <label class="block text-xs font-medium text-gray-600 mb-1">Telefone</label>
                <input type="tel" name="phone" value="{{ old('phone') }}"
                    class="w-full border rounded-lg px-3 py-2.5 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                    placeholder="(11) 99999-9999" autocomplete="tel">
            </div>
        </div>

        {{-- Termos --}}
        <label class="flex items-start gap-3 mb-5 cursor-pointer">
            <input type="checkbox" name="terms" value="1" class="mt-0.5 w-4 h-4 rounded border-gray-300 text-blue-500" required>
            <span class="text-xs text-gray-500">
                Li e aceito os <a href="#" class="text-blue-600 hover:underline">Termos de Uso</a> e a
                <a href="#" class="text-blue-600 hover:underline">Política de Privacidade</a>.
            </span>
        </label>
        @error('terms') <p class="mb-3 text-xs text-red-600">{{ $message }}</p> @enderror

        <button type="submit"
            class="w-full bg-blue-600 hover:bg-blue-700 active:bg-blue-800 text-white font-semibold py-3 rounded-lg transition text-sm">
            <i class="fas fa-user-plus mr-2"></i> Criar Conta e Conectar
        </button>
    </form>
</div>
@endsection

@push('scripts')
<script>
    // Highlight do plano selecionado
    document.querySelectorAll('input[name=plan_id]').forEach(function(radio) {
        radio.addEventListener('change', function() {
            document.querySelectorAll('.plan-option').forEach(function(el) {
                el.classList.remove('border-blue-500', 'bg-blue-50');
                el.classList.add('border-gray-200');
            });
            this.closest('.plan-option').classList.remove('border-gray-200');
            this.closest('.plan-option').classList.add('border-blue-500', 'bg-blue-50');
        });
    });
</script>
@endpush
