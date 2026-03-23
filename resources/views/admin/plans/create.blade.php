@extends('layouts.admin')
@section('title', 'Novo Plano')
@section('page-title', 'Criar Novo Plano')

@section('content')
<div class="mt-2 max-w-2xl">
    <form action="{{ route('admin.plans.store') }}" method="POST" class="space-y-6">
        @csrf

        <div class="bg-white rounded-xl border shadow-sm p-6">
            <h3 class="font-semibold text-gray-800 mb-4 flex items-center">
                <i class="fas fa-layer-group mr-2 text-blue-500"></i> Informações do Plano
            </h3>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div class="sm:col-span-2">
                    <label class="block text-sm font-medium text-gray-700 mb-1">Nome do Plano <span class="text-red-500">*</span></label>
                    <input type="text" name="name" value="{{ old('name') }}"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none @error('name') border-red-400 @enderror"
                        placeholder="Ex: Premium 20MB" required>
                    @error('name') <p class="mt-1 text-xs text-red-600">{{ $message }}</p> @enderror
                </div>

                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Nome do Grupo RADIUS <span class="text-red-500">*</span></label>
                    <input type="text" name="group_name" value="{{ old('group_name') }}" id="group_name"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none font-mono @error('group_name') border-red-400 @enderror"
                        placeholder="premium_20mb" required>
                    @error('group_name') <p class="mt-1 text-xs text-red-600">{{ $message }}</p> @enderror
                    <p class="mt-1 text-xs text-gray-400">Apenas: a-z, 0-9, _. Usado na tabela radusergroup.</p>
                </div>

                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Preço (R$) <span class="text-red-500">*</span></label>
                    <input type="number" name="price" value="{{ old('price', 0) }}" step="0.01" min="0"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" required>
                </div>

                <div class="sm:col-span-2">
                    <label class="block text-sm font-medium text-gray-700 mb-1">Descrição</label>
                    <textarea name="description" rows="2"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none resize-none"
                        placeholder="Descrição exibida no portal de cadastro...">{{ old('description') }}</textarea>
                </div>
            </div>
        </div>

        <div class="bg-white rounded-xl border shadow-sm p-6">
            <h3 class="font-semibold text-gray-800 mb-4 flex items-center">
                <i class="fas fa-tachometer-alt mr-2 text-purple-500"></i> Controle de Banda (RADIUS)
            </h3>
            <p class="text-xs text-gray-500 mb-4 bg-gray-50 rounded-lg p-3">
                Esses valores serão enviados como atributo <code class="bg-gray-100 px-1 rounded">Mikrotik-Rate-Limit = "upload/download"</code>
                no radgroupreply, criando queues dinâmicas no MikroTik.
            </p>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Download <span class="text-red-500">*</span></label>
                    <input type="text" name="download_rate" value="{{ old('download_rate') }}" id="download_rate"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none @error('download_rate') border-red-400 @enderror"
                        placeholder="10M" required>
                    @error('download_rate') <p class="mt-1 text-xs text-red-600">{{ $message }}</p> @enderror
                    <p class="mt-1 text-xs text-gray-400">Ex: 512K, 5M, 50M, 1G</p>
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Upload <span class="text-red-500">*</span></label>
                    <input type="text" name="upload_rate" value="{{ old('upload_rate') }}" id="upload_rate"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none @error('upload_rate') border-red-400 @enderror"
                        placeholder="5M" required>
                    @error('upload_rate') <p class="mt-1 text-xs text-red-600">{{ $message }}</p> @enderror
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Prévia</label>
                    <div id="rate_preview" class="border rounded-lg px-3 py-2 text-sm bg-gray-900 text-green-400 font-mono h-[38px] flex items-center">
                        upload/download
                    </div>
                </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 mt-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Duração (dias)</label>
                    <input type="number" name="duration_days" value="{{ old('duration_days', 30) }}" min="0"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none">
                    <p class="mt-1 text-xs text-gray-400">0 = acesso ilimitado (sem Expiration no RADIUS)</p>
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Limite de Dados (MB)</label>
                    <input type="number" name="data_limit_mb" value="{{ old('data_limit_mb', 0) }}" min="0"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none">
                    <p class="mt-1 text-xs text-gray-400">0 = ilimitado</p>
                </div>
            </div>
        </div>

        <div class="bg-white rounded-xl border shadow-sm p-6">
            <h3 class="font-semibold text-gray-800 mb-4">Configurações</h3>
            <div class="space-y-3">
                <label class="flex items-center gap-3 cursor-pointer">
                    <input type="checkbox" name="is_public" value="1" {{ old('is_public', 1) ? 'checked' : '' }}
                        class="rounded border-gray-300 text-blue-500 w-4 h-4">
                    <div>
                        <span class="text-sm font-medium text-gray-700">Exibir no portal de auto-cadastro</span>
                        <p class="text-xs text-gray-400">Usuários poderão selecionar este plano ao se cadastrar</p>
                    </div>
                </label>
                <label class="flex items-center gap-3 cursor-pointer">
                    <input type="checkbox" name="is_default" value="1" {{ old('is_default') ? 'checked' : '' }}
                        class="rounded border-gray-300 text-blue-500 w-4 h-4">
                    <div>
                        <span class="text-sm font-medium text-gray-700">Plano padrão</span>
                        <p class="text-xs text-gray-400">Pré-selecionado no portal de cadastro</p>
                    </div>
                </label>
                <label class="flex items-center gap-3 cursor-pointer">
                    <input type="checkbox" name="active" value="1" {{ old('active', 1) ? 'checked' : '' }}
                        class="rounded border-gray-300 text-blue-500 w-4 h-4">
                    <div>
                        <span class="text-sm font-medium text-gray-700">Plano ativo</span>
                        <p class="text-xs text-gray-400">Planos inativos não aparecem no portal e não podem receber novos usuários</p>
                    </div>
                </label>
            </div>
        </div>

        <div class="flex gap-3">
            <button type="submit"
                class="bg-blue-600 hover:bg-blue-700 text-white font-semibold px-6 py-2.5 rounded-lg text-sm transition">
                <i class="fas fa-save mr-2"></i> Criar Plano
            </button>
            <a href="{{ route('admin.plans.index') }}"
                class="bg-gray-100 hover:bg-gray-200 text-gray-700 font-semibold px-6 py-2.5 rounded-lg text-sm transition">
                Cancelar
            </a>
        </div>
    </form>
</div>
@endsection

@push('scripts')
<script>
    // Auto-gera group_name a partir do name
    document.querySelector('[name=name]').addEventListener('input', function () {
        const gn = document.getElementById('group_name');
        if (!gn._edited) {
            gn.value = this.value.toLowerCase()
                .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
                .replace(/[^a-z0-9\s_]/g, '')
                .replace(/\s+/g, '_');
        }
    });
    document.getElementById('group_name').addEventListener('input', function () {
        this._edited = true;
    });

    // Prévia do Rate-Limit
    function updatePreview() {
        const ul = document.getElementById('upload_rate').value || 'upload';
        const dl = document.getElementById('download_rate').value || 'download';
        document.getElementById('rate_preview').textContent = `${ul}/${dl}`;
    }
    document.getElementById('upload_rate').addEventListener('input', updatePreview);
    document.getElementById('download_rate').addEventListener('input', updatePreview);
</script>
@endpush
