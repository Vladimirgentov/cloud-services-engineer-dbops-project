# DBOps project

Проектная работа по дисциплине **DBOps**.

В проекте выполнены:

* создание структуры БД интернет-магазина;
* нормализация схемы БД;
* заполнение таблиц тестовыми данными;
* создание индексов для ускорения отчётных запросов;
* запуск Flyway-миграций через GitHub Actions;
* запуск автотестов в GitHub Workflow.

## Состав миграций

В проект добавлены Flyway-миграции:

```text
migrations/
├── V001__create_tables.sql
├── V002__change_schema.sql
├── V003__insert_data.sql
└── V004__create_index.sql
```

Назначение миграций:

```text
V001__create_tables.sql  — создание исходной структуры таблиц.
V002__change_schema.sql  — нормализация схемы.
V003__insert_data.sql    — заполнение таблиц данными.
V004__create_index.sql   — создание индексов для отчётов.
```

## SQL-запросы для создания БД и пользователя

Для выполнения миграций и автотестов была создана отдельная база данных `store` и пользователь `store_user`.

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

## Нормализация схемы БД

В исходной схеме были обнаружены дублирующиеся данные:

* таблицы `product` и `product_info` частично дублировали информацию о товарах;
* таблицы `orders` и `orders_date` частично дублировали информацию о заказах.

В миграции `V002__change_schema.sql` схема была нормализована:

* поле `price` перенесено в таблицу `product`;
* таблица `product_info` удалена;
* поле `date_created` перенесено в таблицу `orders`;
* таблица `orders_date` удалена.

Итоговая рабочая структура после нормализации:

```text
product
orders
order_product
```

Таблица `flyway_schema_history` является служебной таблицей Flyway.

## SQL-запрос количества проданных сосисок за предыдущую неделю

Запрос показывает количество проданных сосисок каждого вида за предыдущую календарную неделю.

```sql
SELECT
    p.id,
    p.name,
    SUM(op.quantity) AS sausages_sold
FROM order_product op
JOIN orders o ON o.id = op.order_id
JOIN product p ON p.id = op.product_id
WHERE o.date_created >= date_trunc('week', CURRENT_DATE) - INTERVAL '1 week'
  AND o.date_created < date_trunc('week', CURRENT_DATE)
GROUP BY p.id, p.name
ORDER BY sausages_sold DESC;
```

Запрос для получения общего количества проданных сосисок за предыдущую календарную неделю:

```sql
SELECT
    SUM(op.quantity) AS sausages_sold_previous_week
FROM order_product op
JOIN orders o ON o.id = op.order_id
WHERE o.date_created >= date_trunc('week', CURRENT_DATE) - INTERVAL '1 week'
  AND o.date_created < date_trunc('week', CURRENT_DATE);
```

## Сравнение выполнения запроса до и после создания индексов

Для анализа производительности использовался запрос с `EXPLAIN ANALYZE`.

```sql
EXPLAIN ANALYZE
SELECT
    p.id,
    p.name,
    SUM(op.quantity) AS sausages_sold
FROM order_product op
JOIN orders o ON o.id = op.order_id
JOIN product p ON p.id = op.product_id
WHERE o.date_created >= date_trunc('week', CURRENT_DATE) - INTERVAL '1 week'
  AND o.date_created < date_trunc('week', CURRENT_DATE)
GROUP BY p.id, p.name
ORDER BY sausages_sold DESC;
```

### До создания индексов

До создания индексов таблицы соединялись без дополнительных индексов на поля, которые участвуют в соединении заказов и товаров.

Основные проблемы:

* таблица `order_product` не имела индекса по полю `order_id`;
* таблица `orders` не имела отдельного индекса по полю `id`;
* при увеличении объёма данных соединение таблиц становится дороже;
* отчётный запрос вынужден обрабатывать больше строк без дополнительной оптимизации по ключевым полям соединения.

### После создания индексов

В миграции `V004__create_index.sql` были добавлены индексы:

```sql
CREATE INDEX idx_order_product_order_id ON order_product(order_id);

CREATE INDEX idx_orders_id ON orders(id);
```

После создания индексов PostgreSQL получил возможность эффективнее выполнять соединение таблиц `orders` и `order_product`.

Сравнение:

| Состояние         | Индексы                                                        | Результат                                                                       |
| ----------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| До оптимизации    | Индексы для отчётного запроса отсутствуют                      | Запрос выполняется менее эффективно при росте объёма данных                     |
| После оптимизации | Созданы индексы `idx_order_product_order_id` и `idx_orders_id` | Соединение таблиц выполняется быстрее, стоимость выполнения запроса уменьшается |

Итог: добавление индексов улучшает выполнение отчётного запроса, так как поля, участвующие в соединении таблиц, становятся индексированными.

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

* `TestTask1` — создание исходной схемы;
* `TestTask2` — нормализация схемы и наличие данных;
* `TestTask3` — создание индексов.

Итоговый статус workflow:

```text
Success
```
