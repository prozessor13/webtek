CREATE DATABASE webtek;
   
CREATE USER webtek WITH PASSWORD 'webtek';

CREATE TABLE session (
  id char(32) NOT NULL,
  data text NOT NULL,
  create_time timestamp NOT NULL,
  ip_address varchar(50) NOT NULL,
  PRIMARY KEY(id)
);
