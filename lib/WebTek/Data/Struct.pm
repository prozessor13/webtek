package WebTek::Data::Struct;

# max demmelbauer
# 31-12-06

use strict;
use WebTek::Util qw( assert );
use WebTek::Exception;
use WebTek::Export qw( struct );
use WebTek::Util::Json qw( encode_json decode_json_or_die );
use Scalar::Util qw( reftype blessed );
use Encode qw( _utf8_on encode_utf8 );

sub struct { __PACKAGE__->new(@_) }

sub new {
   my $class = shift;
   my $struct = shift || {};     # perl obj ref or a json string (scalar)
   my $type = shift || 'json';   # json, perl
   $class = $class . "::" . uc($type);
  
   #... check if $struct is already a struct
   return $struct if ref $struct eq $class;
  
   #... struct a perl ref
   return bless $struct, $class if ref $struct;

   #... create the object from a string
   $class =~ s/JSON/PERL/ if $struct =~ /^\#perl\n/;
   my $ref = $class eq 'WebTek::Data::Struct::PERL'
      ? eval encode_utf8($struct)
      : eval { decode_json_or_die(encode_utf8($struct)) };
   assert $ref, "$struct is not a valid $type string: ".(ref $@ ? $@->msg : $@);      
   return ref $ref ? bless $ref, $class : bless \$ref, $class;
}

sub get {
   my ($self, $path) = @_;
   
   my $obj = $self;
   if (defined $path) {
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

sub to_json {
   my ($self, $params) = @_;

   my $string = encode_json($self->get($params->{'path'}), $params->{'pretty'});
   _utf8_on($string);
   return $string;
}

sub to_perl {
   my $string = dumper(shift->get);
   _utf8_on($string);
   return "#perl\nuse utf8;\n$string";
}

sub dumper {
   my $ref = shift;  
   $ref = $ref->DUMPER if blessed $ref && $ref->can('DUMPER');

   if (!defined $ref || reftype $ref eq 'CODE') {
      return 'undef';
   } elsif (reftype $ref eq 'ARRAY') {
      return '[' . join(',', map { dumper($_) } @$ref) . ']';
   } elsif (reftype $ref eq 'HASH') {
      return '{' . join(',', map {
         "'" . quote($_) . "'=>" . dumper($ref->{$_})
      } keys %$ref) . '}';
   } elsif ($ref =~ /^\-?\.?\d*\.?\d+$/) { # check simple number
      return 0+$ref;
   } else {
      return "'" . quote($ref) . "'";
   }
}

sub quote {
   my $string = shift;
   $string =~ s/\\/\\\\/g;
   $string =~ s/\'/\\\'/g;
   return $string;
}

sub to_string { &to_json }

package WebTek::Data::Struct::JSON;

use base qw( WebTek::Data::Struct );
use overload '""' => \&to_string;

sub TO_JSON { shift->get(@_) }

sub to_db { shift->to_json(@_) }

sub to_string { shift->to_json(@_) }

package WebTek::Data::Struct::PERL;

use base qw( WebTek::Data::Struct );
use overload '""' => \&to_string;

sub DUMPER { shift->get(@_) }

sub to_db { shift->to_perl(@_) }

sub to_string { shift->to_json(@_) }

1;