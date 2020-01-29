--
-- Database schema for BJJ Compete. Version 1.5
--
-- Handcrafted with love by Giovanni Espinosa
--

-- Experiment with db version for control
CREATE TABLE dbversion (
    mandatory text,
    optional  text NULL
);

CREATE TABLE people (
    name  text PRIMARY KEY,
    color text NOT NULL,
    pet   varchar(5) NOT NULL
);

