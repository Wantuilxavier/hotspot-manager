<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Corrige o tipo da coluna authdate em radpostauth.
 *
 * O FreeRADIUS insere NOW() nesta coluna. Com VARCHAR(32) o valor é armazenado
 * como string, impedindo consultas e ordenação por data. TIMESTAMP permite uso
 * de funções de data (DATE_FORMAT, BETWEEN, etc.) e ordenação correta.
 *
 * ATENÇÃO: dados existentes em VARCHAR são convertidos automaticamente pelo
 * MySQL/MariaDB se estiverem no formato "YYYY-MM-DD HH:MM:SS". Dados em
 * outros formatos serão convertidos para NULL.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('radpostauth', function (Blueprint $table) {
            $table->timestamp('authdate')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('radpostauth', function (Blueprint $table) {
            $table->string('authdate', 32)->default('')->change();
        });
    }
};
