@extends('layouts.admin')
@section('title', 'Editar Plano')
@section('page-title', 'Editar Plano: '.$plan->name)

@section('content')
<div class="mt-2 max-w-2xl">
    <form action="{{ route('admin.plans.update', $plan) }}" method="POST" class="space-y-6">
        @csrf @method('PUT')

        <div class="bg-white rounded-xl border shadow-sm p-6">
            <h3 class="font-semibold text-gray-800 mb-4">Informações do Plano</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div class="sm:col-span-2">
                    <label class="block text-sm font-medium text-gray-700 mb-1">Nome</label>
                    <input type="text" name="name" value="{{ old('name', $plan->name) }}"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" required>
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Grupo RADIUS</label>
                    <input type="text" name="group_name" value="{{ old('group_name', $plan->group_name) }}"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none font-mono" required>
                    <p class="mt-1 text-xs text-orange-500"><i class="fas fa-exclamation-triangle mr-1"></i>Alterar o grupo_name desvincula usuários existentes</p>
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Preço (R$)</label>
                    <input type="number" name="price" value="{{ old('price', $plan->price) }}" step="0.01" min="0"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none">
                </div>
                <div class="sm:col-span-2">
                    <label class="block text-sm font-medium text-gray-700 mb-1">Descrição</label>
                    <textarea name="description" rows="2"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none resize-none">{{ old('description', $plan->description) }}</textarea>
                </div>
            </div>
        </div>

        <div class="bg-white rounded-xl border shadow-sm p-6">
            <h3 class="font-semibold text-gray-800 mb-4">Controle de Banda</h3>
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Download</label>
                    <input type="text" name="download_rate" value="{{ old('download_rate', $plan->download_rate) }}" id="download_rate"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" required>
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Upload</label>
                    <input type="text" name="upload_rate" value="{{ old('upload_rate', $plan->upload_rate) }}" id="upload_rate"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none" required>
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Rate-Limit Atual</label>
                    <div id="rate_preview" class="border rounded-lg px-3 py-2 text-sm bg-gray-900 text-green-400 font-mono h-[38px] flex items-center">
                        {{ $plan->upload_rate }}/{{ $plan->download_rate }}
                    </div>
                </div>
            </div>
            <div class="grid grid-cols-2 gap-4 mt-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Duração (dias)</label>
                    <input type="number" name="duration_days" value="{{ old('duration_days', $plan->duration_days) }}" min="0"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none">
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Limite de Dados (MB)</label>
                    <input type="number" name="data_limit_mb" value="{{ old('data_limit_mb', $plan->data_limit_mb) }}" min="0"
                        class="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none">
                </div>
            </div>
        </div>

        <div class="bg-white rounded-xl border shadow-sm p-6">
            <h3 class="font-semibold text-gray-800 mb-4">Configurações</h3>
            <div class="space-y-3">
                <label class="flex items-center gap-3 cursor-pointer">
                    <input type="checkbox" name="is_public" value="1" {{ old('is_public', $plan->is_public) ? 'checked' : '' }} class="rounded border-gray-300 text-blue-500 w-4 h-4">
                    <span class="text-sm text-gray-700">Exibir no portal de auto-cadastro</span>
                </label>
                <label class="flex items-center gap-3 cursor-pointer">
                    <input type="checkbox" name="is_default" value="1" {{ old('is_default', $plan->is_default) ? 'checked' : '' }} class="rounded border-gray-300 text-blue-500 w-4 h-4">
                    <span class="text-sm text-gray-700">Plano padrão</span>
                </label>
                <label class="flex items-center gap-3 cursor-pointer">
                    <input type="checkbox" name="active" value="1" {{ old('active', $plan->active) ? 'checked' : '' }} class="rounded border-gray-300 text-blue-500 w-4 h-4">
                    <span class="text-sm text-gray-700">Ativo</span>
                </label>
            </div>
        </div>

        <div class="flex gap-3">
            <button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white font-semibold px-6 py-2.5 rounded-lg text-sm transition">
                <i class="fas fa-save mr-2"></i> Salvar e Sincronizar com RADIUS
            </button>
            <a href="{{ route('admin.plans.index') }}" class="bg-gray-100 hover:bg-gray-200 text-gray-700 font-semibold px-6 py-2.5 rounded-lg text-sm transition">
                Cancelar
            </a>
        </div>
    </form>
</div>
@endsection

@push('scripts')
<script>
    function updatePreview() {
        const ul = document.getElementById('upload_rate').value || 'upload';
        const dl = document.getElementById('download_rate').value || 'download';
        document.getElementById('rate_preview').textContent = `${ul}/${dl}`;
    }
    document.getElementById('upload_rate').addEventListener('input', updatePreview);
    document.getElementById('download_rate').addEventListener('input', updatePreview);
</script>
@endpush
