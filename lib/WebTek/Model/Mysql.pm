package WebTek::Model::Mysql;

# max demmelbauer
# 14-02-06
#
# superclass of all mysql based models

use strict;
use base qw( WebTek::Model );

sub _columns {
   my $class = shift;
   return $class->SUPER::_columns unless @_;
   
   my $columns = shift;
   foreach my $column (@$columns) {
      my $type = $column->{type};
      my $name = $column->{name};
      
      #... find webtek_data_type
      if ($class->DATATYPES->{$name}) {
         $column->{webtek_data_type} = $class->DATATYPES->{$name}
      } elsif ($name =~ /^(is_|has_|show_)/i || $type =~ /bit/i) {
         $column->{webtek_data_type} = $class->DATA_TYPE_BOOLEAN;
      } elsif ($type =~ /bit|int|double|float|decimal/i) {
         $column->{webtek_data_type} = $class->DATA_TYPE_NUMBER;
      } elsif ($type =~ /blob/i) {
         $column->{webtek_data_type} = $class->DATA_TYPE_BLOB;
      } elsif ($type =~ /datetime|timestamp/i) {
         $column->{webtek_data_type} = $class->DATA_TYPE_DATE;
      } elsif ($type =~ /char|binary|text|enum|set/i) {
         $column->{webtek_data_type} = $class->DATA_TYPE_STRING;
      } else {
         $column->{webtek_data_type} = $class->DATA_TYPE_UNKNOWN;
      }
   }
   return $class->SUPER::_columns($columns);
}

sub _do_action {
   my ($self, $sql, @args) = @_;
   
   eval {
      $self->_db->do_action($sql, @args);
   } or do {
      die $@ unless $@ =~ /Duplicate entry .* for key (\d+)/;
      $self->_set_errors({ $1 => 'alreadyexists' });
      $self->is_valid("die");
   }
}

1;