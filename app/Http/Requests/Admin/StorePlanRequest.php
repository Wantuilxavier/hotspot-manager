<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePlanRequest extends FormRequest
{
    public function authorize(): bool { return true; }

    public function rules(): array
    {
        $planId = $this->route('plan')?->id;

        return [
            'name'          => ['required', 'string', 'max:100'],
            'group_name'    => ['required', 'string', 'max:64', 'regex:/^[a-z0-9_]+$/',
                                Rule::unique('plans', 'group_name')->ignore($planId)],
            'description'   => ['nullable', 'string', 'max:500'],
            'download_rate' => ['required', 'string', 'regex:/^\d+[KMG]$/'],
            'upload_rate'   => ['required', 'string', 'regex:/^\d+[KMG]$/'],
            'duration_days' => ['required', 'integer', 'min:0'],
            'price'         => ['required', 'numeric', 'min:0'],
            'data_limit_mb' => ['nullable', 'integer', 'min:0'],
            'is_default'    => ['nullable', 'boolean'],
            'is_public'     => ['nullable', 'boolean'],
            'active'        => ['nullable', 'boolean'],
        ];
    }

    public function messages(): array
    {
        return [
            'group_name.regex'    => 'O nome do grupo deve conter apenas letras minúsculas, números e _',
            'download_rate.regex' => 'Formato inválido. Ex: 10M, 512K, 1G',
            'upload_rate.regex'   => 'Formato inválido. Ex: 5M, 256K, 1G',
        ];
    }
}
