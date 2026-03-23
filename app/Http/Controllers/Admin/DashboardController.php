<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\RadAcct;
use App\Services\MikrotikService;
use App\Services\RadiusService;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function __construct(
        private readonly RadiusService  $radiusService,
        private readonly MikrotikService $mikrotikService,
    ) {}

    public function index()
    {
        $stats       = $this->radiusService->getDashboardStats();
        $onlineUsers = $this->radiusService->getOnlineUsers();

        // Últimas 10 autenticações (log)
        $recentAuth = DB::table('radpostauth')
            ->orderByDesc('id')
            ->limit(10)
            ->get();

        // Consumo por usuário nas últimas 24h
        $topUsers = DB::table('radacct')
            ->select('username',
                DB::raw('SUM(acctoutputoctets) as download'),
                DB::raw('SUM(acctinputoctets) as upload'),
                DB::raw('COUNT(*) as sessions'))
            ->where('acctstarttime', '>=', now()->subDay())
            ->groupBy('username')
            ->orderByDesc('download')
            ->limit(10)
            ->get();

        $routerInfo = $this->mikrotikService->isEnabled()
            ? $this->mikrotikService->getRouterInfo()
            : [];

        return view('admin.dashboard', compact(
            'stats', 'onlineUsers', 'recentAuth', 'topUsers', 'routerInfo'
        ));
    }
}
