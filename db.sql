-- ===========================================================
--   BASE DE DATOS COMPLETA PARA EV3: Paquexpress
-- ===========================================================

-- Crear BD
DROP DATABASE IF EXISTS EV3_BD;
CREATE DATABASE EV3_BD;
USE EV3_BD;

-- ===========================================================
-- TABLA: Usuarios (agentes)
-- ===========================================================
CREATE TABLE P9_users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Usuario de prueba (username: agente1, password: 1234)
INSERT INTO P9_users (username, password_hash, full_name)
VALUES (
    'agente1',
    MD5('1234'),
    'Agente de Prueba'
);

-- ===========================================================
-- TABLA: Asistencia genérica
-- ===========================================================
CREATE TABLE P9_attendance (
    attendance_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    address VARCHAR(255),
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES P9_users(user_id)
);

-- ===========================================================
-- TABLA: Fotos (P10 - práctica de evidencia)
-- ===========================================================
CREATE TABLE P10_foto (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    descripcion VARCHAR(255) NOT NULL,
    ruta_foto VARCHAR(255) NOT NULL,
    fecha TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP
);

-- ===========================================================
-- TABLA: Paquetes asignados a agentes
-- ===========================================================
CREATE TABLE P9_packages (
    package_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL, 
    tracking_code VARCHAR(50) NOT NULL,
    destino VARCHAR(255) NOT NULL,
    estatus VARCHAR(20) DEFAULT 'pendiente',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES P9_users(user_id)
);

-- Paquetes de prueba asignados al usuario 1
INSERT INTO P9_packages (user_id, tracking_code, destino, estatus)
VALUES
(1, 'PKG-001', 'Av. Reforma 123, CDMX', 'pendiente'),
(1, 'PKG-002', 'Calle Hidalgo 45, Querétaro', 'pendiente'),
(1, 'PKG-003', 'Col. Centro 88, León, Guanajuato', 'pendiente');

-- ===========================================================
-- TABLA: Entregas (foto + GPS + dirección)
-- ===========================================================
CREATE TABLE P9_deliveries (
    delivery_id INT AUTO_INCREMENT PRIMARY KEY,
    package_id INT NOT NULL,
    user_id INT NOT NULL,
    ruta_foto VARCHAR(255) NOT NULL,
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    address VARCHAR(255),
    delivered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (package_id) REFERENCES P9_packages(package_id),
    FOREIGN KEY (user_id) REFERENCES P9_users(user_id)
);

-- ===========================================================
-- FIN DE LA BD
-- ===========================================================
