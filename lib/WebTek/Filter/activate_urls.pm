package WebTek::Filter;

use strict;

sub activate_urls :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ # convert urls to links
      s-((ftp:|http:|https:|www\.)[^\s\|]+)(\|\S+)?-
         my $href = $1;
         my $display = $3 ? substr($3, 1) : $href;
         if ($href =~ /^www./) { $href = "http://$href"; }
         a_tag({'href' => $href, 'display' => $display, 'target' => '_blank'});
      -eg;
   $string =~ # convert email-adresses to links
      s-(\w[^\s,;:&]*\@[^\s,;:&]*\w)-
         a_tag({'href' => "mailto:$1", 'display' => $1 });
      -eg;
 
   return $string;
}

1;