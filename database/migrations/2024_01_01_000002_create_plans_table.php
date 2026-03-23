<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Tabela de planos do Hotspot Manager.
 * Cada plano corresponde a um grupo no RADIUS (radusergroup/radgroupreply).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('plans', function (Blueprint $table) {
            $table->id();

            // Nome amigável exibido na interface
            $table->string('name', 100);

            // Nome do grupo RADIUS — deve ser único e igual ao groupname em radusergroup
            $table->string('group_name', 64)->unique();

            // Descrição do plano
            $table->text('description')->nullable();

            // Velocidade de download (ex: "10M")
            $table->string('download_rate', 20);

            // Velocidade de upload (ex: "5M")
            $table->string('upload_rate', 20);

            // Valor do Mikrotik-Rate-Limit (ex: "5M/10M") — gerado automaticamente
            $table->string('rate_limit', 40)->virtualAs("CONCAT(upload_rate, '/', download_rate)");

            // Duração em dias (0 = ilimitado)
            $table->unsignedInteger('duration_days')->default(30);

            // Preço do plano (informativo)
            $table->decimal('price', 8, 2)->default(0.00);

            // Limite de dados em MB (0 = ilimitado)
            $table->unsignedBigInteger('data_limit_mb')->default(0);

            // Plano padrão para auto-cadastro
            $table->boolean('is_default')->default(false);

            // Plano visível no portal de cadastro
            $table->boolean('is_public')->default(true);

            $table->boolean('active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('plans');
    }
};
