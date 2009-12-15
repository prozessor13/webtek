package WebTek::Model;

# max demmelbauer
# 14-02-06
#
# superclass of all models

use strict;
use Encode ();
use WebTek::Exception;
use WebTek::Event qw( event=>_event );
use WebTek::Data::Date qw( date=>_date );
use WebTek::Logger qw( log_debug log_warning );
use WebTek::Data::Struct  qw( struct=>_struct );
use WebTek::Util qw( assert=>__assert make_accessor=>__make_accessor );
use Scalar::Util qw( blessed );
use base qw( WebTek::Handler );

our %Real;
our %Has_a;
our %Columns;
our %Primary_keys;

__make_accessor '_in_db' ;      # boolean
__make_accessor '_checked';     # boolean
__make_accessor '_updated';     # array
__make_accessor '_errors';      # hash
__make_accessor '_content';     # hash
__make_accessor '_f_keys';      # hash
__make_accessor '_modified';    # hash
__make_accessor '_accessors';   # hash

# --------------------------------------------------------------------------
# constants
# --------------------------------------------------------------------------

sub DATA_TYPE_UNKNOWN { 0 }
sub DATA_TYPE_STRING { 1 }
sub DATA_TYPE_NUMBER { 2 }
sub DATA_TYPE_BOOLEAN { 3 }
sub DATA_TYPE_DATE { 4 }
sub DATA_TYPE_BLOB { 5 }
sub DATA_TYPE_JSON { 6 }
sub DATA_TYPE_PERL { 7 }

# --------------------------------------------------------------------------
# export into pages
# --------------------------------------------------------------------------

sub import {
   my ($class, %export) = @_;
   return unless keys %export;
   my $caller = caller;

   #... export handler
   my @handler = $export{handler} =~ /(\w)(\s*:public)?/i;
   __assert scalar(@handler), "handler not defined for $caller";
   my @attrs = $handler[1] ? ('Handler', 'Public') : ('Handler');
   WebTek::Util::may_make_method($caller, $handler[0], undef, @attrs);
}

# --------------------------------------------------------------------------
# set custom properties
# --------------------------------------------------------------------------

sub PROTECTED { [] }

sub PROPERTIES { {} }

sub DATATYPES { {} }

sub DEFAULTS { {} }

sub UNIQUE_CONSTRAINTS { {} }

sub has_a {
   my ($class, $name, $model, $constructor) = @_;

   #... create column and accessor name
   my $column;
   my $accessor;
   if ($name =~ /^(.+)_id$/) {
      $column = $name;
      $accessor = $1;
   } else {
      $column = "$name\_id";
      $accessor = $name;
   }

   #... find the model and constructor for the foreign-key
   $model ||= $Has_a{$::appname}{$class}{$column}[2];
   unless ($model) {
      my $modelprefix = $class;
      $modelprefix =~ s/(\w+)$//;
      my $modelname = ucfirst($accessor);
      $modelname =~ s/_(\w)/\u$1/g;
      $model = $modelprefix . $modelname;
   }
   $constructor ||= 'new';
   
   #... extend class
   $Has_a{$::appname}{$class}{$column} = [$accessor, $model, $constructor];
   my ($type) = grep $column eq $_->{name}, @{$class->_columns};
   $class->_make_accessor($accessor, $type);
}

# --------------------------------------------------------------------------
# model information
# --------------------------------------------------------------------------

sub _real {
   my $class = shift;
   $class = ref $class || $class;
   
   $Real{$::appname}{$class} = shift if @_;
   return $Real{$::appname}{$class};
}

sub _primary_keys {
   my $class = shift;
   $class = ref $class || $class;
   
   $Primary_keys{$::appname}{$class} = shift if @_;
   return $Primary_keys{$::appname}{$class};
}

sub _columns {
   my $class = shift;
   $class = ref $class || $class;
   
   $Columns{$::appname}{$class} = shift() if @_;
   return $Columns{$::appname}{$class};
}

sub _foreign_keys {
   my $class = shift;
   my $f_keys = $Has_a{$::appname}{ref $class || $class};
   
   return [ map [ $_, @{$f_keys->{$_}} ], keys %$f_keys ];
}

sub _init {
   my $class = shift;
   $class->SUPER::_init;
   no strict 'refs';

   #... check if model is a real model
   #... (i.e. model is direct subclass of WebTek::Model)
   $class->_real($class);
   sub is_real_model { grep /^WebTek::Model/, @{"$_[0]\::ISA"} }

   #... handle unreal models (= single table inheritance)
   #... copy real-model column-info into this class
   unless (is_real_model($class)) {
      my $real = $class;
      while (not is_real_model($real) and @{"$real\::ISA"}) {
         foreach my $isa (@{"$real\::ISA"}) {
            $real = $isa;
            last if is_real_model($real);
         }
      }
      $real = ${"$real\::ISA"}[0] while not is_real_model($real);
      $class->_real($real);
      log_debug "$$: copy modelinfos from $real into not real model $class";
      #... set model info
      $class->_columns($real->_columns);
      $class->_primary_keys($real->_primary_keys);
      $class->has_a(@$_[1,2,3]) foreach @{$real->foreign_keys};
      WebTek::Util::may_make_method($class, '_class', sub { $class });
      return;
   }

   log_debug("$$: init model $class");
   
   #... find model class for database vendor
   my $vendor = $class->_db->vendor;
   my $modelclass;
   if ($vendor eq WebTek::DB::DB_VENDOR_MYSQL()) {
      $modelclass = 'WebTek::Model::Mysql';
   } elsif ($vendor eq WebTek::DB::DB_VENDOR_POSTGRES()) {
      $modelclass = 'WebTek::Model::Postgres';
   } elsif ($vendor eq WebTek::DB::DB_VENDOR_ORACLE()) {
      $modelclass = 'WebTek::Model::Oracle';
   }
   WebTek::Loader->load($modelclass);
   __assert $modelclass, "Modelclass not found for vendor: '$vendor'";
   #... replace the superclass with the vendor-specific one
   for (my $i=0; $i<scalar(@{"$class\::ISA"}); $i++) {
      if (''.${"$class\::ISA"}[$i] eq __PACKAGE__) {
         ${"$class\::ISA"}[$i] = $modelclass;
      }
   }

   #... create TABLE_NAME
   my $tablename = substr $class, rindex($class, ':') + 1;
   $tablename =~ s/([a-z])([A-Z])([a-z])/$1\_$2$3/g;
   $tablename = lc $tablename;
   WebTek::Util::may_make_method($class, 'TABLE_NAME', sub { $tablename });

   #... analyze table
   my $tablename = $class->TABLE_NAME;
   my $columns = $class->_db->column_info($tablename);
   my $primary_keys = $class->_db->primary_keys($tablename);
   __assert scalar(@$primary_keys), "no primary keys defined for '$tablename'";

   #... remember colums and primary keys
   $class->_columns($columns);
   $class->_primary_keys($primary_keys);

   #... create model accessor methods
   foreach my $column (@$columns) {
      $class->_make_accessor($column->{name}, $column->{webtek_data_type});
      $class->has_a($column->{name}) if $column->{name} =~ /^.+_id$/;
   }
}

# --------------------------------------------------------------------------
# get database/cache object for this model
# --------------------------------------------------------------------------

sub _db { WebTek::DB::DB() }

sub _cache { WebTek::Cache::cache() }

# --------------------------------------------------------------------------
# create and init model
# --------------------------------------------------------------------------

sub new {
   my ($class, %content) = @_;
   
   #... fill in default values
   foreach my $column (@{$class->_columns}) {
      my $n = $column->{name};
      next if exists $content{$n};
      if (exists $class->DEFAULTS->{$n}) {
         if (ref($class->DEFAULTS->{$n}) eq 'CODE') {
            $content{$n} = $class->DEFAULTS->{$n}->($class);
         } else {
            $content{$n} = $class->DEFAULTS->{$n};
         }
      } elsif ($n eq 'class') {
         $content{$n} = $class;
      } elsif (exists $column->{default}) {
         $content{$n} = $column->{default}
      }
   }
   
   #... create model
   my $self = $class->_new;
   $self->_update(\%content);
   return $self;
}

sub new_from_db {
   my ($class, $content, $f_keys) = @_;
   
   $class = $content->{class} if $content->{class};
   my $self = $class->_new;
   $self->{_content} = $content;
   $self->{_f_keys} = $f_keys;
   $self->{_checked} = 1;
   $self->{_in_db} = 1;
   return $self;
}

sub _new {
   return shift->SUPER::new({
      _in_db => 0, _checked => 0,
      _updated => [], _errors => {},
      _content => {}, _f_keys => {}, _modified => {}, _accessors => {},      
   });
}

# --------------------------------------------------------------------------
# fetching model rows
# --------------------------------------------------------------------------

sub find_one {
   my ($class, %params) = @_;

   my $obj = $class->_get_from_cache(%params);
   unless ($obj) {
      $obj = $class->find(%params)->[0];
      $obj->_set_to_cache if $obj;
   }
   return $obj;
}

sub find {
   my ($class, %params) = @_;

   #... fetch from db
   my $f_keys = $class->_prepare_params(\%params);
   my $table = $class->TABLE_NAME;
   my $order = $params{order} ? "order by $params{order}" : '';
   my $combine = $params{combine} || 'and';
   my $limit = $params{limit} ? "limit $params{limit}" : '';
   my $offset = $params{offset} ? "offset $params{offset}" : '';
   my $fetch = $params{fetch} || "*";
   my $where = $params{where} ? "where $params{where}" : '';
   my $args = $params{args} || []; 
   $order = '' if $fetch eq 'count(*)';
   delete @params{qw( fetch limit offset order combine where args )};
   # single table inheritance
   $params{'class'} ||= $class->_class if $class->can('_class');
   # parse conditions
   my (@where, @conditions);
   foreach my $key (keys %params) {
      __assert !$where, "try to set conditons, but where clause exists already";
      if ($key =~ /^((and|or)\s+)?(\S+)(\s+(\S+))?$/) {
         my $com = $2 || $combine;
         my $col = $3;
         my $match = $5 || "=";
         push @conditions, [$key, $com, $col, $match];
      } else {
         log_warning $class . "->find: cannot understand condition '$key'";
      }
   }
   # order conditions (and before or) and create where clause
   foreach (sort { $a->[1] <=> $b->[1] } @conditions) {
      my ($key, $com, $col, $match) = @$_;
      if (ref $params{$key} eq 'ARRAY') {
         my $in = join ' or ', map { "`$col` $match ?" } @{$params{$key}};
         push @$args, @{$params{$key}};
         push @where, (@where ? "$com ( $in )" : "( $in )");
      } else {
         push @$args, $params{$key};
         push @where, (@where ? "$com `$col` $match ?" : "`$col` $match ?");
      }
   }
   $where ||= @where ? 'where ' . join(' ', @where) : '';
   # create sql, fetch and return result
   my $sql = qq{ select $fetch from $table $where $order $limit $offset };
   my $rows = $class->_db->do_query($sql, @$args);
   return $fetch eq 'count(*)'
      ? $rows->[0]->{'count(*)'}
      : [ map $class->new_from_db($_, $f_keys), @$rows ];
}

# --------------------------------------------------------------------------
# change object state
# --------------------------------------------------------------------------

#... updates model with all NOT PROTECTED values in the params hash
sub update {
   my ($self, %params) = @_;
   my $class = ref $self;
   
   #... delete protected params
   foreach my $protected (@{$self->PROTECTED}) {
      delete $params{$protected};
      delete $params{$Has_a{$::appname}{$class}{$protected}[0]}
         if exists $Has_a{$::appname}{$class}{$protected};
   }
   
   #... update model
   $self->_update(\%params);
}

#... updates model with all values in the params hash
sub _update {
   my ($self, $params) = @_;
   my %modified;
   
   #... update foreign keys
   foreach my $f_key (@{$self->_foreign_keys}) {
      my ($column, $accessor, $model, $constructor) = @$f_key;
      if (exists $params->{$accessor}) {
         my $obj = $params->{$accessor};
         $modified{$column} = $obj && $obj->id;
         $modified{$accessor} = $obj;
         delete $params->{$column};
         delete $params->{$accessor};
      } elsif (exists $params->{$column}) {
         my $id = $params->{$column};
         $modified{$column} = $id;
         $modified{$accessor} = $id && $model->$constructor(id => $id);
         delete $params->{$column};
         delete $params->{$accessor};
      }
   }
   
   #... update normal content
   foreach my $name (map $_->{name}, @{$self->_columns}) {
      $modified{$name} = $params->{$name} if exists $params->{$name};
   }

   #... update obj state
   delete $self->{_accessors}{$_} foreach keys %modified;
   $self->{_modified}{$_} = $modified{$_} foreach keys %modified;
}

sub _fetch {
   my $self = shift;
   my $class = ref $self;

   #... get primary keys
   my %params = map {
      WebTek::Exception->throw("$class->_fetch: primary-key '$_' don't exist!")
         unless exists $self->{_content}{$_};      
      $_ => $self->{_content}{$_};
   } @{$self->_primary_keys};
   
   #... get obj
   my $obj = $class->find_one(%params) or WebTek::Exception->
      throw("$self->_fetch: cannot find db-entry for " . _struct(\%params));
   
   #... copy obj to self
   my ($from, $to) = ($obj->{_content}, $self->{_content});
   $to->{$_} = $from->{$_} foreach (keys %$from);

   #... update obj state
   $self->{_in_db} = 1;
   $self->{_accessors} = {};
}

# --------------------------------------------------------------------------
# some utilities
# --------------------------------------------------------------------------

#... create an accessor to access db-columns via a method
sub _make_accessor {
   my ($class, $name, $type) = @_;

   my $sub = sub {
      my $self = shift;

      $self->_update({ $name => shift }) if @_;
      my $a = $self->{_accessors}{$name} ||= $self->_accessor($name, $type);
      return $a->{$name};
   };
   
   my @attrs = (grep $_ eq $name, @{$class->PROTECTED}) ? () : ('Macro');
   WebTek::Util::make_method($class, $name, $sub, @attrs);
}

#... serialize from strings to WebTek::Data objects
sub _serialize {
   my ($self, $value, $type) = @_;
   
   return $value if blessed $value;
   return $value if not $value or $type eq DATA_TYPE_STRING;
   return ($value ? 1 : 0) if $type eq DATA_TYPE_BOOLEAN;
   return ($value ? 0+$value : $value) if $type eq DATA_TYPE_NUMBER;
   return _struct($value) if $type eq DATA_TYPE_JSON;
   return _struct($value, 'perl') if $type eq DATA_TYPE_PERL;
   my $timezone = $self->_db->config->{timezone};
   return _date($value, $timezone) if $type eq DATA_TYPE_DATE;
   throw "cannot access '$value', unknown data-type '$type'";
}

sub _accessor {
   my ($self, $name, $type) = @_;
 
   my $is_modified = exists $self->{_modified}{$name};
   my $store = $is_modified ? $self->{_modified} : $self->{_content};
   $store->{$name} = $self->_serialize($store->{$name}, $type);
   return $store;
}

#... this function prepare a param hash, to be used by an find function
sub _prepare_params {
   my ($class, $params) = @_;
   
   my $f_keys = {};
   while (my ($key, $value) = each %$params) {
      #... translate objects to db-columns
      if (my $ref = ref $value) {
         next if $ref eq 'ARRAY'; # type ARRAY understands the find fkt
         next unless blessed $ref;
         if ($value->can('to_db')) {
            $params->{$key} = $value->to_db($class->_db);
         } elsif ($value->can('id')) {
            $f_keys->{$key} = $value;
            $params->{"$key\_id"} = $value->id;
            delete $params->{$key};
         }
      }
   }
   return $f_keys;
}

#... this function returns SCALAR values for WebTek::Data:: objects
sub _value_for_column {
   my ($self, $c, $s2) = @_;
   my ($s1, $s2) = ($self->{_content}, $s2 || {});
   
   my $v = exists $s2->{$c} ? $s2->{$c} : $s1->{$c};
   $v = $v->to_db($self->_db) if blessed $v and $v->can('to_db');
   return $v;
}

sub _values_for_columns {
   my ($self, $columns, $store) = @_;
   
   return map $self->_value_for_column($_, $store), @$columns;
}

sub _do_action { shift->_db->do_action(@_) }

sub _get_next_id { } # implement this in the subclass

# --------------------------------------------------------------------------
# make persistent with db
# --------------------------------------------------------------------------

sub save {
   my $self = shift;
   my $class = ref $self;
   
   _event->trigger(obj => $class, name => 'before-save', args => [ $self ]);
   $self->before_save if $self->can('before_save');

   #... check if object is already persistent
   return if $self->_in_db and not keys %{$self->_modified};

   #... check if content is valid
   $self->is_valid('die');
   
   $self->_delete_from_cache;
   my $modified = $self->{_modified};
   my $table_name = $self->TABLE_NAME;
   my $op = $self->_in_db ? 'update' : 'insert';
   _event->trigger(obj => $class, name => "before-$op", args => [$self]);

   #... do an update
   if ($op eq 'update') {
      $self->before_update if $self->can('before_update');
      my @pks = @{$self->_primary_keys};
      my $where = join ' and ', map "`$_` = ?", @pks;
      my @where_values = $self->_values_for_columns(\@pks);
      my @set_columns = keys %{$self->{_modified}};
      my @set_values = $self->_values_for_columns(\@set_columns, $modified);
      my $set = join ', ', map "`$_` = ?", @set_columns;
      my $sql = "update $table_name set $set where $where";
      $self->_do_action($sql, @set_values, @where_values);
      $self->_updated(\@set_columns);

   #... do an insert
   } else {
      $self->before_insert if $self->can('before_insert');
      $self->{_content}{id} = $self->_get_next_id unless $self->{_content}{id};
      my @columns = map $_->{name}, @{$self->_columns};
      my $keys = join ', ', map "`$_`", @columns;
      my $values = join ', ', map '?', @columns;
      my $sql = "insert into $table_name ($keys) values ($values)";
      my @args = $self->_values_for_columns(\@columns, $modified);
      $self->_do_action($sql, @args);
      if ($self->can('id') and not defined $self->{_content}{id}) {
         $self->{_modified}{id} = $self->_db->last_insert_id($table_name, 'id');
      }
      $self->_updated(\@columns);
   }

   $self->{_content}{$_} = $modified->{$_} foreach (keys %$modified);
   $self->{_modified} = {};
   $self->{_accessors} = {};
   $self->_in_db(1);
   _event->trigger(obj => $class, name => "after-$op", args => [$self]);
   my $callback = "after_$op";
   $self->$callback if $self->can($callback);
   $self->_set_to_cache;

   _event->trigger(obj => $class, name => 'after-save', args => [ $self ]);
   $self->after_save if $self->can('after_save');
   return 1;
}

# --------------------------------------------------------------------------
# cache methods
# --------------------------------------------------------------------------

sub _delete_from_cache {
   my $self = shift;
   my $real = $self->_real;

   if (my $keys = WebTek::Cache::settings($real)) {
      foreach my $key (@$keys) {
         my @columns = split ",", $key;
         my @values = $self->_values_for_columns(\@columns);
         my $key = WebTek::Cache::key($real, @columns, @values);
         $self->_cache->delete($key);
         log_debug "$$: WebTek::Model: delete_from_cache: $key";
      }
   }
}

sub _set_to_cache {
   my $self = shift;
   my $class = ref $self;
   my $real = $self->_real;

   #... set obj for each cache key
   if (my $keys = WebTek::Cache::settings($real)) {
      #... create a copy of $self with all foreign-keys setted to lazy refs
      my $obj = $class->new_from_db($self->{_content});
      foreach my $key (@$keys) {
         my @columns = split ',', $key;
         my @values = $self->_values_for_columns(\@columns);
         my $key = WebTek::Cache::key($real, @columns, @values);
         $self->_cache->set($key, $obj);
         log_debug "$$: WebTek::Model: set_to_cache: $key, $obj";
      }
   }
}

sub _cache_key {
   my ($class, %params) = @_;
   my $real = $class->_real;
   
   my $keys = WebTek::Cache::settings($real);
   return unless $keys;
   my $key1 = join ',', sort(keys %params);
   foreach my $key (@$keys) {
      my @columns = sort split ',', $key;
      my $key2 = join ',', @columns;
      if ($key1 eq $key2) {
         $class->_prepare_params(\%params);
         my @values = map $params{$_}, @columns;         
         return WebTek::Cache::key($real, @columns, @values), @columns;
      }
   }
}

sub _get_from_cache {
   my ($class, %params) = @_;
   
   my ($cache_key, @columns) = $class->_cache_key(%params);
   return unless $cache_key;
   my $obj = $class->_cache->get($cache_key) or return;
   $obj->_update({ map { $_ => $params{$_} } @columns });
   log_debug "$$: WebTek::Model: get_from_cache: $cache_key: $obj";
   return $obj;
}

# --------------------------------------------------------------------------
# delete object
# --------------------------------------------------------------------------

sub delete {
   my $self = shift;
   my $class = ref $self;

   _event->trigger(obj => $class, name => 'before-delete', args => [ $self ]);
   $self->before_delete if $self->can('before_delete');

   #... delete from cache
   $self->_delete_from_cache;

   #... delete from db
   my $table_name = $self->TABLE_NAME;
   my $where = join(' and ', map "$_ = ?", @{$self->_primary_keys});
   my $sql = "delete from $table_name where $where";
   $self->_do_action($sql, $self->_values_for_columns($self->_primary_keys));

   _event->trigger(obj => $class, name => "after-delete", args => [ $self ]);
   $self->after_delete if $self->can('after_delete');
}

# --------------------------------------------------------------------------
# check properties
# --------------------------------------------------------------------------

sub is_valid {
   my ($self, $die) = @_;
   
   $self->_check;
   my @errors = keys %{$self->{_errors}};
   unless ($die) { return scalar(@errors) ? 0 : 1 }
   @errors and WebTek::Exception::ModelInvalid->
      throw("model $self invalid for @errors", $self);
}

sub error_on {
   my ($self, $column) = @_;
   
   $self->_check;
   return $self->{_errors}{$column};
}

sub _set_errors {
   my ($self, $errors) = @_;
   
   my $prefix = ref $self;
   $prefix =~ s/.*?:://;
   $prefix =~ s/::/\./g;
   $errors->{$_} = "$prefix.$_.$errors->{$_}" foreach (keys %$errors);
   
   $self->{_checked} = 1;
   $self->{_errors} = $errors;
}

sub _check {
   my $self = shift;
   my $class = ref $self;
   
   _event->trigger(obj => $class, name => 'before-check', args => [ $self ]);
   $self->before_check if $self->can("before_check");
   
   #... is content already checked?
   return if $self->_checked;

   #... check each column
   my $errors = {};
   my $modified = $self->{_modified};
   CHECK: foreach my $name (keys %$modified) {
      my ($column) = grep $name eq $_->{name}, @{$self->_columns};
      my $value = $self->_value_for_column($name, $modified);

      #... dont check the id-field when model is not in db
      next CHECK if $name eq 'id' and not $self->_in_db;

      #... is there a property check defined 
      my $prop = $self->PROPERTIES->{$name};
      if ($prop) {
         next CHECK if ref $prop eq "CODE" and &$prop($self, $name, $value);
         next CHECK if $value =~ /$prop/;
         unless ($value) { $errors->{$name} = 'empty' }
         else { $errors->{$name} = 'invalid' }
         next CHECK;
      }

      #... check for nullable
      next CHECK if $column->{nullable} and ($value eq '');
      if (!$column->{nullable} and ($value eq '')) {
         $errors->{$name} = 'empty';
         next CHECK;
      }

      #... check for valid dates
      if ($column->{webtek_data_type} eq DATA_TYPE_DATE) {
         $errors->{$name} = 'invalid' unless _date($value)->is_valid;
         next CHECK;
      }

      #... check length
      {
         use bytes;
         next CHECK unless defined $column->{length};
         next CHECK if $column->{webtek_data_type} eq DATA_TYPE_DATE;
         next CHECK if $column->{length} >= length($value);       
      }

      #... ok, all test failed, push column to errors
      $errors->{$name} = "invalid";
   }
   
   #... add model-name to the keys
   $self->_set_errors($errors);

   _event->trigger(obj => $class, name => 'after-check', args => [ $self ]);
   $self->after_check if $self->can('after_check');
}

# --------------------------------------------------------------------------
# serialize
# --------------------------------------------------------------------------

sub to_hash {
   my $self = shift;
   
   my $hash = {};
   foreach my $name (map $_->{name}, @{$self->_columns}) {
      next if grep { $name eq $_ } @{$self->PROTECTED};
      $hash->{$name} = $self->_value_for_column($name, $self->{_modified});
   }
   return $hash;
}

sub to_string {
   my $self = shift;
   
   my $hash = $self->to_hash;
   my $table_name = $self->table_name;
   my $values = join "\n", map "   $_: $hash->{$_}", keys %$hash;   
   return "$table_name:\n$values";
}

sub describe {
   my $class = shift;
   
   my $table_name = $class->TABLE_NAME;
   my $primary_keys = join ", ", @{$class->_primary_keys};
   my $desc = "describe $table_name:\n  primary-key: $primary_keys\n";
   foreach my $column (@{$class->columns}) {
      $desc .= join "\n", map "   $_: $column->{$_}", keys %$column;
   }
   return $desc;
}

1;
