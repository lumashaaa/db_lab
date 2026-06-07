CREATE TABLE IF NOT EXISTS user_dict ON CLUSTER 'cluster_2x2' (
    user_id UInt64,
    name    String,
    segment LowCardinality(String)
) ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/user_dict',
    '{replica}'
)
ORDER BY user_id;

CREATE TABLE IF NOT EXISTS user_dict_distributed ON CLUSTER 'cluster_2x2'
AS user_dict
ENGINE = Distributed('cluster_2x2', default, user_dict, xxHash64(user_id));

INSERT INTO user_dict_distributed
SELECT
    number AS user_id,
    concat('User_', toString(number)) AS name,
    ['premium', 'standard', 'trial'][number % 3 + 1] AS segment
FROM numbers(100000);
