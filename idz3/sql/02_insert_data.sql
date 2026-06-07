INSERT INTO repl.events
SELECT
    now() - toIntervalSecond(rand() % 7776000) AS event_time,
    ['click', 'view', 'purchase', 'login', 'logout'][rand() % 5 + 1] AS event_type,
    rand() % 10000 AS user_id,
    concat('payload_', toString(rand() % 1000)) AS payload
FROM numbers(100000);
