-- РОЛЕВАЯ МОДЕЛЬ И УПРАВЛЕНИЕ ДОСТУПОМ

-- 1. СОЗДАНИЕ РОЛЕЙ

-- Роль: Администратор системы
CREATE ROLE role_admin;

COMMENT ON ROLE role_admin IS 'Полный доступ ко всем объектам БД';

-- Роль: Директор зоопарка
CREATE ROLE role_director;

COMMENT ON ROLE role_director IS 'Доступ ко всей информации в режиме чтения, отчеты, аналитика';

-- Роль: Заведующий складом
CREATE ROLE role_warehouse_manager;

COMMENT ON ROLE role_warehouse_manager IS 'Управление складом, поставки, выдача кормов';

-- Роль: Смотритель
CREATE ROLE role_keeper;

COMMENT ON ROLE role_keeper IS 'Работа с животными и выдача кормов';

-- 2. ВЫДАЧА ПРАВ: АДМИНИСТРАТОР

-- Полный доступ ко всем таблицам
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO role_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO role_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO role_admin;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA public TO role_admin;

-- Право создавать объекты
GRANT CREATE ON SCHEMA public TO role_admin;

-- 3. ВЫДАЧА ПРАВ: ДИРЕКТОР

-- Чтение всех таблиц
GRANT SELECT ON ALL TABLES IN SCHEMA public TO role_director;

-- Доступ к представлениям
GRANT SELECT ON 
    v_animals_full_info,
    v_animals_by_enclosure,
    v_current_stock_status,
    v_feed_movement_history,
    v_keepers_workload,
    v_staff_directory,
    v_species_summary,
    v_feed_consumption_last_month,
    v_feed_financial_summary,
    v_enclosures_attention_needed,
    v_feeds_need_reorder,
    v_main_dashboard,
    v_daily_report
TO role_director;

-- Доступ к аналитическим функциям
GRANT EXECUTE ON FUNCTION fn_calculate_daily_feed_requirement TO role_director;
GRANT EXECUTE ON FUNCTION fn_calculate_zoo_daily_feed_requirement TO role_director;
GRANT EXECUTE ON FUNCTION fn_feed_consumption_report TO role_director;
GRANT EXECUTE ON FUNCTION fn_get_enclosure_occupancy TO role_director;
GRANT EXECUTE ON FUNCTION fn_keeper_workload_report TO role_director;
GRANT EXECUTE ON FUNCTION fn_species_statistics TO role_director;
GRANT EXECUTE ON FUNCTION fn_calculate_animal_monthly_cost TO role_director;
GRANT EXECUTE ON FUNCTION fn_find_suitable_enclosure TO role_director;

-- Доступ к процедурам отчетности
GRANT EXECUTE ON PROCEDURE sp_system_health_check TO role_director;
GRANT EXECUTE ON PROCEDURE sp_generate_feed_reorder_list TO role_director;
GRANT EXECUTE ON PROCEDURE sp_plan_daily_feeding TO role_director;

-- Возможность изменять информацию о зоопарке
GRANT UPDATE ON Zoo TO role_director;

-- 4. ВЫДАЧА ПРАВ: ЗАВЕДУЮЩИЙ СКЛАДОМ

-- Полный доступ к кормам и складу
GRANT SELECT, INSERT, UPDATE, DELETE ON FeedProducts, StoreStock, Deliveries TO role_warehouse_manager;

-- Доступ к выдаче кормов
GRANT SELECT, INSERT ON FeedIssues TO role_warehouse_manager;

-- Чтение информации о вольерах и животных (для контроля выдачи)
GRANT SELECT ON Enclosures, Animals, AnimalSpecies TO role_warehouse_manager;

-- Чтение информации о персонале
GRANT SELECT ON Staff TO role_warehouse_manager;

-- Доступ к представлениям склада
GRANT SELECT ON 
    v_current_stock_status,
    v_feed_movement_history,
    v_feed_consumption_last_month,
    v_feed_financial_summary,
    v_feeds_need_reorder
TO role_warehouse_manager;

-- Процедуры управления складом
GRANT EXECUTE ON PROCEDURE sp_register_delivery TO role_warehouse_manager;
GRANT EXECUTE ON PROCEDURE sp_issue_feed TO role_warehouse_manager;
GRANT EXECUTE ON PROCEDURE sp_generate_feed_reorder_list TO role_warehouse_manager;

-- Функции склада
GRANT EXECUTE ON FUNCTION fn_calculate_daily_feed_requirement TO role_warehouse_manager;
GRANT EXECUTE ON FUNCTION fn_calculate_zoo_daily_feed_requirement TO role_warehouse_manager;
GRANT EXECUTE ON FUNCTION fn_feed_consumption_report TO role_warehouse_manager;

-- Доступ к sequences для регистрации операций
GRANT USAGE ON SEQUENCE seq_delivery_id, seq_issue_id TO role_warehouse_manager;

-- 5. ВЫДАЧА ПРАВ: СМОТРИТЕЛЬ

-- Чтение информации о животных
GRANT SELECT ON Animals, AnimalSpecies TO role_keeper;

-- Чтение информации о вольерах
GRANT SELECT ON Enclosures TO role_keeper;

-- Доступ к выдаче кормов (только вставка)
GRANT SELECT, INSERT ON FeedIssues TO role_keeper;

-- Чтение информации о кормах
GRANT SELECT ON FeedProducts, StoreStock TO role_keeper;

-- Ограниченный доступ к персоналу (только просмотр своих данных)
GRANT SELECT ON Staff TO role_keeper;

-- Доступ к представлениям
GRANT SELECT ON 
    v_animals_full_info,
    v_animals_by_enclosure,
    v_current_stock_status,
    v_feeds_need_reorder
TO role_keeper;

-- Процедуры работы с животными
GRANT EXECUTE ON PROCEDURE sp_add_animal TO role_keeper;
GRANT EXECUTE ON PROCEDURE sp_move_animal TO role_keeper;
GRANT EXECUTE ON PROCEDURE sp_issue_feed TO role_keeper;

-- Функции для смотрителей
GRANT EXECUTE ON FUNCTION fn_calculate_daily_feed_requirement TO role_keeper;
GRANT EXECUTE ON FUNCTION fn_get_enclosure_occupancy TO role_keeper;

-- Доступ к sequences
GRANT USAGE ON SEQUENCE seq_animal_id, seq_issue_id TO role_keeper;