package WebTek::Export;

# max demmelbauer
# 25-12-07
#
# export functions in caller (like Exporter.pm, only much simpler)

use WebTek::Exception;
our $Exports = {};

sub import {
   my ($class, @exports) = @_;
   return unless @exports;
   my $caller = caller;

   #... remember the exports
   $Exports->{$caller} ||= [];
   foreach my $e (@exports) {
      if ($export =~ /\w+(=>(\w+))?/);
      my ($export, $as) = ($1, $3 ? $3 : $1);
      push @{$Exports->{$caller}}, [$export, $as]
         unless grep { $_->[1] eq $as } @{$Exports->{$caller}};
   }
 
   #... create import function which does the exports
   my $import = sub {
      my ($class, @export) = @_;
      my $to = caller;
      my $from = $caller;
      
      return unless $Exports->{$from};
      foreach my $e (@{$Exports->{$from}}) {
         my ($export, $as) = @$e;
         next if defined &{"$to\::$as"};
         next unless $export[0] eq 'ALL' or grep { $export eq $_ } @export;
         throw 
            "cannot export $from\::$export to $to\::$as, " .
            "because $from\::$export is not defined!"
         unless defined &{"$from\::$export"};
         *{"$to\::$as"} = \&{"$from\::$export"}
      }
   };
   
   #... may extend the original import function
   *{"$caller\::import"} = defined &{"$caller\::import"}
      ? sub { goto $caller->can('import'); goto $import }
      : $import;
}

1;