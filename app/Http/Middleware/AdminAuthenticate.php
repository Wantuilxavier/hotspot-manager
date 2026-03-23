<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class AdminAuthenticate
{
    public function handle(Request $request, Closure $next): Response
    {
        if (!Auth::guard('admin')->check()) {
            return $request->expectsJson()
                ? response()->json(['message' => 'Unauthenticated.'], 401)
                : redirect()->route('admin.login')->with('error', 'Faça login para continuar.');
        }

        if (!Auth::guard('admin')->user()->active) {
            Auth::guard('admin')->logout();
            return redirect()->route('admin.login')->with('error', 'Conta desativada.');
        }

        return $next($request);
    }
}
