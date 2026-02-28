# **🤖 Telegram VPN Bot**

Проект представляет собой минимально рабочую основу для запуска собственного VPN-сервиса через Telegram-бота. Бот автоматически создаёт пользователей и выдаёт ключи для подключения по Shadowsocks, используя связку **Docker \+ Marzban \+ Python \+ Telegram Bot API**.

---

## **🚀 Что умеет бот**

* **Автоматическая генерация VPN-ключей**: Каждый запуск бота создаёт нового пользователя и выдаёт уникальный ключ для подключения.  
* **Связка с Marzban сервером**: Управление VPN осуществляется через API сервера Marzban.  
* **Поддержка локального и продакшн-окружения**: Гибкая настройка через файл окружения.  
* **Расширяемая бизнес-логика**: Проект готов к дальнейшей доработке и масштабированию под новые задачи.

---

## **📦 Стек технологий**

* **Python**  
* **Docker / Docker Compose**  
* **Marzban**  
* **Telegram Bot API**  
* **Shadowsocks**  
* **Certbot / Let's Encrypt**

---

## **🔧 Установка и запуск**

### **Server deployment (white IP)**

Для развёртывания на VPS с белым IP и `VLESS + Reality` используйте отдельную инструкцию:  
[DEPLOY_SERVER.md](DEPLOY_SERVER.md)

### **1\. Клонирование репозитория**

Клонируйте репозиторий и перейдите в его директорию:

```bash
git clone https://github.com/yarodya1/telegram-vpn-bot.git  
cd telegram-vpn-bot
```

### **2\. Создание и настройка файлов окружения**

Скопируйте шаблоны файлов с настройками:

```bash
cat env.dist > .env  
cat env.marzban.dist > .env.marzban
```

**Основные параметры файла:**

* `BOT_TOKEN='TOKEN'` – Токен Telegram-бота. Его можно получить через @BotFather.  
* `DOMAIN='localhost'` – Домен; для локального тестирования используйте `localhost`, а для продакшена – свой домен.  
* `ADMIN=222222` – Telegram ID администратора.  
* `MARZ_HAS_CERTIFICATE=True` – Флаг использования сертификатов (актуально как для локального окружения, так и для продакшена).  
* `CERT_FULLCHAIN_PATH=''` и `CERT_KEY_PATH=''` – Пути к сертификату и ключу соответственно.

### **3. Выпуск сертификатов**

**Локальное окружение (самоподписанные сертификаты):**

Для локального тестирования можно использовать самоподписанные сертификаты:

```bash
openssl req -x509 -newkey rsa:2048 -nodes -keyout privkey.pem -out fullchain.pem -days 365 -subj "/CN=localhost"
```

После генерации сертификатов пропишите полный путь к файлам `fullchain.pem` и `privkey.pem` в файле `.env`.

**Продакшн окружение (Let's Encrypt):**

Для получения сертификатов на продакшене выполните следующие команды (пример для Alpine Linux):

```bash
apt update  
apt install certbot  
certbot certonly --standalone -d www.yourdomain.com
```

После успешного получения сертификатов обновите переменные в `.env`:

CERT_FULLCHAIN_PATH=/etc/letsencrypt/live/yourdomain_com/fullchain.pem  
CERT_KEY_PATH=/etc/letsencrypt/live/yourdomain_com/privkey.pem

### **4. Сборка и запуск проекта**

Для сборки и запуска всего проекта выполните:

```bash
./refresh.sh
```

---

## **✅ Проверка работы**

**Панель управления Marzban:**

Перейдите по адресу: [https://localhost:8002/dashboard/](https://localhost:8002/dashboard/)

Здесь можно проверить статус сервера и его настройки.

**Проверка Telegram-бота:**

Отправьте команду `/start` боту в Telegram и убедитесь, что он отвечает и выдаёт ключ для подключения.
