@extends('layouts.admin')
@section('title', 'Novo Usuário')
@section('page-title', 'Criar Novo Usuário')

@section('content')
<div class="mt-2 max-w-2xl">
    <form action="{{ route('admin.users.store') }}" method="POST" class="space-y-6">
        @csrf

        <div class="bg-white rounded-xl border shadow-sm p-6">
            <h3 class="font-semibold text-gray-800 mb-4 flex items-center">
                <i class="fas fa-user-shield mr-2 text-blue-500"></i> Credenciais RADIUS
            </h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Username <span class="text-red-500">*</span></label>
                    <input type="text" name="username" value="{{ old('username') }}"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none @error('username') border-red-400 @enderror"
                        placeholder="joao.silva" required>
                    @error('username') <p class="mt-1 text-xs text-red-600">{{ $message }}</p> @enderror
                    <p class="mt-1 text-xs text-gray-400">Letras, números e: . _ @ -</p>
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Senha <span class="text-red-500">*</span></label>
                    <input type="text" name="password" value="{{ old('password') }}"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none @error('password') border-red-400 @enderror"
                        placeholder="Mínimo 6 caracteres" required>
                    @error('password') <p class="mt-1 text-xs text-red-600">{{ $message }}</p> @enderror
                    <p class="mt-1 text-xs text-gray-400">Será armazenada como Cleartext-Password no RADIUS</p>
                </div>
            </div>

            <div class="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Plano <span class="text-red-500">*</span></label>
                    <select name="plan_id"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none @error('plan_id') border-red-400 @enderror" required>
                        <option value="">Selecione um plano...</option>
                        @foreach($plans as $plan)
                            <option value="{{ $plan->id }}" {{ old('plan_id') == $plan->id ? 'selected' : '' }}>
                                {{ $plan->name }} — {{ $plan->download_rate }} ↓ / {{ $plan->upload_rate }} ↑
                                @if($plan->duration_days > 0) ({{ $plan->duration_days }}d) @else (ilimitado) @endif
                            </option>
                        @endforeach
                    </select>
                    @error('plan_id') <p class="mt-1 text-xs text-red-600">{{ $message }}</p> @enderror
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Sessões simultâneas</label>
                    <input type="number" name="simultaneous_use" value="{{ old('simultaneous_use', 1) }}"
                        min="1" max="10"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none">
                    <p class="mt-1 text-xs text-gray-400">Máximo de dispositivos conectados ao mesmo tempo</p>
                </div>
            </div>
        </div>

        <div class="bg-white rounded-xl border shadow-sm p-6">
            <h3 class="font-semibold text-gray-800 mb-4 flex items-center">
                <i class="fas fa-id-card mr-2 text-green-500"></i> Dados do Cliente (opcional)
            </h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div class="sm:col-span-2">
                    <label class="block text-sm font-medium text-gray-700 mb-1">Nome Completo</label>
                    <input type="text" name="full_name" value="{{ old('full_name') }}"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                        placeholder="João da Silva">
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">E-mail</label>
                    <input type="email" name="email" value="{{ old('email') }}"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                        placeholder="joao@email.com">
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Telefone</label>
                    <input type="text" name="phone" value="{{ old('phone') }}"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                        placeholder="(11) 99999-9999">
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">CPF/CNPJ</label>
                    <input type="text" name="document" value="{{ old('document') }}"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                        placeholder="000.000.000-00">
                </div>
                <div class="sm:col-span-2">
                    <label class="block text-sm font-medium text-gray-700 mb-1">Observações</label>
                    <textarea name="notes" rows="2"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none resize-none"
                        placeholder="Notas internas...">{{ old('notes') }}</textarea>
                </div>
            </div>
        </div>

        <div class="flex gap-3">
            <button type="submit"
                class="bg-blue-600 hover:bg-blue-700 text-white font-semibold px-6 py-2.5 rounded-lg text-sm transition">
                <i class="fas fa-save mr-2"></i> Criar Usuário
            </button>
            <a href="{{ route('admin.users.index') }}"
                class="bg-gray-100 hover:bg-gray-200 text-gray-700 font-semibold px-6 py-2.5 rounded-lg text-sm transition">
                Cancelar
            </a>
        </div>
    </form>
</div>
@endsection
