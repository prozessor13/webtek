package WebTek::Util::File;

# max wukits
# 11-02-09
#
# some file utils

use strict;
use WebTek::Exception;
use WebTek::Util qw( assert );
use WebTek::Export qw( slurp write copy find );

sub slurp {
   my $file = shift;
   my $is_binary_file = shift;

   my $enc = $is_binary_file ? ':raw' : ':utf8';
   open(FILE, '<' . $enc, $file) or throw "cannot slurp file '$file': $!";
   my @lines = <FILE>;
   close(FILE);
   return join('', @lines);
}

sub write {
   my ($file, @content) = @_;
   
   open(FILE, '>:utf8', $file) or throw "cannot write file '$file': $!";
   print FILE @content;
   close(FILE);
   return;
}

sub copy {
   my ($src, $dest) = @_;
   
   open(SRC, '<:raw', $src) or throw "cannot read file '$src': $!";
   open(DEST, '>:raw', $dest) or throw "cannot write file '$dest': $!";
   while(<SRC>) { print DEST }
   close(DEST);
   close(SRC);
}

sub find {
   my %params = @_;
   
   my ($name, $dir) = ($params{name}, $params{dir});
   assert -d $dir, 'find: no dir defined or exists';
   $name =~ s/\./\\./g;
   $name =~ s/\*/\.*/g;
      
   sub aux {
      my $path = shift;
      
      if (-f $path) {
         return $path =~ /^$name$/ ? ($path) : ();
      } elsif (-d $path) {
         opendir my ($handle), $path or die "Error in opening dir '$path': $!";
         my @result = ();
         while (my $filename = readdir($handle)) {
            next if $filename =~ /^\.+$/;
            push @result, aux($path . "/" . $filename);
         }
         closedir($handle);
         return @result;
      } else {
         return ();
      }
   }
   
   return aux($dir);
}

1;