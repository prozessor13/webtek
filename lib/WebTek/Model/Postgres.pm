package WebTek::Model::Postgres;

# max demmelbauer
# 14-02-06
#
# superclass of all postgres based models

use strict;
use base qw( WebTek::Model );

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
      } elsif ($name =~ /^(is_|has_|show_)/ || $type =~ /boolean/i) {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_BOOLEAN;
      } elsif ($type =~ /int|double|float|decimal|numeric|real|serial/i) {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_NUMBER;
      } elsif ($type =~ /bytea/i) {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_BLOB;
      } elsif ($column->{'type'} =~ /timestamp/i) {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_DATE;
      } elsif ($column->{'type'} =~ /char|text/i) {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_STRING;
      } elsif ($column->{'type'} =~ /geometry/i) {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_GEOJSON;
      } else {
         $column->{'webtek-data-type'} = $class->DATA_TYPE_UNKNOWN;
      }

      #... define fetch-string
      if ($column->{'webtek-data-type'} eq $class->DATA_TYPE_GEOJSON) {
         $column->{'fetch'} = "ST_ASGeoJSON($name) as $name";         
      }
   
      #... find default-value
      $column->{'default'} = $column->{'default'} =~ /'(.*)'::\w/
         ? $1
         : $column->{'default'};
   }
   $class->SUPER::_columns($columns);
}

1;