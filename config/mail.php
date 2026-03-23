<?php

return [
    'default' => env('MAIL_MAILER', 'log'),

    'mailers' => [
        'log' => [
            'transport' => 'log',
            'channel'   => env('MAIL_LOG_CHANNEL'),
        ],
        'smtp' => [
            'transport'    => 'smtp',
            'scheme'       => env('MAIL_SCHEME'),
            'url'          => env('MAIL_URL'),
            'host'         => env('MAIL_HOST', 'smtp.mailgun.org'),
            'port'         => env('MAIL_PORT', 587),
            'username'     => env('MAIL_USERNAME'),
            'password'     => env('MAIL_PASSWORD'),
            'timeout'      => null,
            'local_domain' => env('MAIL_EHLO_DOMAIN', parse_url(env('APP_URL', 'http://localhost'), PHP_URL_HOST)),
        ],
    ],

    'from' => [
        'address' => env('MAIL_FROM_ADDRESS', 'hotspot@example.com'),
        'name'    => env('MAIL_FROM_NAME', 'Hotspot Manager'),
    ],
];
