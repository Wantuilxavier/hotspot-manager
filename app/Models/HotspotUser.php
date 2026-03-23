<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class HotspotUser extends Model
{
    protected $fillable = [
        'username', 'full_name', 'email', 'phone', 'document',
        'registered_ip', 'mac_address', 'plan_id',
        'expires_at', 'status', 'notes',
    ];

    protected $casts = [
        'expires_at' => 'date',
    ];

    // ---- Relationships --------------------------------------------------

    public function plan(): BelongsTo
    {
        return $this->belongsTo(Plan::class);
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(RadAcct::class, 'username', 'username');
    }

    // ---- Accessors ------------------------------------------------------

    public function getIsExpiredAttribute(): bool
    {
        return $this->expires_at && $this->expires_at->isPast();
    }

    public function getActiveSessions(): int
    {
        return RadAcct::where('username', $this->username)->whereNull('acctstoptime')->count();
    }

    // ---- Scopes ---------------------------------------------------------

    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }

    public function scopeExpired($query)
    {
        return $query->where('status', 'expired')
                     ->orWhere(fn($q) => $q->whereNotNull('expires_at')->where('expires_at', '<', now()));
    }
}
