-- ПРОЦЕДУРЫ ДЛЯ БИЗНЕС-ПРОЦЕССОВ

-- 1. РАСЧЕТЫ

-- Расчет суточной потребности в корме для вольера
CREATE OR REPLACE FUNCTION fn_calculate_daily_feed_requirement(
    p_enclosure_id INTEGER
)
RETURNS TABLE (
    feed_type VARCHAR,
    total_daily_kg DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        asp.feed_type,
        SUM(asp.base_daily_feed_kg) as total_daily_kg
    FROM Animals a
    JOIN AnimalSpecies asp ON a.species_id = asp.species_id
    WHERE a.enclosure_id = p_enclosure_id
    GROUP BY asp.feed_type;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_calculate_daily_feed_requirement IS 'Расчет суточной потребности в корме для конкретного вольера';

-- Расчет общей суточной потребности зоопарка в кормах
CREATE OR REPLACE FUNCTION fn_calculate_zoo_daily_feed_requirement()
RETURNS TABLE (
    feed_type VARCHAR,
    total_daily_kg DECIMAL,
    current_stock_kg DECIMAL,
    days_remaining DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        asp.feed_type,
        SUM(asp.base_daily_feed_kg) as total_daily_kg,
        COALESCE(ss.quantity_kg, 0) as current_stock_kg,
        CASE 
            WHEN SUM(asp.base_daily_feed_kg) > 0 THEN 
                ROUND(COALESCE(ss.quantity_kg, 0) / SUM(asp.base_daily_feed_kg), 2)
            ELSE 0
        END as days_remaining
    FROM AnimalSpecies asp
    JOIN Animals a ON a.species_id = asp.species_id
    LEFT JOIN FeedProducts fp ON fp.feed_type = asp.feed_type
    LEFT JOIN StoreStock ss ON ss.product_id = fp.product_id
    GROUP BY asp.feed_type, ss.quantity_kg
    ORDER BY days_remaining;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_calculate_zoo_daily_feed_requirement IS 'Расчет общей суточной потребности зоопарка в кормах и остатков';

-- 2. ПЛАНИРОВАНИЕ КОРМЛЕНИЯ

-- Процедура планирования кормления на день
CREATE OR REPLACE PROCEDURE sp_plan_daily_feeding(
    p_feeding_date DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_enclosure RECORD;
    v_feed RECORD;
BEGIN
    RAISE NOTICE '=== ПЛАН КОРМЛЕНИЯ НА % ===', p_feeding_date;
    
    FOR v_enclosure IN 
        SELECT DISTINCT e.enclosure_id, e.enclosure_type
        FROM Enclosures e
        WHERE e.status = 'IN_SERVICE'
        AND EXISTS (SELECT 1 FROM Animals a WHERE a.enclosure_id = e.enclosure_id)
        ORDER BY e.enclosure_id
    LOOP
        RAISE NOTICE 'Вольер ID=%:', v_enclosure.enclosure_id;
        
        FOR v_feed IN 
            SELECT * FROM fn_calculate_daily_feed_requirement(v_enclosure.enclosure_id)
        LOOP
            RAISE NOTICE '  - Корм: %, Количество: % кг', v_feed.feed_type, v_feed.total_daily_kg;
        END LOOP;
    END LOOP;
END;
$$;

COMMENT ON PROCEDURE sp_plan_daily_feeding IS 'Формирование плана кормления на день';

-- 3. УПРАВЛЕНИЕ ЗАПАСАМИ

-- Процедура автоматического формирования заказа кормов
CREATE OR REPLACE PROCEDURE sp_generate_feed_reorder_list()
LANGUAGE plpgsql
AS $$
DECLARE
    v_feed RECORD;
    v_daily_consumption DECIMAL;
    v_recommended_order DECIMAL;
BEGIN
    RAISE NOTICE '=== СПИСОК КОРМОВ ДЛЯ ЗАКАЗА ===';
    
    FOR v_feed IN 
        SELECT 
            fp.product_id,
            fp.feed_type,
            ss.quantity_kg,
            ss.reorder_threshold_kg
        FROM FeedProducts fp
        JOIN StoreStock ss ON ss.product_id = fp.product_id
        WHERE ss.quantity_kg < ss.reorder_threshold_kg
        ORDER BY (ss.quantity_kg / NULLIF(ss.reorder_threshold_kg, 0))
    LOOP
        -- Расчет суточного потребления
        SELECT COALESCE(SUM(asp.base_daily_feed_kg), 0)
        INTO v_daily_consumption
        FROM Animals a
        JOIN AnimalSpecies asp ON a.species_id = asp.species_id
        WHERE asp.feed_type = v_feed.feed_type;
        
        -- Рекомендуемый заказ на 30 дней
        v_recommended_order := GREATEST(
            v_feed.reorder_threshold_kg * 2,
            v_daily_consumption * 30
        );
        
        RAISE NOTICE 'Корм: %', v_feed.feed_type;
        RAISE NOTICE '  Текущий остаток: % кг', v_feed.quantity_kg;
        RAISE NOTICE '  Суточное потребление: % кг', v_daily_consumption;
        RAISE NOTICE '  Рекомендуемый заказ: % кг', ROUND(v_recommended_order, 2);
        RAISE NOTICE '';
    END LOOP;
END;
$$;

COMMENT ON PROCEDURE sp_generate_feed_reorder_list IS 'Формирование списка кормов для заказа';

-- 4. ОТЧЕТЫ ПО РАСХОДУ КОРМОВ

-- Отчет по расходу кормов за период
CREATE OR REPLACE FUNCTION fn_feed_consumption_report(
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    feed_type VARCHAR,
    total_issued_kg DECIMAL,
    total_deliveries_kg DECIMAL,
    net_consumption_kg DECIMAL,
    total_cost DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        fp.feed_type,
        COALESCE(SUM(fi.output_kg), 0) as total_issued_kg,
        COALESCE(SUM(d.delivery_kg), 0) as total_deliveries_kg,
        COALESCE(SUM(fi.output_kg), 0) - COALESCE(SUM(d.delivery_kg), 0) as net_consumption_kg,
        COALESCE(SUM(d.delivery_kg * d.price_per_kg), 0) as total_cost
    FROM FeedProducts fp
    LEFT JOIN FeedIssues fi ON fi.product_id = fp.product_id 
        AND fi.issue_date BETWEEN p_start_date AND p_end_date
    LEFT JOIN Deliveries d ON d.product_id = fp.product_id 
        AND d.delivery_date BETWEEN p_start_date AND p_end_date
    GROUP BY fp.feed_type
    ORDER BY total_issued_kg DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_feed_consumption_report IS 'Отчет по расходу и поступлению кормов за период';

-- 5. УПРАВЛЕНИЕ ВОЛЬЕРАМИ

-- Получение информации о загруженности вольера
CREATE OR REPLACE FUNCTION fn_get_enclosure_occupancy(
    p_enclosure_id INTEGER
)
RETURNS TABLE (
    enclosure_id INTEGER,
    size_m2 DECIMAL,
    occupied_area_m2 DECIMAL,
    available_area_m2 DECIMAL,
    animal_count INTEGER,
    occupancy_percent DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.enclosure_id,
        e.size_m2,
        COALESCE(SUM(asp.required_area), 0) as occupied_area_m2,
        e.size_m2 - COALESCE(SUM(asp.required_area), 0) as available_area_m2,
        COUNT(a.animal_id)::INTEGER as animal_count,
        ROUND((COALESCE(SUM(asp.required_area), 0) / e.size_m2 * 100), 2) as occupancy_percent
    FROM Enclosures e
    LEFT JOIN Animals a ON a.enclosure_id = e.enclosure_id
    LEFT JOIN AnimalSpecies asp ON a.species_id = asp.species_id
    WHERE e.enclosure_id = p_enclosure_id
    GROUP BY e.enclosure_id, e.size_m2;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_get_enclosure_occupancy IS 'Получение информации о загруженности вольера';

-- Поиск подходящего вольера для животного
CREATE OR REPLACE FUNCTION fn_find_suitable_enclosure(
    p_species_id INTEGER
)
RETURNS TABLE (
    enclosure_id INTEGER,
    size_m2 DECIMAL,
    available_area_m2 DECIMAL,
    current_animals INTEGER
) AS $$
DECLARE
    v_required_type VARCHAR;
    v_required_water VARCHAR;
    v_required_area DECIMAL;
BEGIN
    -- Получение требований вида
    SELECT required_enclosure_type, required_enclosure_water, required_area
    INTO v_required_type, v_required_water, v_required_area
    FROM AnimalSpecies
    WHERE species_id = p_species_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Вид животного не найден';
    END IF;
    
    RETURN QUERY
    SELECT 
        e.enclosure_id,
        e.size_m2,
        e.size_m2 - COALESCE(SUM(asp.required_area), 0) as available_area_m2,
        COUNT(a.animal_id)::INTEGER as current_animals
    FROM Enclosures e
    LEFT JOIN Animals a ON a.enclosure_id = e.enclosure_id
    LEFT JOIN AnimalSpecies asp ON a.species_id = asp.species_id
    WHERE e.enclosure_type = v_required_type
        AND e.enclosure_water = v_required_water
        AND e.status = 'IN_SERVICE'
    GROUP BY e.enclosure_id, e.size_m2
    HAVING e.size_m2 - COALESCE(SUM(asp.required_area), 0) >= v_required_area
    ORDER BY available_area_m2 DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_find_suitable_enclosure IS 'Поиск подходящих вольеров для размещения животного';

-- 6. ОТЧЕТЫ ПО ПЕРСОНАЛУ

-- Отчет о нагрузке смотрителей
CREATE OR REPLACE FUNCTION fn_keeper_workload_report()
RETURNS TABLE (
    payroll_number INTEGER,
    full_name VARCHAR,
    enclosures_count INTEGER,
    total_animals INTEGER,
    feed_issues_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.payroll_number,
        s.full_name,
        COUNT(DISTINCT e.enclosure_id)::INTEGER as enclosures_count,
        COUNT(DISTINCT a.animal_id)::INTEGER as total_animals,
        COUNT(DISTINCT fi.issue_id)::INTEGER as feed_issues_count
    FROM Staff s
    LEFT JOIN Enclosures e ON e.payroll_number = s.payroll_number
    LEFT JOIN Animals a ON a.enclosure_id = e.enclosure_id
    LEFT JOIN FeedIssues fi ON fi.responsible_staff_id = s.payroll_number
    WHERE s.position = 'смотритель'
    GROUP BY s.payroll_number, s.full_name
    ORDER BY enclosures_count DESC, total_animals DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_keeper_workload_report IS 'Отчет о нагрузке смотрителей';

-- 7. ПРОВЕРКА СОСТОЯНИЯ СИСТЕМЫ

-- Комплексная проверка состояния системы
CREATE OR REPLACE PROCEDURE sp_system_health_check()
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_animals INTEGER;
    v_total_enclosures INTEGER;
    v_total_staff INTEGER;
    v_low_stock_count INTEGER;
    v_enclosures_needing_repair INTEGER;
BEGIN
    RAISE NOTICE '=== ПРОВЕРКА СОСТОЯНИЯ СИСТЕМЫ ===';
    RAISE NOTICE '';
    
    -- Общая статистика
    SELECT COUNT(*) INTO v_total_animals FROM Animals;
    SELECT COUNT(*) INTO v_total_enclosures FROM Enclosures;
    SELECT COUNT(*) INTO v_total_staff FROM Staff;
    
    RAISE NOTICE 'Общая статистика:';
    RAISE NOTICE '  Животных в зоопарке: %', v_total_animals;
    RAISE NOTICE '  Вольеров: %', v_total_enclosures;
    RAISE NOTICE '  Сотрудников: %', v_total_staff;
    RAISE NOTICE '';
    
    -- Проверка запасов корма
    SELECT COUNT(*) INTO v_low_stock_count
    FROM StoreStock
    WHERE quantity_kg < reorder_threshold_kg;
    
    IF v_low_stock_count > 0 THEN
        RAISE WARNING 'ВНИМАНИЕ: % видов корма ниже порога заказа!', v_low_stock_count;
    ELSE
        RAISE NOTICE 'Запасы кормов в норме';
    END IF;
    RAISE NOTICE '';
    
    -- Проверка вольеров
    SELECT COUNT(*) INTO v_enclosures_needing_repair
    FROM Enclosures
    WHERE status = 'UNDER_REPAIR';
    
    IF v_enclosures_needing_repair > 0 THEN
        RAISE NOTICE 'Вольеров на ремонте: %', v_enclosures_needing_repair;
    END IF;
    
    -- Проверка перегруженных вольеров
    IF EXISTS (
        SELECT 1
        FROM Enclosures e
        LEFT JOIN Animals a ON a.enclosure_id = e.enclosure_id
        LEFT JOIN AnimalSpecies asp ON a.species_id = asp.species_id
        GROUP BY e.enclosure_id, e.size_m2
        HAVING COALESCE(SUM(asp.required_area), 0) > e.size_m2
    ) THEN
        RAISE WARNING 'ВНИМАНИЕ: Обнаружены перегруженные вольеры!';
    ELSE
        RAISE NOTICE 'Все вольеры в пределах допустимой загрузки';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== ПРОВЕРКА ЗАВЕРШЕНА ===';
END;
$$;

COMMENT ON PROCEDURE sp_system_health_check IS 'Комплексная проверка состояния системы';

-- 8. МАССОВЫЕ ОПЕРАЦИИ

-- Массовое кормление всех вольеров
CREATE OR REPLACE PROCEDURE sp_feed_all_enclosures(
    p_feeding_date DATE,
    p_staff_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_enclosure RECORD;
    v_feed RECORD;
    v_product_id INTEGER;
BEGIN
    RAISE NOTICE 'Начало массового кормления на дату: %', p_feeding_date;
    
    FOR v_enclosure IN 
        SELECT DISTINCT e.enclosure_id
        FROM Enclosures e
        WHERE e.status = 'IN_SERVICE'
        AND EXISTS (SELECT 1 FROM Animals a WHERE a.enclosure_id = e.enclosure_id)
    LOOP
        FOR v_feed IN 
            SELECT * FROM fn_calculate_daily_feed_requirement(v_enclosure.enclosure_id)
        LOOP
            -- Получить product_id по типу корма
            SELECT product_id INTO v_product_id
            FROM FeedProducts
            WHERE feed_type = v_feed.feed_type;
            
            -- Выдать корм
            BEGIN
                CALL sp_issue_feed(
                    p_feeding_date,
                    v_enclosure.enclosure_id,
                    v_product_id,
                    v_feed.total_daily_kg,
                    p_staff_id
                );
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'Ошибка при кормлении вольера %: %', v_enclosure.enclosure_id, SQLERRM;
            END;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE 'Массовое кормление завершено';
END;
$$;

COMMENT ON PROCEDURE sp_feed_all_enclosures IS 'Массовое кормление всех вольеров';

-- 9. СТАТИСТИКА И АНАЛИТИКА

-- Получение статистики по видам животных
CREATE OR REPLACE FUNCTION fn_species_statistics()
RETURNS TABLE (
    species_name VARCHAR,
    class VARCHAR,
    total_count INTEGER,
    male_count INTEGER,
    female_count INTEGER,
    avg_age_years DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        asp.scientific_name,
        asp.class,
        COUNT(a.animal_id)::INTEGER as total_count,
        COUNT(CASE WHEN a.sex = 'М' THEN 1 END)::INTEGER as male_count,
        COUNT(CASE WHEN a.sex = 'Ж' THEN 1 END)::INTEGER as female_count,
        ROUND(AVG(EXTRACT(YEAR FROM AGE(CURRENT_DATE, a.birth_date))), 1) as avg_age_years
    FROM AnimalSpecies asp
    LEFT JOIN Animals a ON a.species_id = asp.species_id
    GROUP BY asp.species_id, asp.scientific_name, asp.class
    HAVING COUNT(a.animal_id) > 0
    ORDER BY total_count DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_species_statistics IS 'Статистика по видам животных';

-- Расчет стоимости содержания животного
CREATE OR REPLACE FUNCTION fn_calculate_animal_monthly_cost(
    p_animal_id INTEGER
)
RETURNS DECIMAL AS $$
DECLARE
    v_daily_feed_kg DECIMAL;
    v_avg_price_per_kg DECIMAL;
    v_monthly_cost DECIMAL;
BEGIN
    -- Получение суточной нормы корма
    SELECT asp.base_daily_feed_kg
    INTO v_daily_feed_kg
    FROM Animals a
    JOIN AnimalSpecies asp ON a.species_id = asp.species_id
    WHERE a.animal_id = p_animal_id;
    
    IF NOT FOUND THEN
        RETURN 0;
    END IF;
    
    -- Получение средней цены корма за последние 3 месяца
    SELECT AVG(d.price_per_kg)
    INTO v_avg_price_per_kg
    FROM Animals a
    JOIN AnimalSpecies asp ON a.species_id = asp.species_id
    JOIN FeedProducts fp ON fp.feed_type = asp.feed_type
    JOIN Deliveries d ON d.product_id = fp.product_id
    WHERE a.animal_id = p_animal_id
        AND d.delivery_date >= CURRENT_DATE - INTERVAL '3 months'
        AND d.price_per_kg IS NOT NULL;
    
    IF v_avg_price_per_kg IS NULL THEN
        v_avg_price_per_kg := 100; -- Значение по умолчанию
    END IF;
    
    v_monthly_cost := v_daily_feed_kg * v_avg_price_per_kg * 30;
    
    RETURN ROUND(v_monthly_cost, 2);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_calculate_animal_monthly_cost IS 'Расчет ежемесячной стоимости содержания животного (только корм)';
