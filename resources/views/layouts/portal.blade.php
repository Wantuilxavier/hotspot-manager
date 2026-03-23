<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'Acesso Hotspot')</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
</head>
<body class="bg-gradient-to-br from-blue-600 to-blue-900 min-h-screen flex items-center justify-center p-4">

    <div class="w-full max-w-md">
        <!-- Logo / Header -->
        <div class="text-center mb-8">
            <div class="inline-flex items-center justify-center w-20 h-20 bg-white rounded-full shadow-lg mb-4">
                <i class="fas fa-wifi text-blue-600 text-3xl"></i>
            </div>
            <h1 class="text-white text-2xl font-bold">@yield('header-title', 'Hotspot')</h1>
            <p class="text-blue-200 text-sm mt-1">@yield('header-subtitle', 'Conecte-se à internet')</p>
        </div>

        <!-- Card -->
        <div class="bg-white rounded-2xl shadow-xl overflow-hidden">
            @yield('content')
        </div>

        <p class="text-center text-blue-200 text-xs mt-6">
            &copy; {{ date('Y') }} Hotspot Manager — Todos os direitos reservados
        </p>
    </div>

@stack('scripts')
</body>
</html>
