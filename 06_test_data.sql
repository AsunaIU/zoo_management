-- ТЕСТОВЫЕ ДАННЫЕ ДЛЯ СИСТЕМЫ УПРАВЛЕНИЯ ЗООПАРКОМ

-- 1. ИНФОРМАЦИЯ О ЗООПАРКЕ

INSERT INTO Zoo (license_number, zoo_name, director_fullname, contact_phone)
VALUES ('ZOO-2024-001', 'Московский зоологический парк', 'Иванов Иван Иванович', '+7-495-123-45-67');

-- 2. ПЕРСОНАЛ

-- Используем процедуры для добавления персонала
-- Директор
CALL sp_add_staff(1001, 'Иванов Иван Иванович', '4510 123456', '1975-03-15', 'М', 'директор', 150000.00);

-- Администраторы
CALL sp_add_staff(1002, 'Петрова Мария Петровна', '4511 234567', '1985-07-22', 'Ж', 'администратор', 80000.00);
CALL sp_add_staff(1003, 'Сидорова Елена Сергеевна', '4512 345678', '1990-11-10', 'Ж', 'администратор', 75000.00);

-- Заведующий складом
CALL sp_add_staff(2001, 'Кузнецов Алексей Викторович', '4513 456789', '1982-05-30', 'М', 'заведующий складом', 70000.00);

-- Смотрители
CALL sp_add_staff(3001, 'Алексеев Петр Дмитриевич', '4514 567890', '1988-09-12', 'М', 'смотритель', 55000.00);
CALL sp_add_staff(3002, 'Дмитриева Анна Олеговна', '4515 678901', '1992-04-25', 'Ж', 'смотритель', 52000.00);
CALL sp_add_staff(3003, 'Васильев Сергей Иванович', '4516 789012', '1987-12-08', 'М', 'смотритель', 56000.00);
CALL sp_add_staff(3004, 'Николаева Ольга Александровна', '4517 890123', '1995-06-17', 'Ж', 'смотритель', 50000.00);
CALL sp_add_staff(3005, 'Федоров Дмитрий Николаевич', '4518 901234', '1991-02-28', 'М', 'смотритель', 53000.00);

-- 3. ВИДЫ КОРМОВ

INSERT INTO FeedProducts (feed_type) VALUES 
('Сено и трава'),
('Мясо сырое'),
('Рыба свежая'),
('Фрукты и овощи'),
('Зерновые смеси'),
('Специальный корм для хищников'),
('Насекомые'),
('Водные растения');

-- 4. СКЛАД (автоматически создается триггером, но можем обновить)

UPDATE StoreStock SET quantity_kg = 500, reorder_threshold_kg = 150 WHERE product_id = 1; -- Сено
UPDATE StoreStock SET quantity_kg = 80, reorder_threshold_kg = 50 WHERE product_id = 2;  -- Мясо
UPDATE StoreStock SET quantity_kg = 60, reorder_threshold_kg = 40 WHERE product_id = 3;  -- Рыба
UPDATE StoreStock SET quantity_kg = 200, reorder_threshold_kg = 80 WHERE product_id = 4; -- Фрукты
UPDATE StoreStock SET quantity_kg = 300, reorder_threshold_kg = 100 WHERE product_id = 5; -- Зерновые
UPDATE StoreStock SET quantity_kg = 45, reorder_threshold_kg = 30 WHERE product_id = 6;  -- Корм для хищников
UPDATE StoreStock SET quantity_kg = 25, reorder_threshold_kg = 20 WHERE product_id = 7;  -- Насекомые
UPDATE StoreStock SET quantity_kg = 70, reorder_threshold_kg = 40 WHERE product_id = 8;  -- Водные растения

-- 5. ВИДЫ ЖИВОТНЫХ

-- Млекопитающие - травоядные
CALL sp_add_animal_species(
    'Африканский слон (Loxodonta africana)', 'MAMMALS', 'OPEN', 'DRY', 
    100.00, 'HERBIVORE', 'Сено и трава', 150.00
);

CALL sp_add_animal_species(
    'Жираф (Giraffa camelopardalis)', 'MAMMALS', 'OPEN', 'DRY', 
    80.00, 'HERBIVORE', 'Сено и трава', 40.00
);

CALL sp_add_animal_species(
    'Зебра Греви (Equus grevyi)', 'MAMMALS', 'OPEN', 'DRY', 
    50.00, 'HERBIVORE', 'Сено и трава', 25.00
);

-- Млекопитающие - хищники
CALL sp_add_animal_species(
    'Амурский тигр (Panthera tigris altaica)', 'MAMMALS', 'CLOSED', 'DRY', 
    120.00, 'CARNIVORE', 'Мясо сырое', 15.00
);

CALL sp_add_animal_species(
    'Африканский лев (Panthera leo)', 'MAMMALS', 'CLOSED', 'DRY', 
    100.00, 'CARNIVORE', 'Мясо сырое', 12.00
);

CALL sp_add_animal_species(
    'Бурый медведь (Ursus arctos)', 'MAMMALS', 'CLOSED', 'DRY', 
    90.00, 'OMNIVORE', 'Фрукты и овощи', 20.00
);

-- Птицы
CALL sp_add_animal_species(
    'Страус африканский (Struthio camelus)', 'BIRDS', 'OPEN', 'DRY', 
    30.00, 'HERBIVORE', 'Зерновые смеси', 8.00
);

CALL sp_add_animal_species(
    'Фламинго розовый (Phoenicopterus roseus)', 'BIRDS', 'OPEN', 'WATER', 
    5.00, 'OMNIVORE', 'Специальный корм для хищников', 2.00
);

CALL sp_add_animal_species(
    'Пингвин Гумбольдта (Spheniscus humboldti)', 'BIRDS', 'OPEN', 'WATER', 
    3.00, 'CARNIVORE', 'Рыба свежая', 1.50
);

-- Рептилии
CALL sp_add_animal_species(
    'Нильский крокодил (Crocodylus niloticus)', 'REPTILES', 'CLOSED', 'WATER', 
    25.00, 'CARNIVORE', 'Мясо сырое', 5.00
);

-- 6. ВОЛЬЕРЫ

-- Вольеры для крупных травоядных (OPEN/DRY)
CALL sp_add_enclosure('OPEN', 'DRY', 500.00, 'IN_SERVICE', 3001);
CALL sp_add_enclosure('OPEN', 'DRY', 400.00, 'IN_SERVICE', 3001);
CALL sp_add_enclosure('OPEN', 'DRY', 300.00, 'IN_SERVICE', 3002);

-- Вольеры для хищников (CLOSED/DRY)
CALL sp_add_enclosure('CLOSED', 'DRY', 250.00, 'IN_SERVICE', 3003);
CALL sp_add_enclosure('CLOSED', 'DRY', 200.00, 'IN_SERVICE', 3003);
CALL sp_add_enclosure('CLOSED', 'DRY', 180.00, 'IN_SERVICE', 3004);

-- Вольеры для птиц (OPEN/DRY и OPEN/WATER)
CALL sp_add_enclosure('OPEN', 'DRY', 150.00, 'IN_SERVICE', 3002);
CALL sp_add_enclosure('OPEN', 'WATER', 200.00, 'IN_SERVICE', 3004);
CALL sp_add_enclosure('OPEN', 'WATER', 180.00, 'IN_SERVICE', 3005);

-- Вольеры для водных животных (CLOSED/WATER)
CALL sp_add_enclosure('CLOSED', 'WATER', 300.00, 'IN_SERVICE', 3005);

-- Вольер на ремонте
CALL sp_add_enclosure('OPEN', 'DRY', 250.00, 'UNDER_REPAIR', 3002);

-- 7. ЖИВОТНЫЕ

-- Слоны (вольер 1)
CALL sp_add_animal(1, 'Дамбо', '2015-06-12', '2016-01-20', 'М', 1);
CALL sp_add_animal(1, 'Майя', '2018-03-25', '2018-08-15', 'Ж', 1);
CALL sp_add_animal(1, 'Джамбо', '2012-11-08', '2013-05-10', 'М', 1);

-- Жирафы (вольер 2)
CALL sp_add_animal(2, 'Софи', '2017-04-15', '2018-02-20', 'Ж', 2);
CALL sp_add_animal(2, 'Джеральд', '2016-09-30', '2017-06-12', 'М', 2);
CALL sp_add_animal(2, 'Мелани', '2019-07-22', '2020-03-05', 'Ж', 2);

-- Зебры (вольер 3)
CALL sp_add_animal(3, 'Марти', '2018-05-10', '2019-01-15', 'М', 3);
CALL sp_add_animal(3, 'Зара', '2019-08-20', '2020-04-10', 'Ж', 3);
CALL sp_add_animal(3, 'Зик', '2017-12-05', '2018-09-25', 'М', 3);
CALL sp_add_animal(3, 'Зина', '2020-03-14', '2020-11-30', 'Ж', 3);

-- Тигры (вольер 4)
CALL sp_add_animal(4, 'Шерхан', '2014-02-28', '2015-01-10', 'М', 4);
CALL sp_add_animal(4, 'Тайга', '2016-07-18', '2017-03-22', 'Ж', 4);

-- Львы (вольер 5)
CALL sp_add_animal(5, 'Симба', '2015-05-12', '2016-02-15', 'М', 5);
CALL sp_add_animal(5, 'Нала', '2016-08-25', '2017-04-20', 'Ж', 5);

-- Медведи (вольер 6)
CALL sp_add_animal(6, 'Миша', '2013-03-20', '2014-01-15', 'М', 6);
CALL sp_add_animal(6, 'Маша', '2014-06-10', '2015-02-28', 'Ж', 6);

-- Страусы (вольер 7)
CALL sp_add_animal(7, 'Оззи', '2018-04-05', '2019-01-20', 'М', 7);
CALL sp_add_animal(7, 'Олли', '2019-07-15', '2020-03-10', 'М', 7);
CALL sp_add_animal(7, 'Оливия', '2018-09-22', '2019-05-18', 'Ж', 7);

-- Фламинго (вольер 8)
CALL sp_add_animal(8, 'Фламми-1', '2017-03-10', '2018-01-25', 'М', 8);
CALL sp_add_animal(8, 'Фламми-2', '2017-03-10', '2018-01-25', 'Ж', 8);
CALL sp_add_animal(8, 'Фламми-3', '2018-06-15', '2019-02-20', 'М', 8);
CALL sp_add_animal(8, 'Фламми-4', '2018-06-15', '2019-02-20', 'Ж', 8);
CALL sp_add_animal(8, 'Фламми-5', '2019-09-20', '2020-05-10', 'Ж', 8);

-- Пингвины (вольер 9)
CALL sp_add_animal(9, 'Пинг', '2016-11-12', '2017-08-20', 'М', 9);
CALL sp_add_animal(9, 'Понг', '2017-02-05', '2017-11-15', 'М', 9);
CALL sp_add_animal(9, 'Пеппа', '2018-05-18', '2019-01-30', 'Ж', 9);
CALL sp_add_animal(9, 'Пенни', '2018-05-18', '2019-01-30', 'Ж', 9);

-- Крокодилы (вольер 10)
CALL sp_add_animal(10, 'Крок', '2010-08-15', '2012-03-20', 'М', 10);
CALL sp_add_animal(10, 'Кроко', '2012-10-22', '2014-05-15', 'Ж', 10);

-- 8. ПОСТАВКИ КОРМОВ (последние 3 месяца)

-- Октябрь 2025
CALL sp_register_delivery('2025-10-05', 'ООО "АгроКорм"', 1, 500.00, 35.50);
CALL sp_register_delivery('2025-10-10', 'ИП Мясников', 2, 150.00, 280.00);
CALL sp_register_delivery('2025-10-15', 'ООО "РыбПром"', 3, 100.00, 320.00);
CALL sp_register_delivery('2025-10-20', 'ООО "ФрутКомпани"', 4, 200.00, 120.00);

-- Ноябрь 2025
CALL sp_register_delivery('2025-11-03', 'ООО "АгроКорм"', 1, 600.00, 36.00);
CALL sp_register_delivery('2025-11-08', 'ООО "Зерно"', 5, 400.00, 45.00);
CALL sp_register_delivery('2025-11-12', 'ИП Мясников', 2, 200.00, 285.00);
CALL sp_register_delivery('2025-11-18', 'ООО "РыбПром"', 3, 120.00, 315.00);
CALL sp_register_delivery('2025-11-25', 'ООО "Спецкорм"', 6, 80.00, 450.00);

-- Декабрь 2025
CALL sp_register_delivery('2025-12-02', 'ООО "ФрутКомпани"', 4, 250.00, 125.00);
CALL sp_register_delivery('2025-12-08', 'ООО "АгроКорм"', 1, 500.00, 37.00);
CALL sp_register_delivery('2025-12-15', 'ИП Мясников', 2, 180.00, 290.00);
CALL sp_register_delivery('2025-12-22', 'ООО "РыбПром"', 3, 100.00, 325.00);
CALL sp_register_delivery('2025-12-28', 'ООО "Насекомые"', 7, 50.00, 600.00);

-- Январь 2026
CALL sp_register_delivery('2026-01-05', 'ООО "АгроКорм"', 1, 550.00, 38.00);

-- 9. ВЫДАЧА КОРМОВ (последние 30 дней)

-- Симуляция ежедневного кормления за последние 15 дней
DO $$
DECLARE
    v_date DATE;
    v_day INTEGER;
BEGIN
    FOR v_day IN 1..15 LOOP
        v_date := CURRENT_DATE - v_day;
        
        -- Вольер 1: Слоны (450 кг сена в день)
        CALL sp_issue_feed(v_date, 1, 1, 450.00, 3001);
        
        -- Вольер 2: Жирафы (120 кг сена)
        CALL sp_issue_feed(v_date, 2, 1, 120.00, 3001);
        
        -- Вольер 3: Зебры (100 кг сена)
        CALL sp_issue_feed(v_date, 3, 1, 100.00, 3002);
        
        -- Вольер 4: Тигры (30 кг мяса)
        CALL sp_issue_feed(v_date, 4, 2, 30.00, 3003);
        
        -- Вольер 5: Львы (24 кг мяса)
        CALL sp_issue_feed(v_date, 5, 2, 24.00, 3003);
        
        -- Вольер 6: Медведи (40 кг фруктов и овощей)
        CALL sp_issue_feed(v_date, 6, 4, 40.00, 3004);
        
        -- Вольер 7: Страусы (24 кг зерновых)
        CALL sp_issue_feed(v_date, 7, 5, 24.00, 3002);
        
        -- Вольер 8: Фламинго (10 кг спецкорма)
        CALL sp_issue_feed(v_date, 8, 6, 10.00, 3004);
        
        -- Вольер 9: Пингвины (6 кг рыбы)
        CALL sp_issue_feed(v_date, 9, 3, 6.00, 3005);
        
        -- Вольер 10: Крокодилы (10 кг мяса)
        CALL sp_issue_feed(v_date, 10, 2, 10.00, 3005);
    END LOOP;
END;
$$;

-- ПРОВЕРКА ДАННЫХ

-- Статистика
SELECT '=== СТАТИСТИКА СИСТЕМЫ ===' as info;
SELECT 'Сотрудников:', COUNT(*) FROM Staff;
SELECT 'Видов животных:', COUNT(*) FROM AnimalSpecies;
SELECT 'Вольеров:', COUNT(*) FROM Enclosures;
SELECT 'Животных:', COUNT(*) FROM Animals;
SELECT 'Видов кормов:', COUNT(*) FROM FeedProducts;
SELECT 'Поставок:', COUNT(*) FROM Deliveries;
SELECT 'Выдач корма:', COUNT(*) FROM FeedIssues;

-- Проверка состояния склада
SELECT '=== СОСТОЯНИЕ СКЛАДА ===' as info;
SELECT * FROM v_current_stock_status;

-- Проверка загруженности вольеров
SELECT '=== ЗАГРУЖЕННОСТЬ ВОЛЬЕРОВ ===' as info;
SELECT 
    enclosure_id,
    enclosure_type,
    animal_count,
    ROUND(occupancy_percent, 2) as "Загрузка %",
    keeper_name
FROM v_animals_by_enclosure
ORDER BY enclosure_id;

COMMENT ON SCHEMA public IS 'Тестовые данные успешно загружены. Система готова к работе.';
