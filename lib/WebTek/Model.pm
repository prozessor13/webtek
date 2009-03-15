package WebTek::Model;

# max demmelbauer
# 14-02-06
#
# superclass of all models

use strict;
use WebTek::DB qw( DB );
use WebTek::App qw( app );
use WebTek::Util qw( assert make_accessor );
use WebTek::Event qw( event );
use WebTek::Logger qw( ALL );
use WebTek::Config qw( config );
use WebTek::Exception;
use WebTek::Data::Date qw( date );
use WebTek::Data::Struct  qw( struct );
use base qw( WebTek::Handler );
use Encode qw( _utf8_on decode encode_utf8 );

our %Primary_keys;
our %Columns;
our %Has_a;

make_accessor('_in_db');               # boolean
make_accessor('_checked');             # boolean
make_accessor('_modified');            # boolean
make_accessor('_lazy');                # array
make_accessor('_updated');             # array
make_accessor('_errors');              # hash
make_accessor('_persistent_content');  # hash

# --------------------------------------------------------------------------
# constants
# --------------------------------------------------------------------------

sub DATA_TYPE_UNKNOWN { 0 }
sub DATA_TYPE_STRING { 1 }
sub DATA_TYPE_NUMBER { 2 }
sub DATA_TYPE_BOOLEAN { 3 }
sub DATA_TYPE_DATE { 4 }
sub DATA_TYPE_BLOB { 5 }
sub DATA_TYPE_STRUCT { 6 }

# --------------------------------------------------------------------------
# export macros into pages
# --------------------------------------------------------------------------

sub import {
   my $class = shift;
   
   #... check if there is something to do
   return unless @_;
   
   #... export methods into caller (=page)
   my %export = @_;
   my $caller = caller;
   my $handler = $export{'handler'} || $export{'accessor'};
   my @macros = $export{'macros'} ? @{$export{'macros'}} : ();
   my @public = $export{'public'} ? @{$export{'public'}} : ();
   assert($handler, "handler not defined for $caller");
   #... export handler
   unless (defined &{"$caller\::$handler"}) {
      my @attrs = ('Handler');
      if (grep { $handler eq $_ } @public) { push @attrs, 'Public' }
      WebTek::Util::make_method($caller, $handler, undef, @attrs);
   }
   #... export macros
   foreach my $macro (@macros) {
      my ($column, $as) = ($macro, $macro);
      my @attrs = ( 'Macro' );
      if (grep { $column eq $_ } @public) { push @attrs, 'Public' }
      #... check 'macro as other' syntax
      if ($macro =~ /^(\w+) as (\w+)$/) { $column = $1; $as = $2 }
      next if (defined &{"$caller\::$as"});
      make_macro_method($caller, $handler, $column, $as, @attrs);
   }
}

# --------------------------------------------------------------------------
# get information about the model
# --------------------------------------------------------------------------

sub PROTECTED { [] }

sub PROPERTIES { {} }

sub DATATYPES { {} }

sub DEFAULTS { {} }

# from unique constraint name to column
sub UNIQUE_CONSTRAINTS { {} }

sub primary_keys {
   my $class = ref $_[0] || $_[0];

   return $Primary_keys{app->name}->{$class} || [];
}

# returns list of hashes, each hash has keys 'name', 'default'
sub columns { 
   my $class = ref $_[0] || $_[0];

   return $Columns{app->name}->{$class} || [];
}

sub foreign_keys {
   my $class = ref $_[0] || $_[0];
   
   my @has_a = map {
      [ $_, @{$Has_a{app->name}->{$class}->{$_}} ]
   } keys %{$Has_a{app->name}->{$class}};
   return \@has_a;
}

# --------------------------------------------------------------------------
# set information about the model
# --------------------------------------------------------------------------

sub _primary_keys {
   my $class = shift;
   my $keys = shift;    # array-ref with primary key names
   
   $Primary_keys{app->name}->{$class} = $keys;
}

sub _columns {
   my $class = shift;
   my $cols = shift;    # array-ref with column names
   
   $Columns{app->name}->{$class} = $cols;
}

sub has_a {
   my $class = shift;
   my $name = shift;
   my $model = shift;         # optional
   my $constructor = shift;   # optional

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
   unless ($model) {
      my $modelprefix = $class;
      $modelprefix =~ s/(\w+)$//;
      my $modelname = ucfirst($accessor);
      $modelname =~ s/_(\w)/\u$1/g;
      $model = $modelprefix . $modelname;
   }
   $constructor ||= 'new';
   
   #... remember in $Has_a
   $Has_a{app->name}->{$class}->{$column} =
      [$accessor, $model, $constructor];
   #... make a model method
   $class->make_has_a_method($accessor, $column);   
}

# --------------------------------------------------------------------------
# get database object for this model
# --------------------------------------------------------------------------

sub db { DB }

# --------------------------------------------------------------------------
# create and init model
# --------------------------------------------------------------------------

sub _new {
   my $class = shift;
   
   assert !ref($class), "try to create a model with an obj, not a classname";
   my $self = $class->SUPER::new;
   $self->_errors({});
   $self->_updated([]);
   return $self;
}

sub new {
   my $class = shift;
   my %content = ref $_[0] ? %{$_[0]} : @_;

   #... create lazy instance
   my $self = $class->_new;
   #... set lazy
   $self->_lazy([keys %content]);
   #... update with params
   $self->_update(\%content);

   event->notify("$class-created", $self);
   $self->class_created if $self->can("class_created");

   return $self;
}

sub new_default {
   my $class = shift;
   my %content = ref $_[0] ? %{$_[0]} : @_;
   
   #... fill in default values
   foreach my $column (@{$class->columns}) {
      my $n = $column->{'name'};
      next if exists $content{$n};
      if (exists $class->DEFAULTS->{$n}) {
         if (ref($class->DEFAULTS->{$n}) eq 'CODE') {
            $content{$n} = $class->DEFAULTS->{$n}->($class);
         } else {
            $content{$n} = $class->DEFAULTS->{$n};
         }
      } elsif ($n eq 'class') {
         $content{$n} = $class;
      } elsif (exists $column->{'default'}) {
         $content{$n} = $column->{'default'}
      }
   }
   #... create model
   my $self = $class->new(%content);
   return $self;
}

sub new_from_db {
   my $class = shift;
   my $content = shift;    # hashref with contents
   my $f_keys = shift;     # hashref with f_key objects
   
   $class = $content->{'class'} if $content->{'class'};
   my $self = $class->_new;
   $self->_lazy([]);
   $self->_persistent_content({ %$content });
   $self->_content_into_objs($content);
   $self->_populate($content, $f_keys);
   $self->_modified(0);
   $self->_in_db(1);
   return $self;
}

sub _init {
   my $class = shift;
   
   no strict 'refs';

   #... check if model is a real model
   #... (i.e. model is direct subclass of WebTek::Model)
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
      log_debug "$$: copy modelinfos from $real into not real model $class";
      $class->_columns($real->columns);
      $class->_primary_keys($real->primary_keys);
      $class->has_a(@$_[1,2,3]) foreach @{$real->foreign_keys};
      WebTek::Util::may_make_method($class, '_class', sub { $class });
      return;
   }

   log_debug("$$: init model $class");
   
   #... find model class for database vendor
   my $vendor = $class->db->vendor;
   my $modelclass;
   if ($vendor eq WebTek::DB::DB_VENDOR_MYSQL()) {
      $modelclass = 'WebTek::Model::Mysql';
   } elsif ($vendor eq WebTek::DB::DB_VENDOR_POSTGRES()) {
      $modelclass = 'WebTek::Model::Postgres';
   } elsif ($vendor eq WebTek::DB::DB_VENDOR_ORACLE()) {
      $modelclass = 'WebTek::Model::Oracle';
   }
   WebTek::Loader->load($modelclass);
   assert($modelclass, "Modelclass not found for vendor: '$vendor'");
   #... replace the superclass with the vendor-specific one
   for(my $i=0; $i<scalar(@{"$class\::ISA"}); $i++) {
      if ("".${"$class\::ISA"}[$i] eq __PACKAGE__) {
         ${"$class\::ISA"}[$i] = $modelclass;
      }
   }

   #... create TABLE_NAME
   my $tablename = substr $class, rindex($class, ":") + 1;
   $tablename =~ s/([a-z])([A-Z])([a-z])/$1\_$2$3/g;
   $tablename = lc $tablename;
   WebTek::Util::may_make_method($class, 'TABLE_NAME', sub { $tablename });
   #... analyze table
   my $tablename = $class->TABLE_NAME;
   my $columns = $class->db->column_info($tablename);
   my $primary_keys = $class->db->primary_keys($tablename);
   assert(scalar(@$primary_keys), "no primary keys defined for '$tablename'");
   #... create model methods   
   foreach my $column (@$columns) {
      #... create an accessor for each column
      $class->make_columnname_method($column->{'name'});
      #... check if column is a foreign key
      if ($column->{'name'} =~ /^.+_id$/) {
         $class->has_a($column->{'name'});
      }
   }
   #... remember colums and primary keys
   $class->_columns($columns);
   $class->_primary_keys($primary_keys);
}

# --------------------------------------------------------------------------
# fetching model rows
# --------------------------------------------------------------------------

sub find_one {
   my $class = shift;
   my $params = ref $_[0] ? $_[0] : { @_ };

   my $obj = $class->get_from_cache($params);
   unless ($obj) {
      $obj = $class->find($params)->[0];
      $obj->set_to_cache if $obj;
   }
   return $obj;
}

sub find_one_or_die {
   my $class = shift;
   my $params = ref $_[0] ? $_[0] : { @_ };

   my $result = $class->find_one($params);
   assert $result, "Row not found in database: table '".$class->TABLE_NAME().
      "': ".join(", ", map { "'$_' => '".$params->{$_}."'" } keys(%$params));
   return $result;
}

sub find {
   my $class = shift;
   my $params = ref $_[0] ? $_[0] : { @_ };

   #... fetch from db
   my $f_keys = $class->_prepare_params($params);
   my $table = $class->TABLE_NAME;
   my $order = $params->{'order'} ? "order by $params->{'order'}" : '';
   my $combine = $params->{'combine'} || 'and';
   my $limit = $params->{'limit'} ? "limit $params->{'limit'}" : '';
   my $offset = $params->{'offset'} ? "offset $params->{'offset'}" : '';
   my $fetch = $params->{'FETCH'} || "*";
   delete $params->{'FETCH'};
   delete $params->{'limit'};
   delete $params->{'offset'};
   delete $params->{'order'};
   delete $params->{'combine'};
   # single table inheritance
   $params->{'class'} ||= $class->_class if $class->can('_class');
   # parse conditions
   my @conditions = ();
   foreach my $key (keys %$params) {
      if ($key =~ /^((and|or)\s+)?(\S+)(\s+(\S+))?$/) {
         my $com = $2 || $combine;
         my $col = $3;
         my $match = $5 || "=";
         push @conditions, [$key, $com, $col, $match];
      } else {
         log_warning $class . "->find: cannot understand condition '$key'";
      }
   }
   # order conditions (and before or)
   @conditions = sort { $a->[1] <=> $b->[1] } @conditions;
   # create where clause
   my @args = ();
   my @where = ();
   foreach (@conditions) {
      my ($key, $com, $col, $match) = @$_;
      if (ref $params->{$key} eq 'ARRAY') {
         my $in = join " or ", map { "`$col` $match ?" } @{$params->{$key}};
         push @args, @{$params->{$key}};
         push @where, (@where ? "$com ( $in )" : "( $in )");
      } else {
         push @args, $params->{$key};
         push @where, (@where ? "$com `$col` $match ?" : "`$col` $match ?");
      }
   }
   my $where = @where ? "where " . join(" ", @where) : "";
   # create sql and fetch result
   my $sql = qq{ select $fetch from $table $where $order $limit $offset };
   my $rows = $class->db->do_query($sql, @args);
   #... check if only the count was requested
   return $rows->[0]->{'c'} if $fetch eq 'count(*) as c';
   #... create objects
   my $objs = $class->_objs_for_rows($rows, $f_keys);
   return $objs;      
}

sub _count {
   my $class = shift;
   my $params = ref $_[0] ? $_[0] : { @_ };

   $params->{'FETCH'} = 'count(*) as c';
   return $class->find($params);
}

sub count { &_count }

sub where {
   my $class = shift;
   my $where = shift;   # where and order sql part
   my @args = @_;
   
   #... fetch from db
   my $table = $class->TABLE_NAME;
   my $sql = qq{ select * from $table where $where };
   
   #... create objects
   my $objs =  $class->_objs_for_rows($class->db->do_query($sql, @args));
   return $objs;
}

sub count_where {
   my $class = shift;
   my $where = shift;   # where and order sql part
   my @args = @_;

   my $table = $class->TABLE_NAME;
   my $sql = qq{ select count(*) as count from $table where $where };
   return $class->db->do_query($sql, @args)->[0]->{'count'};
}

sub _objs_for_rows {
   my $class = shift;
   my $rows = shift;
   my $f_keys = shift;  # optional f_keys objs for the model

   my $objs = [];
   foreach my $row (@$rows) {
      push @$objs, $class->new_from_db($row, $f_keys);
   }
   return $objs;  
}

# --------------------------------------------------------------------------
# change object state
# --------------------------------------------------------------------------

#... updates model with all values in the params hash
sub _update {
   my $self = shift;
   my $params = shift;
   
   $self->_content_into_objs($params);
   #... update content
   foreach my $column (@{$self->columns}) {
      my $name = $column->{'name'};
      $self->$name($params->{$name}) if exists $params->{$name};
   }
   #... update f_keys
   foreach my $f_key (@{$self->foreign_keys}) {
      my ($column, $accessor, $model, $constructor) = @$f_key;
      $self->$accessor($params->{$accessor}) if exists $params->{$accessor};
   }
}

#... updates model with all NOT PROTECTED values in the params hash
sub update {
   my $self = shift;
   my $params = ref $_[0] ? $_[0] : { @_ };
   
   #... delete protected params
   foreach my $protected (@{$self->PROTECTED}) {
      my $foreign_key_accessor = "";
      foreach my $f_key (@{$self->foreign_keys}) {
         if ($f_key->[0] eq $protected) {
            $foreign_key_accessor = $f_key->[1];
            last;
         }
      }
      if ($foreign_key_accessor) { delete $params->{$foreign_key_accessor} }
      delete $params->{$protected};
   }
   #... update model
   $self->_update($params);
}

#... fetch an lazy object from the db FIXME!
sub _fetch {
   my $self = shift;
   my $class = ref $self;

   #... prepare params
   my @k = @{$self->_lazy};
   my %params = map { $_ => $self->$_() } @{$self->_lazy};

   #... check if all primay keys are defined
   foreach (@{$self->primary_keys}) {
      WebTek::Exception->throw("$self->_fetch: primary-key '$_' don't exists!")
         unless exists $params{$_};
   }
   
   #... get obj
   my $obj = $class->find_one(%params) or WebTek::Exception->
      throw("$self->_fetch: cannot find db-entry for " . struct(\%params));

   #... copy obj to self
   $self->{$_} = $obj->{$_} foreach (keys %$obj);
}

# --------------------------------------------------------------------------
# some utilities
# --------------------------------------------------------------------------

#... converts all SCALAR params to the coresponding WebTek::Data:: objects.
sub _content_into_objs {
   my $class_or_self = shift;
   my $content = shift;          # hashref with contents
   
   foreach my $column (@{$class_or_self->columns}) {
      my $name = $column->{'name'};
      my $data_type = $column->{'webtek-data-type'};
      #... check if there is something to do
      next unless $content->{$name};
      next if ref($content->{$name}) =~ /^WebTek::Data::/;
      #... create content object
      my $value = $content->{$name};
      if ($data_type == DATA_TYPE_BOOLEAN) {
         $content->{$name} = $value ? 1 : 0;         
      } elsif ($data_type == DATA_TYPE_STRUCT) {
         $content->{$name} = struct($value);
      } elsif ($data_type == DATA_TYPE_NUMBER) {
         $content->{$name} = $value;
      } elsif ($data_type == DATA_TYPE_DATE) {
         my $timezone = $class_or_self->db->config->{'timezone'};
         $content->{$name} = date($value, $timezone);
      } elsif ($data_type == DATA_TYPE_STRING) {
         $content->{$name} = $value;
      }
   }
}

#... this function creates all f_key objects for this model
#... i.e. creates an User object for the content 'user_id'
sub _populate {
   my $self = shift;
   my $content = shift;       # hashref with content objects (WebTek::Data::X)
   my $f_keys = shift || {};  # optional hashref with f_key objects

   #... set content
   $self->{'content'} = $content;
   #... handle f_keys
   foreach my $f_key (@{$self->foreign_keys}) {
      my ($column, $accessor, $model, $constructor) = @$f_key;
      #... f_key is already there FIXME! is this save?
      next if (ref $self->{'has_a'}->{$accessor});
      #... f_key comes from the user of this model
      if (exists $f_keys->{$accessor}) {
         $self->{'has_a'}->{$accessor} = $f_keys->{$accessor};
      #... create lazy f_key object
      } elsif (defined $self->{'content'}->{$column}) {
         $self->{'has_a'}->{$accessor} = 
            $model->$constructor('id' => $self->{'content'}->{$column});
      } else {
         $self->{'has_a'}->{$accessor} = undef;
      }
   }
}

#... this function prepare a param hash, to be used by an find function
#...   WebTek::Data:: objects -> SCALAR
#...   has_a params -> SCALAR (i.e. the object under user -> SCALAR user_id)
#... - this function takes a hashref an convert all values
#... - and it returns a hashref with all foreign-key objects
sub _prepare_params {
   my $class_or_self = shift;
   my $params = shift;     # hashref
   
   my $f_keys = {};
   while (my ($key, $value) = each(%$params)) {
      #... translate objects to db-columns
      if (my $ref = ref $value) {
         if ($ref =~ /^WebTek::Data::/) {
            $params->{$key} = $value->to_db($class_or_self->db);
         } elsif ($ref ne 'ARRAY') { # the ARRAY understands the find fkt
            $f_keys->{$key} = $value;
            $params->{"$key\_id"} = $value->id;
            delete $params->{$key};
         }
      }
   }
   return $f_keys;
}

#... this function returns SCALAR values for all the WebTek::Data:: objects
sub _values_for_columns {
   my $self = shift;
   my $columns = shift;
   my $content = shift || $self->{'content'};

   return map {
      (ref $content->{$_})
         ? $content->{$_}->to_db($self->db)
         : $content->{$_}
   } @$columns;
}

sub _get_next_id { } # implement this in the subclass

# --------------------------------------------------------------------------
# make persistent with db
# --------------------------------------------------------------------------

# like "$self->db->do_action" but subclasses can override to throw meaningful exceptions
sub _do_do_action {
   my ($self, $sql, @args) = @_;
   $self->db->do_action($sql, @args);
}

sub throw_model_invalid_if_errors {
   my $self = shift;
   
   unless ($self->is_valid) {
      my @errors = keys %{$self->_errors};
      WebTek::Exception::ModelInvalid->
         throw("model $self invalid for @errors", $self);
   }
}

# like "$self->db->do_action" but converts constraint errors into $self->{errors}
sub _do_action {
   my ($self, $sql, @args) = @_;
   
   my $chk = eval { $self->_do_do_action($sql, @args); 1; };
   unless (defined($chk)) {
      my $err = $@;
      if (ref($err) eq "WebTek::DB::UniqueConstraintViolatedException") {
         my $column = $self->UNIQUE_CONSTRAINTS()->{$err->constraint_name()};
         if ($column) {
            $self->_set_errors({ $column => 'alreadyexists' });
            $self->throw_model_invalid_if_errors();
         }
      }
      die($err);
   }
}

sub save {
   my $self = shift;
   my $class = ref $self;
   
   event->notify("$class-before-save", $self);
   $self->before_save if $self->can("before_save");

   #... check if object is already persistent
   return if $self->_in_db and not $self->_modified;

   #... check if content is valid
   $self->throw_model_invalid_if_errors();
   
   $self->delete_from_cache;
   my $table_name = $self->TABLE_NAME;
   my $operation = $self->_in_db ? 'update' : 'insert';
   event->notify("$class-before-$operation", $self);

   #... do an update
   if ($operation eq 'update') {
      $self->before_update if $self->can("before_update");
      my @pks = @{$self->primary_keys};
      my $where = join " and ", map { "`$_` = ?" } @pks;
      my @where_values =
         $self->_values_for_columns(\@pks, $self->_persistent_content);
      my @set_columns = @{$self->_lazy};
      my @set_values = $self->_values_for_columns(\@set_columns);
      my $set = join ", ", map { "`$_` = ?" } @set_columns;
      my $sql = qq{ update $table_name set $set where $where };
      $self->_do_action($sql, @set_values, @where_values);
      $self->_updated(\@set_columns);

   #... do an insert
   } else {
      $self->before_insert if $self->can("before_insert");
      unless ($self->{'content'}->{'id'}) {
         $self->{'content'}->{'id'} = $self->_get_next_id;
      }
      my @columns = map { $_->{'name'} } @{$self->columns};
      my $keys = join(", ", map { "`$_`" } @columns);
      my $values = join(", ", map { '?' } @columns);
      my $sql = qq{ insert into $table_name ($keys) values ($values) };
      my @args = $self->_values_for_columns(\@columns);
      $self->_do_action($sql, @args);
      if ($self->can('id') and not defined $self->{'content'}->{'id'}) {
         $self->id($self->db->last_insert_id($table_name, 'id'));
      }
      $self->_updated(\@columns);
   }

   $self->_persistent_content({ %{$self->{'content'}} });
   $self->_modified(0);
   $self->_in_db(1);
   $self->_lazy([]);
   event->notify("$class-after-$operation", $self);
   my $callback = "after_$operation";
   $self->$callback if $self->can($callback);
   $self->set_to_cache;

   event->notify("$class-after-save", $self);
   $self->after_save if $self->can("after_save");
}

# --------------------------------------------------------------------------
# cache methods
# --------------------------------------------------------------------------

sub delete_from_cache {
   my $self = shift;
   my $class = ref $self;

   if (my $keys = WebTek::Cache::settings($class)) {
      foreach my $key (@$keys) {
         my @columns = split ",", $key;
         #... remove old content (state before update) from cache
         if (my $content = $self->_persistent_content) {
            my @values = $self->_values_for_columns(\@columns, $content);
            my $key = WebTek::Cache::key($class, @columns, @values);
            WebTek::Cache::cache()->delete($key);
            log_debug "$$: WebTek::Model: delete_from_cache - old: $key";
         }
         #... remove new content (state after update) from cache
         my @values = $self->_values_for_columns(\@columns);
         my $key = WebTek::Cache::key($class, @columns, @values);
         WebTek::Cache::cache()->delete($key);
         log_debug "$$: WebTek::Model: delete_from_cache - new: $key";
      }
   }
}

sub set_to_cache {
   my $self = shift;
   my $class = ref $self;

   #... set obj for each cache key
   if (my $keys = WebTek::Cache::settings($class)) {
      #... create a copy of $self with all foreign-keys setted to lazy refs
      my $obj = $class->new_from_db($self->{'content'});
      foreach my $key (@$keys) {
         my @columns = split ",", $key;
         my @values = $self->_values_for_columns(\@columns);
         my $key = WebTek::Cache::key($class, @columns, @values);
         WebTek::Cache::cache()->set($key, $obj);
         log_debug "$$: WebTek::Model: set_to_cache: $key, $obj";
      }
   }
}

sub get_from_cache {
   my ($class, $params) = @_;
   
   my $keys = WebTek::Cache::settings($class);
   return unless $keys;
   my $key1 = join ",", sort(keys %$params);
   foreach my $key (@$keys) {
      my @columns = sort(split ",", $key);
      my $key2 = join ",", @columns;
      if ($key1 eq $key2) {
         my %p = %$params;
         $class->_prepare_params(\%p);
         my @values = map $p{$_}, @columns;         
         my $cache_key = WebTek::Cache::key($class, @columns, @values);
         my $obj = WebTek::Cache::cache()->get($cache_key);
         return unless $obj;
         #... populate object with search setting (they may be objects)
         $obj->$_($params->{$_}) foreach (@columns);
         log_debug "$$: WebTek::Model: get_from_cache: $cache_key: $obj";
         return $obj;
      }
   }
}

# --------------------------------------------------------------------------
# delete object
# --------------------------------------------------------------------------

sub delete {
   my $self = shift;
   my $class = ref $self;

   event->notify("$class-before-delete", $self);
   $self->before_delete if $self->can("before_delete");

   #... delete from cache
   $self->delete_from_cache;

   #... delete from db
   my $table_name = $self->TABLE_NAME;
   my $where = join(" and ", map { "$_ = ?" } @{$self->primary_keys});
   my @args = map { $self->{'content'}->{$_} } @{$self->primary_keys};
   my $sql = qq{ delete from $table_name where $where };
   $self->db->do_action($sql, @args);

   event->notify("$class-after-delete", $self);
   $self->after_delete if $self->can("after_delete");
}

# --------------------------------------------------------------------------
# check properties
# --------------------------------------------------------------------------

sub is_valid {
   my $self = shift;
   
   $self->_check;
   return scalar(keys %{$self->_errors}) ? 0 : 1;
}

# returns e.g. "Model.Xyz.col.alreadyexists"
sub error_on { (shift->error_key_for(shift)) }

# returns e.g. "alreadyexists"
sub error_suffix_on {
   my $self = shift;
   my $column = shift;  # columnname
   
   my $error = $self->error_on($column); # e.g. "Model.Xyz.col.alreadyexists"
   if ($error =~ /^Model.(\w+).(\w+).(\w+)$/) {
      my ($cl, $col, $err) = ($1, $2, $3);
      assert ref($self) =~ /\Q$cl/;
      assert $col eq $column;
      return $err;
   } else {
      return undef;
   }
}

sub error_key_for {
   my $self = shift;
   my $column = shift;  # columnname
   
   $self->_check;
   return $self->_errors->{$column};
}

sub error_keys {
   my $self = shift;
   
   $self->_check;
   #... create keys
   my $keys = [];
   while (my ($column, $key) = each(%{$self->_errors})) {
      push @$keys, "$column.$key";
   }
   return $keys;
}

sub _set_errors {
   my $self = shift;
   my $errors = shift;          # column-name to e.g. "empty"
   
   my $prefix = ref $self;
   $prefix =~ s/.*?:://;
   $prefix =~ s/::/\./g;
   foreach (keys %$errors) { $errors->{$_} = "$prefix.$_.$errors->{$_}" }
   
   $self->_checked(1);
   $self->_errors($errors);
}

sub _check {
   my $self = shift;
   my $class = ref $self;
   
   event->notify("$class-before-check", $self);
   $self->before_check if $self->can("before_check");
   
   #... is content already checked?
   return if $self->_checked;

   #... check each column
   my $errors = {};
   CHECK: foreach my $column (@{$self->columns}) {
      my $name = $column->{'name'};
      my $content = $self->{'content'}->{$name};
      my $value = ref $content ? $content->to_db($self->db) : $content;

      #... dont check the id-field when model is not in db
      next CHECK if $name eq 'id' and !$self->_in_db;

      #... is there a property check defined 
      my $prop = $self->PROPERTIES->{$name};
      if ($prop) {
         next CHECK if ref $prop eq "CODE" and &$prop($self, $name, $value);
         next CHECK if $value =~ /$prop/;
         unless ($value) { $errors->{$name} = "empty" }
         else { $errors->{$name} = "invalid" }
         next CHECK;
      }

      #... check for nullable
      next CHECK if $column->{'nullable'} and ($value eq "");
      if (!$column->{'nullable'} and ($value eq "")) {
         $errors->{$name} = "empty";
         next CHECK;
      }

      #... check for valid dates
      if ($column->{'webtek-data-type'} == DATA_TYPE_DATE) {
         my $date = ref $content ? $content : date($content);
         unless ($date->is_valid) { $errors->{$name} = "invalid" }
         next CHECK;
      }

      #... check length for strings
      {
         use bytes;
         next CHECK unless defined $column->{'length'};
         next CHECK unless $column->{'webtek-data-type'} == DATA_TYPE_STRING;
         next CHECK if $column->{'length'} >= length($value);       
      }

      #... ok, all test failed, push column to errors
      $errors->{$name} = "invalid";
   }
   
   #... add model-name to the keys
   $self->_set_errors($errors);

   event->notify("$class-after-check", $self);
   $self->after_check if $self->can('after_check');
}

# --------------------------------------------------------------------------
# make methods
# --------------------------------------------------------------------------

sub make_columnname_method {
   my $class = shift;
   my $method = shift;
   
   my @attrs = (grep { $_ eq $method } @{$class->PROTECTED}) ? () : ('Macro');
   my $sub = sub {
      my $self = shift;

      if (@_) {
         my $value = shift;
         $self->_modified(1);
         $self->_checked(0);
         $self->_content_into_objs({ $method => $value });
         $self->{'content'}->{$method} = $value;
         unless (grep { $_ eq $method } @{$self->_lazy}) {
             push @{$self->_lazy}, $method;
         }
      } elsif (not exists $self->{'content'}->{$method}) {
         $self->_fetch;
      }
      return $self->{'content'}->{$method};
   };
   WebTek::Util::make_method($class, $method, $sub, @attrs);
}

sub make_has_a_method {
   my ($class, $method, $column) = @_;
   
   my @attrs = (grep { $_ eq $method } @{$class->PROTECTED}) ? () : ('Handler');
   my $sub = sub {
      my $self = shift;
      
      if (@_) {
         my $obj = shift;
         $self->_modified(1);
         $self->_checked(0);
         $self->{'has_a'}->{$method} = $obj ? $obj : undef;
         $self->{'content'}->{$column} = $obj ? $obj->id : undef;            
         unless (grep { $_ eq $method } @{$self->_lazy}) {
             push @{$self->_lazy}, $column;
         }
      } elsif (not exists $self->{'has_a'}->{$method}) {
         $self->_fetch;
      }
      return $self->{'has_a'}->{$method};
   };
   WebTek::Util::make_method($class, $method, $sub, @attrs);
}

sub make_macro_method {
   my ($class, $accessor, $column, $macro, @attrs) = @_;

   #... make method
   my $sub = sub { shift->$accessor()->$column() };
   WebTek::Util::make_method($class, $macro, $sub, @attrs);
}

# --------------------------------------------------------------------------
# serialize
# --------------------------------------------------------------------------

sub to_hash {
   my $self = shift;
   
   my $hash = {};
   foreach my $c (@{$self->columns}) {
      my $name = $c->{'name'};
      next if grep { $name eq $_ } @{$self->PROTECTED};
      my $content = $self->{'content'}->{$name};
      $hash->{$name} = encode_utf8(
         ref($content) =~ /^WebTek::Data/
            ? $content->to_db($self->db)
            : $content
      );
      _utf8_on($hash->{$name});
   }
   return $hash;
}

sub to_string {
   my $self = shift;
   
   return "$self: " . join(", ", map {
      "$_->{'name'}: " . $self->{'content'}->{$_->{'name'}};
   } @{$self->columns});
}

sub describe {
   my $class_or_self = shift;
   
   my $desc =
      "describe " . $class_or_self->TABLE_NAME . ":\n" .
      "primary-key: " . join(", ", @{$class_or_self->primary_keys}) . "\n";
   foreach my $column (@{$class_or_self->columns}) {
      $desc .= join(",", map { "$_: $column->{$_}" } keys %$column) . "\n";
   }
   return $desc;
}

1;

=head1 NOTES

=head2 Mandatory fields

A field which is marked as "not null" in the database is interpreted as
mandatory by WekTek. This means that firstly, the value must be "defined" (as
defined by the "defined" function) and secondly the value must not be empty.
This follows the semantics generally intended when setting a field to be not
null in a database. This also follows the implementation of Oracle, which
treats nulls and the empty strings both as nulls, but not MySQL.

=head2 Using different table names to class names

By default WebTek assumes that the class name is the same as the table name. If
the class is called MyApp::Model::Xyz then the table "xyz" in the database is
used.

This can be altered (for example to enable the class MyApp::Model::SalesPerson
to use the table "sales_person", i.e. with an extra underscore) by:

=over 4

=item 1.

Defining a TABLE_NAME function in your subclass such as:

   sub TABLE_NAME { "sales_person" }

=item 2.

Any classes which have a relationship to your class (e.g. if a class
MyApp::Model::Profile has a database field "sales_person_id" which should, in
the object model, reference a MyApp::Model::SalesPerson), then you need the
following in your subclass:

   __PACKAGE__->has_a('sales_person_id', 'MyApp::Model::SalesPerson');

=back

=head2 UNIQUE_CONSTRAINTS

If the underlying table has any unique constraints, if they are violated, you
want to let the user know of this. Unfortunately databases provide unhelpful
constraint violation messages such as:

   ERROR 1062 (23000): Duplicate entry 'abc' for key 2

In case of multiple constraints on the table, the only way to know which one
has been violated is the "key 2" part of the message. The front-end needs to
know which field should be highlighted with the error, so the
UNIQUE_CONSTRAINTS function should be defined in your model having a
relationship from the "key" in the error message to the column which should be
highlighted as having the error in the front-end. For example:

   sub UNIQUE_CONSTRAINTS { { 2 => 'name' } }

In the case that the above error is received, an error will be displayed on the
"name" field. If the model being defined is MyModel then the following key will
be searched for:

   Model.MyModel.name.alreadyexists
   
=head1 METHODS

=head2 update($hash)

Keys are field names; values are user-interface values e.g. "1,5" if the language
is German.
