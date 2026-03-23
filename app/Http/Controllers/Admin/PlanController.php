<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\StorePlanRequest;
use App\Models\HotspotUser;
use App\Models\Plan;
use App\Services\RadiusService;
use Illuminate\Http\Request;

class PlanController extends Controller
{
    public function __construct(private readonly RadiusService $radiusService) {}

    public function index()
    {
        $plans = Plan::withCount([
            'hotspotUsers as users_count',
            'hotspotUsers as active_count' => fn($q) => $q->where('status', 'active'),
        ])->orderBy('price')->get();

        return view('admin.plans.index', compact('plans'));
    }

    public function create()
    {
        return view('admin.plans.create');
    }

    public function store(StorePlanRequest $request)
    {
        $plan = Plan::create($request->validated());
        $this->radiusService->syncPlanGroup($plan);

        return redirect()
            ->route('admin.plans.index')
            ->with('success', "Plano '{$plan->name}' criado e sincronizado com o RADIUS!");
    }

    public function edit(Plan $plan)
    {
        return view('admin.plans.edit', compact('plan'));
    }

    public function update(StorePlanRequest $request, Plan $plan)
    {
        $plan->update($request->validated());
        $this->radiusService->syncPlanGroup($plan);

        return redirect()
            ->route('admin.plans.index')
            ->with('success', "Plano '{$plan->name}' atualizado e sincronizado com o RADIUS!");
    }

    public function destroy(Plan $plan)
    {
        $count = HotspotUser::where('plan_id', $plan->id)->where('status', 'active')->count();

        if ($count > 0) {
            return back()->withErrors(['plan' => "Não é possível excluir: {$count} usuário(s) ativo(s) neste plano."]);
        }

        $this->radiusService->deletePlanGroup($plan);
        $plan->delete();

        return redirect()
            ->route('admin.plans.index')
            ->with('success', "Plano excluído.");
    }

    public function toggleActive(Plan $plan)
    {
        $plan->update(['active' => !$plan->active]);
        $status = $plan->active ? 'ativado' : 'desativado';

        return back()->with('success', "Plano {$status}.");
    }
}
