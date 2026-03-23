<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Tabela radreply — atributos enviados de volta ao NAS após autenticação.
 *
 * Atributos comuns para MikroTik Hotspot:
 *  - Mikrotik-Rate-Limit  op:=  value:"5M/10M"
 *  - Framed-IP-Address    op:=  value:"192.168.1.100"
 *  - Session-Timeout      op:=  value:86400
 */
class RadReply extends Model
{
    public $table = 'radreply';
    public $timestamps = false;

    protected $fillable = ['username', 'attribute', 'op', 'value'];

    // ---- Helpers --------------------------------------------------------

    public static function setRateLimit(string $username, string $upload, string $download): void
    {
        static::updateOrCreate(
            ['username' => $username, 'attribute' => 'Mikrotik-Rate-Limit'],
            ['op' => '=', 'value' => "{$upload}/{$download}"]
        );
    }

    public static function setSessionTimeout(string $username, int $seconds): void
    {
        static::updateOrCreate(
            ['username' => $username, 'attribute' => 'Session-Timeout'],
            ['op' => '=', 'value' => (string) $seconds]
        );
    }

    public static function deleteAllForUser(string $username): void
    {
        static::where('username', $username)->delete();
    }
}
