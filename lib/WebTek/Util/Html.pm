package WebTek::Util::Html;

# max demmelbauer
# 21-03-06
#
# some utilities for html manipulation

use strict;
use WebTek::Export
   qw( a_tag img_tag select_tag textarea_tag input_tag form_tag );

sub a_tag {
   my $args = shift;    # hashref
   my $display = $args->{'display'};
   delete $args->{'display'};
   
   return '<a ' . _map_args($args) . ">$display</a>";
}

sub img_tag { '<img ' . &_map_args . ' />' }

sub input_tag { '<input ' . &_map_args . ' />' }

sub form_tag { '<form ' . &_map_args . '>' }

sub textarea_tag {
   my $args = shift;    # hashref
   my $value = $args->{'value'};
   delete $args->{'value'};
   
   return '<textarea ' . _map_args($args) . ">$value</textarea>";
}

sub select_tag {
   my $args = shift;    # hashref
   my $options = $args->{'options'};
   my $selected = $args->{'selected'};
   delete $args->{'options'};
   delete $args->{'selected'};

   my $html = '<select ' . _map_args($args) . ">\n";
   my $sel = 0;
   foreach my $option (@$options) {
      my $value = (ref($option) eq 'HASH') ? $option->{'value'} : $option;
      my $display = (ref($option) eq 'HASH') ? $option->{'display'} : $option;
      my $is_selected = ($value eq $selected and not $sel)
         ? ' selected="selected"'
         : '';
      $sel = 1 if $is_selected;
      $html .= "\t<option value=\"$value\"$is_selected>$display</option>\n";
   }
   $html .= '</select>';
   return $html;
}


sub _map_args {
   my $args = shift;    # hashref

   #... may delete the disabled property if it is false
   delete $args->{'disabled'} unless $args->{'disabled'};

   return join " ", map { $_ . '="' . $args->{$_} . '"'} keys %$args;
}

1;