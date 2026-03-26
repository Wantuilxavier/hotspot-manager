<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Expira usuários com validade vencida — roda diariamente à 01:00
Schedule::command('hotspot:expire-users')->dailyAt('01:00');
