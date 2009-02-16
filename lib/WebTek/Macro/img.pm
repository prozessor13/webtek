sub img :Macro :Param(renders an image tag) {
   my ($self, %params) = @_;
   
   return img_tag(\%params);
}
