package WebTek::Data::Struct;

# max demmelbauer
# 31-12-06

use strict;
use WebTek::Util qw( assert );
use WebTek::Exception;
use WebTek::Export qw( struct );
use WebTek::Util::Json qw( encode_json decode_json_or_die );
use Scalar::Util qw( reftype blessed );
use overload '""' => \&to_string;
use Encode qw( _utf8_on encode_utf8 );

sub struct { __PACKAGE__->new($_[0]) }

sub new {
   my $class = shift;
   my $struct = shift || {}; # perl obj (hash, array) or a json string (scalar)
  
   #... check if $struct is already a struct
   return $struct if ref $struct eq __PACKAGE__;
  
   #... struct is already an object
   if (ref $struct) { return bless $struct, $class }

   #... create the object from a JSON string
   my $ref = eval { decode_json_or_die(encode_utf8($struct)) };
   assert $ref, "$struct is not a valid JSON string: ".(ref $@ ? $@->msg : $@);
   return ref $ref ? bless $ref, $class : bless \$ref, $class;
}

sub get {
   my ($self, $path) = @_;
   
   my $obj = $self;
   if ($path) {
      foreach my $element (split /\.|___/, $path) {
         if (reftype($obj) eq 'ARRAY') { $obj = $obj->[$element] }
         elsif (reftype($obj) eq 'HASH') { $obj = $obj->{$element} }
         else { throw "there is no element '$element' at obj '$obj'" }
      }
   }
   return $obj unless ref $obj and blessed $obj;
   return [@$obj] if reftype($obj) eq 'ARRAY';
   return {%$obj} if reftype($obj) eq 'HASH';
   return $$obj if reftype($obj) eq 'SCALAR';
   throw "cannot deserialize blessed reference '$obj'";
}

sub to_string {
   my ($self, $params) = @_;

   my $string = encode_json($self->get($params->{'path'}), $params->{'pretty'});
   _utf8_on($string);
   return $string;
}

sub to_json { &to_string }

sub to_db { &to_string }

sub TO_JSON { &get }

1;