use utf8;

my $name = 'test äü';
Encode::_utf8_on($name);

sub init {
   DB->do_action('delete from model1');
   DB->do_action('delete from model2');
   DB->do_action('alter table model1 auto_increment = 1');
   DB->do_action('alter table model2 auto_increment = 1');
}

sub desc1 :Test {
   my $pk = app::Model::Model1->_primary_keys;
   my $c = app::Model::Model1->_columns;
   
   is_deeply $pk, ['id'];
   is_deeply $c, [
      {'mysql_is_pri_key'=>1,'length'=>11,'nullable'=>0,'name'=>'id','default'=>undef,'type'=>'int','pos'=>1,'webtek_data_type'=>2},
      {'mysql_is_pri_key'=>'','length'=>50,'nullable'=>0,'name'=>'class','default'=>undef,'type'=>'varchar','pos'=>2,'webtek_data_type'=>1},
      {'mysql_is_pri_key'=>'','length'=>10,'nullable'=>0,'name'=>'name','default'=>undef,'type'=>'varchar','pos'=>3,'webtek_data_type'=>1},
      {'mysql_is_pri_key'=>'','length'=>10,'nullable'=>1,'name'=>'count','default'=>undef,'type'=>'int','pos'=>4,'webtek_data_type'=>2},
      {'mysql_is_pri_key'=>'','length'=>1,'nullable'=>1,'name'=>'is_enabled','default'=>0,'type'=>'int','pos'=>5,'webtek_data_type'=>3},
      {'mysql_is_pri_key'=>'','length'=>19,'nullable'=>0,'name'=>'create_time','default'=>undef,'type'=>'datetime','pos'=>6,'webtek_data_type'=>4}
   ];
}

sub desc2 :Test {
   my $pk = app::Model::Model2->_primary_keys;
   my $c = app::Model::Model2->_columns;
   
   is_deeply $pk, ['key1', 'key2'];
   is_deeply $c, [
      {'mysql_is_pri_key'=>1,'length'=>20,'nullable'=>0,'name'=>'key1','default'=>undef,'type'=>'varchar','pos'=>1,'webtek_data_type'=>1},
      {'mysql_is_pri_key'=>1,'length'=>10,'nullable'=>0,'name'=>'key2','default'=>undef,'type'=>'int','pos'=>2,'webtek_data_type'=>2},
      {'mysql_is_pri_key'=>'','length'=>11,'nullable'=>1,'name'=>'model1_id','default'=>undef,'type'=>'int','pos'=>3,'webtek_data_type'=>2},
      {'mysql_is_pri_key'=>'','length'=>65535,'nullable'=>1,'name'=>'perl','default'=>undef,'type'=>'text','pos'=>4,'webtek_data_type'=>7},
      {'mysql_is_pri_key'=>'','length'=>65535,'nullable'=>1,'name'=>'json','default'=>undef,'type'=>'text','pos'=>5,'webtek_data_type'=>6}
   ]
}

sub insert1 :Test {
   my $m1 = app::Model::Model1->new;
   is_deeply $m1->to_hash, {'is_enabled'=>0,'count'=>undef,'name'=>undef,'create_time'=>undef,'id'=>undef,'class'=>'Test::Model::Model1'};

   my $m1 = app::Model::Model1->new(count => 3, name => 'test öäü', create_time => date('now'));
   is_deeply $m1->to_hash, {'is_enabled'=>0,'count'=>3,'name'=>'test öäü','create_time'=>date('now')->to_db($m1->_db),'id'=>undef,'class'=>'Test::Model::Model1'};
   throws_ok { $m1->save } qr/invalid for name/;

   my $m1a = app::Model::Model1a->new(count => 3, name => $name, create_time => date('now'));
   is_deeply $m1a->to_hash, {'is_enabled'=>0,'count'=>3,'name'=>$name,'create_time'=>date('now')->to_db($m1a->_db),'id'=>undef,'class'=>'Test::Model::Model1a'};
   ok $m1a->save;
   is_deeply $m1a->to_hash, {'is_enabled'=>0,'count'=>3,'name'=>$name,'create_time'=>date('now')->to_db($m1a->_db),'id'=>1,'class'=>'Test::Model::Model1a'};

   my $m2 = app::Model::Model2->new(perl => {a=>1}, json => '{"a":1}', name => $name, create_time => date('now'), model1 => $m1a, key1 => 'key', key2 => 1);
   is_deeply $m2->to_hash, {'perl'=>{'a'=>1},'key2'=>1,'key1'=>'key','model1_id'=>1,'json'=>'{"a":1}'};
   is_deeply $m2->model1->to_hash, $m1a->to_hash;
   is $m2->perl, '{"a":1}';
   is $m2->perl->to_perl, "#perl\nuse utf8;\n{'a'=>1}";
   is $m2->json, '{"a":1}';
   ok $m2->save;
}