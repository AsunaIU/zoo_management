-- СИСТЕМА УПРАВЛЕНИЯ ЗООПАРКОМ
-- Скрипт создания таблиц и задания ограничений

-- Создание sequences для автогенерации ID
CREATE SEQUENCE seq_species_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_enclosure_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_animal_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_product_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_delivery_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_issue_id START WITH 1 INCREMENT BY 1;

-- 1. СПРАВОЧНАЯ ИНФОРМАЦИЯ О ЗООПАРКЕ
CREATE TABLE Zoo (
    license_number VARCHAR(50) PRIMARY KEY,
    zoo_name VARCHAR(200),
    director_fullname VARCHAR(150),
    contact_phone VARCHAR(20),
    CONSTRAINT chk_zoo_single_row CHECK (license_number IS NOT NULL)
);

COMMENT ON TABLE Zoo IS 'Информация о зоопарке (допускается только 1 запись)';
COMMENT ON COLUMN Zoo.license_number IS 'Номер лицензии (уникальный)';
COMMENT ON COLUMN Zoo.zoo_name IS 'Наименование зоопарка';
COMMENT ON COLUMN Zoo.director_fullname IS 'ФИО руководителя/директора';
COMMENT ON COLUMN Zoo.contact_phone IS 'Телефон для связи';

-- 2. ПЕРСОНАЛ
CREATE TABLE Staff (
    payroll_number INTEGER PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    passport_series_number VARCHAR(20) NOT NULL UNIQUE,
    birth_date DATE,
    gender CHAR(1) CHECK (gender IN ('М', 'Ж')),
    position VARCHAR(100) NOT NULL CHECK (position IN ('директор', 'администратор', 'заведующий складом', 'смотритель')),
    salary DECIMAL(10,2) CHECK (salary >= 0)
);

COMMENT ON TABLE Staff IS 'Персонал зоопарка';
COMMENT ON COLUMN Staff.payroll_number IS 'Табельный номер';
COMMENT ON COLUMN Staff.full_name IS 'Ф.И.О.';
COMMENT ON COLUMN Staff.passport_series_number IS 'Серия и номер паспорта';
COMMENT ON COLUMN Staff.position IS 'Должность: директор, администратор, заведующий складом, смотритель';

-- 3. СПРАВОЧНИК ВИДОВ ЖИВОТНЫХ
CREATE TABLE AnimalSpecies (
    species_id INTEGER DEFAULT nextval('seq_species_id') PRIMARY KEY,
    scientific_name VARCHAR(200) NOT NULL UNIQUE,
    class VARCHAR(50) NOT NULL CHECK (class IN ('MAMMALS', 'BIRDS', 'REPTILES')),
    required_enclosure_type VARCHAR(10) NOT NULL CHECK (required_enclosure_type IN ('OPEN', 'CLOSED')),
    required_enclosure_water VARCHAR(10) NOT NULL CHECK (required_enclosure_water IN ('WATER', 'DRY')),
    required_area DECIMAL(6,2) NOT NULL CHECK (required_area > 0),
    category VARCHAR(20) NOT NULL CHECK (category IN ('HERBIVORE', 'CARNIVORE', 'OMNIVORE')),
    feed_type VARCHAR(100) NOT NULL,
    base_daily_feed_kg DECIMAL(6,2) NOT NULL CHECK (base_daily_feed_kg > 0)
);

CREATE INDEX idx_species_feed_type ON AnimalSpecies(feed_type);

COMMENT ON TABLE AnimalSpecies IS 'Справочник видов животных с требованиями к содержанию';
COMMENT ON COLUMN AnimalSpecies.required_area IS 'Требуемая площадь вольера на одну особь (м²)';
COMMENT ON COLUMN AnimalSpecies.base_daily_feed_kg IS 'Базовая суточная норма корма (кг)';

-- 4. СПРАВОЧНИК КОРМОВ
CREATE TABLE FeedProducts (
    product_id INTEGER DEFAULT nextval('seq_product_id') PRIMARY KEY,
    feed_type VARCHAR(100) NOT NULL UNIQUE
);

CREATE UNIQUE INDEX idx_feed_type_unique ON FeedProducts(feed_type);

COMMENT ON TABLE FeedProducts IS 'Справочник видов кормов';
COMMENT ON COLUMN FeedProducts.feed_type IS 'Вид корма';

-- 5. ВОЛЬЕРЫ
CREATE TABLE Enclosures (
    enclosure_id INTEGER DEFAULT nextval('seq_enclosure_id') PRIMARY KEY,
    enclosure_type VARCHAR(10) NOT NULL CHECK (enclosure_type IN ('OPEN', 'CLOSED')),
    enclosure_water VARCHAR(10) NOT NULL CHECK (enclosure_water IN ('WATER', 'DRY')),
    size_m2 DECIMAL(8,2) NOT NULL CHECK (size_m2 > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'IN_SERVICE' CHECK (status IN ('IN_SERVICE', 'UNDER_REPAIR', 'QUARANTINE')),
    payroll_number INTEGER NOT NULL,
    CONSTRAINT fk_enclosure_staff FOREIGN KEY (payroll_number) 
        REFERENCES Staff(payroll_number) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE
);

CREATE INDEX idx_enclosure_staff ON Enclosures(payroll_number);
CREATE INDEX idx_enclosure_status ON Enclosures(status);

COMMENT ON TABLE Enclosures IS 'Вольеры для содержания животных';
COMMENT ON COLUMN Enclosures.size_m2 IS 'Размер вольера (м²)';
COMMENT ON COLUMN Enclosures.payroll_number IS 'Ответственный смотритель';

-- 6. ЖИВОТНЫЕ
CREATE TABLE Animals (
    animal_id INTEGER DEFAULT nextval('seq_animal_id') PRIMARY KEY,
    species_id INTEGER NOT NULL,
    animal_name VARCHAR(100),
    birth_date DATE,
    arrival_date DATE,
    sex CHAR(1) CHECK (sex IN ('М', 'Ж')),
    enclosure_id INTEGER NOT NULL,
    CONSTRAINT fk_animal_species FOREIGN KEY (species_id) 
        REFERENCES AnimalSpecies(species_id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_animal_enclosure FOREIGN KEY (enclosure_id) 
        REFERENCES Enclosures(enclosure_id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE
);

CREATE INDEX idx_animal_species ON Animals(species_id);
CREATE INDEX idx_animal_enclosure ON Animals(enclosure_id);
CREATE INDEX idx_animal_enclosure_species ON Animals(enclosure_id, species_id);

COMMENT ON TABLE Animals IS 'Животные, содержащиеся в зоопарке';
COMMENT ON COLUMN Animals.animal_name IS 'Кличка / регистрационное имя';

-- 7. СКЛАД (остатки кормов)
CREATE TABLE StoreStock (
    product_id INTEGER PRIMARY KEY,
    quantity_kg DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (quantity_kg >= 0),
    reorder_threshold_kg DECIMAL(10,2) NOT NULL CHECK (reorder_threshold_kg >= 0),
    CONSTRAINT fk_stock_product FOREIGN KEY (product_id) 
        REFERENCES FeedProducts(product_id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE
);

COMMENT ON TABLE StoreStock IS 'Остатки кормов на складе. Так как склад один, product_id - единственный первичный ключ';
COMMENT ON COLUMN StoreStock.quantity_kg IS 'Текущий остаток корма (кг)';
COMMENT ON COLUMN StoreStock.reorder_threshold_kg IS 'Минимальный порог для автозаказа (кг)';

-- 8. ПОСТАВКИ КОРМОВ
CREATE TABLE Deliveries (
    delivery_id INTEGER DEFAULT nextval('seq_delivery_id') PRIMARY KEY,
    delivery_date DATE NOT NULL,
    supplier_name VARCHAR(200),
    product_id INTEGER NOT NULL,
    delivery_kg DECIMAL(10,2) NOT NULL CHECK (delivery_kg > 0),
    price_per_kg DECIMAL(8,2) CHECK (price_per_kg >= 0),
    CONSTRAINT fk_delivery_product FOREIGN KEY (product_id) 
        REFERENCES FeedProducts(product_id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE
);

CREATE INDEX idx_delivery_date ON Deliveries(delivery_date);
CREATE INDEX idx_delivery_product ON Deliveries(product_id);
CREATE INDEX idx_delivery_supplier ON Deliveries(supplier_name);

COMMENT ON TABLE Deliveries IS 'Поставки кормов на склад';
COMMENT ON COLUMN Deliveries.delivery_kg IS 'Количество корма в поставке (кг)';

-- 9. ВЫДАЧА КОРМОВ
CREATE TABLE FeedIssues (
    issue_id INTEGER DEFAULT nextval('seq_issue_id') PRIMARY KEY,
    issue_date DATE NOT NULL,
    enclosure_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    output_kg DECIMAL(8,2) NOT NULL CHECK (output_kg > 0),
    responsible_staff_id INTEGER NOT NULL,
    CONSTRAINT fk_issue_enclosure FOREIGN KEY (enclosure_id) 
        REFERENCES Enclosures(enclosure_id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_issue_product FOREIGN KEY (product_id) 
        REFERENCES FeedProducts(product_id) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    CONSTRAINT fk_issue_staff FOREIGN KEY (responsible_staff_id) 
        REFERENCES Staff(payroll_number) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE
);

CREATE INDEX idx_issue_date ON FeedIssues(issue_date);
CREATE INDEX idx_issue_enclosure ON FeedIssues(enclosure_id);
CREATE INDEX idx_issue_product ON FeedIssues(product_id);
CREATE INDEX idx_issue_staff ON FeedIssues(responsible_staff_id);
CREATE INDEX idx_issue_date_enclosure ON FeedIssues(issue_date, enclosure_id);

COMMENT ON TABLE FeedIssues IS 'Выдача кормов в вольеры';
COMMENT ON COLUMN FeedIssues.output_kg IS 'Выдано кг';
COMMENT ON COLUMN FeedIssues.responsible_staff_id IS 'Ответственный сотрудник';

-- ДОПОЛНИТЕЛЬНЫЕ ОГРАНИЧЕНИЯ

-- Ограничение на единственную запись в Zoo
CREATE UNIQUE INDEX idx_zoo_single_record ON Zoo((1));

COMMENT ON INDEX idx_zoo_single_record IS 'Гарантирует наличие только одной записи в таблице Zoo';
