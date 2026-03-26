# Guia de Configuração MikroTik + FreeRADIUS

## 1. Configurar o cliente RADIUS no MikroTik

Execute os comandos abaixo no **Terminal do RouterOS** (Winbox → Terminal ou SSH):

```routeros
# Adiciona o servidor RADIUS
# Substitua 192.168.1.100 pelo IP do seu servidor FreeRADIUS
# Substitua "testing123" pelo secret definido no FreeRADIUS (clients.conf)

/radius add \
    service=hotspot \
    address=192.168.1.100 \
    secret=testing123 \
    authentication-port=1812 \
    accounting-port=1813 \
    timeout=3000 \
    comment="Hotspot Manager - FreeRADIUS"
```

## 2. Configurar o Hotspot para usar RADIUS

```routeros
# Cria o perfil do Hotspot apontando para RADIUS
/ip hotspot profile set [find name=hsprof1] \
    use-radius=yes \
    radius-accounting=yes \
    nas-identifier="MikroTik-Hotspot" \
    radius-interim-update=5m \
    radius-mac-format=XX-XX-XX-XX-XX-XX

# Ou crie um novo perfil
/ip hotspot profile add \
    name=radius-profile \
    use-radius=yes \
    radius-accounting=yes \
    nas-identifier="MikroTik-Hotspot" \
    radius-interim-update=5m \
    login-by=http-pap,http-chap \
    html-directory=flash/hotspot \
    radius-mac-format=XX-XX-XX-XX-XX-XX
```

## 3. Configurar o Hotspot na interface WAN/LAN

```routeros
# Veja as interfaces disponíveis
/interface print

# Configura o Hotspot na bridge (ou interface direta)
/ip hotspot setup
# Siga o wizard e selecione o perfil "radius-profile"
```

## 4. Configurar as Queue Trees (Rate-Limit via RADIUS)

O atributo `Mikrotik-Rate-Limit` enviado pelo RADIUS criará queues **dinamicamente**.
Para isso, o Queue Type deve estar configurado:

```routeros
# Verifica os queue types disponíveis (default-small é suficiente)
/queue type print

# O MikroTik criará filas dinâmicas automaticamente quando o RADIUS
# responder com Mikrotik-Rate-Limit = "upload/download"
# Exemplo de atributo enviado: Mikrotik-Rate-Limit = "5M/10M"
#   → 5Mbps upload, 10Mbps download por usuário
```

## 5. Verificar se o RADIUS está funcionando

```routeros
# Verifica o status do RADIUS
/radius print

# Monitora o log (autenticações e erros)
/log print where topics~"radius"

# Usuários ativos no Hotspot
/ip hotspot active print

# Teste de autenticação (ferramenta embutida)
/radius incoming print
```

## 6. Configurar o Captive Portal externo (Hotspot Manager)

O Hotspot Manager funciona como portal captivo externo. O MikroTik redireciona
usuários não autenticados para o servidor Laravel, que exibe o formulário de
auto-cadastro e devolve as credenciais.

```routeros
# Redireciona usuários não autenticados para o portal externo
# Substitua 192.168.1.100 pelo IP do servidor Hotspot Manager
/ip hotspot profile set [find name=radius-profile] \
    login-by=http-pap \
    http-proxy=192.168.1.100:80

# O MikroTik passa estes parâmetros na query string para o portal:
# ?mac=XX:XX:XX:XX:XX:XX&ip=192.168.x.x&link-login=...&link-orig=...
# O portal /portal já os captura e processa automaticamente.
```

**URL do portal:** `http://IP_DO_SERVIDOR/portal`

## 7. Configurar clients.conf do FreeRADIUS

Adicione o MikroTik como cliente autorizado:

```conf
# /etc/freeradius/3.0/clients.conf

client mikrotik-hotspot {
    ipaddr  = 192.168.88.1      # IP do roteador MikroTik
    secret  = testing123         # Mesmo secret do /radius add
    shortname = mikrotik
    nastype = other
}

# Para múltiplos roteadores, adicione um bloco por roteador
# Ou use a tabela "nas" no MySQL (habilite read_clients = yes no sql.conf)
```

## 8. Schema SQL — Inserção Manual de Teste

```sql
-- Cria um usuário de teste
INSERT INTO radcheck (username, attribute, op, value)
VALUES ('teste', 'Cleartext-Password', ':=', 'senha123');

-- Associa ao grupo "basic_5mb"
INSERT INTO radusergroup (username, groupname, priority)
VALUES ('teste', 'basic_5mb', 1);

-- O rate-limit é definido no grupo:
INSERT INTO radgroupreply (groupname, attribute, op, value)
VALUES ('basic_5mb', 'Mikrotik-Rate-Limit', '=', '2M/5M');
-- ^ 2Mbps upload / 5Mbps download para todos do grupo basic_5mb

-- Verifica
SELECT rc.username, rc.attribute, rc.value AS 'senha',
       rug.groupname, rgr.attribute AS 'reply_attr', rgr.value AS 'rate_limit'
FROM radcheck rc
LEFT JOIN radusergroup rug ON rc.username = rug.username
LEFT JOIN radgroupreply rgr ON rug.groupname = rgr.groupname
WHERE rc.username = 'teste';
```

## 9. Comandos de diagnóstico FreeRADIUS

```bash
# Testa autenticação PAP
radtest teste senha123 127.0.0.1 0 testing123

# Testa autenticação com detalhes (verbose)
radtest -P pap teste senha123 127.0.0.1 1812 testing123

# Rodar o FreeRADIUS em modo debug (muito útil)
sudo systemctl stop freeradius
sudo freeradius -X

# Verificar módulo SQL
sudo freeradius -XC 2>&1 | grep -i sql

# Testar conexão com o banco
radtest -P pap usuario senha 127.0.0.1 0 secret
```

## 10. Fluxo completo de autenticação

```
Dispositivo do Usuário
    │  (HTTP request)
    ▼
MikroTik Hotspot (redireciona não-autenticados)
    │  (HTTPS redirect)
    ▼
http://SEU_SERVIDOR/portal (Captive Portal PHP/Laravel)
    │  (POST /portal/register)
    ▼
Laravel → RadiusService → MySQL
    │  (INSERT em radcheck, radusergroup, hotspot_users)
    ▼
Usuário clica "Conectar Agora" → página de login do MikroTik
    │  (username + password)
    ▼
MikroTik envia Access-Request → FreeRADIUS (porta 1812)
    │  (consulta MySQL: radcheck, radusergroup, radgroupreply)
    ▼
FreeRADIUS responde Access-Accept
    + Mikrotik-Rate-Limit = "2M/5M"
    ▼
MikroTik cria queue dinâmica para o usuário ✓
    ▼
Dispositivo navega com o rate-limit do plano
    │  (Accounting-Request Start/Interim/Stop)
    ▼
FreeRADIUS grava em radacct → Dashboard mostra sessão ativa
```

## Dicas de Segurança

- Use `secret` forte (mínimo 32 caracteres aleatórios) no clients.conf
- Restrinja o IP do cliente RADIUS no clients.conf (não use `0.0.0.0/0`)
- Configure firewall para permitir UDP 1812/1813 apenas do MikroTik:
  ```bash
  sudo ufw allow from 192.168.88.1 to any port 1812,1813 proto udp
  ```
- Use HTTPS no servidor do portal captivo
- Considere `Simultaneous-Use := 1` para evitar compartilhamento de senha
