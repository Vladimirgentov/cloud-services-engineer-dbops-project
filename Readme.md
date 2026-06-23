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

Для проверки времени выполнения запроса использовалась команда:

```sql
\timing
```

Также для анализа плана выполнения использовался запрос:

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

## Сравнение выполнения запроса до и после создания индексов

### До создания индексов

До создания индексов отчётный запрос выполнялся менее эффективно, так как таблицы `orders` и `order_product` соединялись без дополнительного индекса по полю связи.

Проблемные места:

* в таблице `order_product` не было индекса по полю `order_id`;
* при росте количества заказов соединение таблиц становилось дороже;
* PostgreSQL приходилось обрабатывать больше строк без оптимального доступа по полю связи.

Пример выполнения запроса до создания индексов:

```text
Time: 5826.138 ms
```

### После создания индексов

В миграции `V004__create_index.sql` были созданы индексы:

```sql
CREATE INDEX idx_order_product_order_id ON order_product(order_id);

CREATE INDEX idx_orders_id ON orders(id);
```

После добавления индексов PostgreSQL получил возможность эффективнее выполнять соединение таблиц `orders` и `order_product`.

Сравнение:

| Состояние         | Индексы                                                        | Результат                    |
| ----------------- | -------------------------------------------------------------- | ---------------------------- |
| До оптимизации    | Индексы для отчётного запроса отсутствуют                      | Запрос выполняется медленнее |
| После оптимизации | Созданы индексы `idx_order_product_order_id` и `idx_orders_id` | Запрос выполняется быстрее   |

Итог: после создания индексов стоимость выполнения отчётного запроса уменьшается, так как поля, участвующие в соединении таблиц, становятся индексированными.

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
