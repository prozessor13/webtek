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
   *{"$caller\::import"} = sub {
      my ($class, @export) = @_;
      my $to = caller;
      my $from = $caller;
      
      return unless $Exports->{$from};
      foreach my $export (@{$Exports->{$from}}) {
         next if defined &{"$to\::$export"};
         next unless $export[0] eq 'ALL' or grep { $export eq $_ } @export;
         throw 
            "cannot export $from\::$export to $to\::$export, " .
            "because $from\::$export is not already defined!"
         unless defined &{"$from\::$export"};
         *{"$to\::$export"} = \&{"$from\::$export"}
      }
   } unless defined &{"$caller\::import"};
}

1;