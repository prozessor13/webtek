CREATE DATABASE webtek;

GRANT SELECT,INSERT,UPDATE,DELETE ON
webtek.* TO webtek@localhost IDENTIFIED BY 'webtek';

USE webtek;

CREATE TABLE session (
   id char(32) NOT NULL,
   data text NOT NULL,
   create_time datetime NOT NULL,
   ip_address varchar(50) NOT NULL,
   UNIQUE KEY id (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
