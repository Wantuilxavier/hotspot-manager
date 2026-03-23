<?php

namespace App\Http\Controllers\Portal;

use App\Http\Controllers\Controller;
use App\Http\Requests\Portal\SelfRegisterRequest;
use App\Models\Plan;
use App\Services\RadiusService;
use Illuminate\Http\Request;

/**
 * CaptivePortalController — Ponto de entrada do auto-cadastro.
 *
 * O MikroTik redireciona usuários não autenticados para esta página.
 * Após o cadastro, o usuário recebe as credenciais e pode se autenticar
 * na página de login do Hotspot do MikroTik.
 *
 * Parâmetros passados pelo MikroTik na query string:
 *   ?link-login=...&link-orig=...&mac=...&ip=...&error=...
 */
class CaptivePortalController extends Controller
{
    public function __construct(private readonly RadiusService $radiusService) {}

    public function index(Request $request)
    {
        $plans = Plan::public()->orderBy('price')->get();

        // Parâmetros do MikroTik
        $mikrotikParams = [
            'mac'        => $request->input('mac', ''),
            'ip'         => $request->input('ip', $request->ip()),
            'link_login' => $request->input('link-login', ''),
            'link_orig'  => $request->input('link-orig', ''),
            'error'      => $request->input('error', ''),
        ];

        return view('portal.register', compact('plans', 'mikrotikParams'));
    }

    public function register(SelfRegisterRequest $request)
    {
        $data = $request->validated();

        // Enriquece com dados do contexto
        $data['registered_ip'] = $request->ip();
        $data['mac_address']   = $request->input('mac_address') ?: $request->input('mac');

        $user = $this->radiusService->createUser($data);

        // Redireciona para tela de sucesso com as credenciais
        return redirect()->route('portal.success', [
            'username'   => $user->username,
            'link_login' => $request->input('link_login', ''),
        ]);
    }

    public function success(Request $request)
    {
        $username  = $request->input('username');
        $linkLogin = $request->input('link_login', '');

        if (!$username) {
            return redirect()->route('portal.index');
        }

        $user = \App\Models\HotspotUser::where('username', $username)->with('plan')->firstOrFail();

        return view('portal.success', compact('user', 'linkLogin'));
    }
}
