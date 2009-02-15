use Text::Textile;
use WebTek::Export qw( textile );

sub textile :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ s-(\r\n|\r|\n)\@(.*?)\@(\r\n|\r|\n)(.)?-
      my ($code, $next) = ($2, $4);
      $next =~ /\*|\#/
         ? "\n<br /><code><pre>$code</pre></code><br />\n$next"
         : "\n<br /><code><pre>$code</pre></code>\n$next";
   -esg;
   return Text::Textile::textile($string);
}
