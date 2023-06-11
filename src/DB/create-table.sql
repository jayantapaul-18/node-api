/* create a table called flags with three fields, two VARCHAR types, 
and an auto-incrementing PRIMARY KEY ID: */
/* CREATE TABLE  */
/*#################################################################*/
CREATE TABLE flags (
  ID SERIAL,
  name VARCHAR(30) PRIMARY KEY,
  enabled BOOLEAN NOT NULL,
  project VARCHAR(30),
  environment VARCHAR(15),
  description VARCHAR(256),
  lastToogle DATE,
  createdAt DATE,
  updatedAt DATE
);
/*#################################################################*/
/* 
 */
/* INSERT INTO  */
INSERT INTO flags (name, enabled)
  VALUES ('monitoring', 'true'), ('apm', 'false');
/*#################################################################*/
/* SELECT   */
SELECT * FROM flags;
SELECT * FROM flags WHERE name = 'api_monitoring';
SELECT * FROM flags WHERE name = 'api_monitoring' AND enabled = true;
/*#################################################################*/
DELETE FROM flags;
DELETE FROM flags WHERE name = 'api_monitoring5';
/*#################################################################*/
-- Table: public.flags

-- DROP TABLE IF EXISTS public.flags;

CREATE TABLE IF NOT EXISTS public.flags
(
    id integer NOT NULL DEFAULT nextval('flags_id_seq'::regclass),
    name character varying(30) COLLATE pg_catalog."default" NOT NULL,
    enabled boolean NOT NULL,
    project character varying(30) COLLATE pg_catalog."default",
    environment character varying(15) COLLATE pg_catalog."default",
    description character varying(256) COLLATE pg_catalog."default",
    lasttoogle date,
    createdat date,
    updatedat date,
    CONSTRAINT flags_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.flags
    OWNER to postgres;
/*#################################################################*/
/* create DB = feature_flag_audit*/
CREATE DATABASE feature_flag_audit
\c feature_flag_audit
/*#################################################################*/
/* create feature flag audit*/
CREATE TABLE flag_audit (
  ID SERIAL,
  name VARCHAR(30) NOT NULL,
  enabled BOOLEAN NOT NULL,
  user_name VARCHAR(50) NOT NULL,
  color VARCHAR(10),
  children VARCHAR(150) NOT NULL,
  dot VARCHAR(15),
  environment VARCHAR(15),
  auditdate DATE NOT NULL
);
/*#################################################################*/
\c feature_flag_audit
/*#################################################################*/
DROP TABLE IF EXISTS flag_audit
/*#################################################################*/