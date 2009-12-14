package WebTek::App;

# max demmelbauer
# 20-03-06
#
# knows some things of an webtek application

use strict;
use WebTek::Util qw( assert make_accessor );
use WebTek::Logger qw( ALL );
use WebTek::Exception;
use WebTek::Attributes qw( MODIFY_CODE_ATTRIBUTES );
use WebTek::Export qw( app );
use base qw( WebTek::Handler );

our $App;
our %Apps;

make_accessor 'name', 'Macro';
make_accessor 'dir', 'Macro';
make_accessor 'env';
make_accessor 'libraries';
make_accessor 'modules';
make_accessor 'log_level';
make_accessor 'prefix';
make_accessor 'engine';

sub app :Handler { $App or throw "App not initialized!" }

sub activate {
   $App = $Apps{$_[1]};
   $::app = $App;                      # shortcut for performance
   $::appname = $App && $App->name;    # shortcut for performance
   return $App;
}

sub init {
   my ($class, %params) = @_;

   #... check properties
   assert $params{name}, "app name not defined!";
   assert -d $params{dir}, "app dir '$params{dir}' does not exist";
   
   #... create app
   my $self = $Apps{$params{name}} = bless {}, $class;
   $params{dir} =~ s|/$||g;           # trailing / makes bad things happen
   $self->name($params{name});
   $self->dir($params{dir});
   $self->env($params{env} || []);
   $self->libraries($params{libraries});
   $self->modules($params{modules});
   $self->prefix(substr $params{dir}, (rindex $params{dir}, "/") + 1);
   $self->log_level($params{log_level} || WebTek::Logger::LOG_LEVEL_DEBUG());
   $self->engine($params{engine});
   
   #... set global accessable
   $self->activate($params{name});
   
   #... init backend for app
   WebTek::Loader->init($params{loader});
}

sub dirs { [
   (map { $App->dir . "/libraries/$_" } @{$App->libraries}),
   $App->dir,
   (map { $App->dir . "/modules/$_" } @{$App->modules}),
] }

1;
