package WebTek::Model::Mysql;

# max demmelbauer
# 14-02-06
#
# superclass of all mysql based models

use strict;
use base qw( WebTek::Model );

sub _quote { '`' }

sub _columns {
   my $class = shift;
   my $columns = shift; # arrayref with all column-info
   
   foreach my $column (@$columns) {
      my $type = $column->{'type'};
      my $name = $column->{'name'};
      
      #... find webtek-data-type
      if ($class->DATATYPES->{$name}) {
         $column->{'webtek-data-type'} = $class->DATATYPES->{$name}
      } elsif ($name =~ /^(is_|has_|show_)/i || $type =~ /bit/i) {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_BOOLEAN;
      } elsif ($type =~ /bit|int|double|float|decimal/i) {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_NUMBER;
      } elsif ($type =~ /blob/i) {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_BLOB;
      } elsif ($column->{'type'} =~ /datetime|timestamp/i) {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_DATE;
      } elsif ($column->{'type'} =~ /char|binary|text|enum|set/i) {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_STRING;
      } else {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_UNKNOWN;
      }   
   }
   $class->SUPER::_columns($columns);
}

sub _do_do_action {
   my ($self, $sql, @args) = @_;
   
   unless (defined(eval {
      $self->SUPER::_do_do_action($sql, @args);
      1;
   })) {
      my $err = $@;
      if ($err =~ /Duplicate entry .* for key (\d+)/) {
         die(WebTek::DB::UniqueConstraintViolatedException->create($err, $1));
      }
      die($err);
   }
}

1;