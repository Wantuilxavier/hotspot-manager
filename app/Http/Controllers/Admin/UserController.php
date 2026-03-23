<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\StoreUserRequest;
use App\Http\Requests\Admin\UpdateUserRequest;
use App\Models\HotspotUser;
use App\Models\Plan;
use App\Services\MikrotikService;
use App\Services\RadiusService;
use Illuminate\Http\Request;

class UserController extends Controller
{
    public function __construct(
        private readonly RadiusService   $radiusService,
        private readonly MikrotikService $mikrotikService,
    ) {}

    public function index(Request $request)
    {
        $query = HotspotUser::with('plan')->latest();

        if ($search = $request->input('search')) {
            $query->where(fn($q) => $q
                ->where('username', 'like', "%{$search}%")
                ->orWhere('full_name', 'like', "%{$search}%")
                ->orWhere('email', 'like', "%{$search}%")
                ->orWhere('phone', 'like', "%{$search}%")
            );
        }

        if ($status = $request->input('status')) {
            $query->where('status', $status);
        }

        if ($planId = $request->input('plan_id')) {
            $query->where('plan_id', $planId);
        }

        $users = $query->paginate(20)->withQueryString();
        $plans = Plan::active()->get(['id', 'name']);

        return view('admin.users.index', compact('users', 'plans'));
    }

    public function create()
    {
        $plans = Plan::active()->get();
        return view('admin.users.create', compact('plans'));
    }

    public function store(StoreUserRequest $request)
    {
        $user = $this->radiusService->createUser($request->validated());

        return redirect()
            ->route('admin.users.show', $user)
            ->with('success', "Usuário {$user->username} criado com sucesso!");
    }

    public function show(HotspotUser $user)
    {
        $user->load('plan');

        $sessions = \App\Models\RadAcct::forUser($user->username)
            ->orderByDesc('acctstarttime')
            ->limit(20)
            ->get();

        $activeSessions = \App\Models\RadAcct::forUser($user->username)
            ->online()
            ->get();

        return view('admin.users.show', compact('user', 'sessions', 'activeSessions'));
    }

    public function edit(HotspotUser $user)
    {
        $plans = Plan::active()->get();
        return view('admin.users.edit', compact('user', 'plans'));
    }

    public function update(UpdateUserRequest $request, HotspotUser $user)
    {
        $data = $request->validated();

        // Troca de plano
        if (isset($data['plan_id']) && $data['plan_id'] != $user->plan_id) {
            $newPlan = Plan::findOrFail($data['plan_id']);
            $this->radiusService->changePlan($user, $newPlan);
        }

        // Troca de senha
        if (!empty($data['password'])) {
            $this->radiusService->changePassword($user->username, $data['password']);
        }

        $user->update(array_filter([
            'full_name' => $data['full_name'] ?? null,
            'email'     => $data['email']     ?? null,
            'phone'     => $data['phone']     ?? null,
            'document'  => $data['document']  ?? null,
            'notes'     => $data['notes']     ?? null,
        ]));

        return redirect()
            ->route('admin.users.show', $user)
            ->with('success', 'Usuário atualizado com sucesso!');
    }

    public function destroy(HotspotUser $user)
    {
        $username = $user->username;
        $this->radiusService->deleteUser($user);

        return redirect()
            ->route('admin.users.index')
            ->with('success', "Usuário {$username} removido.");
    }

    public function suspend(HotspotUser $user)
    {
        $this->radiusService->suspendUser($user);

        // Desconecta do roteador se estiver online
        $this->mikrotikService->disconnectUser($user->username);

        return back()->with('success', "Usuário {$user->username} suspenso.");
    }

    public function reactivate(HotspotUser $user)
    {
        $this->radiusService->reactivateUser($user);
        return back()->with('success', "Usuário {$user->username} reativado.");
    }

    public function disconnect(HotspotUser $user)
    {
        $result = $this->mikrotikService->disconnectUser($user->username);

        return back()->with(
            $result ? 'success' : 'error',
            $result ? "Usuário {$user->username} desconectado do roteador." : 'Falha ao desconectar (API MikroTik desabilitada?).'
        );
    }
}
