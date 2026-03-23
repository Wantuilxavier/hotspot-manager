<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Tabela radcheck — atributos verificados durante autenticação.
 *
 * Atributos comuns:
 *  - Cleartext-Password  op:==   value:<senha>
 *  - Expiration          op:==   value:"Jan 01 2025 00:00:00"
 *  - Simultaneous-Use    op::=   value:1
 */
class RadCheck extends Model
{
    public $table = 'radcheck';
    public $timestamps = false;

    protected $fillable = ['username', 'attribute', 'op', 'value'];

    // ---- Helpers --------------------------------------------------------

    public static function setPassword(string $username, string $password): void
    {
        static::updateOrCreate(
            ['username' => $username, 'attribute' => 'Cleartext-Password'],
            ['op' => ':=', 'value' => $password]
        );
    }

    public static function setExpiration(string $username, \Carbon\Carbon $date): void
    {
        static::updateOrCreate(
            ['username' => $username, 'attribute' => 'Expiration'],
            ['op' => ':=', 'value' => $date->format('M d Y H:i:s')]
        );
    }

    public static function setSimultaneousUse(string $username, int $max = 1): void
    {
        static::updateOrCreate(
            ['username' => $username, 'attribute' => 'Simultaneous-Use'],
            ['op' => ':=', 'value' => (string) $max]
        );
    }

    public static function deleteAllForUser(string $username): void
    {
        static::where('username', $username)->delete();
    }
}
