package WebTek::Page;

use strict;
use WebTek::Filter qw( format_number encode_qq encode_html );

sub form_field :Macro {
   my ($self, %params) = @_;
   
   assert $params{name}, 'no form field name defined';
   assert $params{type}, 'no form field type defined';
   my ($name, $elm_name) = ($params{name}, $params{name});
   my $type = $params{type};

   #... is the field for a handler
   my $h = $params{handler} || $params{model};
   my $handler = eval { $self->handler($h) };
   
   #... if yes, update the form field name with handler-information
   $params{name} = $elm_name = "$h\___$name" if $h;
   delete $params{handler};
   delete $params{model};

   #... check for an error
   my $error = $handler ? $handler->error_on($name) : $self->error_on($name);
   if ($error and my $errors = $self->{__form_errors}) {
      push @$errors, $name
         if $type ne 'radio' or not grep { $name eq $_ } @$errors
   }

   #... handle a radio button (is it checked?)
   if ($type eq 'radio' and defined $params{value}) {
      $params{checked} = 'checked'
         if $params{value} eq request->param->$elm_name
            or $handler and $handler->can($name)
            and $params{value} eq $handler->$name();
   }

   #... find value
   unless (exists $params{value}) {
      #... for submit buttons the value = name
      if ($type eq 'submit') {
         $params{value} = $name;
      #... prefill with request value
      } elsif (defined request->param->$elm_name) {
         my @req_params = request->param->$elm_name;
         if (@req_params == 1) {
            $params{value} = $req_params[0];
         } else {
            my $i = $self->{'__default_value_for_' . $elm_name} || 0;
            $params{value} = $req_params[$i];
            $self->{'__default_value_for_' . $elm_name} = $i + 1;
         }
      #... prefill with handler value   
      } elsif ($handler) {
         my $sub = $name;
         if ($name =~ /(\w+)___(.+)$/) {  # check if name is a struct key
            $sub = $1;
            $params{path} = $2;           # path of WebTek::Data::Struct
         }
         my $val = $handler->can($sub) ? $handler->$sub() : undef;
         $val = $val->to_string(\%params) if ref $val;
         $params{value} = length($val) ? $val : $params{default_value};
         delete $params{path};
      #... set empty
      } else {
         $params{value} = $params{default_value};
      }
   }
   delete $params{default_value};
   if ($params{format_number}) {
      my $f = { format => $params{format_number} };
      $params{value} = $self->format_number($params{value}, $f);
   }
   $params{value} = $self->encode_html($params{value});
   if (not length($params{value}) or $type eq 'password') {
      delete $params{value};
   } elsif ($type ne 'textarea') {
      $params{value} = $self->encode_qq($params{value});
   };

   #... on error update css class with error-class
   if ($error) {
      $params{class} = $params{class}
         ? "$params{class} " . $self->FORM_ERROR_CLASS
         : $self->FORM_ERROR_CLASS;
   }

   #... render form field
   my $html = '';
   #... handle checkbox
   if ($type eq 'checkbox') {
      $html .= input_tag({
         type => 'hidden',
         name => $elm_name,
         value => ($params{value} ? '1' : '0'),
      });
      $params{onclick} =
         "this.form.$elm_name.value=this.checked?'1':'0';$params{'onclick'}";
      $params{checked} ||= 'checked' if $params{value};
      delete $params{name};
      $html .= input_tag(\%params);
   #... handle textarea
   } elsif ($type eq 'textarea') {
      delete $params{type};
      $html .= textarea_tag(\%params);
   #... handle select boxes
   } elsif ($type eq 'select') {
      $params{selected} = $params{value} || $params{selected};
      delete $params{value};
      delete $params{type};
      $html .= select_tag(\%params);
   #... handle all other
   } else {
      $html .= input_tag(\%params);
   }

   return $html;
}

1;