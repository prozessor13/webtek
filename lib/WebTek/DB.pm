package WebTek::DB;

# max demmelbauer
# 14-02-06
#
# database access object
# this class is inspired by adrian smith

use DBI;
use strict;
use WebTek::App qw( app );
use WebTek::Logger qw( ALL );
use WebTek::Event qw( event );
use WebTek::Exception;
use Encode qw( _utf8_on decode );
use WebTek::Timing qw( ALL );
use WebTek::Export qw( DB );
require WebTek::Config;

our %DB = ();

sub _init {
   event->register(
      'name' => 'request-end',
      'method' => 'commit_all',
      'priority' => 10,
   );
   event->register(
      'name' => 'request-had-errors',
      'method' => 'rollback_all',
      'priority' => 10,
   );
}

# ----------------------------------------------------------------------------
# constants
# ----------------------------------------------------------------------------

sub PING_INTERVAL { 1 } # check the db-connection every x seconds
sub DB_VENDOR_MYSQL { 'mysql' }
sub DB_VENDOR_POSTGRES { 'postgres' }
sub DB_VENDOR_ORACLE { 'oracle' }
sub DB_VENDOR_UNKNOWN { 'unknown' }

# ----------------------------------------------------------------------------
# create and get the database object
# ----------------------------------------------------------------------------

sub DB {
   my $config = $_[0] || 'db';
   $DB{app->name}->{$config} ||= WebTek::DB->new($config);
}

sub new {
   my ($class, $config) = @_;
   return bless { 'config' => $config }, $class;
}

sub DESTROY {
   if ($DB{app->name}) {
      foreach my $db (values %{$DB{app->name}}) {
         if ($db->{'dbh'}) { $db->{'dbh'}->disconnect }
      }
   }
   delete($DB{app->name});
}

# ----------------------------------------------------------------------------
# get config for the db object
# ----------------------------------------------------------------------------

sub config { WebTek::Config::config($_[0]->{'config'}) }

# ----------------------------------------------------------------------------
# DBI wrapper methods
# ----------------------------------------------------------------------------

sub connect {
   my $self = shift;

   my $dbh = DBI->connect_cached(
      $self->config->{'connect'},
      $self->config->{'username'},
      $self->config->{'password'}
   ) or throw "DB: cannot connect to database: " . $DBI::errstr;
   return $dbh;
}

sub ping {
   my $self = shift;
   
   return 0 unless $self->{'dbh'};
   return 1 if ($self->{'last-ping-time'} + PING_INTERVAL) > time;
   $self->{'last-ping-time'} = time;
   return $self->{'dbh'}->ping;
}

sub dbh {
   my $self = shift;
   
   #... check existing connection
   return $self->{'dbh'} if $self->ping;
   #... create new connection
   $self->{'dbh'} = $self->connect;
   $self->{'dbh'}->{'FetchHashKeyName'} = 'NAME_lc';
   $self->{'dbh'}->{'AutoCommit'} = 0;
   if (my $long_read_len = $self->config->{'long-read-length'}) {
      $self->{'dbh'}->{'LongReadLen'} = $long_read_len;      
   }
   return $self->{'dbh'};
}

sub vendor {
   my $self = shift;
   
   my $vendor = lc($self->dbh->get_info(17));
   if ($vendor eq 'mysql') { return DB_VENDOR_MYSQL }
   elsif ($vendor =~ /^pg|postgres|postgresql$/) { return DB_VENDOR_POSTGRES }
   elsif ($vendor eq 'oracle') { return DB_VENDOR_ORACLE }
   else { return DB_VENDOR_UNKNOWN }
}

sub do_prepare {
   my ($self, $sql) = @_;
   
   my $sth = $self->config->{'cache-prepare'}
      ? $self->dbh->prepare_cached($sql)
      : $self->dbh->prepare($sql);
   return $sth or log_fatal "error in prepare $sql";
}

sub do_action {
   my ($self, $sql, @args) = @_;
   
   if (config->{'log-sql'}) {
      log_info("[SQL] $sql with args ('" . join("', '",@args) . "')");
   }
   my $dbh = $self->dbh;
   my $sth = $dbh->prepare($sql)
      or log_fatal "error '".$dbh->errstr."' in $sql: @args";
   $sth->execute(@args)
      or log_fatal "error '".$dbh->errstr."' in $sql: @args";
   return $sth;
}

sub do_query {
   my ($self, $sql, @args) = @_;
   
   timer_start('do_query') if config->{'log-sql'};
   my $sth = $self->do_action($sql, @args);
   my $result = $sth->fetchall_arrayref({});
   my $charset = $self->config->{'charset'};
   my $is_utf8 = $charset =~ /utf-?8/i;
   if ($sth->err) { log_fatal "error in $sql: @args" }
   foreach my $row (@$result) {
      foreach my $key (keys %$row) {
         if ($is_utf8) { _utf8_on($row->{$key}) }
         else { $row->{$key} = decode($charset, $row->{$key}) }
      }
   }
   timer_end('do_query') if config->{'log-sql'};
   return $result;
}

sub commit { shift->dbh->commit }

sub commit_all { $_->commit foreach values %{$DB{app->name}} };

sub rollback { shift->dbh->rollback }

sub rollback_all { $_->rollback foreach values %{$DB{app->name}} };

# ---------------------------------------------------------------------------
# table description methods
# ---------------------------------------------------------------------------

sub catalog { undef }

sub schema {
   my $self = shift;
   
   if ($self->vendor eq DB_VENDOR_ORACLE) {
      return uc($self->config->{'username'});
   } elsif ($self->vendor eq DB_VENDOR_POSTGRES) {
      return 'public';
   } else {
      return undef;
   }
}

sub primary_keys {
   my ($self, $t) = @_; # $t ... table name
   $t = uc($t) if $self->vendor eq DB_VENDOR_ORACLE;
   
   my @keys = ($self->vendor eq DB_VENDOR_MYSQL)
      ? map{$_->{'name'}}grep{$_->{'mysql_is_pri_key'}}@{$self->column_info($t)}
      : $self->dbh->primary_key($self->catalog, $self->schema, $t);
   return \@keys;
}

sub column_info {
   my ($self, $table) = @_;
   $table = uc($table) if $self->vendor eq DB_VENDOR_ORACLE;

   #... postgres outputs the names somtimes in qotes (why?)
   sub _clean { my $name = shift; $name =~s /\W//g; return $name }

   #... fetch column info from db
   my $sth = $self->dbh->column_info(
      $self->catalog, $self->schema, $table, '%'
   ) or throw $self->dbh->errstr;
   my $rows = $sth->fetchall_arrayref({});
   if ($sth->err) { throw $sth->err }
   
   #... create column info for a model
   my @columns = ();
   foreach my $row (@$rows) {
      my $table_name = _clean($row->{'TABLE_NAME'} || $row->{'table_name'});
      next unless ($table_name eq $table);
      push @columns, {
         'pos' => (exists $row->{'ORDINAL_POSITION'}
            ? $row->{'ORDINAL_POSITION'}
            : $row->{'ordinal_position'}),
         'name' => _clean(lc(exists $row->{'COLUMN_NAME'}
            ? $row->{'COLUMN_NAME'}
            : $row->{'column_name'})),
         'type' => lc(exists $row->{'TYPE_NAME'}
            ? $row->{'TYPE_NAME'}
            : $row->{'type_name'}),
         'length' => (exists $row->{'COLUMN_SIZE'}
            ? $row->{'COLUMN_SIZE'}
            : $row->{'column_size'}),
         'nullable' => (exists $row->{'NULLABLE'}
            ? $row->{'NULLABLE'}
            : $row->{'nullable'}),
         'default' => (exists $row->{'COLUMN_DEF'}
            ? $row->{'COLUMN_DEF'}
            : $row->{'column_def'}),
         'mysql_is_pri_key' => $row->{'mysql_is_pri_key'},
      };
   }
   @columns = sort { $a->{'pos'} <=> $b->{'pos'} } @columns;
   return \@columns;
}

sub last_insert_id {
   my ($self, $table, $column) = @_;
   
   my $id = $self->dbh->last_insert_id(
      $self->catalog, $self->schema, $table, $column
   );
   if ( ! defined($id)) {
      # This is necessary on Emerion Web Hosting.
      # I have no idea why.
      $id = $self->dbh->{'mysql_insertid'};
   }
   return $id;
}

=head1 EXCEPTIONS

C<WebTek::DB::UniqueConstraintViolatedException>

This exception has a single attribute 'constraint-name' which is
the name of the unique constraint which was violated.
For MySQL this is a number like "1" or "2".

=cut

package WebTek::DB::UniqueConstraintViolatedException;

use WebTek::Util qw( make_accessor );

our @ISA = qw( WebTek::Exception );

make_accessor('constraint_name');

sub create {
   my $class_or_self = shift;
   my $msg = shift;
   my $constraint_name = shift;

   my $self = $class_or_self->SUPER::create($msg);
   $self->{'constraint_name'} = $constraint_name;
   
   return $self;
}

1;
