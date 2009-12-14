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
   foreach my $export (@exports) {
      push @{$Exports->{$caller}}, $export
         unless grep { $_ eq $export } @{$Exports->{$caller}};
   }
 
   #... create import function which does the exports
   my $import = sub {
      my ($class, @export) = @_;
      my $to = caller;
      my $from = $caller;

      #... parse for different export names
      %export = map { /(\w+)(=>(\w+))?/ ? ($1 => $3 ? $3 : $1) : () } @export;
      
      return unless $Exports->{$from};
      foreach my $e (@{$Exports->{$from}}) {
         next if defined &{"$to\::$export{$e}"};
         next unless $export[0] eq 'ALL' or $export{$e};
         throw 
            "cannot export $from\::$e to $to\::$export{$e}, " .
            "because $from\::$e is not defined!"
         unless defined &{"$from\::$e"};
         $export{$e} ||= $e;
         *{"$to\::$export{$e}"} = \&{"$from\::$e"}
      }
   };
   
   #... may extend the original import function
   *{"$caller\::import"} = defined &{"$caller\::import"}
      ? sub { goto $caller->can('import'); goto $import }
      : $import;
}

1;