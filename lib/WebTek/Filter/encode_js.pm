use WebTek::Export qw( encode_js );
use WebTek::Data::Struct qw( struct );

sub encode_js :Filter {
   my ($handler, $js, $params) = @_;
   
   return struct(ref $js ? $js : \$js)->to_string($params);
}
