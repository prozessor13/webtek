package WebTek::Compiler;

# max demmelbauer 
# 12-03-08
#
# compiles webtek-templates into perlcode with the following rules
#
# Terminale:
# ==========
# CHAR           -> .
# EQUAL          -> =
# UNEVAL         -> ~
# DOT            -> \.
# PIPE           -> \|
# ESCAPE         -> \\
# QUOTE_START    -> " | ' | q\{ | q\[ | q\(
# QUOTE_END      -> " | ' | \} | \] | \)
# SPACE          -> \s+
# NAME           -> \w+
# MACRO_START    -> <%
# MACRO_END      -> %>
#
# NonTerminale:
# =============
# Template       -> ( Macro | CHAR )*
# Macro          -> MACRO_START
#                   SPACE
#                   NAME ( DOT NAME )*
#                   ( Param )*
#                   ( PIPE SPACE NAME ( Param )* )*
#                   SPACE
#                   MACRO_END
# Param          -> NAME EQUAL QUOTE_START Template QUOTE_END
#                   |
#                   NAME UNEVAL QUOTE_START ( CHAR )* QUOTE_END

use strict;
use WebTek::Util qw( assert );

my $String;
my $LineNo;
my $CharNo;
my $Handler;
my @QuoteEnd;

# --------------------------------------------------------------------------
# terminal symbols
# --------------------------------------------------------------------------

sub CHAR { '.' }
sub EQUAL { '=' }
sub UNEVAL { '~' }
sub SPACE { '\s+' }
sub NAME { '\w+' }
sub MACRO_START { '<%' }
sub MACRO_END { '%>' }
sub DOT { '\.' }
sub PIPE { '\|' }
sub ESCAPE { '\\' }
sub QUOTES { {
   '"' => '"',
   "'" => "'",
   "q{" => '\}',
   "q[" => '\]',
   "q(" => '\)',
} }
sub QUOTE_START { '(\'|"|q\{|q\[|q\()' }
sub QUOTE_END { $QuoteEnd[$#QuoteEnd] }

# --------------------------------------------------------------------------
# public methods
# --------------------------------------------------------------------------

sub compile {
   my $class = shift;
   $Handler = shift;
   my $string = shift;

   my $code = to_perl($class->parse($string));
   # WebTek::Logger::log_info("sub { my (\$handler, \$params) = \@_; return $code }");
   my $compiled = eval "sub { my (\$handler, \$params) = \@_; return $code }";
   assert $compiled, "cannot compile code: $code, details: $@";
   return $compiled;
}

sub parse {
   my $class = shift;
   $String = shift;
   $LineNo = 1;
   $CharNo = 0;
   @QuoteEnd = ();

   return template();
}

# --------------------------------------------------------------------------
# utils
# --------------------------------------------------------------------------

sub syntax_error {
   my $msg = $_[0] && ": $_[0]";
   die "syntax_error at line $LineNo, char $CharNo$msg\n";
}

sub macro_error {
   my $msg = $_[0] && ": $_[0]";
   die "macro_error $msg\n";
}

sub quote_start { # finds the coresponding quote end-tag
   my $left = shift;
   
   push @QuoteEnd, QUOTES->{$left};
}

sub quote_end { pop @QuoteEnd }

sub compact { # compact ['a','b','c',{},] to ['abc',{}]
   my $array = shift;
   
   my $compact = undef;
   my @compact = ();
   foreach my $item (@$array) {
      if (ref $item) {
         push @compact, $compact if defined $compact;
         push @compact, $item;
         $compact = undef;
      } else {
         $compact .= $item;
      }
   }
   push @compact, $compact if defined $compact;
   return \@compact;
}

sub to_perl {  # converts an array (from the template method) to perlcode
   my $array = shift;
   
   my @code;
   foreach my $item (@$array) {
      if (ref $item) {
      
         if ($item->{'type'} eq 'macro') {
            my ($name, %params, @filters);

            #... process params
            foreach my $key (keys %{$item->{'params'}}) {
               $params{$key} = to_perl($item->{'params'}->{$key});
            }

            #... extract params: if,unless,prefix,suffix,failmode,default
            my ($if, $unless, $prefix, $suffix, $failmode, $default) =
               delete @params{qw( if unless prefix suffix failmode default )};
            my $silent = ($failmode eq '"silent"');
                        
            #... process name
            my ($macro, @handlers) = reverse split /\./, $item->{'name'};
            if ($handlers[-1] eq 'param') {
               shift @handlers;
               my $get = join ".", (reverse(@handlers), $macro);
               #$macro = "\$params->get('$get')";
               $macro = "\$params->{'$macro'}";
            } else {
               my $h = join "", map "->_handler('$_')", reverse @handlers;
               my $p = join ",", map "'$_'=>$params{$_}", keys %params;
               $macro = "\$handler$h->_macro('$macro', {$p})";
            }

            #... process filters
            foreach my $filter (@{$item->{'filters'}}) {
               my ($f, @handlers) = reverse split /\./, $filter->{'name'};
               my $h = join "", map "->_handler('$_')", reverse @handlers;
               my %p;
               foreach my $key (keys %{$filter->{'params'}}) {
                  $p{$key} = to_perl($filter->{'params'}->{$key});
               }
               my $p = join ",", map "'$_'=>$p{$_}", keys %p;
               $macro = "\$handler$h->_filter('$f', $macro, {$p})";
            }
            
            #... composite special params
            my $util = "WebTek::Compiler::Util";
            $macro = "$util\::default($macro, $default)" if defined $default;
            if ($prefix or $suffix) {
               $prefix ||= "''";
               $suffix ||= "''";
               $macro = "$util\::prefix_suffix($macro, $prefix, $suffix)";
            }
            $macro = "( $if ? $macro : undef )" if defined $if;
            $macro = "( $unless ? undef : $macro )" if defined $unless;
            $macro = "( eval { $macro } )" if $silent;

            push @code, $macro;
         }
      
      } else {
         
         $item =~ s/\\/\\\\/g;
         $item =~ s/"/\\"/g;
         $item =~ s/\n/\\n/g;
         $item =~ s/\r/\\r/g;
         $item =~ s/\t/\\t/g;
         $item =~ s/\$/\\\$/g;
         $item =~ s/\@/\\\@/g;
         push @code, "\"$item\"";
      
      }
   }
   
   return @code ? join(" . ", @code) : "''";
}

# --------------------------------------------------------------------------
# scanner
# --------------------------------------------------------------------------

sub lookahead { $String =~ /^$_[0]/s ? 1 : undef }

sub match {
   #... check for a syntax error
   unless (&lookahead) {
      my $string = substr $String, 0, index $String, "\n";
      syntax_error("expected $_[0] but found '$string'");
   }
   #... do the match
   $String =~ s/^($_[0])//s;
   my $match = $1;
   #... update line-number
   my $start = 0;
   while ($start = index($match, "\n", $start) + 1) {
      $LineNo++;
      $CharNo = 0;
   }
   #... update char-number
   my $length = length $match;
   my $newline = rindex $match, "\n";
   $CharNo += $newline ne -1 ? $length - $newline : $length;
   #... return match
   return $match;
}

# --------------------------------------------------------------------------
# parser
# --------------------------------------------------------------------------

sub template {
   my $tpl = [];
   while (defined( my $part = macro() || lookahead(CHAR) && match(CHAR) )) {
      push @$tpl, $part;
   }
   return compact($tpl);
}

sub macro {
   #... check for an macro
   return undef unless lookahead(MACRO_START);
   my $line_number = $LineNo;
   #... match marco-start
   match(MACRO_START);
   match(SPACE);
   #... match name
   my $name = match(NAME);
   while (lookahead(DOT)) { $name .= match(DOT) . match(NAME) }
   #... match params
   match(SPACE);
   my $params = {};
   while ( my @param = param() ) { $params = { %$params, @param } }
   #... match filters
   my $filters = [];
   while ( lookahead(PIPE) ) {
      match(PIPE);
      match(SPACE);
      my $f_name = match(NAME);
      my $f_params = {};
      match(SPACE);
      while ( my @param = param() ) { $f_params = { %$f_params, @param } }
      push @$filters, { 'name' => $f_name, 'params' => $f_params };
   }
   #... match macro-end
   match(MACRO_END);
   #... return hash representing the macro
   return {
      'type' => 'macro',
      'name' => $name,
      'params' => $params,
      'filters' => $filters,
      'line_number' => $line_number,
   };
}

sub param {
   return () unless lookahead(NAME);
   my $name = match(NAME);
   my $type = lookahead(UNEVAL) ? match(UNEVAL) : match(EQUAL);
   quote_start(match(QUOTE_START));
   my $value = value($type);
   quote_end(match(QUOTE_END));
   match(SPACE);
   return $name => $value;
}

sub value {
   my $type = shift;
   my $escape = 0;
   my $value = [];
   while (not lookahead(QUOTE_END) or $escape) {
      my $part = ($type eq EQUAL)
         ? macro() || lookahead(CHAR) && match(CHAR)
         : lookahead(CHAR) && match(CHAR);
      if (defined $part) {
         pop @$value if $part eq QUOTE_END;
         push @$value, $part;
         $escape = $part eq ESCAPE;
      } else {
         my $end = QUOTE_END;
         $end =~ s/\\//g;
         syntax_error("cannot find quote end char '$end'");
      }
   }
   return compact($value);
}

package WebTek::Compiler::Util;

sub default {
   my ($string, $default) = @_;
   
   return length $string ? $string : $default;
}

sub prefix_suffix {
   my ($string, $prefix, $suffix) = @_;
   
   return length $string ? $prefix . $string . $suffix : $string;
}

1;