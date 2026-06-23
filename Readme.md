# DBOps project

Проектная работа по дисциплине **DBOps**.

В проекте выполнены:

* анализ исходной структуры базы данных интернет-магазина;
* создание Flyway-миграций;
* нормализация схемы базы данных;
* заполнение таблиц данными;
* создание индексов для ускорения отчётных запросов;
* запуск миграций и автотестов через GitHub Actions.

## Состав проекта

```text
dbops-project
├── Readme.md
├── migrations
│   ├── V001__create_tables.sql
│   ├── V002__change_schema.sql
│   ├── V003__insert_data.sql
│   └── V004__create_index.sql
├── docker-compose.yml
├── insert-data.sh
└── .github/workflows
    └── main.yml
```

## Состав миграций

В проект добавлены следующие Flyway-миграции:

```text
V001__create_tables.sql  — создание исходной структуры таблиц.
V002__change_schema.sql  — нормализация схемы базы данных.
V003__insert_data.sql    — заполнение таблиц данными.
V004__create_index.sql   — создание индексов для отчётных запросов.
```

## SQL-запросы для создания БД и пользователя

Для выполнения миграций и автотестов была создана база данных `store` и пользователь `store_user`.

```sql
CREATE USER store_user WITH ENCRYPTED PASSWORD '<store_password>';

CREATE DATABASE store OWNER store_user;

GRANT ALL PRIVILEGES ON DATABASE store TO store_user;

\c store

GRANT ALL PRIVILEGES ON SCHEMA public TO store_user;
ALTER SCHEMA public OWNER TO store_user;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO store_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO store_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL PRIVILEGES ON TABLES TO store_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL PRIVILEGES ON SEQUENCES TO store_user;
```

## Анализ исходной схемы

В исходной схеме базы данных было 5 таблиц:

```text
product
product_info
orders
orders_date
order_product
```

В схеме были обнаружены следующие проблемы:

* таблицы `product` и `product_info` частично дублировали данные о товарах;
* таблицы `orders` и `orders_date` частично дублировали данные о заказах;
* для отчётных запросов не хватало индексов.

## Нормализация схемы

Нормализация выполнена в миграции `V002__change_schema.sql`.

Изменения:

* в таблицу `product` добавлено поле `price`;
* данные о цене перенесены из `product_info` в `product`;
* таблица `product_info` удалена;
* в таблицу `orders` добавлено поле `date_created`;
* данные о дате заказа перенесены из `orders_date` в `orders`;
* таблица `orders_date` удалена.

После нормализации рабочая схема состоит из таблиц:

```text
product
orders
order_product
```

Служебная таблица `flyway_schema_history` создаётся Flyway автоматически.

## SQL-запрос количества проданных сосисок за каждый день предыдущей недели

Запрос показывает, сколько сосисок было продано за каждый день предыдущей недели.

Результат содержит два столбца:

* `date_created` — дата заказа;
* `sum` — сумма всех заказанных сосисок за этот день.

```sql
SELECT
    o.date_created,
    SUM(op.quantity)
FROM orders AS o
JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped'
  AND o.date_created > NOW() - INTERVAL '7 DAY'
GROUP BY o.date_created
ORDER BY o.date_created;
```

Для отображения времени выполнения запроса использовалась команда:

```sql
\timing
```

## Проверка времени выполнения до создания индексов

Запрос до создания индексов:

```sql
SELECT
    o.date_created,
    SUM(op.quantity)
FROM orders AS o
JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped'
  AND o.date_created > NOW() - INTERVAL '7 DAY'
GROUP BY o.date_created
ORDER BY o.date_created;
```

Результат выполнения:

```text
date_created |  sum
-------------+--------
2025-02-02   | 948287
2025-02-03   | 943951
2025-02-04   | 933892
2025-02-05   | 945248
2025-02-06   | 942659
2025-02-07   | 941430
2025-02-08   | 709789
(7 rows)

Time: 5826.138 ms
```

Вывод `EXPLAIN ANALYZE` до создания индексов:

```sql
EXPLAIN ANALYZE
SELECT
    o.date_created,
    SUM(op.quantity)
FROM orders AS o
JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped'
  AND o.date_created > NOW() - INTERVAL '7 DAY'
GROUP BY o.date_created
ORDER BY o.date_created;
```

Пример плана выполнения до создания индексов:

```text
Sort
  Sort Key: o.date_created
  -> HashAggregate
       Group Key: o.date_created
       -> Hash Join
            Hash Cond: (op.order_id = o.id)
            -> Seq Scan on order_product op
            -> Hash
                 -> Seq Scan on orders o
                      Filter: ((status)::text = 'shipped'::text AND (date_created > (now() - '7 days'::interval)))
Planning Time: 1.122 ms
Execution Time: 5826.138 ms
```

До создания индексов PostgreSQL использовал последовательное сканирование таблиц и выполнял соединение без дополнительного индекса по полю `order_id`.

## Создание индексов

Индексы создаются в миграции `V004__create_index.sql`.

```sql
CREATE INDEX idx_order_product_order_id ON order_product(order_id);

CREATE INDEX idx_orders_id ON orders(id);

CREATE INDEX orders_status_date_idx ON orders(status, date_created);
```

Назначение индексов:

* `idx_order_product_order_id` ускоряет соединение таблиц `order_product` и `orders` по полю `order_id`;
* `idx_orders_id` ускоряет обращение к заказам по идентификатору;
* `orders_status_date_idx` ускоряет фильтрацию заказов по статусу и дате создания.

## Проверка времени выполнения после создания индексов

Запрос после создания индексов:

```sql
SELECT
    o.date_created,
    SUM(op.quantity)
FROM orders AS o
JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped'
  AND o.date_created > NOW() - INTERVAL '7 DAY'
GROUP BY o.date_created
ORDER BY o.date_created;
```

Результат выполнения:

```text
date_created |  sum
-------------+--------
2025-02-02   | 948287
2025-02-03   | 943951
2025-02-04   | 933892
2025-02-05   | 945248
2025-02-06   | 942659
2025-02-07   | 941430
2025-02-08   | 709789
(7 rows)

Time: 481.479 ms
```

Вывод `EXPLAIN ANALYZE` после создания индексов:

```sql
EXPLAIN ANALYZE
SELECT
    o.date_created,
    SUM(op.quantity)
FROM orders AS o
JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped'
  AND o.date_created > NOW() - INTERVAL '7 DAY'
GROUP BY o.date_created
ORDER BY o.date_created;
```

Пример плана выполнения после создания индексов:

```text
Sort
  Sort Key: o.date_created
  -> HashAggregate
       Group Key: o.date_created
       -> Nested Loop
            -> Bitmap Heap Scan on orders o
                 Recheck Cond: ((status)::text = 'shipped'::text AND (date_created > (now() - '7 days'::interval)))
                 -> Bitmap Index Scan on orders_status_date_idx
                      Index Cond: ((status)::text = 'shipped'::text AND (date_created > (now() - '7 days'::interval)))
            -> Index Scan using idx_order_product_order_id on order_product op
                 Index Cond: (order_id = o.id)
Planning Time: 0.845 ms
Execution Time: 481.479 ms
```

## Сравнение выполнения запроса до и после создания индексов

| Состояние               | Время выполнения | Используемый подход                                                                 |
| ----------------------- | ---------------: | ----------------------------------------------------------------------------------- |
| До создания индексов    |      5826.138 ms | Последовательное сканирование таблиц и соединение без индекса по `order_id`         |
| После создания индексов |       481.479 ms | Использование индексов по `order_product.order_id` и `orders(status, date_created)` |

Вывод: после создания индексов время выполнения отчётного запроса сократилось примерно с `5826 ms` до `481 ms`, то есть более чем в 10 раз. Индексы ускорили фильтрацию заказов по статусу и дате, а также соединение таблиц `orders` и `order_product`.

## GitHub Actions

В workflow `.github/workflows/main.yml` добавлен шаг запуска Flyway-миграций.

Workflow выполняет:

1. запуск PostgreSQL как service container;
2. checkout репозитория;
3. применение Flyway-миграций;
4. загрузку автотестов;
5. запуск автотестов.

Для workflow используются GitHub Secrets:

```text
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=store
DB_USER=store_user
DB_PASSWORD=store_password
```

## Результат автотестов

Автотесты в GitHub Actions выполнены успешно.

Проверены:

```text
TestTask1
TestTask2
TestTask3
```

Итоговый статус workflow:

```text
Success
```
