<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Vínculo entre usuário e grupo RADIUS.
 * Um usuário pode estar em múltiplos grupos, mas normalmente está em apenas um (o plano).
 */
class RadUserGroup extends Model
{
    public $table = 'radusergroup';
    public $timestamps = false;
    public $incrementing = false;
    protected $primaryKey = null;

    protected $fillable = ['username', 'groupname', 'priority'];

    public static function assignGroup(string $username, string $groupname, int $priority = 1): void
    {
        static::where('username', $username)->delete(); // Remove grupos anteriores
        static::create([
            'username'  => $username,
            'groupname' => $groupname,
            'priority'  => $priority,
        ]);
    }

    public static function removeUser(string $username): void
    {
        static::where('username', $username)->delete();
    }
}
