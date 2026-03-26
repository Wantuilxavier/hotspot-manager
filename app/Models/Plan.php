<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Plan extends Model
{
    protected $fillable = [
        'name', 'group_name', 'description',
        'download_rate', 'upload_rate',
        'duration_days', 'price', 'data_limit_mb',
        'is_default', 'is_public', 'active',
    ];

    protected $casts = [
        'is_default'    => 'boolean',
        'is_public'     => 'boolean',
        'active'        => 'boolean',
        'price'         => 'float',
        'data_limit_mb' => 'integer',
        'duration_days' => 'integer',
    ];

    // ---- Relationships --------------------------------------------------

    public function hotspotUsers(): HasMany
    {
        return $this->hasMany(HotspotUser::class);
    }

    // ---- Accessors ------------------------------------------------------

    public function getPriceFormattedAttribute(): string
    {
        return 'R$ ' . number_format($this->price, 2, ',', '.');
    }

    // ---- Scopes ---------------------------------------------------------

    public function scopeActive($query)
    {
        return $query->where('active', true);
    }

    public function scopePublic($query)
    {
        return $query->where('is_public', true)->where('active', true);
    }
}
