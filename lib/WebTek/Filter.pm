package WebTek::Filter;

# max demmelbauer
# 04-04-07
#
#  macro filters

use strict;
use WebTek::Html qw( ALL );
use WebTek::Attributes qw( MODIFY_CODE_ATTRIBUTES );
use WebTek::Data::Struct qw( struct );
use WebTek::Util qw( assert );
use Encode qw( encode );
use Date::Parse qw( str2time );
use Date::Format qw( time2str );
use Date::Language;
use POSIX qw(locale_h);
use WebTek::Export qw(
   boolean format_date format_number truncate encode_param encode_js
   encode_xml encode_html encode_q encode_qq newline_to_br space_to_nbsp
   activate_urls trim charset lowercase uppercase uppercase_first textile
   encode_url decode_url format_time compose_uri parse_number
   insert_spaces_into_long_words count
);

sub DateLanguageForCode { {
   'de' => 'German',
   'en' => 'English',
} }

# --------------------------------------------------------------------------
# filter methods
# --------------------------------------------------------------------------

sub compose_uri :Filter {
   my ($handler, $uri, $params) = @_;
   return $uri unless $params and keys %$params;

   #... encode params
   my $encoded = {};
   sub _encode {
      my $string = shift;
      $string =~ s/([^\w-\.\!\~\*\'\(\)])/'%'.sprintf("%02x", ord($1))/eg;
      return $string;
   }

   return "$uri?" . join('&', map {
      my ($key, $value) = ($_, $params->{$_});
      ref $value eq 'ARRAY'
         ? map($key . "=" . _encode($_), @$value)
         : $key . "=" . _encode($value)
   } keys %$params);
}

sub encode_url :Filter {
   my ($handler, $string, $params) = @_;
   use bytes;

   $string =~ s/\ /\+/g;   # convert spaces to +
   $string =~ s/([^a-zA-Z0-9\+\_\-\/\:\.])/'%'.sprintf("%02x", ord($1))/eg;
   return $string;
}

sub decode_url :Filter {
   my ($handler, $string, $params) = @_;   
   
   $string =~ s/\+/\ /g;
   $string =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
   return $string;
}

sub boolean :Filter {
   my ($handler, $value, $params) = @_;
   
   my $yes = defined $params->{'yes'} ? $params->{'yes'} : 'yes';
   my $no = defined $params->{'no'} ? $params->{'no'} : 'no';
   return $value ? $yes : $no; 
}

sub format_date :Filter {
   my ($handler, $date, $params) = @_;

   $date = WebTek::Data::Date::date($date) unless ref $date;
   return "[invalid date format]" unless $date->is_valid;
   my $format = $params && $params->{'format'} || "%d.%m.%Y %H:%M";
   my $timezone = $params && $params->{'timezone'} || $date->timezone;
   my $l = DateLanguageForCode->{
      $params->{'language'}
      || eval { $handler->session->langauge }
      || eval { $handler->request->language }
   };
   return $l
      ? Date::Language->new($l)->time2str($format, $date->to_time, $timezone)
      : time2str($format, $date->to_time, $timezone);
}

sub format_time :Filter {
   my ($handler, $time, $params) = @_;

   my $format = $params && $params->{'format'} || "%H:%M:%S";
   my $date = WebTek::Data::Date::date("2000-01-01 00:00:00 GMT")->to_time;
   return time2str($format, $time + $date, "GMT");
}

sub format_number :Filter {
   my ($handler, $number, $params) = @_;

   return $number unless $params;

   #... make kilo, mega, or whatever
   if (my $type = $params->{'type'}) {
      if ($type eq 'kilo') { $number /= 1_000; }
      elsif ($type eq 'mega') { $number /= 1_000_000; }
      elsif ($type eq 'giga') { $number /= 1_000_000_000; }
      elsif ($type eq 'kilobytes') { $number /= 1_024; }
      elsif ($type eq 'megabytes') { $number /= 1_048_576; }
      elsif ($type eq 'gigabytes') { $number /= 1_073_741_824; }
   }
   
   #... format number (make an sprintf)
   $number = sprintf($params->{'format'}, $number) if $params->{'format'};
   
   #... make thousand separators
   if ($params->{'thousands_sep'}) {
      $number = reverse $number;
      $number =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1\,/g;
      $number = scalar reverse $number; 
   }

   #... localize
   my $c = WebTek::Config::config('numbers');
   my $language = $params->{'language'} || eval { $handler->request->language };
   my $country = uc($params->{'country'} || eval { $handler->request->country });
   my $locale = $country ? "$language\_$country" : $language;
   if (my $config = $c->{"$language\_$country"} || $c->{$language}) {
      $number =~ s/\,/__T__/g;
      $number =~ s/\./__D__/g;
      $number =~ s/__T__/$config->{'thousands_sep'}/g;
      $number =~ s/__D__/$config->{'decimal_point'}/g;
   }
   
   return $number;
}

sub parse_number :Filter {
   my ($handler, $number, $params) = @_;
   
   #... localize
   my $c = WebTek::Config::config('numbers');
   my $language = $params->{'language'} || eval { $handler->request->language };
   my $country = uc($params->{'country'} || eval { $handler->request->country });
   my $locale = $country ? "$language\_$country" : $language;
   if (my $config = $c->{"$language\_$country"} || $c->{$language}) {
      my $thousands_sep = $config->{'thousands_sep'};
      $thousands_sep = '\.' if $thousands_sep eq '.';
      my $decimal_point = $config->{'decimal_point'};
      $decimal_point = '\.' if $decimal_point eq '.';
      $number =~ s/$thousands_sep//g;
      $number =~ s/$decimal_point/\./g;
   }
   
   return 0+$number;
}

sub truncate :Filter {
   my ($handler, $string, $params) = @_;

   assert $params->{'limit'}, "'limit' parameter mandatory";
   
   if (length($string) > $params->{'limit'}) {
      my $suffix = defined $params->{'suffix'} ? $params->{'suffix'} : '...';
      my $offset = $params->{'limit'} - length($suffix);
      substr($string, $offset) = $suffix;
   }
   return $string;
}

sub insert_spaces_into_long_words :Filter :Public
   :Param("sometimes you don't want '...' but still want text to ")
   :Param("  format nicely in a not-too-wide block")
   :Param("length='12' maximum length of a word before")
{
   my ($handler, $string, $params) = @_;

   my $l = $params->{'length'};
   assert $l >= 1, "'length' parameter missing or invalid";

   while ($string =~ s/(\w{$l})(\w)/$1 $2/) { }

   return $string;
}

sub encode_param :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ s/\"/\\\"/g;
   $string =~ s/\|/\\\|/g;
   
   return $string;
}

sub encode_js :Filter {
   my ($handler, $js, $params) = @_;
   
   return struct(ref $js ? $js : \$js)->to_string($params);
}

sub lowercase :Filter {
   my ($handler, $string, $params) = @_;
   
   return lc($string);
}

sub uppercase :Filter {
   my ($handler, $string, $params) = @_;
   
   return uc($string);
}

sub uppercase_first :Filter {
   my ($handler, $string, $params) = @_;
   
   return ucfirst($string);
}

sub encode_xml :Filter { &encode_html }

sub encode_html :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ s/&/&amp;/g;
   $string =~ s/"/&quot;/g;
   $string =~ s/'/&apos;/g;
   $string =~ s/</&lt;/g;
   $string =~ s/>/&gt;/g;
   
   return $string;
}

sub activate_urls :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ # convert urls to links
      s-((ftp:|http:|https:|www\.)[^\s\|]+)(\|\S+)?-
         my $href = $1;
         my $display = $3 ? substr($3, 1) : $href;
         if ($href =~ /^www./) { $href = "http://$href"; }
         a_tag({
            %$params,
            'href' => $href,
            'display' => $display,
            'target' => '_blank'
         });
      -eg;
   $string =~ # convert email-adresses to links
      s-(\w[^\s,;:&]*\@[^\s,;:&]*\w)-
         a_tag({%$params, 'href' => "mailto:$1", 'display' => $1 });
      -eg;
 
   return $string;
}

sub encode_q :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ s/\'/\\\'/g;
   return $string;
}

sub encode_qq :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ s/\"/\\\"/g;
   return $string;
}

sub newline_to_br :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ s/\n/\<br\>/g;
   return $string;
}

sub space_to_nbsp :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ s/( +)/"&nbsp;" x length($1)/eg;
   return $string;   
}

sub trim :Filter {
   my ($handler, $string, $param) = @_;
   
   $string =~ s/\A\s+//;
   $string =~ s/\s+\z//;
   return $string;
}

sub charset :Filter {
   my ($handler, $string, $params) = @_;

   my $charset = $params->{'charset'};
   return ($charset and $charset !~ /^utf-?8/i)
      ? encode($charset, $string)
      : $string;
}

sub textile :Filter {
   my ($handler, $string, $params) = @_;
   
   $string =~ s-(\r\n|\r|\n)\@(.*?)\@(\r\n|\r|\n)(.)?-
      my ($code, $next) = ($2, $4);
      $next =~ /\*|\#/
         ? "\n<br /><code><pre>$code</pre></code><br />\n$next"
         : "\n<br /><code><pre>$code</pre></code>\n$next";
   -esg;
   #... do textile on string
   WebTek::Loader->load("Text::Textile");
   return Text::Textile::textile($string);
}

sub count :Filter
   :Param(take a list, and convert it to a number - the list's size)
   :Param(to enable <% customer.profiles | count %>)
{
   my ($handler, $input, $params) = @_;
   return scalar(@$input);
}

1;
