package WebTek::Model::Postgres;

# max demmelbauer
# 14-02-06
#
# superclass of all postgres based models

use strict;
use base qw( WebTek::Model );

sub _columns {
   my $class = shift;
   my $columns = shift; # arrayref with all column-info
   
   foreach my $column (@$columns) {
      my $type = $column->{type};
      my $name = $column->{name};
      
      #... find webtek_data_type
      if ($class->DATATYPES->{$name}) {
         $column->{webtek_data_type} = $class->DATATYPES->{$name}
      } elsif ($name =~ /^(is_|has_|show_)/ || $type =~ /boolean/i) {
         $column->{webtek_data_type} = $class->DATA_TYPE_BOOLEAN;
      } elsif ($type =~ /int|double|float|decimal|numeric|real|serial/i) {
         $column->{webtek_data_type} = $class->DATA_TYPE_NUMBER;
      } elsif ($type =~ /bytea/i) {
         $column->{webtek_data_type} = $class->DATA_TYPE_BLOB;
      } elsif ($type =~ /timestamp/i) {
         $column->{webtek_data_type} = $class->DATA_TYPE_DATE;
      } elsif ($type =~ /char|text/i) {
         $column->{webtek_data_type} = $class->DATA_TYPE_STRING;
      } else {
         $column->{webtek_data_type} = $class->DATA_TYPE_UNKNOWN;
      }
   
      #... find default-value
      $column->{default} = $1 if $column->{default} =~ /'(.*)'::\w/;
   }
   $class->SUPER::_columns($columns);
}

1;