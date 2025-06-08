-- 1. Запрос с использованием автономных подзапросов
-- Автономный подзапрос — это вложенный запрос, который не зависит от внешнего и выполняется отдельно.
-- Клиенты, у которых сумма хотя бы одного заказа превышает среднюю общую сумму заказов по всем клиентам.

SELECT DISTINCT c.Full_Name, o.Total_Amount -- Убрать дубликаты
FROM Clients c
JOIN Orders o ON c.Client_ID = o.Client_ID
WHERE o.Total_Amount > (
    SELECT AVG(Total_Amount) -- Автономный
    FROM Orders
);

-- 2. Запрос с использованием коррелированных подзапросов в SELECT и WHERE
-- Коррелированный подзапрос — зависит от внешнего запроса, выполняется для каждой строки внешнего запроса.
-- Для каждого клиента показать общее количество заказов и только тех, у кого сумма всех заказов больше 10000.

SELECT 
    c.Full_Name,
    (SELECT COUNT(*) 
     FROM Orders o 
     WHERE o.Client_ID = c.Client_ID) AS Order_Count
FROM Clients c
WHERE (
    SELECT SUM(o.Total_Amount)
    FROM Orders o
    WHERE o.Client_ID = c.Client_ID
) > 50000
LIMIT 100;


-- 3. Запрос с использованием временных таблиц
-- Временная таблица — это таблица, которая существует только во время этого соединения
-- Временная таблица с заказами на сумму больше 3000
CREATE TEMP TABLE temp_high_value_orders AS
SELECT *
FROM Orders
WHERE Total_Amount > 30000;

-- Количество клиентов, у которых есть заказы на сумму больше 30000
SELECT COUNT(DISTINCT t.Client_ID) AS High_Value_Clients
FROM temp_high_value_orders t;


-- 4. Запрос с использованием обобщенных табличных выражений (CTE)
-- CTE — временная таблица, доступная только в рамках текущего запроса.
-- Используем CTE для подсчета общей суммы заказов каждого клиента
WITH Client_Total_Orders AS (
    SELECT Client_ID, SUM(Total_Amount) AS Total_Spent
    FROM Orders
    GROUP BY Client_ID
)
-- Выводим информацию о клиентах, чья общая сумма заказов превышает 30000
SELECT c.Full_Name, cto.Total_Spent
FROM Clients c
JOIN Client_Total_Orders cto ON c.Client_ID = cto.Client_ID
WHERE cto.Total_Spent > 30000;


-- 5. Слияние данных (INSERT, UPDATE) с помощью инструкции MERGE.
-- MERGE используется для объединения данных из разных таблиц
-- Обновляем зарплату механиков с опытом более 5 лет на 10%
MERGE INTO Mechanics AS m
USING (
    SELECT Mechanic_ID
    FROM Mechanics
    WHERE Experience > 5
) AS experienced_mechanics
ON m.Mechanic_ID = experienced_mechanics.Mechanic_ID
WHEN MATCHED THEN
    UPDATE SET Salary = Salary * 1.10
WHEN NOT MATCHED THEN
    INSERT (Full_Name, Phone_Number, Qualification, Salary, Experience)
    VALUES ('Новый Механик', '+79161234567', 'Механик', 45000, 1);


-- 6. Запрос с использованием оператора PIVOT
-- Оператор PIVOT преобразует строки в столбцы. Но Pivot не существует в postgressql
CREATE EXTENSION IF NOT EXISTS tablefunc;

-- Используем crosstab для создания сводной таблицы по месяцам
SELECT *
FROM crosstab(
  'SELECT c.Full_Name, EXTRACT(MONTH FROM o.Order_Date) AS Order_Month, COUNT(o.Order_ID)
   FROM Clients c
   JOIN Orders o ON c.Client_ID = o.Client_ID
   GROUP BY c.Full_Name, EXTRACT(MONTH FROM o.Order_Date)
   ORDER BY c.Full_Name, Order_Month',
  'SELECT DISTINCT EXTRACT(MONTH FROM Order_Date) FROM Orders ORDER BY 1'
) AS pivot_table(
  Full_Name TEXT,
  "1" INT,
  "2" INT,
  "3" INT,
  "4" INT,
  "5" INT,
  "12" INT
);


-- 7. Запрос с использованием оператора  UN PIVOT.
-- UNPIVOT - это операция, которая преобразует данные, переворачивая столбцы в строки.
-- Сначала создаем сводную таблицу
WITH pivot_table AS (
  SELECT *
  FROM crosstab(
    'SELECT c.Full_Name, EXTRACT(MONTH FROM o.Order_Date) AS Order_Month, COUNT(o.Order_ID)
     FROM Clients c
     JOIN Orders o ON c.Client_ID = o.Client_ID
     GROUP BY c.Full_Name, EXTRACT(MONTH FROM o.Order_Date)
     ORDER BY c.Full_Name, Order_Month',
    'SELECT DISTINCT EXTRACT(MONTH FROM Order_Date) FROM Orders ORDER BY 1'
  ) AS pivot(
    Full_Name TEXT,
    "1" INT,
    "2" INT,
    "3" INT,
    "4" INT,
    "5" INT,
    "12" INT
  )
)

-- Применяем UNPIVOT с UNION ALL для преобразования столбцов в строки
SELECT Full_Name, '1' AS Month, "1" AS Order_Count FROM pivot_table
UNION ALL
SELECT Full_Name, '2' AS Month, "2" AS Order_Count FROM pivot_table
UNION ALL
SELECT Full_Name, '3' AS Month, "3" AS Order_Count FROM pivot_table
UNION ALL
SELECT Full_Name, '4' AS Month, "4" AS Order_Count FROM pivot_table
UNION ALL
SELECT Full_Name, '5' AS Month, "5" AS Order_Count FROM pivot_table
UNION ALL
SELECT Full_Name, '12' AS Month, "12" AS Order_Count FROM pivot_table;



--8.Запрос с использованием GROUP BY с операторами ROLLUP, CUBE и GROUPING SETS.

-- ROLLUP - суммирование по группам и подгруппам
-- Итог по каждому клиенту и общий итог в конце
SELECT 
    c.Full_Name,
    pt.Payment_Name,
    SUM(o.Total_Amount) AS Total_Sum
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID
JOIN Payment_Types pt ON o.Payment_Method_ID = pt.Payment_Type_ID
GROUP BY ROLLUP (c.Full_Name, pt.Payment_Name)
ORDER BY c.Full_Name, pt.Payment_Name;

-- CUBE - всем возможным комбинациям
-- CUBE Итог по каждому клиенту, по каждому способу оплаты и общий ито
SELECT 
    c.Full_Name,
    pt.Payment_Name,
    SUM(o.Total_Amount) AS Total_Sum
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID
JOIN Payment_Types pt ON o.Payment_Method_ID = pt.Payment_Type_ID
GROUP BY CUBE (c.Full_Name, pt.Payment_Name)
ORDER BY c.Full_Name, pt.Payment_Name;


-- GROUPING SETS - выбор конкретных группировок.
--  Отдельно по клиентам и отдельно по способам оплаты
SELECT 
    c.Full_Name,
    pt.Payment_Name,
    SUM(o.Total_Amount) AS Total_Sum
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID
JOIN Payment_Types pt ON o.Payment_Method_ID = pt.Payment_Type_ID
GROUP BY GROUPING SETS (
    (c.Full_Name),
    (pt.Payment_Name),
    ()
)
ORDER BY c.Full_Name, pt.Payment_Name;


-- 9. Секционирование с использованием OFFSET FETCH
-- OFFSET пропускает N строк, а FETCH NEXT выбирает следующие M строк.

-- Вывести заказы с 3 по 5
SELECT 
    o.Order_ID,    
    c.Full_Name,      
    o.Order_Date,     
    o.Total_Amount    
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID
ORDER BY o.Order_Date DESC 
OFFSET 2 ROWS -- Пропускаем первые 2 строки (заказа)
FETCH NEXT 3 ROWS only; -- выбираем следующие 3 строки



-- 10. Запросы с использованием ранжирующих оконных функций
-- ROW_NUMBER, RANK, DENSE_RANK, NTILE – применяются для нумерации и ранжирования строк в пределах группы.

-- Нумерация заказов по каждому клиенту (по дате), с использованием ROW_NUMBER
SELECT 
    o.Order_ID,
    c.Full_Name,
    o.Order_Date,
    o.Total_Amount,
    ROW_NUMBER() OVER (PARTITION BY c.Client_ID ORDER BY o.Order_Date) AS Row_Num -- Нумерация по клиенту
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID;	


-- RANK – одинаковым значениям присваивается одинаковый ранг,  10к - 1, 10к - 1, 2к - 3
    o.Order_ID,
    c.Full_Name,
    o.Total_Amount,
    RANK() OVER (PARTITION BY c.Client_ID ORDER BY o.Total_Amount DESC) AS Rank_Value
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID;

-- DENSE_RANK – одинаковым значениям присваивается одинаковый ранг, но следующий не пропускается, 10к - 1, 10к - 1, 2к - 2
SELECT 
    o.Order_ID,
    c.Full_Name,
    o.Total_Amount,
    DENSE_RANK() OVER (PARTITION BY c.Client_ID ORDER BY o.Total_Amount DESC) AS Dense_Rank_Value
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID;

-- NTILE – разбивает строки на равные группы (например, 3 группы по сумме заказа), если у клиента 6 заказов то три группы по 2
SELECT 
    o.Order_ID,
    c.Full_Name,
    o.Total_Amount,
    NTILE(3) OVER (PARTITION BY c.Client_ID ORDER BY o.Total_Amount DESC) AS Tercile -- Делим на 3 группы
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID;


-- 11. Перенаправление ошибок в TRY/CATCH
-- TRY...CATCH позволяет отлавливать ошибки
-- В postgress - EXCEPTION

DO $$
BEGIN
    -- Попытка вставки дубликата (пользовательское исключение внутри функции/триггера)
    INSERT INTO Cars (owner_id, Model, Color, License_Plate)
    VALUES (1, 'Lada Vesta', 'Белый', 'М112АО164');
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM; -- Показываем текст ошибки
END;
$$;


-- 12. Создание процедур обработки ошибок в блоке EXCEPTION с использованием функций получения информации об ошибке

DO $$
DECLARE
    v_sqlstate TEXT;
    v_message TEXT;
    v_detail TEXT;
BEGIN
    INSERT INTO Cars (Owner_ID, Model, Color, License_Plate)
    VALUES (1, 'Lada Vesta', 'Белый', 'М112АО164');
EXCEPTION
    WHEN OTHERS THEN
        -- Получаем информацию об ошибке
        GET STACKED DIAGNOSTICS -- Аналог Error
            v_sqlstate = RETURNED_SQLSTATE,
            v_message = MESSAGE_TEXT,
            v_detail = PG_EXCEPTION_DETAIL;

        RAISE NOTICE 'Код ошибки: %, Сообщение: %, Детали: %', v_sqlstate, v_message, v_detail;
END;
$$;


-- 13. Использование THROW (RAISE EXCEPTION в PostgreSQL)

DO $$
DECLARE
    v_amount NUMERIC;
BEGIN
    SELECT Total_Amount INTO v_amount
    FROM Orders
    WHERE Order_ID = 2; -- например, заказ с ID = 2

    IF v_amount > 100000 THEN
        RAISE EXCEPTION 'Сумма заказа слишком велика: % руб.', v_amount;
    ELSE
        RAISE NOTICE 'Сумма в пределах нормы: % руб.', v_amount;
    END IF;
END;
$$;

-- 14. Контроль транзакций с BEGIN и COMMIT

BEGIN;

-- Вставка нового заказа
INSERT INTO Orders (Car_ID, Order_Date, Payment_Method_ID, Workplace_ID, Client_ID, Total_Amount)
VALUES (3, CURRENT_DATE, 1, 2, 3, 7000.00)
RETURNING Order_ID;

-- Далее можно вставить связанные записи в Parts_in_Orders и Services_in_Orders
-- Пример ниже зависит от возвращённого Order_ID, для простоты можно представить ID = 6

-- Добавим запчасти
INSERT INTO Parts_in_Orders (Part_ID, Order_ID, Quantity)
VALUES (10, 6, 2);

-- Добавим услуги
INSERT INTO Services_in_Orders (Service_ID, Order_ID, Mechanic_ID, Quantity)
VALUES (10, 6, 1, 1); -- Поставить id механика 1, и ничего не выйдет

COMMIT; -- Фиксируем все изменения


rollback;


-- 15. Использование XACT_ABORT
-- В postgress - rollback, отмена того, что сделал

SELECT AVG(Salary) FROM Mechanics;

-- Добавляем механика, если среднее за стало больше, то rollback
BEGIN;

-- Добавляем нового механика
INSERT INTO Mechanics (Full_Name, Phone_Number, Qualification, Salary, Experience)
VALUES ('Иван Иванов', '+79160001234', 'Автомеханик', 100000.00, 5);

-- Проверяем средний уровень зарплаты после добавления нового механика
DO $$
DECLARE
    avg_salary DECIMAL;
BEGIN
    -- Получаем среднюю зарплату всех механиков
    SELECT AVG(Salary) INTO avg_salary FROM Mechanics;

    IF avg_salary > 970000 THEN
        ROLLBACK;  -- Откатываем все изменения в транзакции
        RAISE NOTICE 'Средний уровень зарплаты слишком высок! Транзакция отменена.';
    ELSE
        COMMIT;
    END IF;
END $$;

-- Пробуем это
SELECT AVG(Salary) FROM Mechanics;

-- После rollback заработает
ROLLBACK;


-- 15. Добавление логики обработки транзакций в блоке CATCH - аналог EXCEPTION
-- Если в блоке TRY происходит ошибка, откатываем транзакцию и логируем сообщение об ошибке

DO $$
DECLARE
    v_order_id INTEGER;
BEGIN
    BEGIN
        -- Начало транзакции
        INSERT INTO Orders (Car_ID, Order_Date, Payment_Method_ID, Workplace_ID, Client_ID, Total_Amount)
        VALUES (3, CURRENT_DATE, 99, 1, 3, 5000.00)  -- Ошибка: нет метода оплаты с ID 99
        RETURNING Order_ID INTO v_order_id;

        -- Если здесь ошибка — она будет перехвачена
        INSERT INTO Parts_in_Orders (Part_ID, Order_ID, Quantity)
        VALUES (1, v_order_id, 1);

        COMMIT; -- Подтверждаем, если всё успешно

    EXCEPTION WHEN OTHERS THEN
        -- Откат, если произошла ошибка
        ROLLBACK;
        RAISE NOTICE 'Ошибка в транзакции: %', SQLERRM;
    END;
END;
$$;




--4. Запросы с использованием ранжирующих оконных функций OVER (PARTITION BY...)
--   Использовать функции нумерации строк ROW_NUMBER(), RANK(), DENSE_RANK(),
--   CUME_DIST(), NTILE(), LAG(), LEAD(), FIRST_VALUE(), LAST_VALUE(), NTH_VALUE().

-- ROW_NUMBER — уникальный номер строки внутри группы
-- ROW_NUMBER: Нумерация заказов по каждому клиенту (по дате)
SELECT 
    o.Order_ID,
    c.Full_Name,
    o.Order_Date,
    o.Total_Amount,
    ROW_NUMBER() OVER (PARTITION BY c.Client_ID ORDER BY o.Order_Date) AS Row_Num
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID;

-- RANK — одинаковым значениям присваивается одинаковый ранг, с пропусками;
-- RANK: Ранг заказов по сумме (с пропусками при равенстве)
SELECT 
    o.Order_ID,
    c.Full_Name,
    o.Total_Amount,
    RANK() OVER (PARTITION BY c.Client_ID ORDER BY o.Total_Amount DESC) AS Rank_Value
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID;


-- DENSE_RANK — одинаковым значениям присваивается одинаковый ранг, без пропусков;
-- DENSE_RANK: Ранг заказов без пропусков
SELECT 
    o.Order_ID,
    c.Full_Name,
    o.Total_Amount,
    DENSE_RANK() OVER (PARTITION BY c.Client_ID ORDER BY o.Total_Amount DESC) AS Dense_Rank_Value
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID;

-- NTILE — разбивает строки в группе на n равных частей;
-- NTILE: Разделение заказов на 2 группы по сумме
SELECT 
    o.Order_ID,
    c.Full_Name,
    o.Total_Amount,
    NTILE(2) OVER (PARTITION BY c.Client_ID ORDER BY o.Total_Amount DESC) AS Tercile
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID;

-- CUME_DIST — относительное положение строки среди всех в группе (доля строк ≤ текущей);
-- CUME_DIST: Процент заказов с суммой <= текущей внутри клиента
SELECT 
    o.Order_ID,
    c.Full_Name,
    o.Total_Amount,
    CUME_DIST() OVER (PARTITION BY c.Client_ID ORDER BY o.Total_Amount) AS Cumulative_Distribution
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID;

-- LAG — значение предыдущей строки;
-- LAG: Сумма предыдущего заказа клиента
SELECT 
    o.Order_ID,
    c.Full_Name,
    o.Order_Date,
    o.Total_Amount,
    LAG(o.Total_Amount) OVER (PARTITION BY c.Client_ID ORDER BY o.Order_Date) AS Previous_Amount
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID;

-- LEAD — значение следующей строки;
-- LEAD: Сумма следующего заказа клиента
SELECT 
    o.Order_ID,
    c.Full_Name,
    o.Order_Date,
    o.Total_Amount,
    LEAD(o.Total_Amount) OVER (PARTITION BY c.Client_ID ORDER BY o.Order_Date) AS Next_Amount
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID;


-- FIRST_VALUE — первое значение в группе;
-- FIRST_VALUE: Первая сумма заказа клиента
SELECT 
    o.Order_ID,
    c.Full_Name,
    o.Total_Amount,
    FIRST_VALUE(o.Total_Amount) OVER (PARTITION BY c.Client_ID ORDER BY o.Order_Date) AS First_Amount
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID;


-- LAST_VALUE — последнее значение в группе;
-- LAST_VALUE: Последняя сумма заказа клиента
SELECT 
    o.Order_ID,
    c.Full_Name,
    o.Total_Amount,
    LAST_VALUE(o.Total_Amount) OVER (
        PARTITION BY c.Client_ID 
        ORDER BY o.Order_Date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED following -- Чтобы действительно последняя
    ) AS Last_Amount
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID;

-- NTH_VALUE — n-ое значение в группе.
-- NTH_VALUE: Вторая сумма заказа клиента
SELECT 
    o.Order_ID,
    c.Full_Name,
    o.Total_Amount,
    NTH_VALUE(o.Total_Amount, 2) OVER (
        PARTITION BY c.Client_ID 
        ORDER BY o.Order_Date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS Second_Amount
FROM Orders o
JOIN Clients c ON o.Client_ID = c.Client_ID;



-- 8. Запрос, трансформирующий столбцы в строки с применением UNNEST совместно с ARRAY или CROSS JOIN LATERAL
-- UNNEST — функция, превращающая массив в набор строк
SELECT 
    sub.Order_ID,
    unnested_part.part_name
FROM (
    SELECT 
        o.Order_ID,
        ARRAY_AGG(p.Part_Name) AS part_names -- ARRAY_AGG собирает множество значений в один массив
    FROM Orders o
    JOIN Parts_in_Orders po ON o.Order_ID = po.Order_ID
    JOIN Parts p ON po.Part_ID = p.Part_ID
    GROUP BY o.Order_ID
) AS sub
CROSS JOIN LATERAL UNNEST(sub.part_names) AS unnested_part(part_name); -- UNNEST — функция, превращающая массив в набор строк
-- CROSS JOIN LATERAL — позволяет для каждой строки основной таблицы выполнить функцию, зависящую от этой строки 


-- 11. Управление транзакциями:
-- контроль транзакций с BEGIN, COMMIT, ROLLBACK и SAVEPOINT;

-- вывод сообщений и ошибок RAISE;

-- обработчик ошибок EXCEPTION. Сравните стеки вызовов, получаемые конструкциями GET STACKED diagnostics
-- с элементом pg_exception_context и GET [CURRENT] DIAGNOSTICS с элементом pg_context. ,
-- чтобы передать сообщение об ошибке клиенту.

-- 1.
-- BEGIN — начало транзакции
-- COMMIT — подтверждение всех изменений в транзакции
-- ROLLBACK — откат всех изменений транзакции
-- SAVEPOINT — точка сохранения внутри транзакции, позволяет откатиться к ней, не отменяя всю транзакцию

BEGIN;  -- Начинаем транзакцию
-- Вставляем новый заказ
INSERT INTO Orders (Car_ID, Order_Date, Payment_Method_ID, Workplace_ID, Client_ID, Total_Amount)
VALUES (3, CURRENT_DATE, 1, 2, 3, 7000.00)
RETURNING Order_ID;  -- Можно сохранить возвращённый Order_ID для последующих вставок

SAVEPOINT after_order_insert;  -- Создаём точку сохранения после вставки заказа

-- Пытаемся добавить запчасти к заказу
INSERT INTO Parts_in_Orders (Part_ID, Order_ID, Quantity)
VALUES (10, currval('orders_order_id_seq'), 2);  -- currval берёт последний Order_ID в сессии

-- Пытаемся добавить услуги к заказу
INSERT INTO Services_in_Orders (Service_ID, Order_ID, Mechanic_ID, Quantity)
VALUES (10, currval('orders_order_id_seq'), 5, 1); -- Нет механика с id 0

-- Если всё успешно — подтверждаем транзакцию
COMMIT;

ROLLBACK TO SAVEPOINT after_order_insert; -- откат к сохранённой точке без отмены всей транзакции - Если так, то будет написано, что транзакция уже выполняется
-- ROLLBACK; -- отмена всей транзакции
rollback;



-- вывод сообщений и ошибок RAISE;

DO $$
DECLARE
    v_order_id INTEGER;
BEGIN
    -- Пытаемся выполнить всю логику
    BEGIN
        INSERT INTO Orders (Car_ID, Order_Date, Payment_Method_ID, Workplace_ID, Client_ID, Total_Amount)
        VALUES (3, CURRENT_DATE, 5, 2, 3, 7000.00) -- Типа оплаты 5 - нет
        RETURNING Order_ID INTO v_order_id;

        BEGIN  -- вложенный блок для попытки добавить части и услуги
            INSERT INTO Parts_in_Orders (Part_ID, Order_ID, Quantity)
            VALUES (10, v_order_id, 2);

            INSERT INTO Services_in_Orders (Service_ID, Order_ID, Mechanic_ID, Quantity)
            VALUES (10, v_order_id, 0, 1);  -- Ошибка: механика нет
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Ошибка при добавлении деталей и услуг. Ошибка: %', SQLERRM;
        END;

        RAISE NOTICE 'Заказ добавлен с ID: % (но детали и услуги могли не добавиться)', v_order_id;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING 'Ошибка при добавлении заказа. Всё откатывается. Ошибка: %', SQLERRM;
    END;
END;
$$;

-- обработчик ошибок EXCEPTION.


-- GET STACKED DIAGNOSTICS - Получает ошибку внутри блока EXCEPTION
-- GET CURRENT DIAGNOSTICS - Получает текущее состояние выполнения


DO $$
DECLARE
    v_order_id INTEGER;
    v_err_text TEXT;
    v_stack_text TEXT;
BEGIN
    BEGIN
        -- Намеренно вызовем ошибку: механика с id = -1 не существует
        INSERT INTO Services_in_Orders (Service_ID, Order_ID, Mechanic_ID, Quantity)
        VALUES (1, 1, -1, 1);

    EXCEPTION
        WHEN OTHERS THEN
            -- Сохраняем стек вызовов при ошибке
            GET STACKED DIAGNOSTICS v_stack_text = PG_EXCEPTION_CONTEXT;

            RAISE NOTICE 'GET STACKED CONTEXT: %', v_stack_text; -- Полностью ошибка
    END;

    -- Покажем обычный контекст без ошибки (GET CURRENT DIAGNOSTICS)
    GET CURRENT DIAGNOSTICS v_err_text = PG_CONTEXT;
    RAISE NOTICE 'GET CURRENT CONTEXT: %', v_err_text; -- Показывает строку ошибки, где нахожусь

END;
$$;





