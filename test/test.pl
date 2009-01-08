#!/usr/bin/env perl

use strict;
use Test::Unit::TestSuite;
use Test::Unit::TestRunner;

sub add {
   my $suite = shift;   # Test::Unit::TestSuite
   my $root = shift;    # e.g. '/home/adrian/project/test'
   my $path = shift;    # e.g. '/Uboot/MyModule/XyzTest.pm'

   if ($path =~ /Test\.pm$/) {
      $path =~ s|^/+||;
      $path =~ s|/|::|g;
      $path =~ s|.pm$||;
      eval "use $path; 1;" or die $@;
      $suite->add_test($path);
   } elsif (-d "$root/$path") {
      opendir my ($dir), "$root/$path" or die "Error opening dir '$root/$path': $!\n";
      while (my $filename = readdir($dir)) {
         next if ($filename =~ /^\./);
         add($suite, $root, "$path/$filename");
      }
      closedir($dir);
   }
}

sub suite {
   my $suite = Test::Unit::TestSuite->empty_new("WebTek");
   foreach my $dir (@INC) {
      add($suite, $dir, "") if ($dir =~ /test$/)
   }
   return $suite;
}

sub set_inc {
   my @pwd = `pwd`;
   my $dir = $pwd[0];
   $dir =~ s/\\/\//g;
   chop $dir;
   my $base = "$dir/..";
   $base =~ s|^/cygdrive/(.)|$1:|;
   
   unshift(@INC, "$base/lib");
   unshift(@INC, "$base/test");
}

sub main {
   set_inc();
   my $testrunner = Test::Unit::TestRunner->new();
   $testrunner->start("main");
}

main();