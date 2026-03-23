<?php

namespace App\Http\Requests\Portal;

use Illuminate\Foundation\Http\FormRequest;

class SelfRegisterRequest extends FormRequest
{
    public function authorize(): bool { return true; }

    public function rules(): array
    {
        $phoneRequired = config('app.portal_require_phone', false) ? 'required' : 'nullable';

        return [
            'username'    => ['required', 'string', 'min:3', 'max:64', 'unique:hotspot_users,username', 'regex:/^[a-zA-Z0-9._@-]+$/'],
            'password'    => ['required', 'string', 'min:6', 'max:64', 'confirmed'],
            'plan_id'     => ['required', 'exists:plans,id'],
            'full_name'   => ['required', 'string', 'max:150'],
            'email'       => ['nullable', 'email', 'max:150'],
            'phone'       => [$phoneRequired, 'string', 'max:20'],
            'mac_address' => ['nullable', 'string', 'max:17'],
            'link_login'  => ['nullable', 'string'],
            'terms'       => ['required', 'accepted'],
        ];
    }

    public function messages(): array
    {
        return [
            'username.unique' => 'Este nome de usuário já está em uso. Por favor, escolha outro.',
            'username.regex'  => 'O username pode conter apenas letras, números e os caracteres: . _ @ -',
            'terms.accepted'  => 'Você precisa aceitar os termos de uso para continuar.',
        ];
    }
}
