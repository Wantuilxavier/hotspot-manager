<?php

namespace App\Services;

use App\Models\HotspotUser;
use App\Models\Plan;
use App\Models\RadCheck;
use App\Models\RadGroupReply;
use App\Models\RadReply;
use App\Models\RadUserGroup;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * RadiusService — Camada de negócio para manipulação das tabelas RADIUS.
 *
 * Toda escrita nas tabelas radius* passa por aqui para garantir consistência.
 */
class RadiusService
{
    // ====================================================================
    // USUÁRIOS
    // ====================================================================

    /**
     * Cria ou atualiza um usuário no RADIUS.
     * Insere em: radcheck, radreply, radusergroup, hotspot_users.
     */
    public function createUser(array $data): HotspotUser
    {
        DB::transaction(function () use ($data, &$user) {
            $plan = Plan::findOrFail($data['plan_id']);

            // 1. Calcula expiração
            $expiresAt = $plan->duration_days > 0
                ? Carbon::now()->addDays($plan->duration_days)
                : null;

            // 2. radcheck — senha em texto plano (PAP/CHAP compatível com Hotspot MikroTik)
            //    Para MD5 use: Crypt-Password com password_hash($pwd, PASSWORD_MD5)
            RadCheck::setPassword($data['username'], $data['password']);

            // Limite simultâneo de sessões (padrão: 1 por usuário)
            RadCheck::setSimultaneousUse($data['username'], $data['simultaneous_use'] ?? 1);

            // Expiração no RADIUS (se houver)
            if ($expiresAt) {
                RadCheck::setExpiration($data['username'], $expiresAt);
            }

            // 3. radusergroup — associa ao grupo/plano
            RadUserGroup::assignGroup($data['username'], $plan->group_name);

            // 4. hotspot_users — dados complementares
            $user = HotspotUser::updateOrCreate(
                ['username' => $data['username']],
                [
                    'full_name'     => $data['full_name']     ?? null,
                    'email'         => $data['email']         ?? null,
                    'phone'         => $data['phone']         ?? null,
                    'document'      => $data['document']      ?? null,
                    'registered_ip' => $data['registered_ip'] ?? null,
                    'mac_address'   => $data['mac_address']   ?? null,
                    'plan_id'       => $plan->id,
                    'expires_at'    => $expiresAt?->toDateString(),
                    'status'        => 'active',
                ]
            );
        });

        return $user;
    }

    /**
     * Altera a senha de um usuário no RADIUS.
     */
    public function changePassword(string $username, string $newPassword): void
    {
        RadCheck::setPassword($username, $newPassword);
    }

    /**
     * Muda o plano de um usuário — atualiza radusergroup e expiração.
     */
    public function changePlan(HotspotUser $hotspotUser, Plan $plan): void
    {
        DB::transaction(function () use ($hotspotUser, $plan) {
            $expiresAt = $plan->duration_days > 0
                ? Carbon::now()->addDays($plan->duration_days)
                : null;

            RadUserGroup::assignGroup($hotspotUser->username, $plan->group_name);

            if ($expiresAt) {
                RadCheck::setExpiration($hotspotUser->username, $expiresAt);
            } else {
                RadCheck::where('username', $hotspotUser->username)
                        ->where('attribute', 'Expiration')
                        ->delete();
            }

            $hotspotUser->update([
                'plan_id'    => $plan->id,
                'expires_at' => $expiresAt?->toDateString(),
                'status'     => 'active',
            ]);
        });
    }

    /**
     * Suspende um usuário — remove da radcheck para bloquear autenticação.
     */
    public function suspendUser(HotspotUser $user): void
    {
        DB::transaction(function () use ($user) {
            // Insere Auth-Type := Reject para barrar o login
            RadCheck::updateOrCreate(
                ['username' => $user->username, 'attribute' => 'Auth-Type'],
                ['op' => ':=', 'value' => 'Reject']
            );
            $user->update(['status' => 'suspended']);
        });
    }

    /**
     * Reativa um usuário suspenso.
     */
    public function reactivateUser(HotspotUser $user): void
    {
        DB::transaction(function () use ($user) {
            RadCheck::where('username', $user->username)
                    ->where('attribute', 'Auth-Type')
                    ->delete();
            $user->update(['status' => 'active']);
        });
    }

    /**
     * Remove completamente um usuário de todas as tabelas RADIUS.
     */
    public function deleteUser(HotspotUser $user): void
    {
        DB::transaction(function () use ($user) {
            RadCheck::deleteAllForUser($user->username);
            RadReply::deleteAllForUser($user->username);
            RadUserGroup::removeUser($user->username);
            $user->delete();
        });
    }

    // ====================================================================
    // PLANOS / GRUPOS
    // ====================================================================

    /**
     * Sincroniza um plano com as tabelas radgroupreply.
     * Deve ser chamado ao criar ou editar um plano.
     */
    public function syncPlanGroup(Plan $plan): void
    {
        // Rate-Limit via atributo VSA MikroTik: upload/download
        RadGroupReply::setRateLimit(
            $plan->group_name,
            $plan->upload_rate,
            $plan->download_rate
        );

        // Session-Timeout em segundos (se plano tem duração definida)
        if ($plan->duration_days > 0) {
            \App\Models\RadGroupReply::updateOrCreate(
                ['groupname' => $plan->group_name, 'attribute' => 'Session-Timeout'],
                ['op' => '=', 'value' => (string) ($plan->duration_days * 86400)]
            );
        }
    }

    /**
     * Remove um grupo RADIUS ao excluir um plano.
     */
    public function deletePlanGroup(Plan $plan): void
    {
        RadGroupReply::deleteAllForGroup($plan->group_name);
        \App\Models\RadGroupCheck::deleteAllForGroup($plan->group_name);
    }

    // ====================================================================
    // ESTATÍSTICAS
    // ====================================================================

    /**
     * Usuários online no momento (sessões abertas no radacct).
     */
    public function getOnlineUsers(): \Illuminate\Support\Collection
    {
        return DB::table('radacct')
            ->whereNull('acctstoptime')
            ->orderByDesc('acctstarttime')
            ->get();
    }

    /**
     * Resumo de totais para o dashboard.
     */
    public function getDashboardStats(): array
    {
        return [
            'total_users'   => HotspotUser::count(),
            'active_users'  => HotspotUser::where('status', 'active')->count(),
            'online_now'    => DB::table('radacct')->whereNull('acctstoptime')->count(),
            'total_plans'   => Plan::where('active', true)->count(),
            'expired_users' => HotspotUser::where('status', 'expired')
                                ->orWhere(fn($q) => $q->where('expires_at', '<', now())
                                    ->where('status', 'active'))
                                ->count(),
        ];
    }
}
