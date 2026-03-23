<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;

/**
 * MikrotikService — Integração opcional via RouterOS API.
 *
 * Permite desconectar usuários ativos, consultar sessões em tempo real
 * e gerenciar filas diretamente no roteador.
 *
 * Requer: pear/net_routeros ou PEAR2_Net_RouterOS.
 * Instale com: composer require pear/net_routeros
 *
 * Nota: Este serviço é OPCIONAL. O controle de banda é feito via RADIUS
 * (Mikrotik-Rate-Limit), portanto esta classe serve para operações
 * administrativas em tempo real no roteador.
 */
class MikrotikService
{
    private ?object $client = null;
    private bool $enabled;

    public function __construct()
    {
        $this->enabled = config('mikrotik.enabled', false);
    }

    // ====================================================================
    // CONEXÃO
    // ====================================================================

    private function connect(): bool
    {
        if (!$this->enabled) {
            return false;
        }

        if ($this->client !== null) {
            return true;
        }

        try {
            // Usando PEAR2_Net_RouterOS
            if (!class_exists('\PEAR2\Net\RouterOS\Client')) {
                Log::warning('MikrotikService: pear/net_routeros não instalado. Execute: composer require pear/net_routeros');
                return false;
            }

            $this->client = new \PEAR2\Net\RouterOS\Client(
                config('mikrotik.host'),
                config('mikrotik.user'),
                config('mikrotik.pass'),
                config('mikrotik.port', 8728)
            );

            return true;
        } catch (\Exception $e) {
            Log::error('MikrotikService: Falha na conexão — ' . $e->getMessage());
            return false;
        }
    }

    // ====================================================================
    // HOTSPOT
    // ====================================================================

    /**
     * Lista usuários ativos no Hotspot do MikroTik.
     */
    public function getActiveHotspotUsers(): array
    {
        if (!$this->connect()) return [];

        try {
            $request = new \PEAR2\Net\RouterOS\Request('/ip/hotspot/active/print');
            $responses = $this->client->sendSync($request);
            $users = [];

            foreach ($responses as $response) {
                if ($response->getType() === \PEAR2\Net\RouterOS\Response::TYPE_DATA) {
                    $users[] = [
                        'id'       => $response->getProperty('.id'),
                        'server'   => $response->getProperty('server'),
                        'user'     => $response->getProperty('user'),
                        'address'  => $response->getProperty('address'),
                        'mac'      => $response->getProperty('mac-address'),
                        'uptime'   => $response->getProperty('uptime'),
                        'rx_bytes' => $response->getProperty('bytes-in'),
                        'tx_bytes' => $response->getProperty('bytes-out'),
                    ];
                }
            }

            return $users;
        } catch (\Exception $e) {
            Log::error('MikrotikService::getActiveHotspotUsers — ' . $e->getMessage());
            return [];
        }
    }

    /**
     * Desconecta um usuário do Hotspot pelo username.
     */
    public function disconnectUser(string $username): bool
    {
        if (!$this->connect()) return false;

        try {
            // Encontra a sessão ativa
            $findReq = new \PEAR2\Net\RouterOS\Request('/ip/hotspot/active/print');
            $findReq->setQuery(\PEAR2\Net\RouterOS\Query::where('user', $username));
            $responses = $this->client->sendSync($findReq);

            foreach ($responses as $response) {
                if ($response->getType() === \PEAR2\Net\RouterOS\Response::TYPE_DATA) {
                    $removeReq = new \PEAR2\Net\RouterOS\Request('/ip/hotspot/active/remove');
                    $removeReq->setArgument('.id', $response->getProperty('.id'));
                    $this->client->sendSync($removeReq);
                    Log::info("MikrotikService: Usuário {$username} desconectado.");
                }
            }

            return true;
        } catch (\Exception $e) {
            Log::error('MikrotikService::disconnectUser — ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Retorna informações do roteador (uptime, versão do RouterOS).
     */
    public function getRouterInfo(): array
    {
        if (!$this->connect()) return [];

        try {
            $request = new \PEAR2\Net\RouterOS\Request('/system/resource/print');
            $responses = $this->client->sendSync($request);

            foreach ($responses as $response) {
                if ($response->getType() === \PEAR2\Net\RouterOS\Response::TYPE_DATA) {
                    return [
                        'uptime'         => $response->getProperty('uptime'),
                        'version'        => $response->getProperty('version'),
                        'cpu_load'       => $response->getProperty('cpu-load'),
                        'free_memory'    => $response->getProperty('free-memory'),
                        'total_memory'   => $response->getProperty('total-memory'),
                        'free_hdd'       => $response->getProperty('free-hdd-space'),
                        'board_name'     => $response->getProperty('board-name'),
                        'architecture'   => $response->getProperty('architecture-name'),
                    ];
                }
            }
        } catch (\Exception $e) {
            Log::error('MikrotikService::getRouterInfo — ' . $e->getMessage());
        }

        return [];
    }

    public function isEnabled(): bool
    {
        return $this->enabled;
    }
}
