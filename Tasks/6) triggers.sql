1. -- INSERT — AFTER  После вставки новой записи в Parts_in_Orders автоматически уменьшается Stock_Quantity
-- в таблице Parts в соответствии с количеством.

CREATE OR REPLACE FUNCTION decrease_stock_quantity() 
RETURNS TRIGGER AS $$
BEGIN
    -- Проверяем, что на складе достаточно запчастей
    IF (SELECT Stock_Quantity FROM Parts WHERE Part_ID = NEW.Part_ID) < NEW.Quantity THEN
        RAISE EXCEPTION 'Недостаточно запчастей на складе для выполнения этого заказа';
    END IF;

    -- Уменьшаем количество на складе в таблице Parts
    UPDATE Parts
    SET Stock_Quantity = Stock_Quantity - NEW.Quantity
    WHERE Part_ID = NEW.Part_ID;

    -- Возвращаем NEW, чтобы операция продолжалась
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER decrease_stock_trigger
AFTER INSERT
ON Parts_in_Orders
FOR EACH ROW
EXECUTE FUNCTION decrease_stock_quantity();


INSERT INTO Parts_in_Orders (Order_ID, Part_ID, Quantity)
VALUES (103, 1, 2);


--  INSERT — INSTEAD OF Вставка в представление car_full_info_view (объединение клиентов и машин)
-- триггер вставляет данные в таблицы Clients и Cars, устанавливая связь между ними через client_id.
CREATE VIEW car_full_info_view as -- создание представления
SELECT 
    c.client_id,
    c.full_name,
    c.phone,
    car.car_id,
    car.model,
    car.color,
    car.license_plate
FROM 
    Clients c
JOIN 
    Cars car ON c.client_id = car.owner_id;

SELECT * FROM car_full_info_view;

CREATE OR REPLACE FUNCTION insert_into_car_full_info_view()
RETURNS TRIGGER AS $$
BEGIN
    -- Проверка клиента
    IF NOT EXISTS (SELECT 1 FROM Clients WHERE client_id = NEW.client_id) THEN
        INSERT INTO Clients(client_id, full_name, phone)
        VALUES (NEW.client_id, NEW.full_name, NEW.phone);
    END IF;

    -- Проверка автомобиля
    IF NOT EXISTS (SELECT 1 FROM Cars WHERE car_id = NEW.car_id) THEN
        INSERT INTO Cars(car_id, owner_id, model, color, license_plate)
        VALUES (NEW.car_id, NEW.client_id, NEW.model, NEW.color, NEW.license_plate);
    END IF;

    RETURN NULL; -- INSTEAD OF INSERT
END;
$$ LANGUAGE plpgsql;



CREATE TRIGGER trg_insert_car_full_info_view
INSTEAD OF INSERT ON car_full_info_view
FOR EACH ROW
EXECUTE FUNCTION insert_into_car_full_info_view();

-- Вставим новую запись в представление:
INSERT INTO car_full_info_view (client_id, full_name, phone, car_id, model, color, license_plate)
VALUES (444444, 'Кузнецова Ольга Юрьевна', '+79001112234', 444444, 'Kia Rio', 'Белый', 'X111YY78');

-- Проверим результат:
SELECT * FROM Clients WHERE full_name = 'Кузнецова Ольга Юрьевна';
SELECT * FROM Cars WHERE license_plate = 'X111YY78';
SELECT * FROM car_full_info_view WHERE full_name = 'Кузнецова Ольга Юрьевна';


-- 3. UPDATE — AFTER
-- При обновлении опыта (Experience) механика в таблице Mechanics, его зарплата (Salary) автоматически увеличивается на 10,000.

CREATE OR REPLACE FUNCTION update_salary_after_experience()
RETURNS TRIGGER AS $$
BEGIN
    -- Если опыт изменился
    IF NEW.experience IS DISTINCT FROM OLD.experience THEN
        -- Увеличиваем зарплату на 10000
        UPDATE Mechanics
        SET salary = salary + 10000
        WHERE mechanic_id = NEW.mechanic_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_update_salary_after_experience
AFTER UPDATE ON Mechanics
FOR EACH ROW
EXECUTE FUNCTION update_salary_after_experience();


-- Посмотрим текущие данные по механику
SELECT * FROM Mechanics WHERE mechanic_id = 2;

-- Обновим опыт
UPDATE Mechanics
SET experience = experience + 1
WHERE mechanic_id = 2;

-- Посмотрим снова
SELECT * FROM Mechanics WHERE mechanic_id = 2;


-- 4: UPDATE — INSTEAD OF
-- При изменении поля Order_Date в представлении Client_Orders_View 
-- триггер перехватывает операцию и обновляет соответствующую запись в таблице Orders.

CREATE VIEW Client_Orders_View AS
SELECT
    o.order_id,
    o.order_date,
    o.total_amount,
    c.client_id,
    c.full_name AS client_name,
    c.phone AS client_phone
FROM
    Orders o
JOIN
    Clients c ON o.client_id = c.client_id;

select * from Client_Orders_View

CREATE OR REPLACE FUNCTION update_order_date_in_orders()
RETURNS TRIGGER AS $$
BEGIN
    -- Обновляем дату заказа в таблице Orders
    UPDATE Orders
    SET order_date = NEW.order_date
    WHERE order_id = OLD.order_id;

    RETURN NULL; -- INSTEAD OF
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_order_date
INSTEAD OF UPDATE ON Client_Orders_View
FOR EACH ROW
EXECUTE FUNCTION update_order_date_in_orders();


SELECT order_id, order_date, total_amount, client_id
FROM Orders
WHERE order_id = 1;

-- Обновляем дату заказа в представлении
UPDATE Client_Orders_View
SET order_date = '2025-05-21'
WHERE order_id = 1;


-- 5. DELETE — AFTER
-- После удаления механика из таблицы Mechanics, для всех его записей в таблице Services_in_Orders
-- автоматически назначается другой механик, случайный из таблицы Mechanics.

CREATE OR REPLACE FUNCTION update_mechanic_after_delete()
RETURNS TRIGGER AS $$
DECLARE
    random_mechanic_id INTEGER;
BEGIN
    -- Получаем ID случайного механика, который не является удаленным
    SELECT Mechanic_ID INTO random_mechanic_id
    FROM Mechanics
    WHERE Mechanic_ID != OLD.Mechanic_ID
    ORDER BY RANDOM()
    LIMIT 1;

    -- Заменяем все NULL значения в Services_in_Orders на случайного механика
    UPDATE Services_in_Orders
    SET Mechanic_ID = random_mechanic_id
    WHERE Mechanic_ID IS NULL;

    -- Возвращаем NULL после выполнения
    RETURN NULL; -- AFTER
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_mechanic_after_delete
AFTER DELETE ON Mechanics
FOR EACH ROW
EXECUTE FUNCTION update_mechanic_after_delete();


SELECT * FROM Services_in_Orders WHERE Mechanic_ID = 103;

SELECT * FROM Services_in_Orders WHERE order_id = 17212;

DELETE FROM Mechanics WHERE Mechanic_ID = 103;



-- 6. DELETE — INSTEAD OF
-- Удаление записи из представления parts_in_order_view
-- увеличивает количество на складе соответствующей запчасти (Stock_Quantity) в таблице Parts.

CREATE OR REPLACE VIEW parts_in_order_view AS
SELECT 
    pio.order_id,
    pio.part_id,
    p.part_name,
    pio.quantity
FROM Parts_in_Orders pio
JOIN Parts p ON pio.part_id = p.part_id;


select * from parts_in_order_view


CREATE OR REPLACE FUNCTION return_part_to_stock_on_delete()
RETURNS TRIGGER AS $$
BEGIN
    -- Увеличиваем количество на складе
    UPDATE Parts
    SET stock_quantity = stock_quantity + OLD.quantity
    WHERE part_id = OLD.part_id;

    -- Удаляем запись из связующей таблицы
    DELETE FROM Parts_in_Orders
    WHERE order_id = OLD.order_id AND part_id = OLD.part_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_return_part_to_stock_on_delete
INSTEAD OF DELETE ON parts_in_order_view
FOR EACH ROW
EXECUTE FUNCTION return_part_to_stock_on_delete();


SELECT * FROM Parts WHERE part_id = 2;
-- До удаления
SELECT * FROM parts_in_order_view WHERE part_id = 2;

-- Удаляем из представления (например, часть вернули)
DELETE FROM parts_in_order_view WHERE order_id = 76 AND part_id = 2;

-- Проверим, что в таблице Parts количество увеличилось
SELECT * FROM Parts WHERE part_id = 2;


-- 7. INSERT — BEFORE

-- При вставке нового автомобиля проверяется, есть ли уже автомобиль с таким номером в таблице Cars.
-- Если есть, вставка отменяется и выводится ошибка.

CREATE OR REPLACE FUNCTION check_duplicate_license_plate()
RETURNS TRIGGER AS $$
BEGIN
    -- Проверка, есть ли уже такой номер
    IF EXISTS (
        SELECT 1 FROM Cars
        WHERE license_plate = NEW.license_plate
    ) THEN
        RAISE EXCEPTION 'Автомобиль с номером % уже существует.', NEW.license_plate;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_check_license_plate_before_insert
BEFORE INSERT ON Cars
FOR EACH ROW
EXECUTE FUNCTION check_duplicate_license_plate();


SELECT * FROM Cars WHERE license_plate = 'Х459ЕМ44';

-- Попробуем вставить машину с уже существующим номером
INSERT INTO Cars(owner_id, model, color, license_plate)
VALUES (123, 'Toyota', 'Черный', 'Х459ЕМ44');


--  DELETE — BEFORE
--Удаление запчасти, если она используется в активных заказах:
-- Если запчасть используется в активных заказах, удаление отменяется.

CREATE OR REPLACE FUNCTION prevent_part_deletion_if_used()
RETURNS TRIGGER AS $$
BEGIN
    -- Проверка: есть ли такие записи в связанной таблице
    IF EXISTS (
        SELECT 1
        FROM Parts_in_Orders
        WHERE Part_ID = OLD.Part_ID
    ) THEN
        RAISE EXCEPTION 'Нельзя удалить запчасть, так как она используется в заказах';
    END IF;

    RETURN OLD; -- Удаление разрешено, если запчасть нигде не используется
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_part_deletion_if_used
BEFORE DELETE ON Parts
FOR EACH ROW
EXECUTE FUNCTION prevent_part_deletion_if_used();

-- Посмотреть, используется ли запчасть
SELECT * FROM Parts_in_Orders WHERE Part_ID = 34;

-- Попытка удалить
DELETE FROM Parts WHERE Part_ID = 34;

