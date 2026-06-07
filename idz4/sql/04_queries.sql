-- 1. Глобальный COUNT
SELECT count() FROM events_distributed;

-- COUNT на каждом шарде для сравнения
SELECT hostName(), count() FROM events_local GROUP BY hostName();

-- 2. TOP-10 пользователей (GROUP BY по шардированному ключу — эффективно)
SELECT user_id, count() AS events
FROM events_distributed
GROUP BY user_id
ORDER BY events DESC
LIMIT 10;

-- 3. TOP-10 страниц (GROUP BY без шардированного ключа — shuffle между шардами)
SELECT page_url, count() AS visits
FROM events_distributed
GROUP BY page_url
ORDER BY visits DESC
LIMIT 10;

-- 4. JOIN через GLOBAL IN (решение проблемы broadcast JOIN)
SELECT e.user_id, u.name, u.segment, count() AS events
FROM events_distributed e
GLOBAL JOIN user_dict_distributed u ON e.user_id = u.user_id
GROUP BY e.user_id, u.name, u.segment
ORDER BY events DESC
LIMIT 10;

-- 5. Проверка распределения данных по шардам
SELECT hostName() AS host, uniq(user_id) AS unique_users, count() AS rows
FROM events_local
GROUP BY host;
