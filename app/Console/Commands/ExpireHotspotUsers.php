<?php

namespace App\Console\Commands;

use App\Models\HotspotUser;
use Carbon\Carbon;
use Illuminate\Console\Command;

/**
 * Marca como 'expired' todos os usuários do hotspot cuja validade já passou.
 *
 * O FreeRADIUS já bloqueia o login via atributo Expiration no radcheck;
 * este comando apenas sincroniza o status em hotspot_users para refletir
 * corretamente no painel administrativo.
 *
 * Execução: php artisan hotspot:expire-users
 * Agendado: diariamente às 01:00 (configurar no cron ou em routes/console.php)
 */
class ExpireHotspotUsers extends Command
{
    protected $signature   = 'hotspot:expire-users';
    protected $description = 'Marca como expirados os usuários com validade vencida';

    public function handle(): int
    {
        $count = HotspotUser::where('status', 'active')
            ->whereNotNull('expires_at')
            ->where('expires_at', '<', Carbon::today())
            ->update(['status' => 'expired']);

        if ($count > 0) {
            $this->info("{$count} usuário(s) marcado(s) como expirado(s).");
        } else {
            $this->info('Nenhum usuário expirado encontrado.');
        }

        return Command::SUCCESS;
    }
}
