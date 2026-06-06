SELECT
    column,
    formatReadableSize(sum(column_data_compressed_bytes))   AS compressed,
    formatReadableSize(sum(column_data_uncompressed_bytes)) AS uncompressed,
    round(sum(column_data_uncompressed_bytes) /
          sum(column_data_compressed_bytes), 2)             AS ratio
FROM system.parts_columns
WHERE table = 'orders_flat' AND database = 'shop' AND active
GROUP BY column
ORDER BY sum(column_data_uncompressed_bytes) DESC;

SELECT
    table,
    formatReadableSize(sum(bytes_on_disk))           AS disk_size,
    formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed,
    round(sum(data_uncompressed_bytes) / sum(bytes_on_disk), 2) AS ratio,
    sum(rows) AS total_rows
FROM system.parts
WHERE database = 'shop' AND active
GROUP BY table;
