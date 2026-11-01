CREATE TABLE `users` (`avatar` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `email` TEXT DEFAULT '' NOT NULL, `emailVisibility` BOOLEAN DEFAULT FALSE NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `password` TEXT DEFAULT '' NOT NULL, `tokenKey` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `verified` BOOLEAN DEFAULT FALSE NOT NULL, "role" TEXT DEFAULT '' NOT NULL);

CREATE TABLE `specializations` (`created` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `description` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `cabinets` (`created` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `equipment` TEXT DEFAULT '' NOT NULL, `floor` NUMERIC DEFAULT 0 NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `number` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `service_categories` (`created` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `description` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `services` (`category` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `description` TEXT DEFAULT '' NOT NULL, `durationMin` NUMERIC DEFAULT 0 NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `price` NUMERIC DEFAULT 0 NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `patients` (`address` TEXT DEFAULT '' NOT NULL, `birthDate` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `email` TEXT DEFAULT '' NOT NULL, `fullName` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `phone` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `patient_cards` (`allergies` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `notes` TEXT DEFAULT '' NOT NULL, `number` TEXT DEFAULT '' NOT NULL, `openedOn` TEXT DEFAULT '' NOT NULL, `patient` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `doctors` (`cabinet` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `experienceYears` NUMERIC DEFAULT 0 NOT NULL, `fullName` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `phone` TEXT DEFAULT '' NOT NULL, `specialization` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `user` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `appointments` (`complaints` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `diagnosis` TEXT DEFAULT '' NOT NULL, `discountPercent` NUMERIC DEFAULT 0 NOT NULL, `doctor` TEXT DEFAULT '' NOT NULL, `endAt` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `patient` TEXT DEFAULT '' NOT NULL, `services` JSON DEFAULT '[]' NOT NULL, `startAt` TEXT DEFAULT '' NOT NULL, `status` TEXT DEFAULT '' NOT NULL, `total` NUMERIC DEFAULT 0 NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `payments` (`amount` NUMERIC DEFAULT 0 NOT NULL, `appointment` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deletedAt` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `method` TEXT DEFAULT '' NOT NULL, `paidAt` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

