package tests;

use strict;
use WebTek::Globals;
use Test::Builder;
use Test::Exception;
use Test::More 'no_plan';

our @Tests;

sub MODIFY_CODE_ATTRIBUTES {
   my ($class, $coderef, $attr) = @_;
   if ($attr =~ /Test/) { push @tests::Tests, $coderef }
   return ();
}

package WebTek::Util::Test;

use WebTek::Logger qw( ALL );

my $Log = "";
my $Test = Test::Builder->new;
*Test::Builder::_print = sub { $Log .= $_[1] };
*Test::Builder::_print_diag = sub {
   $Log .= join("\n", map { substr $_, 1 } split /\n/, $_[1]) . "\n";
};

sub run {
   my ($class, $file) = @_;
   
   log_info "run testfile $file";
   
   # load code
   @tests::Tests = ();
   *tests::init = undef;
   *tests::finish = undef;
   WebTek::Module->do($file, 'tests');

   # run tests
   my @result = ();
   tests::init() if defined &tests::init;
   foreach my $test (@tests::Tests) {
      #... init Test::Builder
      $Log = "";
      $Test->reset;
      $Test->no_plan;
      $Test->no_header(1);
      #... call testfkt
      my $subname = WebTek::Util::subname_for_coderef('tests', $test);
      log_info "   - run test '$subname':";
      eval {
         $test->();
         WebTek::DB::DB()->commit;
         1;
      } or do {
         WebTek::DB::DB()->rollback;
         log_error "     error running tests, details: $@";
      };
      #... check and generate result
      my @tests = $Test->summary;
      if (grep !$_, @tests) {
         log_error "     there were some failed tests, look at the details:";
         foreach (split /\n/, $Log) { log_error "        $_" };
      }
      push @result, @tests;
   }
   tests::finish() if defined &tests::finish;
   
   #... return result of done tests
   return @result;
}

1;