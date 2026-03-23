<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;

/**
 * Tabela radacct — registro de accounting (sessões RADIUS).
 * Populada automaticamente pelo FreeRADIUS; não deve ser escrita pela aplicação.
 */
class RadAcct extends Model
{
    public $table = 'radacct';
    public $primaryKey = 'radacctid';
    public $timestamps = false;

    protected $fillable = [];
    protected $guarded = ['*'];

    // ---- Scopes ---------------------------------------------------------

    public function scopeOnline(Builder $query): Builder
    {
        return $query->whereNull('acctstoptime');
    }

    public function scopeForUser(Builder $query, string $username): Builder
    {
        return $query->where('username', $username);
    }

    // ---- Acessors -------------------------------------------------------

    public function getSessionDurationAttribute(): string
    {
        $seconds = $this->acctsessiontime ?? 0;
        $h = floor($seconds / 3600);
        $m = floor(($seconds % 3600) / 60);
        $s = $seconds % 60;
        return sprintf('%02d:%02d:%02d', $h, $m, $s);
    }

    public function getDownloadFormattedAttribute(): string
    {
        return $this->formatBytes($this->acctoutputoctets ?? 0);
    }

    public function getUploadFormattedAttribute(): string
    {
        return $this->formatBytes($this->acctinputoctets ?? 0);
    }

    private function formatBytes(int $bytes): string
    {
        if ($bytes >= 1073741824) return round($bytes / 1073741824, 2) . ' GB';
        if ($bytes >= 1048576)    return round($bytes / 1048576, 2) . ' MB';
        if ($bytes >= 1024)       return round($bytes / 1024, 2) . ' KB';
        return $bytes . ' B';
    }
}
