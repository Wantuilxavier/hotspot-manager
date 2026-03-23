<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Atributos de reply enviados para todos os usuários de um grupo.
 * Principal uso: definir Mikrotik-Rate-Limit por plano.
 */
class RadGroupReply extends Model
{
    public $table = 'radgroupreply';
    public $timestamps = false;

    protected $fillable = ['groupname', 'attribute', 'op', 'value'];

    public static function setRateLimit(string $groupname, string $upload, string $download): void
    {
        static::updateOrCreate(
            ['groupname' => $groupname, 'attribute' => 'Mikrotik-Rate-Limit'],
            ['op' => '=', 'value' => "{$upload}/{$download}"]
        );
    }

    public static function deleteAllForGroup(string $groupname): void
    {
        static::where('groupname', $groupname)->delete();
    }
}
