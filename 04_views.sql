-- ПРЕДСТАВЛЕНИЯ (VIEWS) ДЛЯ ОСНОВНЫХ ЗАПРОСОВ

-- 1. ПРЕДСТАВЛЕНИЯ ДЛЯ ЖИВОТНЫХ

-- Полная информация о животных
CREATE OR REPLACE VIEW v_animals_full_info AS
SELECT 
    a.animal_id,
    a.animal_name,
    asp.scientific_name as species_name,
    asp.class,
    asp.category,
    a.sex,
    a.birth_date,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, a.birth_date))::INTEGER as age_years,
    a.arrival_date,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, a.arrival_date))::INTEGER as years_in_zoo,
    e.enclosure_id,
    e.enclosure_type,
    e.enclosure_water,
    s.full_name as keeper_name,
    asp.feed_type,
    asp.base_daily_feed_kg
FROM Animals a
JOIN AnimalSpecies asp ON a.species_id = asp.species_id
JOIN Enclosures e ON a.enclosure_id = e.enclosure_id
JOIN Staff s ON e.payroll_number = s.payroll_number;

COMMENT ON VIEW v_animals_full_info IS 'Полная информация о всех животных в зоопарке';

-- Животные по вольерам
CREATE OR REPLACE VIEW v_animals_by_enclosure AS
SELECT 
    e.enclosure_id,
    e.enclosure_type,
    e.enclosure_water,
    e.size_m2,
    e.status,
    COUNT(a.animal_id) as animal_count,
    COALESCE(SUM(asp.required_area), 0) as occupied_area_m2,
    e.size_m2 - COALESCE(SUM(asp.required_area), 0) as available_area_m2,
    ROUND((COALESCE(SUM(asp.required_area), 0) / e.size_m2 * 100), 2) as occupancy_percent,
    s.full_name as keeper_name,
    s.payroll_number as keeper_id
FROM Enclosures e
LEFT JOIN Animals a ON a.enclosure_id = e.enclosure_id
LEFT JOIN AnimalSpecies asp ON a.species_id = asp.species_id
JOIN Staff s ON e.payroll_number = s.payroll_number
GROUP BY e.enclosure_id, e.enclosure_type, e.enclosure_water, e.size_m2, 
         e.status, s.full_name, s.payroll_number;

COMMENT ON VIEW v_animals_by_enclosure IS 'Информация о животных, сгруппированных по вольерам';

-- 2. ПРЕДСТАВЛЕНИЯ ДЛЯ КОРМОВ

-- Текущее состояние склада
CREATE OR REPLACE VIEW v_current_stock_status AS
SELECT 
    fp.product_id,
    fp.feed_type,
    ss.quantity_kg as current_stock_kg,
    ss.reorder_threshold_kg,
    CASE 
        WHEN ss.quantity_kg < ss.reorder_threshold_kg THEN 'НИЗКИЙ'
        WHEN ss.quantity_kg < ss.reorder_threshold_kg * 1.5 THEN 'СРЕДНИЙ'
        ELSE 'ДОСТАТОЧНЫЙ'
    END as stock_level,
    -- Суточное потребление
    COALESCE((
        SELECT SUM(asp.base_daily_feed_kg)
        FROM Animals a
        JOIN AnimalSpecies asp ON a.species_id = asp.species_id
        WHERE asp.feed_type = fp.feed_type
    ), 0) as daily_consumption_kg,
    -- Дней остаток
    CASE 
        WHEN COALESCE((
            SELECT SUM(asp.base_daily_feed_kg)
            FROM Animals a
            JOIN AnimalSpecies asp ON a.species_id = asp.species_id
            WHERE asp.feed_type = fp.feed_type
        ), 0) > 0 THEN 
            ROUND(ss.quantity_kg / (
                SELECT SUM(asp.base_daily_feed_kg)
                FROM Animals a
                JOIN AnimalSpecies asp ON a.species_id = asp.species_id
                WHERE asp.feed_type = fp.feed_type
            ), 1)
        ELSE 999
    END as days_remaining
FROM FeedProducts fp
JOIN StoreStock ss ON ss.product_id = fp.product_id
ORDER BY days_remaining, stock_level;

COMMENT ON VIEW v_current_stock_status IS 'Текущее состояние склада с расчетом остатков';

-- История движения кормов
CREATE OR REPLACE VIEW v_feed_movement_history AS
SELECT 
    'ПОСТАВКА' as operation_type,
    d.delivery_id as operation_id,
    d.delivery_date as operation_date,
    fp.feed_type,
    d.delivery_kg as quantity_kg,
    d.supplier_name as counterparty,
    NULL::INTEGER as enclosure_id,
    NULL::VARCHAR as staff_name,
    d.delivery_kg * COALESCE(d.price_per_kg, 0) as total_cost
FROM Deliveries d
JOIN FeedProducts fp ON d.product_id = fp.product_id

UNION ALL

SELECT 
    'ВЫДАЧА' as operation_type,
    fi.issue_id as operation_id,
    fi.issue_date as operation_date,
    fp.feed_type,
    -fi.output_kg as quantity_kg,
    'Вольер #' || fi.enclosure_id as counterparty,
    fi.enclosure_id,
    s.full_name as staff_name,
    NULL as total_cost
FROM FeedIssues fi
JOIN FeedProducts fp ON fi.product_id = fp.product_id
JOIN Staff s ON fi.responsible_staff_id = s.payroll_number

ORDER BY operation_date DESC, operation_type;

COMMENT ON VIEW v_feed_movement_history IS 'История всех операций с кормами (поставки и выдачи)';

-- 3. ПРЕДСТАВЛЕНИЯ ДЛЯ ПЕРСОНАЛА

-- Информация о смотрителях и их нагрузке
CREATE OR REPLACE VIEW v_keepers_workload AS
SELECT 
    s.payroll_number,
    s.full_name,
    s.salary,
    COUNT(DISTINCT e.enclosure_id) as enclosures_count,
    COUNT(DISTINCT a.animal_id) as total_animals,
    COALESCE(SUM(e.size_m2), 0) as total_area_m2,
    COUNT(DISTINCT fi.issue_id) as feed_operations_last_30_days
FROM Staff s
LEFT JOIN Enclosures e ON e.payroll_number = s.payroll_number
LEFT JOIN Animals a ON a.enclosure_id = e.enclosure_id
LEFT JOIN FeedIssues fi ON fi.responsible_staff_id = s.payroll_number 
    AND fi.issue_date >= CURRENT_DATE - INTERVAL '30 days'
WHERE s.position = 'смотритель'
GROUP BY s.payroll_number, s.full_name, s.salary
ORDER BY enclosures_count DESC, total_animals DESC;

COMMENT ON VIEW v_keepers_workload IS 'Нагрузка смотрителей: вольеры, животные, операции';

-- Все сотрудники с краткой информацией
CREATE OR REPLACE VIEW v_staff_directory AS
SELECT 
    s.payroll_number,
    s.full_name,
    s.position,
    s.gender,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, s.birth_date))::INTEGER as age,
    s.salary,
    CASE s.position
        WHEN 'смотритель' THEN (
            SELECT COUNT(*) 
            FROM Enclosures 
            WHERE payroll_number = s.payroll_number
        )
        ELSE NULL
    END as enclosures_managed
FROM Staff s
ORDER BY s.position, s.full_name;

COMMENT ON VIEW v_staff_directory IS 'Справочник сотрудников';

-- 4. АНАЛИТИЧЕСКИЕ ПРЕДСТАВЛЕНИЯ

-- Статистика по видам животных
CREATE OR REPLACE VIEW v_species_summary AS
SELECT 
    asp.species_id,
    asp.scientific_name,
    asp.class,
    asp.category,
    asp.feed_type,
    COUNT(a.animal_id) as animal_count,
    COUNT(CASE WHEN a.sex = 'М' THEN 1 END) as male_count,
    COUNT(CASE WHEN a.sex = 'Ж' THEN 1 END) as female_count,
    ROUND(AVG(EXTRACT(YEAR FROM AGE(CURRENT_DATE, a.birth_date))), 1) as avg_age_years,
    COUNT(a.animal_id) * asp.base_daily_feed_kg as daily_feed_requirement_kg,
    asp.required_area * COUNT(a.animal_id) as total_required_area_m2
FROM AnimalSpecies asp
LEFT JOIN Animals a ON a.species_id = asp.species_id
GROUP BY asp.species_id, asp.scientific_name, asp.class, asp.category, 
         asp.feed_type, asp.base_daily_feed_kg, asp.required_area
HAVING COUNT(a.animal_id) > 0
ORDER BY animal_count DESC;

COMMENT ON VIEW v_species_summary IS 'Сводная статистика по видам животных';

-- Расход кормов за последний месяц
CREATE OR REPLACE VIEW v_feed_consumption_last_month AS
SELECT 
    fp.feed_type,
    COUNT(fi.issue_id) as issue_count,
    SUM(fi.output_kg) as total_issued_kg,
    ROUND(AVG(fi.output_kg), 2) as avg_issue_kg,
    MIN(fi.issue_date) as first_issue_date,
    MAX(fi.issue_date) as last_issue_date
FROM FeedProducts fp
LEFT JOIN FeedIssues fi ON fi.product_id = fp.product_id
    AND fi.issue_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY fp.product_id, fp.feed_type
ORDER BY total_issued_kg DESC;

COMMENT ON VIEW v_feed_consumption_last_month IS 'Расход кормов за последние 30 дней';

-- Финансовая статистика по кормам
CREATE OR REPLACE VIEW v_feed_financial_summary AS
SELECT 
    fp.feed_type,
    COUNT(d.delivery_id) as delivery_count,
    SUM(d.delivery_kg) as total_delivered_kg,
    ROUND(AVG(d.price_per_kg), 2) as avg_price_per_kg,
    SUM(d.delivery_kg * COALESCE(d.price_per_kg, 0)) as total_cost,
    MIN(d.delivery_date) as first_delivery,
    MAX(d.delivery_date) as last_delivery
FROM FeedProducts fp
LEFT JOIN Deliveries d ON d.product_id = fp.product_id
GROUP BY fp.product_id, fp.feed_type
ORDER BY total_cost DESC;

COMMENT ON VIEW v_feed_financial_summary IS 'Финансовая сводка по кормам';

-- 5. ОПЕРАЦИОННЫЕ ПРЕДСТАВЛЕНИЯ

-- Вольеры требующие внимания
CREATE OR REPLACE VIEW v_enclosures_attention_needed AS
SELECT 
    e.enclosure_id,
    e.enclosure_type,
    e.enclosure_water,
    e.status,
    e.size_m2,
    COALESCE(SUM(asp.required_area), 0) as occupied_area_m2,
    ROUND((COALESCE(SUM(asp.required_area), 0) / e.size_m2 * 100), 2) as occupancy_percent,
    COUNT(a.animal_id) as animal_count,
    s.full_name as keeper_name,
    CASE 
        WHEN e.status != 'IN_SERVICE' THEN 'Требуется обслуживание'
        WHEN COALESCE(SUM(asp.required_area), 0) > e.size_m2 * 0.9 THEN 'Высокая загрузка'
        WHEN COALESCE(SUM(asp.required_area), 0) > e.size_m2 THEN 'ПЕРЕГРУЖЕН!'
        ELSE 'Норма'
    END as attention_reason
FROM Enclosures e
LEFT JOIN Animals a ON a.enclosure_id = e.enclosure_id
LEFT JOIN AnimalSpecies asp ON a.species_id = asp.species_id
JOIN Staff s ON e.payroll_number = s.payroll_number
GROUP BY e.enclosure_id, e.enclosure_type, e.enclosure_water, e.status, 
         e.size_m2, s.full_name
HAVING e.status != 'IN_SERVICE' 
    OR COALESCE(SUM(asp.required_area), 0) > e.size_m2 * 0.9
ORDER BY 
    CASE 
        WHEN COALESCE(SUM(asp.required_area), 0) > e.size_m2 THEN 1
        WHEN e.status = 'UNDER_REPAIR' THEN 2
        WHEN e.status = 'QUARANTINE' THEN 3
        ELSE 4
    END,
    occupancy_percent DESC;

COMMENT ON VIEW v_enclosures_attention_needed IS 'Вольеры, требующие внимания (перегрузка, ремонт, карантин)';

-- Корма требующие заказа
CREATE OR REPLACE VIEW v_feeds_need_reorder AS
SELECT 
    fp.product_id,
    fp.feed_type,
    ss.quantity_kg as current_stock,
    ss.reorder_threshold_kg,
    COALESCE((
        SELECT SUM(asp.base_daily_feed_kg)
        FROM Animals a
        JOIN AnimalSpecies asp ON a.species_id = asp.species_id
        WHERE asp.feed_type = fp.feed_type
    ), 0) as daily_consumption,
    CASE 
        WHEN COALESCE((
            SELECT SUM(asp.base_daily_feed_kg)
            FROM Animals a
            JOIN AnimalSpecies asp ON a.species_id = asp.species_id
            WHERE asp.feed_type = fp.feed_type
        ), 0) > 0 THEN
            ROUND(ss.quantity_kg / (
                SELECT SUM(asp.base_daily_feed_kg)
                FROM Animals a
                JOIN AnimalSpecies asp ON a.species_id = asp.species_id
                WHERE asp.feed_type = fp.feed_type
            ), 1)
        ELSE 999
    END as days_remaining,
    ROUND(GREATEST(
        ss.reorder_threshold_kg * 2,
        COALESCE((
            SELECT SUM(asp.base_daily_feed_kg) * 30
            FROM Animals a
            JOIN AnimalSpecies asp ON a.species_id = asp.species_id
            WHERE asp.feed_type = fp.feed_type
        ), 0)
    ), 2) as recommended_order_kg
FROM FeedProducts fp
JOIN StoreStock ss ON ss.product_id = fp.product_id
WHERE ss.quantity_kg < ss.reorder_threshold_kg
ORDER BY days_remaining, (ss.quantity_kg / ss.reorder_threshold_kg);

COMMENT ON VIEW v_feeds_need_reorder IS 'Корма, которые необходимо заказать';

-- 6. ОБЩИЕ ДАШБОРДЫ

-- Главная панель управления
CREATE OR REPLACE VIEW v_main_dashboard AS
SELECT 
    (SELECT COUNT(*) FROM Animals) as total_animals,
    (SELECT COUNT(*) FROM Enclosures WHERE status = 'IN_SERVICE') as active_enclosures,
    (SELECT COUNT(*) FROM Staff WHERE position = 'смотритель') as total_keepers,
    (SELECT COUNT(*) FROM FeedProducts) as feed_types,
    (SELECT COUNT(*) FROM StoreStock WHERE quantity_kg < reorder_threshold_kg) as low_stock_items,
    (SELECT COUNT(*) FROM v_enclosures_attention_needed) as enclosures_need_attention,
    (SELECT ROUND(SUM(asp.base_daily_feed_kg), 2)
     FROM Animals a
     JOIN AnimalSpecies asp ON a.species_id = asp.species_id) as daily_feed_requirement_kg,
    (SELECT COUNT(*) FROM FeedIssues WHERE issue_date = CURRENT_DATE) as today_feed_issues;

COMMENT ON VIEW v_main_dashboard IS 'Главная панель управления - основные показатели';

-- Ежедневный отчет
CREATE OR REPLACE VIEW v_daily_report AS
SELECT 
    CURRENT_DATE as report_date,
    COUNT(DISTINCT fi.enclosure_id) as enclosures_fed,
    COUNT(fi.issue_id) as feed_operations,
    ROUND(SUM(fi.output_kg), 2) as total_feed_issued_kg,
    COUNT(DISTINCT fi.responsible_staff_id) as staff_involved,
    COUNT(d.delivery_id) as deliveries_received,
    ROUND(COALESCE(SUM(d.delivery_kg), 0), 2) as total_delivered_kg
FROM FeedIssues fi
FULL OUTER JOIN Deliveries d ON d.delivery_date = CURRENT_DATE
WHERE fi.issue_date = CURRENT_DATE OR d.delivery_date = CURRENT_DATE;

COMMENT ON VIEW v_daily_report IS 'Ежедневный отчет по операциям';
