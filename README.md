# Food Delivery (StackFood) - Instalador Automatizado

Este repositório contém o código-fonte do projeto Food Delivery e um **Pré-Instalador Automatizado** que configura sua VPS Ubuntu (22.04 ou 24.04 LTS) do zero, transformando-a em uma hospedagem pronta com todas as dependências e arquivos extraídos.

## 🚀 Instalação Rápida (Recomendado)

Para configurar sua VPS e preparar o projeto para a instalação web em **um único comando**, conecte-se à sua VPS via SSH e execute:

```bash
curl -sSL https://raw.githubusercontent.com/sistemacodigolucrativo/Food-Delivery/main/pre-instalador.sh | sudo bash
```

### O que este comando faz?
1.  **Prepara o Ambiente:** Instala Apache, PHP 8.2 (com extensões), MariaDB, Composer e Node.js.
2.  **Configura o Banco:** Cria automaticamente um banco de dados e usuário com senha segura.
3.  **Extrai a Aplicação:** Baixa os arquivos do Painel Administrativo deste repositório e os extrai na pasta web.
4.  **Ajusta Permissões:** Configura as permissões de pastas (`storage`, `cache`) para o servidor web.
5.  **Gera Link Final:** Entrega o link direto para você concluir a instalação pelo navegador.

---

## 🛠️ Próximos Passos (Após o comando acima)

Após a execução do comando, você verá uma tela com os dados do banco de dados gerados. Use esses dados para finalizar a instalação acessando:

**Link:** `http://SEU_IP_DA_VPS/install`

### Dados do Banco de Dados
Os dados serão exibidos no terminal, mas você também pode consultá-los a qualquer momento na VPS em:
`sudo cat /root/.food-delivery-credentials`

---

## 📋 Requisitos de Sistema
- **SO:** Ubuntu 22.04 LTS ou 24.04 LTS (Limpo/Recém-instalado).
- **Acesso:** Usuário com permissão de `sudo`.

## 📦 Componentes Instalados
- **Web:** Apache 2.4
- **PHP:** 8.2 + Extensões (bcmath, curl, gd, intl, mbstring, mysql, openssl, xml, zip, etc).
- **DB:** MariaDB Server.
- **Dev:** Composer, Node.js 18, NPM.

---
*Desenvolvido para automatizar a implantação do sistema Food Delivery.*
