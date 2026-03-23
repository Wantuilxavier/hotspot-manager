<?php

return [
    /*
    |--------------------------------------------------------------------------
    | MikroTik RouterOS API
    |--------------------------------------------------------------------------
    | Configurações para conexão via API RouterOS.
    | Habilite apenas se precisar de controle em tempo real (desconectar usuários).
    | O controle de banda é feito via RADIUS e não precisa desta integração.
    */

    'enabled'  => env('MIKROTIK_ENABLED', false),
    'host'     => env('MIKROTIK_HOST', '192.168.88.1'),
    'user'     => env('MIKROTIK_USER', 'admin'),
    'pass'     => env('MIKROTIK_PASS', ''),
    'port'     => (int) env('MIKROTIK_PORT', 8728),
    'timeout'  => 10,
    'ssl'      => false,
];
