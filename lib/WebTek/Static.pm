package WebTek::Static;

# max demmelbauer
# 28-03-2008
#
# merge static files to the static dir

use strict;
use WebTek::App qw( app );
use WebTek::Event qw( event );
use WebTek::Util qw( assert );
use WebTek::Config qw( config );
use WebTek::Logger qw( ALL );
use WebTek::Util::File qw( copy );
use WebTek::Exception;

sub merge_static_file {
   my ($class, $file) = @_;
   
   log_debug "merge static file $file";
   
   #... check static dir
   my $static = config->{static}{dir};
   assert -d $static, "static-dir '$static' does not exists!";

   #... create missing subdirs
   if ($file =~ /(.*)\//) {
      my $dir = $static;
      my $missing = $1;
      foreach my $subdir (split /\//, $missing) {
         $dir .= "/$subdir";
         mkdir $dir or throw "error creating dir $dir, $!" unless -d $dir;
      }
   }
   
   #... copy files
   my @time = (0, 0);
   foreach my $src (grep -e, map "$_/static/$file", @{app->dirs}) {
      #... check modifytime
      my @t = (stat($src))[8,9];
      @time = @t if $t[1] > $time[1];
      #... copy file
      WebTek::Util::File::copy($src, "$static/$file");
      chmod 0777, "$static/$file";
   }

   #... set modify time to the newest file 
   utime @time, "$static/$file";

   event->trigger(name => 'static-file-copied', args => [ "$static/$file" ]);
}

1;