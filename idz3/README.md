# ИДЗ-3. Репликация в ClickHouse

Сукачева Мария, группа P4150

## Топология

3 узла ClickHouse (node1, node2, node3) + 3 узла ClickHouse Keeper (keeper1, keeper2, keeper3).
Keeper совмещён с отдельными контейнерами — это осознанное решение: в продакшене
Keeper принято разворачивать отдельно от ClickHouse, чтобы падение CH-узла
не влияло на кворум координации.

Схема: 1 шард, 3 реплики.

## Запуск

```bash
cd idz3
docker compose up -d

# Подождать 10-15 секунд пока поднимутся все узлы

# Создать таблицу на всех репликах
docker exec node1 clickhouse-client --multiquery < sql/01_create_table.sql

# Вставить 100 000 строк в node1
docker exec node1 clickhouse-client --multiquery < sql/02_insert_data.sql

# Проверить что данные есть на node2 и node3
docker exec node2 clickhouse-client --query "SELECT count() FROM repl.events;"
docker exec node3 clickhouse-client --query "SELECT count() FROM repl.events;"
```

## Структура

```
docker-compose.yml           — 6 контейнеров: 3 Keeper + 3 ClickHouse
config/keeper/               — конфиги Keeper (server_id 1/2/3, Raft)
config/clickhouse/cluster.xml — remote_servers, zookeeper endpoints
config/clickhouse/*_macros.xml — макросы {shard} и {replica} для каждого узла
sql/01_create_table.sql      — создание БД и таблицы ON CLUSTER
sql/02_insert_data.sql       — вставка 100 000 строк
scripts/generate_events.py   — генератор данных
checks/                      — результаты экспериментов
```

## Как работает репликация

При вставке данных в любую реплику ClickHouse записывает в Keeper лог операции.
Остальные реплики читают этот лог и применяют изменения у себя. Keeper обеспечивает
консистентность через алгоритм Raft — кворум (2 из 3 узлов) должен подтвердить
запись в лог. Поэтому при потере одного Keeper кворум сохраняется, а при потере
двух — запись блокируется, но чтение продолжает работать локально.

## Эксперименты

**A — потеря реплики:** node3 останавливается, данные вставляются в node1,
node2 получает их через репликацию. После старта node3 догоняет очередь
через system.replication_queue.

**B — потеря Keeper:** при потере одного Keeper кворум (2/3) сохраняется,
вставка работает. При потере второго кворума нет — INSERT падает с ошибкой,
но SELECT работает (данные читаются локально).

**C — конфликт данных:** конфликтов нет по дизайну — репликация детерминирована
через лог в Keeper. Все реплики применяют одни и те же операции в одном порядке.
