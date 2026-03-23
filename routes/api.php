<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes — Hotspot Manager
|--------------------------------------------------------------------------
| Endpoints protegidos para integração com sistemas externos.
| Exemplo de uso: app mobile do cliente, dashboard externo, etc.
*/

Route::prefix('v1')->group(function () {

    // Status público
    Route::get('/status', fn() => response()->json([
        'service' => 'Hotspot Manager API',
        'status'  => 'ok',
        'time'    => now()->toIso8601String(),
    ]));

    // Rotas protegidas (futuramente com Sanctum/API Key)
    // Route::middleware('auth:sanctum')->group(function () {
    //     Route::get('/users/online', ...);
    //     Route::get('/stats', ...);
    // });
});
