<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;

class UpdateUserRequest extends FormRequest
{
    public function authorize(): bool { return true; }

    public function rules(): array
    {
        return [
            'password'  => ['nullable', 'string', 'min:6', 'max:64'],
            'plan_id'   => ['nullable', 'exists:plans,id'],
            'full_name' => ['nullable', 'string', 'max:150'],
            'email'     => ['nullable', 'email', 'max:150'],
            'phone'     => ['nullable', 'string', 'max:20'],
            'document'  => ['nullable', 'string', 'max:20'],
            'notes'     => ['nullable', 'string', 'max:1000'],
        ];
    }
}
