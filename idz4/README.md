# ИДЗ-4. Шардирование в ClickHouse

Сукачева Мария, группа P4150

## Топология

2 шарда × 2 реплики = 4 узла ClickHouse.
Keeper на узлах s1r1, s1r2, s2r1 (кворум 3/3).

```
Шард 1: s1r1 (leader) + s1r2 (replica)
Шард 2: s2r1 (leader) + s2r2 (replica)
```

## Запуск

```bash
cd idz4
docker compose up -d
sleep 30

docker exec s1r1 clickhouse-client --password click123 --multiquery < sql/01_create_local.sql
docker exec s1r1 clickhouse-client --password click123 --multiquery < sql/02_create_distributed.sql
docker exec s1r1 clickhouse-client --password click123 --multiquery < sql/03_user_dict.sql

python scripts/generate_clickstream.py | docker exec -i s1r1 clickhouse-client \
  --password click123 \
  --query "INSERT INTO events_distributed FORMAT TSV"

docker exec s1r1 clickhouse-client --password click123 --multiquery < sql/04_queries.sql
```

## Структура

```
sql/01_create_local.sql      — локальная таблица ReplicatedMergeTree на каждом шарде
sql/02_create_distributed.sql — распределённая таблица Distributed
sql/03_user_dict.sql         — справочник пользователей для JOIN
sql/04_queries.sql           — аналитические запросы
config/clickhouse/cluster.xml — remote_servers, zookeeper
config/clickhouse/*_macros.xml — макросы {shard} и {replica}
config/keeper/               — конфиги Keeper (кворум из 3 узлов)
scripts/generate_clickstream.py — генератор 2M строк
checks/                      — результаты запросов
```

## Почему ключ шардирования xxHash64(user_id)

user_id выбран потому что большинство аналитических запросов группируются
по пользователю. Если данные одного user_id лежат на одном шарде, запросы
типа "топ пользователей" выполняются локально без shuffle между шардами.

event_date не подходит — данные за один день могут иметь высокую
кардинальность запросов по пользователям, а шарды будут неравномерно
нагружены в зависимости от активности по дням.

rand() не подходит — данные одного пользователя окажутся на разных шардах,
каждый GROUP BY user_id потребует shuffle.

xxHash64 даёт равномерное распределение и детерминированность:
один и тот же user_id всегда попадает на один шард.

## Проблема broadcast JOIN и решение

При JOIN с Distributed-таблицей каждый шард выполняет подзапрос к другой
Distributed-таблице. Это N×M сетевых запросов.

GLOBAL JOIN решает проблему: coordinator один раз скачивает правую таблицу
целиком и рассылает её на все шарды как broadcast. Количество запросов — N+M.

## Ребалансировка при добавлении шарда

Старые данные не перемещаются автоматически. Новые данные сразу пишутся
на все 3 шарда через новый Distributed. Ребалансировка выполняется вручную
через INSERT ... SELECT с последующим ALTER TABLE DELETE.
В продакшене используют over-sharding: создают больше шардов чем нужно,
чтобы избежать ребалансировки при росте.
