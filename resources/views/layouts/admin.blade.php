<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'Hotspot Manager') — Admin</title>
    <!-- Tailwind CSS via CDN (substituir por build local em produção) -->
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            theme: { extend: { colors: { brand: '#0066CC' } } }
        }
    </script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
</head>
<body class="bg-gray-100 min-h-screen font-sans">

<!-- Sidebar -->
<div class="flex h-screen overflow-hidden">
    <aside class="w-64 bg-gray-900 text-white flex-shrink-0 flex flex-col">
        <div class="h-16 flex items-center justify-center border-b border-gray-700">
            <i class="fas fa-wifi text-blue-400 text-2xl mr-2"></i>
            <span class="text-lg font-bold tracking-wide">Hotspot Manager</span>
        </div>

        <nav class="flex-1 overflow-y-auto py-4">
            <p class="px-4 text-xs text-gray-500 uppercase mb-2 tracking-widest">Principal</p>
            <a href="{{ route('admin.dashboard') }}"
               class="flex items-center px-4 py-2.5 text-sm hover:bg-gray-700 transition {{ request()->routeIs('admin.dashboard') ? 'bg-gray-700 text-blue-400 border-l-4 border-blue-400' : 'text-gray-300' }}">
                <i class="fas fa-tachometer-alt w-5 mr-3"></i> Dashboard
            </a>

            <p class="px-4 text-xs text-gray-500 uppercase mt-4 mb-2 tracking-widest">Gerenciamento</p>
            <a href="{{ route('admin.users.index') }}"
               class="flex items-center px-4 py-2.5 text-sm hover:bg-gray-700 transition {{ request()->routeIs('admin.users.*') ? 'bg-gray-700 text-blue-400 border-l-4 border-blue-400' : 'text-gray-300' }}">
                <i class="fas fa-users w-5 mr-3"></i> Usuários
            </a>
            <a href="{{ route('admin.plans.index') }}"
               class="flex items-center px-4 py-2.5 text-sm hover:bg-gray-700 transition {{ request()->routeIs('admin.plans.*') ? 'bg-gray-700 text-blue-400 border-l-4 border-blue-400' : 'text-gray-300' }}">
                <i class="fas fa-layer-group w-5 mr-3"></i> Planos
            </a>

            <p class="px-4 text-xs text-gray-500 uppercase mt-4 mb-2 tracking-widest">Portal</p>
            <a href="{{ route('portal.index') }}" target="_blank"
               class="flex items-center px-4 py-2.5 text-sm text-gray-300 hover:bg-gray-700 transition">
                <i class="fas fa-external-link-alt w-5 mr-3"></i> Captive Portal
            </a>
        </nav>

        <div class="p-4 border-t border-gray-700">
            <div class="flex items-center">
                <div class="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-sm font-bold mr-3">
                    {{ strtoupper(substr(Auth::guard('admin')->user()->name, 0, 1)) }}
                </div>
                <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-white truncate">{{ Auth::guard('admin')->user()->name }}</p>
                    <p class="text-xs text-gray-400 truncate">{{ Auth::guard('admin')->user()->role }}</p>
                </div>
                <form action="{{ route('admin.logout') }}" method="POST">
                    @csrf
                    <button type="submit" class="text-gray-400 hover:text-white transition ml-2" title="Sair">
                        <i class="fas fa-sign-out-alt"></i>
                    </button>
                </form>
            </div>
        </div>
    </aside>

    <!-- Main content -->
    <div class="flex-1 flex flex-col overflow-hidden">
        <!-- Topbar -->
        <header class="h-16 bg-white shadow-sm flex items-center justify-between px-6 flex-shrink-0">
            <h1 class="text-lg font-semibold text-gray-800">@yield('page-title', 'Dashboard')</h1>
            <div class="text-sm text-gray-500">
                <i class="fas fa-clock mr-1"></i>
                <span id="clock"></span>
            </div>
        </header>

        <!-- Alerts -->
        <div class="px-6 pt-4">
            @if(session('success'))
                <div class="bg-green-50 border border-green-200 text-green-800 rounded-lg px-4 py-3 mb-4 flex items-center">
                    <i class="fas fa-check-circle mr-2 text-green-500"></i>
                    {{ session('success') }}
                </div>
            @endif
            @if(session('error'))
                <div class="bg-red-50 border border-red-200 text-red-800 rounded-lg px-4 py-3 mb-4 flex items-center">
                    <i class="fas fa-exclamation-circle mr-2 text-red-500"></i>
                    {{ session('error') }}
                </div>
            @endif
            @if($errors->any())
                <div class="bg-red-50 border border-red-200 text-red-800 rounded-lg px-4 py-3 mb-4">
                    <p class="font-semibold flex items-center"><i class="fas fa-times-circle mr-2"></i>Erros de validação:</p>
                    <ul class="mt-1 ml-6 list-disc text-sm">
                        @foreach($errors->all() as $error)
                            <li>{{ $error }}</li>
                        @endforeach
                    </ul>
                </div>
            @endif
        </div>

        <!-- Page content -->
        <main class="flex-1 overflow-y-auto px-6 pb-6">
            @yield('content')
        </main>
    </div>
</div>

<script>
    function updateClock() {
        const now = new Date();
        document.getElementById('clock').textContent = now.toLocaleTimeString('pt-BR');
    }
    setInterval(updateClock, 1000);
    updateClock();
</script>

@stack('scripts')
</body>
</html>
