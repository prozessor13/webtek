# first create a database and an user
# (i dont know how to do this.. hmmm...)
#
# this create statements works on my oracle testdatabase

CREATE TABLE session (
   id char(32) NOT NULL,
   data clob NOT NULL,
   create_time date NOT NULL,
   ip_address varchar2(50) NOT NULL,
   constraint pk_session primary key(id) using index tablespace "INDX"
);
