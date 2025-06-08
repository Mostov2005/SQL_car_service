-- 1. Создание составного типа для хранения информации о запчасти
CREATE TYPE part_info AS (
    part_name VARCHAR(100),
    manufacturer VARCHAR(100)
);

-- 1. Реализация функции для получения ID запчасти по названию и производителю
CREATE OR REPLACE FUNCTION get_part_id(part_details part_info) 
RETURNS INTEGER AS $$
DECLARE
    result_part_id INTEGER;
BEGIN
    -- Поиск ID запчасти по названию и производителю
    SELECT Parts.Part_ID INTO result_part_id
    FROM Parts
    WHERE Parts.Part_Name = part_details.part_name
    AND Parts.Manufacturer = part_details.manufacturer
    LIMIT 1;

    -- Если запчасть не найдена, выбрасываем исключение
    IF result_part_id IS NULL THEN
        RAISE EXCEPTION 'Запчасть не найдена: % - %', part_details.part_name, part_details.manufacturer;
    END IF;

    -- Возвращаем найденный ID запчасти
    RETURN result_part_id;
END;
$$ LANGUAGE plpgsql;


-- 1. Пример вызова функции get_part_id с передачей параметров
SELECT get_part_id(('Воздушный фильтр', 'Valeo')::part_info);


-- 2. Создание функции для получения ID услуги по названию
CREATE OR REPLACE FUNCTION get_service_id(input_service_name VARCHAR)
RETURNS INTEGER AS $$
DECLARE
    result_service_id INTEGER; -- Переменная для хранения ID услуги
BEGIN
    -- Поиск ID услуги по названию
    SELECT Service_ID INTO result_service_id
    FROM Services
    WHERE Service_Name = input_service_name
    LIMIT 1;

    -- Если услуга не найдена, выбрасываем исключение
    IF result_service_id IS NULL THEN
        RAISE EXCEPTION 'Услуга не найдена: %', input_service_name;
    END IF;

    -- Возвращаем найденный ID услуги
    RETURN result_service_id;
END;
$$ LANGUAGE plpgsql;



-- 2. Пример вызова функции get_service_id
SELECT get_service_id('Покраска кузова');

-- 3. Создание составного типа для передачи производителя и списка названий запчастей
CREATE TYPE part_list_info AS (
    manufacturer VARCHAR,
    part_names TEXT[]
);

-- 3. Создание функции для получения ID запчастей по списку названий и производителей с использованием ранее созданной функции
CREATE OR REPLACE FUNCTION get_parts_ids_full(
    parts_info part_info[] -- Список запчастей с названиями и производителями
)
RETURNS TABLE (part_id INTEGER, part_name VARCHAR, manufacturer VARCHAR) 
LANGUAGE plpgsql
AS $$
DECLARE
    part_record part_info; -- Переменная для хранения текущей записи из массива
    part_id_result INTEGER; -- Переменная для хранения ID запчасти
BEGIN
    -- Перебираем каждый элемент массива parts_info
    FOREACH part_record IN ARRAY parts_info
    LOOP
        BEGIN
            -- Используем уже существующую функцию get_part_id для получения ID
            part_id_result := get_part_id(part_record);
            -- Возвращаем строку с ID, названием и производителем
            part_id := part_id_result;
            part_name := part_record.part_name;
            manufacturer := part_record.manufacturer;
            RETURN NEXT;
        EXCEPTION WHEN OTHERS THEN
            -- Если get_part_id выбросит ошибку (например, не найдёт запчасть), пишем предупреждение
            RAISE NOTICE 'Запчасть не найдена: % - %', part_record.part_name, part_record.manufacturer;
        END;
    END LOOP;
END;
$$;


SELECT * FROM get_parts_ids_full(
    ARRAY[
        ROW('Масляный фильтр', 'Bosch')::part_info,
        ROW('Свеча зажигания', 'Bosch')::part_info,
        ROW('Воздушный фильтр', 'Valeo')::part_info
    ]
);


-- 4. Создание функции для получения таблицы с названиями услуг и их ID
CREATE OR REPLACE FUNCTION get_services_ids(
    service_names TEXT[]
)
RETURNS TABLE (service_name TEXT, service_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    name TEXT;
BEGIN
    -- Перебираем каждое название услуги в массиве
    FOREACH name IN ARRAY service_names
    LOOP
        BEGIN
            -- Получаем ID через уже существующую функцию
            service_id := get_service_id(name);
            service_name := name;
            -- Возвращаем строку
            RETURN NEXT;
        EXCEPTION WHEN OTHERS THEN
            -- Если услуга не найдена, выводим сообщение
            RAISE NOTICE 'Услуга не найдена: %', name;
        END;
    END LOOP;
END;
$$;


SELECT * FROM get_services_ids(
    ARRAY['Покраска кузова', 'Замена масла']
);

-- 5. Создание функции для получения суммы цен всех запчастей по списку их ID
CREATE OR REPLACE FUNCTION get_total_parts_price(parts_ids INTEGER[])
RETURNS DECIMAL(10, 2) AS $$
DECLARE
    total_price DECIMAL(10, 2) := 0.0;  -- Переменная для хранения общей суммы
    parted_id INTEGER;                     -- Переменная для текущего ID запчасти
    part_price DECIMAL(10, 2);              -- Переменная для хранения цены текущей запчасти
BEGIN
    -- Перебираем каждый ID из массива parts_ids
    FOREACH parted_id IN ARRAY parts_ids
    LOOP
        -- Получаем цену текущей запчасти
        SELECT Price INTO part_price
        FROM Parts
        WHERE Parts.Part_ID = parted_id
        LIMIT 1;

        -- Если запчасть не найдена, выбрасываем исключение
        IF part_price IS NULL THEN
            RAISE EXCEPTION 'Запчасть с ID % не найдена', parted_id;
        END IF;

        -- Добавляем цену текущей запчасти к общей сумме
        total_price := total_price + part_price;
    END LOOP;

    -- Возвращаем итоговую сумму
    RETURN total_price;
END;
$$ LANGUAGE plpgsql;


SELECT get_total_parts_price(ARRAY[1, 3, 5]);


-- 6. Создание функции для получения суммы цен всех запчастей по списку их названий и производителей
CREATE OR REPLACE FUNCTION get_total_price_by_names_and_manufacturer(
    parts_info part_info[]  -- Массив с информацией о названиях и производителях запчастей
)
RETURNS DECIMAL(10, 2) AS $$
DECLARE
    total_price DECIMAL(10, 2) := 0.0;  -- Переменная для хранения общей суммы
    parted_id INTEGER;  -- Переменная для хранения ID запчасти
BEGIN
    -- Перебираем все полученные ID запчастей
    FOR parted_id IN
        SELECT part_id FROM get_parts_ids_full(parts_info)
    LOOP
        -- Для каждого ID запчасти добавляем цену к общей сумме
        total_price := total_price + get_total_parts_price(ARRAY[parted_id]);
    END LOOP;

    -- Возвращаем итоговую сумму
    RETURN total_price;
END;
$$ LANGUAGE plpgsql;


-- Пример вызова функции
SELECT get_total_price_by_names_and_manufacturer(
    ARRAY[
        ROW('Масляный фильтр', 'Bosch')::part_info,
        ROW('Свеча зажигания', 'Bosch')::part_info,
        ROW('Воздушный фильтр', 'Valeo')::part_info
    ]
);


-- 7. Создание функции для получения суммы цен всех услуг по списку их ID
CREATE OR REPLACE FUNCTION get_total_services_price(service_ids INTEGER[])
RETURNS DECIMAL(10, 2) AS $$
DECLARE
    total_price DECIMAL(10, 2) := 0.0;  -- Переменная для хранения общей суммы
    serviced_id INTEGER;                   -- Переменная для хранения текущего ID услуги
    service_price DECIMAL(10, 2);         -- Переменная для хранения цены текущей услуги
BEGIN
    -- Перебираем все полученные ID услуг
    FOREACH serviced_id IN ARRAY service_ids
    LOOP
        -- Получаем цену услуги по текущему ID
        SELECT price INTO service_price
        FROM Services
        WHERE Service_ID = serviced_id
        LIMIT 1;

        -- Если услуга не найдена, выбрасываем исключение
        IF service_price IS NULL THEN
            RAISE EXCEPTION 'Услуга с ID % не найдена', serviced_id;
        END IF;

        -- Добавляем цену услуги к общей сумме
        total_price := total_price + service_price;
    END LOOP;

    -- Возвращаем итоговую сумму
    RETURN total_price;
END;
$$ LANGUAGE plpgsql;

SELECT get_total_services_price(ARRAY[1, 2, 5]);


-- 8. Создание функции для получения суммы цен услуг по списку их названий
CREATE OR REPLACE FUNCTION get_total_services_price_by_names(
    service_names TEXT[]
)
RETURNS DECIMAL(10, 2) AS $$
DECLARE
    total_price DECIMAL(10, 2) := 0.0;  -- Переменная для хранения общей суммы
    service_ids INTEGER[] := ARRAY[]::INTEGER[]; -- Массив для хранения ID услуг
    serviced_id INTEGER;  -- Переменная для хранения текущего ID услуги
BEGIN
    -- Получаем список ID услуг по названиям
    FOR serviced_id IN
        SELECT service_id FROM get_services_ids(service_names)
    LOOP
        -- Добавляем каждый ID в массив
        service_ids := array_append(service_ids, serviced_id);
    END LOOP;

    -- Теперь считаем сумму по ID услуг
    total_price := get_total_services_price(service_ids);

    -- Возвращаем итоговую сумму
    RETURN total_price;
END;
$$ LANGUAGE plpgsql;



SELECT get_total_services_price_by_names(
    ARRAY['Покраска кузова', 'Замена масла'] -- 24800
);


-- 9. Создание функции для получения общей суммы по ID услуг и ID запчастей
CREATE OR REPLACE FUNCTION get_total_order_price(
    service_ids INTEGER[],
    part_ids INTEGER[]
)
RETURNS DECIMAL(10, 2) AS $$
DECLARE
    total_services_price DECIMAL(10, 2) := 0.0;
    total_parts_price DECIMAL(10, 2) := 0.0;
BEGIN
    -- Получаем сумму услуг
    IF array_length(service_ids, 1) IS NOT NULL THEN
        total_services_price := get_total_services_price(service_ids);
    END IF;

    -- Получаем сумму запчастей
    IF array_length(part_ids, 1) IS NOT NULL THEN
        total_parts_price := get_total_parts_price(part_ids);
    END IF;

    -- Возвращаем их сумму
    RETURN total_services_price + total_parts_price;
END;
$$ LANGUAGE plpgsql;


SELECT get_total_order_price(
    ARRAY[1, 2, 5], -- id услуг
    ARRAY[3, 4, 7]  -- id запчастей
);


-- 10. Создание функции для получения общей стоимости заказа по названиям услуг и запчастей
CREATE OR REPLACE FUNCTION get_total_order_price_by_names_simple(
    service_names TEXT[],
    parts_info part_info[]
)
RETURNS DECIMAL(10, 2) AS $$
DECLARE
    total_services_price DECIMAL(10, 2) := 0.0;
    total_parts_price DECIMAL(10, 2) := 0.0;
BEGIN
    -- Считаем сумму услуг
    total_services_price := get_total_services_price_by_names(service_names);

    -- Считаем сумму запчастей
    total_parts_price := get_total_price_by_names_and_manufacturer(parts_info);

    -- Возвращаем общую сумму
    RETURN total_services_price + total_parts_price;
END;
$$ LANGUAGE plpgsql;

SELECT get_total_order_price_by_names_simple(
    ARRAY['Покраска кузова', 'Замена масла'],
    ARRAY[
        ROW('Масляный фильтр', 'Bosch')::part_info,
        ROW('Свеча зажигания', 'Bosch')::part_info,
        ROW('Воздушный фильтр', 'Valeo')::part_info
    ]
);


SELECT get_total_services_price_by_names(
    ARRAY['Покраска кузова', 'Замена масла'] -- 24800
);

SELECT get_total_price_by_names_and_manufacturer( --2800
    ARRAY[
        ROW('Масляный фильтр', 'Bosch')::part_info,
        ROW('Свеча зажигания', 'Bosch')::part_info,
        ROW('Воздушный фильтр', 'Valeo')::part_info
    ]
);

-- 11. Функция для расчёта общей стоимости заказа по его ID без обновления записи
CREATE OR REPLACE FUNCTION calculate_order_total(order_id INT)
RETURNS NUMERIC AS $$
DECLARE
    parts_total NUMERIC := 0;
    services_total NUMERIC := 0;
    total NUMERIC := 0;
BEGIN
    -- Считаем стоимость всех запчастей (с учётом количества)
    SELECT COALESCE(SUM(p.Price * poi.Quantity), 0)
    INTO parts_total
    FROM Parts_in_Orders poi
    JOIN Parts p ON poi.Part_ID = p.Part_ID
    WHERE poi.Order_ID = calculate_order_total.order_id;

    -- Считаем стоимость всех услуг
    SELECT COALESCE(SUM(s.Price), 0)
    INTO services_total
    FROM Services_in_Orders sio
    JOIN Services s ON sio.Service_ID = s.Service_ID
    WHERE sio.Order_ID = calculate_order_total.order_id;

    -- Считаем общую сумму
    total := parts_total + services_total;

    -- Просто возвращаем сумму
    RETURN total;
END;
$$ LANGUAGE plpgsql;


SELECT calculate_order_total(5); 

SELECT * FROM orders
WHERE order_id = 5

UPDATE orders
SET total_amount = 1000
WHERE order_id = 5;


-- 1. Процедура: пересчитывает и обновляет сумму заказа
CREATE OR REPLACE PROCEDURE recalculate_order_total(
    orderer_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    old_total NUMERIC;
    new_total NUMERIC;
BEGIN
    -- Получаем старую сумму для заказа
    SELECT Total_Amount INTO old_total
    FROM Orders
    WHERE Order_ID = orderer_id;

    -- Получаем новую сумму для заказа
    new_total := calculate_order_total(orderer_id);

    -- Обновляем сумму заказа в таблице
    UPDATE Orders
    SET Total_Amount = new_total
    WHERE Order_ID = orderer_id;

    -- Возвращаем старую и новую сумму
    RAISE NOTICE 'Старая сумма: %, Новая сумма: %', old_total, new_total;
END;
$$;

CALL recalculate_order_total(5);


-- 2. Процедура для пересчёта сумм заказов по переданным ID
CREATE OR REPLACE PROCEDURE recalculate_orders_by_ids(order_ids INT[])
LANGUAGE plpgsql
AS $$
DECLARE
    orderer_id INT;
    new_total NUMERIC;
BEGIN
    -- Перебираем все ID заказов из переданного массива
    FOREACH orderer_id IN ARRAY order_ids
    LOOP
        -- Получаем новую сумму для текущего заказа
        new_total := calculate_order_total(orderer_id);

        -- Обновляем сумму заказа
        UPDATE Orders
        SET Total_Amount = new_total
        WHERE Order_ID = orderer_id;

        -- Выводим уведомление о пересчитанном заказе
        RAISE NOTICE 'Обновлена сумма заказа №%, новая сумма: %', orderer_id, new_total;
    END LOOP;
END;
$$;

CALL recalculate_orders_by_ids(ARRAY[1, 2, 3]);



-- 3. Процедура для пересчёта сумм всех заказов
CREATE OR REPLACE PROCEDURE recalculate_all_orders()
LANGUAGE plpgsql
AS $$
DECLARE
    order_id INT;
    new_total NUMERIC;
BEGIN
    -- Перебираем все заказы в таблице Orders
    FOR order_id IN
        SELECT Order_ID FROM Orders
    LOOP
        -- Получаем новую сумму для текущего заказа
        new_total := calculate_order_total(order_id);

        -- Обновляем сумму заказа
        UPDATE Orders
        SET Total_Amount = new_total
        WHERE Order_ID = order_id;

        -- Выводим уведомление о пересчитанном заказе
        RAISE NOTICE 'Обновлена сумма заказа №%, новая сумма: %', order_id, new_total;
    END LOOP;
END;
$$;


CALL recalculate_all_orders();


-- 12. Функция для замены номера телефона клиента, если нового номера нет в базе
CREATE OR REPLACE FUNCTION update_client_phone(cliented_id INT, new_phone TEXT)
RETURNS TEXT AS $$
DECLARE
    current_phone TEXT;
BEGIN
    -- Проверяем, что новый номер начинается с +7 и содержит ровно 11 цифр
    IF new_phone !~ '^\+7\d{10}$' THEN
        RAISE EXCEPTION 'Неверный формат номера телефона: %', new_phone;
    END IF;

    -- Проверяем, что такого номера еще нет в базе
    SELECT Phone INTO current_phone
    FROM Clients
    WHERE Phone = new_phone LIMIT 1;

    IF current_phone IS NOT NULL THEN
        RAISE EXCEPTION 'Номер телефона % уже существует в базе', new_phone;
    END IF;

    -- Обновляем номер телефона
    UPDATE Clients
    SET Phone = new_phone
    WHERE Client_ID = cliented_id;

    -- Возвращаем сообщение о успешном изменении
    RETURN 'Номер телефона успешно обновлён';
END;
$$ LANGUAGE plpgsql;


SELECT update_client_phone(2, '+799912368');


-- 13. Функция для проверки наличия запчастей перед оформлением заказа.
CREATE OR REPLACE FUNCTION check_part_availability(parted_id INT, requested_quantity INT)
RETURNS BOOLEAN AS $$
DECLARE
    available_quantity INT;
BEGIN
    -- Получаем доступное количество запчасти
    SELECT COALESCE(Stock_Quantity, 0) INTO available_quantity
    FROM Parts
    WHERE Part_ID = part_id;

    -- Проверяем, достаточно ли запчастей
    IF available_quantity >= requested_quantity THEN
        RETURN TRUE;  -- Если доступное количество больше или равно запрашиваемому, возвращаем TRUE
    ELSE
        RETURN FALSE;  -- Если нет, возвращаем FALSE
    END IF;
END;
$$ LANGUAGE plpgsql;


SELECT check_part_availability(3, 50000);



--  4. Процедура для добавления машины по номеру телефона клиента. Если клиента с таким номером нет — ошибка. 
CREATE OR REPLACE PROCEDURE add_car_for_client(
    phone_number TEXT, 
    cared_id INT,
    car_model TEXT, 
    car_color TEXT, 
    car_licence_plate TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    cliented_id INT;  -- Переменная для хранения cliented_id клиента
    car RECORD;  -- Переменная для хранения данных о машине
BEGIN
    -- Получаем client_id клиента по номеру телефона
    SELECT client_id
    INTO cliented_id
    FROM Clients
    WHERE phone_number = phone;

    -- Если клиента нет, вызываем ошибку
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Клиент с номером % не найден!', phone_number;
    END IF;

    -- Добавление новой машины в таблицу Cars с использованием car_id
    INSERT INTO Cars (car_id, owner_id, model, color, license_plate)
    VALUES (cared_id, cliented_id, car_model, car_color, car_licence_plate);

    -- Вывод всех машин клиента
    RAISE NOTICE 'Машины клиента с номером %:', phone_number;
    FOR car IN
        SELECT model, color, license_plate FROM Cars
        WHERE owner_id = cliented_id
    LOOP
        RAISE NOTICE 'Модель: %, Цвет: %, Рег. номер: %', car.model, car.color, car.license_plate;
    END LOOP;
END;
$$;



CALL add_car_for_client('+79131364183', 100002, 'Chevrolet Lanos', 'Розовый', 'М112АО164');


SELECT c.Full_Name, c.Phone, ca.Model, ca.license_plate
FROM Clients c
JOIN Cars ca ON c.Client_ID = ca.Owner_id
WHERE c.Phone = '+79075095151';



-- 5. Добавляет в parts_in_orders запчасти, которые будут участвовать в заказе(есть триггер, который уменьшит их кол-во на складе)
CREATE TYPE part_order_info AS (
    manufacturer TEXT,
    part_name TEXT,
    quantity INT
);

CREATE OR REPLACE PROCEDURE add_parts_to_order(
    p_order_id INT,
    p_parts part_order_info[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    part_record part_order_info;
    part_id INT;
    stock_quantity INT;
BEGIN
    -- Проверяем все запчасти
    FOREACH part_record IN ARRAY p_parts
    LOOP
        -- Ищем ID запчасти по производителю и названию
        SELECT p.part_id, p.stock_quantity
        INTO part_id, stock_quantity
        FROM Parts p
        WHERE p.manufacturer = part_record.manufacturer
          AND p.part_name = part_record.part_name
        LIMIT 1;

        -- Если не нашли
        IF part_id IS NULL THEN
            RAISE EXCEPTION 'Запчасть "%" производителя "%" не найдена.', part_record.part_name, part_record.manufacturer;
        END IF;

        -- Проверка остатков на складе
        IF stock_quantity < part_record.quantity THEN
            RAISE EXCEPTION 'Недостаточно запчастей "%". На складе: %, требуется: %.', part_record.part_name, stock_quantity, part_record.quantity;
        END IF;
    END LOOP;

    -- Если все проверки успешны, добавляем в заказ
    FOREACH part_record IN ARRAY p_parts
    LOOP
        SELECT p.part_id
        INTO part_id
        FROM Parts p
        WHERE p.manufacturer = part_record.manufacturer
          AND p.part_name = part_record.part_name
        LIMIT 1;

        INSERT INTO Parts_in_Orders (Order_ID, Part_ID, Quantity)
        VALUES (p_order_id, part_id, part_record.quantity);
    END LOOP;

    -- Сообщение об успехе
    RAISE NOTICE 'Запчасти успешно добавлены в заказ %.', p_order_id;
END;
$$;


CALL add_parts_to_order(
    100000,
    ARRAY[
        ROW('Масляный фильтр', 'Bosch', 2)::part_order_info,
        ROW('Свеча зажигания', 'Bosch', 4)::part_order_info
    ]
);

CALL add_parts_to_order(
    100000,
    ARRAY[
        ROW('Bosch', 'Масляный фильтр', 20000)::part_order_info,
        ROW('Valeo', 'Свеча зажигания', 4)::part_order_info
    ]
);

CALL add_parts_to_order(
    100000,
    ARRAY[
        ROW('Bosch', 'Масляный фильтр', 2)::part_order_info,
        ROW('Valeo', 'Свеча зажигания', 4)::part_order_info
    ]
);



-- 6. Процедура добавляет в service_in_orders для одного order_id и для одного и того же механика, услуги, их кол-во

CREATE TYPE service_order_info AS (
    service_name TEXT,
    quantity INT
);


CREATE OR REPLACE PROCEDURE add_services_to_order(
    p_order_id INT,
    p_mechanic_id INT,
    p_services service_order_info[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    service_record service_order_info;
    service_id INT;
BEGIN
    -- Перебираем все переданные услуги
    FOREACH service_record IN ARRAY p_services
    LOOP
        -- Ищем ID услуги по названию
        SELECT s.service_id
        INTO service_id
        FROM Services s
        WHERE s.service_name = service_record.service_name
        LIMIT 1;

        -- Проверка: услуга найдена?
        IF service_id IS NULL THEN
            RAISE EXCEPTION 'Услуга "%" не найдена.', service_record.service_name;
        END IF;

        -- Вставляем в Services_in_Orders
        INSERT INTO Services_in_Orders (Order_ID, Service_ID, Mechanic_ID, Quantity)
        VALUES (p_order_id, service_id, p_mechanic_id, service_record.quantity);
    END LOOP;

    -- Уведомление об успехе
    RAISE NOTICE 'Услуги успешно добавлены в заказ %.', p_order_id;
END;
$$;

CALL add_services_to_order(
    1, -- id заказа
    3, -- id механика
    ARRAY[
        ROW('Замена масла', 1)::service_order_info,
        ROW('Регулировка фар', 1)::service_order_info
    ]
);

