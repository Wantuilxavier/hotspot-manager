<?php

use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\PlanController;
use App\Http\Controllers\Admin\UserController;
use App\Http\Controllers\Auth\LoginController;
use App\Http\Controllers\Portal\CaptivePortalController;
use Illuminate\Support\Facades\Route;

// ============================================================
// CAPTIVE PORTAL (público — redireciona usuários sem autenticação)
// ============================================================
Route::prefix('portal')->name('portal.')->group(function () {
    Route::get('/',        [CaptivePortalController::class, 'index'])    ->name('index');
    Route::post('/register', [CaptivePortalController::class, 'register'])->name('register');
    Route::get('/success', [CaptivePortalController::class, 'success'])  ->name('success');
});

// ============================================================
// AUTENTICAÇÃO DO PAINEL ADMIN
// ============================================================
Route::prefix('admin')->name('admin.')->group(function () {
    Route::get('/login',  [LoginController::class, 'showForm'])->name('login');
    Route::post('/login', [LoginController::class, 'login']);
    Route::post('/logout',[LoginController::class, 'logout'])->name('logout');

    // --------------------------------------------------------
    // Rotas protegidas pelo middleware AdminAuthenticate
    // --------------------------------------------------------
    Route::middleware(\App\Http\Middleware\AdminAuthenticate::class)->group(function () {

        Route::get('/',          [DashboardController::class, 'index'])->name('dashboard');
        Route::get('/dashboard', [DashboardController::class, 'index']);

        // Usuários
        Route::resource('users', UserController::class)->except(['show']);
        Route::get('users/{user}',            [UserController::class, 'show'])       ->name('users.show');
        Route::post('users/{user}/suspend',   [UserController::class, 'suspend'])    ->name('users.suspend');
        Route::post('users/{user}/reactivate',[UserController::class, 'reactivate']) ->name('users.reactivate');
        Route::post('users/{user}/disconnect',[UserController::class, 'disconnect']) ->name('users.disconnect');

        // Planos
        Route::resource('plans', PlanController::class)->except(['show']);
        Route::post('plans/{plan}/toggle',    [PlanController::class, 'toggleActive'])->name('plans.toggle');
    });
});

// Redireciona raiz para o painel
Route::get('/', fn() => redirect()->route('admin.dashboard'));
