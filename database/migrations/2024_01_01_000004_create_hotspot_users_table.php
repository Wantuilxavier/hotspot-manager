<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Tabela complementar de usuários do Hotspot.
 * Armazena dados que o schema do RADIUS não suporta (nome, telefone, etc.).
 * A autenticação real ocorre via tabelas radcheck/radreply do FreeRADIUS.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('hotspot_users', function (Blueprint $table) {
            $table->id();

            // Deve ser idêntico ao username em radcheck
            $table->string('username', 64)->unique();

            $table->string('full_name', 150)->nullable();
            $table->string('email', 150)->nullable();
            $table->string('phone', 20)->nullable();
            $table->string('document', 20)->nullable()->comment('CPF/CNPJ');

            // IP de onde o cadastro foi feito (portal captivo)
            $table->string('registered_ip', 45)->nullable();

            // MAC address do dispositivo (se enviado pelo MikroTik)
            $table->string('mac_address', 17)->nullable();

            // Plano atual
            $table->foreignId('plan_id')->nullable()->constrained('plans')->nullOnDelete();

            // Validade do acesso
            $table->date('expires_at')->nullable();

            // Status
            $table->enum('status', ['active', 'suspended', 'expired', 'pending'])->default('active');

            // Observações administrativas
            $table->text('notes')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('hotspot_users');
    }
};
