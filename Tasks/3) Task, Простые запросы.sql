-- Получить все заказы (полностью) для клиента
-- Поиск идет через связь заказа с машиной, а затем машины с владельцем (клиентом)
SELECT o.*
FROM Orders o
JOIN Cars car ON o.Car_ID = car.Car_ID
JOIN Clients c ON car.Owner_ID = c.Client_ID
WHERE c.Full_Name = 'Иван Иванов';


-- INNER JOIN: Показывает клиентов и их автомобили с номерами
SELECT c.Full_Name, car.Brand, car.License_Plate
FROM Clients c
INNER JOIN Cars car ON c.Client_ID = car.Owner_ID;


-- LEFT JOIN: Покажет всех клиентов и их машины (если есть)
SELECT c.Full_Name, car.Brand, car.License_Plate
FROM Clients c
LEFT JOIN Cars car ON c.Client_ID = car.Owner_ID;


-- RIGHT JOIN: Покажет все машины и их владельцев (если есть)
SELECT c.Full_Name, car.Brand, car.License_Plate
FROM Clients c
RIGHT JOIN Cars car ON c.Client_ID = car.Owner_ID;


-- FULL JOIN: Покажет всех клиентов и все машины
SELECT c.Full_Name, car.Brand, car.License_Plate
FROM Clients c
FULL JOIN Cars car ON c.Client_ID = car.Owner_ID;


-- CROSS JOIN: Декартово произведение
-- Каждая строка из Clients соединится с каждой строкой из Cars
SELECT c.Full_Name, car.Brand, car.License_Plate
FROM Clients c
CROSS JOIN Cars car;


-- САМОСОЕДИНЕНИЕ (SELF JOIN)
-- Найдем пары клиентов, у которых номер телефона начинается одинаково
SELECT c1.Full_Name AS Client1, c2.Full_Name AS Client2, c1.Phone, c2.Phone
FROM Clients c1
JOIN Clients c2 ON LEFT(c1.Phone, 5) = LEFT(c2.Phone, 5) AND c1.Client_ID < c2.Client_ID;



-- Пример использования CROSS JOIN LATERAL для вычисления средней суммы заказов
SELECT c.Client_ID, 
       c.Full_Name, 
       COALESCE(avg_info.Avg_Spent, 0) AS Avg_Spent
FROM Clients c
CROSS JOIN LATERAL (
    SELECT AVG(o.Total_Amount) AS Avg_Spent
    FROM Orders o
    WHERE o.Client_ID = c.Client_ID
) AS avg_info;



-- Все кто причастен к автосервису
SELECT Full_Name FROM Clients
UNION
SELECT Full_Name FROM Mechanics;


-- UNION ALL: Все причастные (с повторами)
SELECT Full_Name FROM Clients
UNION ALL
SELECT Full_Name FROM Mechanics;


-- Кто и клиент и механик
SELECT Full_Name FROM Clients
INTERSECT
SELECT Full_Name FROM Mechanics;


-- EXCEPT: Клиенты, которые не механики
SELECT Full_Name FROM Clients
EXCEPT
SELECT Full_Name FROM Mechanics;


-- 1. BETWEEN: Найти всех механиков с зарплатой от 57000 до 70000 включительно
SELECT *
FROM Mechanics
WHERE Salary BETWEEN 57000 AND 70000;


-- 2. ILIKE: Найти всех клиентов, имя которых начинается на 'Сергей' (без учета регистра)
SELECT *
FROM Clients
WHERE Full_Name ILIKE 'Сергей%';


-- 3. IN: Найти всех клиентов с указанными номерами телефонов
SELECT *
FROM Clients
WHERE Phone IN ('+79161234567', '+79554443322');

-- 4. EXISTS: Найти всех клиентов, у которых есть заказы
SELECT c.*
FROM Clients c
WHERE EXISTS (
    SELECT 1
    FROM Orders o
    WHERE o.Client_ID = c.Client_ID
);


-- 5. SIMILAR TO: Найти клиентов, чьи имена соответствуют определенному шаблону (Петр или Алексей)
SELECT *
FROM Clients
WHERE Full_Name SIMILAR TO '(Петр|Алексей)%';


-- 6. POSIX регулярные выражения: Найти клиентов, чьи номера начинаются с +79 и далее 16 или 95
SELECT *
FROM Clients
WHERE Phone ~ '^\+79(16|55)';


-- 7. ALL: Найти механиков, у которых зарплата больше зарплаты всех механиков с опытом меньше 4 лет
SELECT *
FROM Mechanics
WHERE Salary > ALL (
    SELECT Salary
    FROM Mechanics
    WHERE Experience < 4
);


-- 8. SOME / ANY: Найти механиков, у которых зарплата больше хотя бы одного механика с опытом меньше 4 лет
SELECT *
FROM Mechanics
WHERE Salary > ANY (
    SELECT Salary
    FROM Mechanics
    WHERE Experience < 4
);

-- Выводит марку и цвет автомобиля, а также категорию цвета:
SELECT car.Brand,
       car.Color,
       CASE
           WHEN car.Color IN ('Белый', 'Серый') THEN 'Светлая'
           WHEN car.Color IN ('Черный', 'Синий') THEN 'Тёмная'
           ELSE 'Яркая'
       END AS Color_Category
FROM Cars car;


-- 1. CAST — преобразуем дату заказа в текст
SELECT 
  Order_ID, 
  Order_Date,
  CAST(Order_Date AS VARCHAR) AS Order_Date_Text  -- Преобразуем дату в строку
FROM Orders;

-- 2. COALESCE — подставляем значение по умолчанию, если поле NULL
SELECT 
  Client_ID, 
  COALESCE(phone , 'Не указано') AS Phone_Info     -- Если phone NULL, подставляем 'Не указано'
FROM Clients;


-- 1. LENGTH: Получаем имя клиента и его длину
SELECT Full_Name, LENGTH(Full_Name) AS Name_Length
FROM Clients;


-- 2. REPLACE: Заменяем 'Иванов' на 'Иванова' в именах клиентов
SELECT Full_Name, REPLACE(Full_Name, 'Иванов', 'Иванова') AS New_Name
FROM Clients;

-- 3. CHR: Получаем символ по его ASCII-коду
SELECT CHR(65) AS Character_A;

-- 4. ASCII: Получаем ASCII-код первой буквы имени клиента
SELECT Full_Name, ASCII(SUBSTRING(Full_Name FROM 1 FOR 1)) AS First_Char_Code
FROM Clients;
-- ASCII() возвращает код символа, SUBSTRING берет первый символ


-- 5. STRPOS: Находим позицию слова 'Иван' в имени клиента
SELECT Full_Name, STRPOS(Full_Name, 'Иван') AS Ivan_Position
FROM Clients;


-- 6. OVERLAY: Заменяем часть строки с 1 по 5 символ на 'Петр'
SELECT Full_Name, OVERLAY(Full_Name PLACING 'Петр' FROM 1 FOR 5) AS Replaced_Name
FROM Clients;
-- OVERLAY() позволяет заменить часть строки на другую


-- 7. POSITION: Найти позицию пробела (разделителя между фамилией и именем)
SELECT Full_Name, POSITION(' ' IN Full_Name) AS Space_Position
FROM Clients;

-- 9. LOWER / UPPER: Переводим имена в нижний и верхний регистр
SELECT Full_Name, LOWER(Full_Name) AS Lower_Case, UPPER(Full_Name) AS Upper_Case
FROM Clients;


-- 10. BTRIM / LTRIM / RTRIM: Удаляем лишние пробелы по бокам
SELECT Full_Name, 
       BTRIM('   ' || Full_Name || '   ') AS Trimmed_Name,
       LTRIM('   ' || Full_Name) AS Left_Trimmed,
       RTRIM(Full_Name || '   ') AS Right_Trimmed
FROM Clients;


-- BTRIM() удаляет пробелы с обеих сторон
-- LTRIM() - слева, RTRIM() - справа


-- 1. AGE: Разница между текущей датой и датой заказа
SELECT Order_ID, Order_Date, AGE(Order_Date) AS Age_Difference
FROM Orders;


-- 2. NOW: Текущая дата и время
SELECT Order_ID, Order_Date, NOW() AS Current_Timestamp
FROM Orders;


-- 3. CURRENT_DATE: Текущая дата (без времени)
SELECT Order_ID, Order_Date, CURRENT_DATE AS Current_Date
FROM Orders;


-- 4. CURRENT_TIME: Текущее время (без даты)
SELECT Order_ID, Order_Date, CURRENT_TIME AS Current_Time
FROM Orders;


-- 5. CURRENT_TIMESTAMP: Текущая дата и время с точностью до секунд
SELECT Order_ID, Order_Date, CURRENT_TIMESTAMP AS Current_Timestamp
FROM Orders;


-- 6. LOCALTIMESTAMP: Локальное текущее время (время с точностью до секунд)
SELECT Order_ID, Order_Date, LOCALTIMESTAMP AS Local_Timestamp
FROM Orders;


-- 7. DATE_PART: Часть даты (например, год или месяц)
SELECT Order_ID, Order_Date, DATE_PART('year', Order_Date) AS Order_Year
FROM Orders;



-- 1. Средняя сумма трат каждого клиента, где эта сумма больше 500
SELECT Client_ID, AVG(Total_Amount) AS Avg_Spent
FROM Orders
GROUP BY Client_ID
HAVING AVG(Total_Amount) > 500; 


-- 2. Средняя сумма трат каждого клиента, где эта сумма больше 4500
SELECT Client_ID, AVG(Total_Amount) AS Avg_Spent
FROM Orders
GROUP BY Client_ID
HAVING AVG(Total_Amount) > 4500;


-- 3. Средняя сумма трат каждого клиента, где эта сумма больше 500, отсортировано по Client_ID
SELECT Client_ID, AVG(Total_Amount) AS Avg_Spent
FROM Orders
GROUP BY Client_ID
HAVING AVG(Total_Amount) > 500
ORDER BY Client_ID;


-- 4. Сумма всех заказов, сгруппированных по каждому автомобилю (Car_ID)
SELECT Car_ID, SUM(Total_Amount) AS Total_Spent
FROM Orders
GROUP BY Car_ID;


-- 5. Максимальная и минимальная сумма заказа для каждого клиента
SELECT Client_ID, MAX(Total_Amount) AS Max_Order, MIN(Total_Amount) AS Min_Order
FROM Orders
GROUP BY Client_ID;


-- 6. Количество заказов каждого клиента
SELECT Client_ID, COUNT(Order_ID) AS Order_Count
FROM Orders
GROUP BY Client_ID;


-- 7. Среднее количество заказов на клиента, где количество заказов больше 0
SELECT Client_ID, COUNT(Order_ID) AS Order_Count
FROM Orders
GROUP BY Client_ID
HAVING COUNT(Order_ID) > 0;




