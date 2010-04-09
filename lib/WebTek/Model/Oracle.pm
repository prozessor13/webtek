package WebTek::Model::Oracle;

# max demmelbauer
# 14-02-06
#
# superclass of all Oracle based models

use strict;
use base qw( WebTek::Model );

sub SEQUENCE { undef }

sub _quote { '"' }

sub _columns {
   my $class = shift;
   my $columns = shift; # arrayref with all column-info
   
   foreach my $column (@$columns) {
      my $type = $column->{'type'};
      my $name = $column->{'name'};
      
      #... find webtek-data-type
      if ($class->DATATYPES->{$name}) {
         $column->{'webtek-data-type'} = $class->DATATYPES->{$name}
      } elsif ($name =~ /^(is_|has_|show_)/i) {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_BOOLEAN;
      } elsif ($type =~ /number/i) {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_NUMBER;
      } elsif ($type =~ /blob/i) {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_BLOB;
      } elsif ($column->{'type'} =~ /date/i) {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_DATE;
      } elsif ($column->{'type'} =~ /clob|long|char/i) {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_STRING;
      } else {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_UNKNOWN;
      }   
   }
   $class->SUPER::_columns($columns);
}

sub _get_next_id {
   my $self = shift;
   
   if (my $seq = $self->SEQUENCE) {
      return DB->do_query('select $seq.nextval as id from dual ')->[0]->{'id'};
   }
}

1;