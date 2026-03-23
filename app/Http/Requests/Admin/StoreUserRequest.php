<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;

class StoreUserRequest extends FormRequest
{
    public function authorize(): bool { return true; }

    public function rules(): array
    {
        return [
            'username'         => ['required', 'string', 'min:3', 'max:64', 'unique:hotspot_users,username', 'regex:/^[a-zA-Z0-9._@-]+$/'],
            'password'         => ['required', 'string', 'min:6', 'max:64'],
            'plan_id'          => ['required', 'exists:plans,id'],
            'full_name'        => ['nullable', 'string', 'max:150'],
            'email'            => ['nullable', 'email', 'max:150'],
            'phone'            => ['nullable', 'string', 'max:20'],
            'document'         => ['nullable', 'string', 'max:20'],
            'simultaneous_use' => ['nullable', 'integer', 'min:1', 'max:10'],
            'notes'            => ['nullable', 'string', 'max:1000'],
        ];
    }

    public function messages(): array
    {
        return [
            'username.regex' => 'O username pode conter apenas letras, números e os caracteres: . _ @ -',
        ];
    }
}
