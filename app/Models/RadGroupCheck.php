<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RadGroupCheck extends Model
{
    public $table = 'radgroupcheck';
    public $timestamps = false;

    protected $fillable = ['groupname', 'attribute', 'op', 'value'];

    public static function deleteAllForGroup(string $groupname): void
    {
        static::where('groupname', $groupname)->delete();
    }
}
