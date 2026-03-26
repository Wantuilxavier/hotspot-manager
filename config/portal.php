<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Captive Portal — Configurações
    |--------------------------------------------------------------------------
    | Controla o comportamento do portal de auto-cadastro de usuários.
    */

    // Exige telefone no cadastro pelo portal
    'require_phone' => env('PORTAL_REQUIRE_PHONE', false),

    // group_name do plano selecionado por padrão no portal
    'default_plan' => env('PORTAL_DEFAULT_PLAN', null),
];
