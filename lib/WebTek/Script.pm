package WebTek::Script;

# max demmelbauer
# 21-08-08
#
# implements the helpers of the webtek-script

use strict;
use WebTek::Globals;
use WebTek::Util qw( slurp );
use WebTek::Attributes qw( MODIFY_CODE_ATTRIBUTES );

sub assert { throw $_[1] unless $_[0] }

# ---------------------------------------------------------------------------
# commands
# ---------------------------------------------------------------------------

sub model :Info(model <model-name> -> creates a new model) {
   my ($webtekdir, $appname, $appdir, $module, $args, $argv) = @_;
   
   assert $argv->[0], "no modelname defined!";
   assert
      !-e "$appdir$module/Model/$argv->[0].pm",
      "Model $argv->[0].pm already exists!\n";
   _copy(@_, "Model.pm", "$appdir$module/Model/$argv->[0].pm");
   _copy(@_, "Test.t", "$appdir$module/scripts/test/Model/$argv->[0].t");
}

sub page :Info(page <page-name> -> creates a new page) {
   my ($webtekdir, $appname, $appdir, $module, $args, $argv) = @_;

   assert $argv->[0], "no pagename defined!";
   assert
      !-e "$appdir$module/Page/$argv->[0].pm",
      "Page $argv->[0].pm already exists!\n";
   _copy(@_, "Page.pm", "$appdir$module/Page/$argv->[0].pm");
   _copy(@_, "index_page.tpl", "$appdir$module/templates/$argv->[0]/index.tpl");
   _copy(@_, "Test.t", "$appdir$module/scripts/test/Page/$argv->[0].t");
}

sub pre_module :Info(module <module-name> -> creates a new module) {
   my ($webtekdir, $appname, $appdir, $module, $args, $argv) = @_;

   my $m = $argv->[0];
   assert $m, 'no modulename defined';
   assert !-d "$appdir/pre-modules/$m", "Module $m already exists!";

   _makedir("$appdir/pre-modules/$m/Page");
   _makedir("$appdir/pre-modules/$m/Model");
   _makedir("$appdir/pre-modules/$m/templates");
   _makedir("$appdir/pre-modules/$m/config");
   _makedir("$appdir/pre-modules/$m/messages");
   _makedir("$appdir/pre-modules/$m/static");
   _makedir("$appdir/pre-modules/$m/scripts");
   _makedir("$appdir/pre-modules/$m/scripts/test");
}

sub post_module :Info(module <module-name> -> creates a new module) {
   my ($webtekdir, $appname, $appdir, $module, $args, $argv) = @_;

   my $m = $argv->[0];
   assert $m, 'no modulename defined';
   assert !-d "$appdir/post-modules/$m", "Module $m already exists!";

   _makedir("$appdir/post-modules/$m/Page");
   _makedir("$appdir/post-modules/$m/Model");
   _makedir("$appdir/post-modules/$m/templates");
   _makedir("$appdir/post-modules/$m/config");
   _makedir("$appdir/post-modules/$m/messages");
   _makedir("$appdir/post-modules/$m/static");
   _makedir("$appdir/post-modules/$m/scripts");
   _makedir("$appdir$module/post-modules/$m/scripts/test");
}

sub console :Info(console -> starts the webtek console) {
   my ($webtekdir, $appname, $appdir, $module, $args, $argv) = @_;

   app->env([@{app->env || []}, 'console']);
   WebTek::DB->DESTROY;
   WebTek::Loader->reset;
   WebTek::Loader->reload('safe');

   print "Welcome to the WebTek Console\n\n";
   while (1) {
      print "> ";
      my $cmd = <STDIN>;
      exit if $cmd =~ /^q|quit|exit|bye$/;
      $cmd = WebTek::Module->source_filter($cmd);
      WebTek::Loader->reload('safe') if config->{'code-reload'};
      my $output = eval "no strict; $cmd" || $@;
      print $output;
      print "\n" unless $output =~ /\n$/;
   }
}

sub script :Info(script <filename> -> starts a script for this app) {
   my ($webtekdir, $appname, $appdir, $module, $args, $argv) = @_;
   
   assert $argv->[0], "no script-filename defined!";
   my $file = app->dir . '/' . $argv->[0];
   assert -e $file, "script-filename not exists!";
   shift @::argv;
   my $ok = eval {
      WebTek::Module->do($file),
      DB->commit_all;
      1;
   } or do { DB->rollback };
   assert $ok, "error during script, details: $@, $!";
   print "done...\n";
}

sub translate :Info(translate <language>,... -> generate .po files) {
   my ($webtekdir, $appname, $appdir, $module, $args, $argv) = @_;

   my @languages = @$argv
      ? @$argv
      : keys(%{$WebTek::Message::Messages{app->name}});
   
   foreach my $dir (grep -d, @{app->dirs}) {
      my @all_keys = WebTek::GetText::search_keys_in_dir($dir);
      foreach my $language (@languages) {
         my $file = "$dir/messages/$language.po";
         my @missing_keys = grep {
            !WebTek::Message->exists('language' => $language, 'key' => $_->[0])
         } @all_keys;
         if (@missing_keys) {
            print "update file $file with " . @missing_keys . " missing keys\n";
            my $content = -e $file
               ? slurp($file) . "\n\n"
               : "msgid \"\"\n" .
                 "msgstr \"Content-Type: text/plain; charset=UTF-8\"\n\n";
            foreach my $key (@missing_keys) {
               my $src = @{$key->[1]} ? "#: ".join(",",@{$key->[1]})."\n" : "";
               my $msgid = $key->[0];
               $msgid =~ s/\n/\\n/g;
               $msgid =~ s/"/\"/g;
               $content .= "$src\msgid \"$msgid\"\nmsgstr \"\"\n\n";
            }
            WebTek::Util::write($file, $content);
         }
      }
   }
}

sub test :Info(test -> run all tests) {
   my ($webtekdir, $appname, $appdir, $module, $args, $argv) = @_;

   WebTek::Loader->load('WebTek::Test');
   WebTek::Loader->load('WebTek::Engine::Test');
   app->env([@{app->env || []}, 'test']);
   app->engine('WebTek::Engine::Test');
   WebTek::DB->DESTROY;
   WebTek::Loader->reset;
   WebTek::Loader->reload('safe');
   
   my @tests;
   my @dirs = @$argv
      ? @$argv
      : grep(-d, map { "$_/scripts/test" } @{app->dirs});
   foreach (@dirs) {
      foreach my $file (WebTek::Util::find('dir' => $_, 'name' => '*.t')) {
         push @tests, WebTek::Test->run($file);
      }
   }

   print "\nresult: \n";
   print " - planned: " . @tests . "\n";
   print " - successful: " . (grep $_, @tests) . "\n";
   print " - failed: " . (grep !$_, @tests) . "\n";
}

sub migrate
    :Info(migrate <command> -> does a migration, the commands are:)
    :Info(  - history       -> prints the migration history)
    :Info(  - list          -> prints all available migrations)
    :Info(  - up            -> migrate up to the lastest version)
    :Info(  - down          -> migrate down the last migration)
    :Info(  - create <name> -> create a new migration)
{
   my ($webtekdir, $appname, $appdir, $module, $args, $argv) = @_;

   my $cmd = $argv->[0];
   assert
      $cmd =~ /^(up|down|list|history|create)$/ ? 1 : 0,
      "invalid migration command";
   app->env([@{app->env || []}, 'migrate']);
   WebTek::DB->DESTROY;
   WebTek::Loader->reset;
   WebTek::Loader->reload('safe');

   #... manage the history-file
   my $history = sub {
      my @h = -f ".migration.history"
         ? split "\n", slurp(".migration.history")
         : ();
      if (@_) {
         my $name = shift;
         my $time = date('now')->to_string('format' => "%Y-%m-%d %H:%M:%S");
         push @h, "$time\t$name\t$cmd";
         WebTek::Util::write(".migration.history", join "\n", @h);
      }
      return @h;
   };
   
   my $list = sub {
      return sort grep $_, map {
         /((pre|post)-modules\/(\w+))?\/scripts\/migrate\/(\d+_\w+.pl)$/
            ? $3 ? "$4\@$2:$3" : $4 : ''
      } map {
         WebTek::Util::find('dir'=> $_, 'name'=> '*.pl');
      } grep -d $_, map { "$_/scripts/migrate" } @{app->dirs};
   };
   
   my $alreay_done = sub {
      my $name = shift;
      my $d = 0;
      foreach ($history->()) {
         if (/\t$name\t(\w+)$/) {
            $d = 1 if $1 eq 'up';
            $d = 0 if $1 eq 'down';
         }
      }
      return $d;
   };
   
   my $fname = sub {
      my $name = shift;
      return "$appdir/$2-modules/$3/scripts/migrate/$1"
         if $name =~ /^(\d+_\w+.pl)@(\w+):(\w+)$/;
      return "$appdir/scripts/migrate/$name" if $name =~ /^(\d+_\w+.pl)$/;
      return undef;
   };
   
   if ($cmd eq 'up') {
      foreach my $name (grep { not $alreay_done->($_) } $list->()) {
         print "do an $cmd migration of $name\n";
         my $ok = eval {
            WebTek::Module->do("" . $fname->($name));
            main::up();
            DB->commit_all;
            1;
         } or do { DB->rollback };
         assert $ok, "error during migration $name, details: $@";
         $history->($name);
      }
   } elsif ($cmd eq 'down') {
      foreach my $name (reverse grep { $alreay_done->($_) } $list->()) {
         print "do an $cmd migration of $name\n";
         my $ok = eval {
            WebTek::Module->do("".$fname->($name));
            main::down();
            DB->commit_all;
            1;
         } or do { DB->rollback };
         assert $ok, "error during migration $name, details: $@";
         $history->($name);
         last;
      }
   } elsif ($cmd eq 'list') {
      foreach my $name ($list->()) {
         if ($name =~ /^\d+_(\w+).pl(@\w+:\w+)?$/) {
            print " * $1$2 ".($alreay_done->($name)?"(already done)\n":"\n");            
         }
      }
   } elsif ($cmd eq 'history') {
      print join("\n", $history->()) . "\n";
   } elsif ($cmd eq 'create') {
      my $t = date('now')->to_string('format' => "%Y%m%d%H%M%S");
      my $filename = $fname->("$t\_$argv->[1].pl");
      $filename = $fname->("$t\_$argv->[1].pl\@$1:$2")         
         if $module =~ /\/(pre|post)-modules\/(.+)/;
      assert($filename, "no valid name defined!");
      _copy(@_, "Migration.pl", $filename);
   }
}

# ---------------------------------------------------------------------------
# utils
# ---------------------------------------------------------------------------

sub _copy {
   my ($webtekdir, $appname, $appdir, $module, $args, $argv, $infile, $outfile) = @_;
   
   #... create missing directories
   my @dir = grep $_, split "/", $outfile;
   pop @dir;
   _makedir(join "/", @dir);

   #... copy file
   print " => create $outfile\n";
   my $file = "";
   my ($packagename, $packagename_last) = ($argv->[0], $argv->[0]);
   $packagename =~ s/\//::/g;
   $packagename_last =~ s/(.*\/)?([^\/]+)$/$2/;
   open (IN, "$webtekdir/extra/templates/$infile") or die $!;
   open (OUT, "> $outfile") or die $!;
   while (<IN>) {
      s/\<\% appdir \%\>/$appdir/g;
      s/\<\% appname \%\>/$appname/g;
      s/\<\% appname_lower \%\>/lc($appname)/eg;   
      s/\<\% packagename \%\>/$packagename/g;
      s/\<\% packagename_lower \%\>/lc($packagename)/eg;
      s/\<\% packagename_last \%\>/$packagename_last/eg;
      s/\<\% packagename_last_lower \%\>/lc($packagename_last)/eg;
      print OUT;
   }
   close (IN);
   close (OUT);
}

sub _makedir {
   my ($makedir, $dir) = (shift, "");

   foreach (grep $_, split "/", $makedir) {
      $dir .= "/$_";
      unless (-d $dir) {
         print " => create $dir\n";
         mkdir $dir or die $!
      }
   }
}

sub _info {
   my $attrs = WebTek::Attributes->attributes_for_class('WebTek::Script');
   my @cmds = map { /Info\((.*)\)/ ? $1 : "" } map @{$_->[1]}, @$attrs;
   return join "\n", map { "   $_" } grep { $_ } @cmds;
}

1;