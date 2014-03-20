package WebTek::Data::GeoJSON;

# max demmelbauer
# 20-02-14

use strict;
use WebTek::Util qw( assert );
use WebTek::Exception;
use WebTek::Export qw( geojson );
use WebTek::Util::Json qw( encode_json decode_json_or_die );
use overload '""' => \&to_string;

sub geojson { __PACKAGE__->new(@_) }

sub new {
   my $class = shift;
   my $json = shift || '';
  
   #... check if $struct is already a struct
   return $json if ref $json eq $class;
  
   #... struct a perl ref
   return bless $json, $class if ref $json;

   #... create the object from a geojson string
   my $ref = eval { decode_json_or_die($json) };
   assert $ref, "$json is not a valid JSON string: ".(ref $@ ? $@->msg : $@);      
   return ref $ref ? bless $ref, $class : bless \$ref, $class;
}

sub TO_JSON { {%{$_[0]}} }

sub to_string {
   my ($self, $params) = @_;

   return encode_json({%$self}, $params->{'pretty'});
}

sub to_db {
   my ($self, $db) = @_; # $db isa WebTek::DB object

   return $self->geometry($db, $self) if $self->{coordinates};
   return $self->geometry($db, $self->{geometry}) if $self->{geometry};
   return undef;
}

sub geometry {
   my ($self, $db, $geo) = @_;

   if ($geo->{type} eq 'Point') {
      my ($lng, $lat) = @{$geo->{coordinates}};
      return $db->do_query(qq{
         select ST_GeomFromText('POINT($lng $lat)', 4326) as geom
      })->[0]{geom};
   } else {
      throw "Geometry $geo->{type} is not supported!";
   }
}

1;