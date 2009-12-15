sub up {
   DB->do_action(qq{
      CREATE TABLE `model1` (
         `id` int(11) NOT NULL auto_increment,
         `class` varchar(50) NOT NULL,
         `name` varchar(10) NOT NULL,
         `count` int(10),
         `is_enabled` int(1) default 0,
         `create_time` datetime NOT NULL,
         PRIMARY KEY  (`id`),
         UNIQUE KEY `name` (`name`)
      ) ENGINE=MyISAM DEFAULT CHARSET=utf8
   });
   DB->do_action(qq{
      CREATE TABLE `model2` (
         `key1` varchar(20) NOT NULL,
         `key2` int(10) NOT NULL,
         `model1_id` int(11),
         `perl` text,
         `json` text,
         PRIMARY KEY (`key1`, `key2`)
      ) ENGINE=MyISAM DEFAULT CHARSET=utf8
   });
}

sub down {
   #... place here some code   
}