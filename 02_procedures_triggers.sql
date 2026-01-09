-- ПРОЦЕДУРЫ И ТРИГГЕРЫ ДЛЯ УПРАВЛЕНИЯ ДАННЫМИ

-- 1. ПРОЦЕДУРЫ ДЛЯ ПЕРСОНАЛА (Staff)

-- Добавление сотрудника
CREATE OR REPLACE PROCEDURE sp_add_staff(
    p_payroll_number INTEGER,
    p_full_name VARCHAR,
    p_passport VARCHAR,
    p_birth_date DATE,
    p_gender CHAR,
    p_position VARCHAR,
    p_salary DECIMAL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Проверка корректности должности
    IF p_position NOT IN ('директор', 'администратор', 'заведующий складом', 'смотритель') THEN
        RAISE EXCEPTION 'Некорректная должность: %', p_position;
    END IF;
    
    -- Проверка уникальности паспорта
    IF EXISTS (SELECT 1 FROM Staff WHERE passport_series_number = p_passport) THEN
        RAISE EXCEPTION 'Сотрудник с паспортом % уже существует', p_passport;
    END IF;
    
    INSERT INTO Staff (payroll_number, full_name, passport_series_number, 
                       birth_date, gender, position, salary)
    VALUES (p_payroll_number, p_full_name, p_passport, 
            p_birth_date, p_gender, p_position, p_salary);
    
    RAISE NOTICE 'Сотрудник % успешно добавлен', p_full_name;
END;
$$;

-- Изменение данных сотрудника
CREATE OR REPLACE PROCEDURE sp_update_staff(
    p_payroll_number INTEGER,
    p_full_name VARCHAR DEFAULT NULL,
    p_position VARCHAR DEFAULT NULL,
    p_salary DECIMAL DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Проверка существования сотрудника
    IF NOT EXISTS (SELECT 1 FROM Staff WHERE payroll_number = p_payroll_number) THEN
        RAISE EXCEPTION 'Сотрудник с табельным номером % не найден', p_payroll_number;
    END IF;
    
    UPDATE Staff
    SET 
        full_name = COALESCE(p_full_name, full_name),
        position = COALESCE(p_position, position),
        salary = COALESCE(p_salary, salary)
    WHERE payroll_number = p_payroll_number;
    
    RAISE NOTICE 'Данные сотрудника % обновлены', p_payroll_number;
END;
$$;

-- Удаление сотрудника
CREATE OR REPLACE PROCEDURE sp_delete_staff(
    p_payroll_number INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Проверка, не является ли сотрудник ответственным за вольеры
    IF EXISTS (SELECT 1 FROM Enclosures WHERE payroll_number = p_payroll_number) THEN
        RAISE EXCEPTION 'Невозможно удалить сотрудника: он ответственен за вольеры';
    END IF;
    
    -- Проверка наличия операций выдачи корма
    IF EXISTS (SELECT 1 FROM FeedIssues WHERE responsible_staff_id = p_payroll_number) THEN
        RAISE EXCEPTION 'Невозможно удалить сотрудника: есть связанные операции выдачи корма';
    END IF;
    
    DELETE FROM Staff WHERE payroll_number = p_payroll_number;
    
    RAISE NOTICE 'Сотрудник % удален', p_payroll_number;
END;
$$;

-- 2. ПРОЦЕДУРЫ ДЛЯ ВИДОВ ЖИВОТНЫХ (AnimalSpecies)

-- Добавление вида животного
CREATE OR REPLACE PROCEDURE sp_add_animal_species(
    p_scientific_name VARCHAR,
    p_class VARCHAR,
    p_enclosure_type VARCHAR,
    p_enclosure_water VARCHAR,
    p_required_area DECIMAL,
    p_category VARCHAR,
    p_feed_type VARCHAR,
    p_daily_feed DECIMAL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_species_id INTEGER;
    v_product_id INTEGER;
BEGIN
    -- Проверка уникальности научного названия
    IF EXISTS (SELECT 1 FROM AnimalSpecies WHERE scientific_name = p_scientific_name) THEN
        RAISE EXCEPTION 'Вид % уже существует', p_scientific_name;
    END IF;
    
    -- Проверка существования корма, если нет - создать
    SELECT product_id INTO v_product_id 
    FROM FeedProducts 
    WHERE feed_type = p_feed_type;
    
    IF v_product_id IS NULL THEN
        INSERT INTO FeedProducts (feed_type) VALUES (p_feed_type)
        RETURNING product_id INTO v_product_id;
        
        -- Создать запись на складе для нового корма
        INSERT INTO StoreStock (product_id, quantity_kg, reorder_threshold_kg)
        VALUES (v_product_id, 0, 100);
        
        RAISE NOTICE 'Создан новый тип корма: %', p_feed_type;
    END IF;
    
    INSERT INTO AnimalSpecies (
        scientific_name, class, required_enclosure_type, required_enclosure_water,
        required_area, category, feed_type, base_daily_feed_kg
    )
    VALUES (
        p_scientific_name, p_class, p_enclosure_type, p_enclosure_water,
        p_required_area, p_category, p_feed_type, p_daily_feed
    )
    RETURNING species_id INTO v_species_id;
    
    RAISE NOTICE 'Вид животного % добавлен с ID=%', p_scientific_name, v_species_id;
END;
$$;

-- Удаление вида животного
CREATE OR REPLACE PROCEDURE sp_delete_animal_species(
    p_species_id INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Проверка наличия животных данного вида
    IF EXISTS (SELECT 1 FROM Animals WHERE species_id = p_species_id) THEN
        RAISE EXCEPTION 'Невозможно удалить вид: существуют животные данного вида';
    END IF;
    
    DELETE FROM AnimalSpecies WHERE species_id = p_species_id;
    
    RAISE NOTICE 'Вид животного ID=% удален', p_species_id;
END;
$$;

-- 3. ПРОЦЕДУРЫ ДЛЯ ВОЛЬЕРОВ (Enclosures)

-- Добавление вольера
CREATE OR REPLACE PROCEDURE sp_add_enclosure(
    p_enclosure_type VARCHAR,
    p_enclosure_water VARCHAR,
    p_size_m2 DECIMAL,
    p_status VARCHAR,
    p_keeper_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_enclosure_id INTEGER;
BEGIN
    -- Проверка существования смотрителя
    IF NOT EXISTS (SELECT 1 FROM Staff WHERE payroll_number = p_keeper_id AND position = 'смотритель') THEN
        RAISE EXCEPTION 'Смотритель с табельным номером % не найден', p_keeper_id;
    END IF;
    
    INSERT INTO Enclosures (enclosure_type, enclosure_water, size_m2, status, payroll_number)
    VALUES (p_enclosure_type, p_enclosure_water, p_size_m2, p_status, p_keeper_id)
    RETURNING enclosure_id INTO v_enclosure_id;
    
    RAISE NOTICE 'Вольер ID=% успешно создан', v_enclosure_id;
END;
$$;

-- Изменение статуса вольера
CREATE OR REPLACE PROCEDURE sp_update_enclosure_status(
    p_enclosure_id INTEGER,
    p_status VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Enclosures WHERE enclosure_id = p_enclosure_id) THEN
        RAISE EXCEPTION 'Вольер ID=% не найден', p_enclosure_id;
    END IF;
    
    UPDATE Enclosures
    SET status = p_status
    WHERE enclosure_id = p_enclosure_id;
    
    RAISE NOTICE 'Статус вольера ID=% изменен на %', p_enclosure_id, p_status;
END;
$$;

-- Назначение ответственного смотрителя
CREATE OR REPLACE PROCEDURE sp_assign_keeper_to_enclosure(
    p_enclosure_id INTEGER,
    p_keeper_id INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Staff WHERE payroll_number = p_keeper_id AND position = 'смотритель') THEN
        RAISE EXCEPTION 'Смотритель с табельным номером % не найден', p_keeper_id;
    END IF;
    
    UPDATE Enclosures
    SET payroll_number = p_keeper_id
    WHERE enclosure_id = p_enclosure_id;
    
    RAISE NOTICE 'Смотритель % назначен ответственным за вольер ID=%', p_keeper_id, p_enclosure_id;
END;
$$;

-- 4. ПРОЦЕДУРЫ ДЛЯ ЖИВОТНЫХ (Animals)

-- Добавление животного
CREATE OR REPLACE PROCEDURE sp_add_animal(
    p_species_id INTEGER,
    p_animal_name VARCHAR,
    p_birth_date DATE,
    p_arrival_date DATE,
    p_sex CHAR,
    p_enclosure_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_animal_id INTEGER;
    v_required_area DECIMAL;
    v_occupied_area DECIMAL;
    v_enclosure_size DECIMAL;
    v_enclosure_type VARCHAR;
    v_enclosure_water VARCHAR;
    v_required_type VARCHAR;
    v_required_water VARCHAR;
BEGIN
    -- Получение требований вида
    SELECT required_area, required_enclosure_type, required_enclosure_water
    INTO v_required_area, v_required_type, v_required_water
    FROM AnimalSpecies
    WHERE species_id = p_species_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Вид животного ID=% не найден', p_species_id;
    END IF;
    
    -- Получение параметров вольера
    SELECT size_m2, enclosure_type, enclosure_water
    INTO v_enclosure_size, v_enclosure_type, v_enclosure_water
    FROM Enclosures
    WHERE enclosure_id = p_enclosure_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Вольер ID=% не найден', p_enclosure_id;
    END IF;
    
    -- Проверка совместимости типа вольера
    IF v_enclosure_type != v_required_type OR v_enclosure_water != v_required_water THEN
        RAISE EXCEPTION 'Вольер не подходит для данного вида животного';
    END IF;
    
    -- Расчет занятой площади
    SELECT COALESCE(SUM(asp.required_area), 0)
    INTO v_occupied_area
    FROM Animals a
    JOIN AnimalSpecies asp ON a.species_id = asp.species_id
    WHERE a.enclosure_id = p_enclosure_id;
    
    -- Проверка достаточности площади
    IF (v_occupied_area + v_required_area) > v_enclosure_size THEN
        RAISE EXCEPTION 'Недостаточно места в вольере. Требуется: %, Доступно: %', 
            v_required_area, (v_enclosure_size - v_occupied_area);
    END IF;
    
    INSERT INTO Animals (species_id, animal_name, birth_date, arrival_date, sex, enclosure_id)
    VALUES (p_species_id, p_animal_name, p_birth_date, p_arrival_date, p_sex, p_enclosure_id)
    RETURNING animal_id INTO v_animal_id;
    
    RAISE NOTICE 'Животное % (ID=%) успешно добавлено в вольер ID=%', 
        p_animal_name, v_animal_id, p_enclosure_id;
END;
$$;

-- Перемещение животного в другой вольер
CREATE OR REPLACE PROCEDURE sp_move_animal(
    p_animal_id INTEGER,
    p_new_enclosure_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_species_id INTEGER;
    v_required_area DECIMAL;
    v_occupied_area DECIMAL;
    v_enclosure_size DECIMAL;
    v_enclosure_type VARCHAR;
    v_enclosure_water VARCHAR;
    v_required_type VARCHAR;
    v_required_water VARCHAR;
BEGIN
    -- Получение данных о животном
    SELECT species_id INTO v_species_id
    FROM Animals
    WHERE animal_id = p_animal_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Животное ID=% не найдено', p_animal_id;
    END IF;
    
    -- Получение требований вида
    SELECT required_area, required_enclosure_type, required_enclosure_water
    INTO v_required_area, v_required_type, v_required_water
    FROM AnimalSpecies
    WHERE species_id = v_species_id;
    
    -- Получение параметров нового вольера
    SELECT size_m2, enclosure_type, enclosure_water
    INTO v_enclosure_size, v_enclosure_type, v_enclosure_water
    FROM Enclosures
    WHERE enclosure_id = p_new_enclosure_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Вольер ID=% не найден', p_new_enclosure_id;
    END IF;
    
    -- Проверка совместимости
    IF v_enclosure_type != v_required_type OR v_enclosure_water != v_required_water THEN
        RAISE EXCEPTION 'Новый вольер не подходит для данного вида животного';
    END IF;
    
    -- Расчет занятой площади в новом вольере
    SELECT COALESCE(SUM(asp.required_area), 0)
    INTO v_occupied_area
    FROM Animals a
    JOIN AnimalSpecies asp ON a.species_id = asp.species_id
    WHERE a.enclosure_id = p_new_enclosure_id;
    
    IF (v_occupied_area + v_required_area) > v_enclosure_size THEN
        RAISE EXCEPTION 'Недостаточно места в новом вольере';
    END IF;
    
    UPDATE Animals
    SET enclosure_id = p_new_enclosure_id
    WHERE animal_id = p_animal_id;
    
    RAISE NOTICE 'Животное ID=% перемещено в вольер ID=%', p_animal_id, p_new_enclosure_id;
END;
$$;

-- Удаление животного
CREATE OR REPLACE PROCEDURE sp_delete_animal(
    p_animal_id INTEGER,
    p_reason VARCHAR DEFAULT 'Не указана'
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Animals WHERE animal_id = p_animal_id) THEN
        RAISE EXCEPTION 'Животное ID=% не найдено', p_animal_id;
    END IF;
    
    DELETE FROM Animals WHERE animal_id = p_animal_id;
    
    RAISE NOTICE 'Животное ID=% удалено. Причина: %', p_animal_id, p_reason;
END;
$$;

-- 5. ПРОЦЕДУРЫ ДЛЯ ПОСТАВОК (Deliveries)

-- Регистрация поставки корма
CREATE OR REPLACE PROCEDURE sp_register_delivery(
    p_delivery_date DATE,
    p_supplier_name VARCHAR,
    p_product_id INTEGER,
    p_delivery_kg DECIMAL,
    p_price_per_kg DECIMAL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_delivery_id INTEGER;
BEGIN
    -- Проверка существования корма
    IF NOT EXISTS (SELECT 1 FROM FeedProducts WHERE product_id = p_product_id) THEN
        RAISE EXCEPTION 'Корм ID=% не найден', p_product_id;
    END IF;
    
    -- Регистрация поставки
    INSERT INTO Deliveries (delivery_date, supplier_name, product_id, delivery_kg, price_per_kg)
    VALUES (p_delivery_date, p_supplier_name, p_product_id, p_delivery_kg, p_price_per_kg)
    RETURNING delivery_id INTO v_delivery_id;
    
    -- Обновление остатка на складе
    UPDATE StoreStock
    SET quantity_kg = quantity_kg + p_delivery_kg
    WHERE product_id = p_product_id;
    
    RAISE NOTICE 'Поставка ID=% зарегистрирована. Остаток обновлен.', v_delivery_id;
END;
$$;

-- 6. ПРОЦЕДУРЫ ДЛЯ ВЫДАЧИ КОРМА (FeedIssues)

-- Выдача корма в вольер
CREATE OR REPLACE PROCEDURE sp_issue_feed(
    p_issue_date DATE,
    p_enclosure_id INTEGER,
    p_product_id INTEGER,
    p_output_kg DECIMAL,
    p_staff_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_issue_id INTEGER;
    v_current_stock DECIMAL;
    v_feed_type VARCHAR;
    v_species_feed_type VARCHAR;
BEGIN
    -- Проверка остатка на складе
    SELECT quantity_kg INTO v_current_stock
    FROM StoreStock
    WHERE product_id = p_product_id;
    
    IF v_current_stock IS NULL THEN
        RAISE EXCEPTION 'Корм ID=% не найден на складе', p_product_id;
    END IF;
    
    IF v_current_stock < p_output_kg THEN
        RAISE EXCEPTION 'Недостаточно корма на складе. Доступно: % кг, Требуется: % кг', 
            v_current_stock, p_output_kg;
    END IF;
    
    -- Проверка соответствия корма виду животных в вольере
    SELECT fp.feed_type INTO v_feed_type
    FROM FeedProducts fp
    WHERE fp.product_id = p_product_id;
    
    -- Проверяем, что все животные в вольере едят этот корм
    IF EXISTS (
        SELECT 1 
        FROM Animals a
        JOIN AnimalSpecies asp ON a.species_id = asp.species_id
        WHERE a.enclosure_id = p_enclosure_id
        AND asp.feed_type != v_feed_type
    ) THEN
        RAISE EXCEPTION 'Тип корма не соответствует виду животных в вольере';
    END IF;
    
    -- Регистрация выдачи
    INSERT INTO FeedIssues (issue_date, enclosure_id, product_id, output_kg, responsible_staff_id)
    VALUES (p_issue_date, p_enclosure_id, p_product_id, p_output_kg, p_staff_id)
    RETURNING issue_id INTO v_issue_id;
    
    -- Уменьшение остатка на складе
    UPDATE StoreStock
    SET quantity_kg = quantity_kg - p_output_kg
    WHERE product_id = p_product_id;
    
    RAISE NOTICE 'Выдача ID=% зарегистрирована. Выдано % кг корма в вольер ID=%', 
        v_issue_id, p_output_kg, p_enclosure_id;
END;
$$;

-- ТРИГГЕРЫ

-- Триггер: проверка единственности записи в Zoo
CREATE OR REPLACE FUNCTION trg_zoo_single_record()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM Zoo) >= 1 AND TG_OP = 'INSERT' THEN
        RAISE EXCEPTION 'В таблице Zoo может быть только одна запись';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_zoo_single_record
    BEFORE INSERT ON Zoo
    FOR EACH ROW
    EXECUTE FUNCTION trg_zoo_single_record();

-- Триггер: автоматическое создание записи на складе при добавлении нового корма
CREATE OR REPLACE FUNCTION trg_create_stock_for_new_feed()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO StoreStock (product_id, quantity_kg, reorder_threshold_kg)
    VALUES (NEW.product_id, 0, 100)
    ON CONFLICT (product_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_create_stock_for_new_feed
    AFTER INSERT ON FeedProducts
    FOR EACH ROW
    EXECUTE FUNCTION trg_create_stock_for_new_feed();

-- Триггер: предупреждение о низком остатке корма
CREATE OR REPLACE FUNCTION trg_check_low_stock()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.quantity_kg < NEW.reorder_threshold_kg THEN
        RAISE NOTICE 'ВНИМАНИЕ: Остаток корма ID=% ниже порога! Текущий остаток: % кг, Порог: % кг',
            NEW.product_id, NEW.quantity_kg, NEW.reorder_threshold_kg;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_check_low_stock
    AFTER UPDATE OF quantity_kg ON StoreStock
    FOR EACH ROW
    EXECUTE FUNCTION trg_check_low_stock();

-- Триггер: логирование изменений статуса вольера
CREATE TABLE EnclosureStatusLog (
    log_id SERIAL PRIMARY KEY,
    enclosure_id INTEGER NOT NULL,
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION trg_log_enclosure_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO EnclosureStatusLog (enclosure_id, old_status, new_status)
        VALUES (NEW.enclosure_id, OLD.status, NEW.status);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_log_enclosure_status_change
    AFTER UPDATE OF status ON Enclosures
    FOR EACH ROW
    EXECUTE FUNCTION trg_log_enclosure_status_change();

COMMENT ON TABLE EnclosureStatusLog IS 'Журнал изменений статусов вольеров';
