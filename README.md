# Pré-Instalador Automatizado para Food Delivery (StackFood)

Este repositório contém um script de pré-instalação automatizado para configurar uma Virtual Private Server (VPS) com Ubuntu 22.04 LTS ou 24.04 LTS, transformando-a em um ambiente de hospedagem convencional pronto para o projeto Food Delivery (StackFood).

O script instala e configura todas as dependências necessárias, como servidor web Apache, PHP 8.2 e suas extensões, MariaDB, Composer e Node.js, para que o projeto Food Delivery possa ser facilmente implantado e executado.

## Requisitos

- Uma VPS com **Ubuntu 22.04 LTS** ou **Ubuntu 24.04 LTS** (recém-instalado é o ideal).
- Acesso SSH à VPS com um usuário que tenha permissões `sudo`.
- Chave SSH (`.pem`) para autenticação, se aplicável.

## Como Usar

Siga os passos abaixo para preparar sua VPS:

### 1. Conectar à VPS

Utilize sua chave SSH para conectar à sua VPS. Substitua `sua_chave.pem` pelo caminho da sua chave e `seu_usuario@seu_ip` pelas suas credenciais de acesso.

```bash
chmod 600 sua_chave.pem
ssh -i sua_chave.pem seu_usuario@seu_ip
```

### 2. Transferir o Script de Pré-Instalação

Após conectar à VPS, transfira o arquivo `pre-instalador.sh` para o diretório `/home/ubuntu` na sua VPS. Você pode fazer isso do seu terminal local:

```bash
scp -i sua_chave.pem /caminho/para/pre-instalador.sh seu_usuario@seu_ip:/home/ubuntu/pre-instalador.sh
```

### 3. Executar o Script de Pré-Instalação

De volta à sessão SSH da sua VPS, execute o script com permissões de superusuário:

```bash
chmod +x /home/ubuntu/pre-instalador.sh
sudo bash /home/ubuntu/pre-instalador.sh
```

O script levará alguns minutos para ser executado, pois irá atualizar o sistema, instalar pacotes e configurar os serviços. A saída detalhada da instalação será exibida no terminal e também registrada em `/var/log/food-delivery-install.log`.

### 4. Informações Pós-Instalação

Ao final da execução do script, serão exibidas no terminal as seguintes informações cruciais:

- **Dados do Servidor:** Endereço IP, Porta HTTP, Diretório Web.
- **Dados do Banco de Dados:** Nome do Banco, Usuário e Senha gerados automaticamente.
- **Próximos Passos:** Instruções para upload e extração dos arquivos do projeto Food Delivery.
- **Link de Instalação Web:** Um URL clicável para continuar a instalação do projeto através do navegador.

As credenciais do banco de dados e outras informações importantes também serão salvas no arquivo `/root/.food-delivery-credentials` na sua VPS. Guarde-as em segurança.

### 5. Finalizar a Instalação do Projeto Food Delivery

1. **Faça o upload** do arquivo `Admin panel new install V9.0.zip` (ou a versão mais recente do painel administrativo do Food Delivery) para o diretório `/var/www/html/food-delivery` na sua VPS.

2. **Extraia os arquivos** dentro do diretório do projeto. Você pode fazer isso via SSH:
   ```bash
   cd /var/www/html/food-delivery
   unzip 'Admin panel new install V9.0.zip'
   ```

3. **Ajuste as permissões** dos arquivos e diretórios para garantir que o servidor web tenha acesso adequado:
   ```bash
   sudo chown -R www-data:www-data /var/www/html/food-delivery
   sudo chmod -R 775 /var/www/html/food-delivery/storage /var/www/html/food-delivery/bootstrap/cache
   ```

4. **Acesse o link de instalação web** fornecido pelo script (ex: `http://SEU_IP/install`) no seu navegador para completar a configuração do Food Delivery.

## Componentes Instalados

O script instala e configura os seguintes componentes:

- **Sistema Operacional:** Ubuntu 22.04 LTS / 24.04 LTS
- **Servidor Web:** Apache 2.4
- **PHP:** Versão 8.2 (com extensões bcmath, curl, gd, mbstring, mysql, openssl, pdo, tokenizer, xml, zip, intl, soap, opcache, imagick)
- **Banco de Dados:** MariaDB Server
- **Ferramentas:** Git, Composer, Node.js (v18), NPM

## Solução de Problemas

- **Erro de permissão ao executar o script:** Certifique-se de usar `sudo bash pre-instalador.sh`.
- **Problemas de conexão SSH:** Verifique as permissões da sua chave `.pem` (`chmod 600 sua_chave.pem`) e se o IP e usuário estão corretos.
- **Falhas durante a instalação:** Consulte o arquivo de log detalhado em `/var/log/food-delivery-install.log` na sua VPS para identificar a causa do problema.

## Contribuição

Sinta-se à vontade para abrir issues ou pull requests para melhorias e correções.
