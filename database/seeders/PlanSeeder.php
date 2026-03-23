<?php

namespace Database\Seeders;

use App\Models\Plan;
use App\Services\RadiusService;
use Illuminate\Database\Seeder;

class PlanSeeder extends Seeder
{
    public function run(): void
    {
        $plans = [
            [
                'name'          => 'Básico 5MB',
                'group_name'    => 'basic_5mb',
                'description'   => 'Plano básico para uso casual',
                'download_rate' => '5M',
                'upload_rate'   => '2M',
                'duration_days' => 30,
                'price'         => 49.90,
                'data_limit_mb' => 0,
                'is_default'    => true,
                'is_public'     => true,
                'active'        => true,
            ],
            [
                'name'          => 'Intermediário 10MB',
                'group_name'    => 'mid_10mb',
                'description'   => 'Plano intermediário para uso diário',
                'download_rate' => '10M',
                'upload_rate'   => '5M',
                'duration_days' => 30,
                'price'         => 79.90,
                'data_limit_mb' => 0,
                'is_default'    => false,
                'is_public'     => true,
                'active'        => true,
            ],
            [
                'name'          => 'Premium 20MB',
                'group_name'    => 'premium_20mb',
                'description'   => 'Plano premium para download e streaming',
                'download_rate' => '20M',
                'upload_rate'   => '10M',
                'duration_days' => 30,
                'price'         => 119.90,
                'data_limit_mb' => 0,
                'is_default'    => false,
                'is_public'     => true,
                'active'        => true,
            ],
            [
                'name'          => 'Diária 5MB',
                'group_name'    => 'daily_5mb',
                'description'   => 'Acesso por 1 dia — ideal para visitantes',
                'download_rate' => '5M',
                'upload_rate'   => '2M',
                'duration_days' => 1,
                'price'         => 9.90,
                'data_limit_mb' => 200,
                'is_default'    => false,
                'is_public'     => true,
                'active'        => true,
            ],
        ];

        foreach ($plans as $data) {
            $plan = Plan::firstOrCreate(['group_name' => $data['group_name']], $data);

            // Sincroniza o grupo no RADIUS
            app(RadiusService::class)->syncPlanGroup($plan);
        }
    }
}
