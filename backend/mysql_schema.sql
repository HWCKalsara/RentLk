-- Rent.lk Vehicle Rental Management System - MySQL Schema
-- සිංහල සටහන්: Flutter app එක real MySQL/PHP backend එකකට connect කරන විට මෙම tables භාවිතා කරන්න.

CREATE DATABASE IF NOT EXISTS rent_lk CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE rent_lk;

CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('customer','staff','admin','owner') NOT NULL DEFAULT 'customer',
  phone VARCHAR(30),
  nic VARCHAR(50),
  business_name VARCHAR(150) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE vehicles (
  id INT AUTO_INCREMENT PRIMARY KEY,
  owner_id INT NULL,
  name VARCHAR(150) NOT NULL,
  type VARCHAR(50) NOT NULL,
  model VARCHAR(100),
  plate_number VARCHAR(50) NOT NULL UNIQUE,
  fuel_type VARCHAR(50),
  transmission VARCHAR(50),
  location VARCHAR(120),
  seats INT DEFAULT 4,
  price_per_day DECIMAL(10,2) NOT NULL,
  available TINYINT(1) DEFAULT 1,
  image_url TEXT,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE bookings (
  id INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NOT NULL,
  vehicle_id INT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  pickup_location VARCHAR(150),
  return_location VARCHAR(150),
  driver_option ENUM('with_driver', 'without_driver') NOT NULL DEFAULT 'without_driver',
  status ENUM('pending','approved','rejected','completed') DEFAULT 'pending',
  total_amount DECIMAL(10,2) NOT NULL,
  advance_paid DECIMAL(10,2) DEFAULT 0,
  note TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE
);

-- Migration query for existing databases:
-- ALTER TABLE bookings ADD COLUMN driver_option ENUM('with_driver', 'without_driver') NOT NULL DEFAULT 'without_driver';


CREATE TABLE payments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  booking_id INT NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  method VARCHAR(60) NOT NULL,
  status VARCHAR(50) DEFAULT 'Confirmed',
  paid_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
);

CREATE TABLE notifications (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  title VARCHAR(150) NOT NULL,
  message TEXT NOT NULL,
  is_read TINYINT(1) DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

INSERT INTO users (full_name, email, password_hash, role, phone, nic) VALUES
('Rent.lk Admin', 'admin@rent.lk', '$2y$10$replace_with_real_hash', 'admin', '0710001111', 'Admin'),
('Airport Staff', 'staff@rent.lk', '$2y$10$replace_with_real_hash', 'staff', '0710002222', 'Staff'),
('Demo Customer', 'user@rent.lk', '$2y$10$replace_with_real_hash', 'customer', '0771234567', '200012345678'),
('Demo Owner', 'owner@rent.lk', '$2y$10$replace_with_real_hash', 'owner', '0779998888', '199512345678');
