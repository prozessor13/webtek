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
our $AUTOLOAD;

make_accessor 'name', 'Macro';
make_accessor 'dir', 'Macro';
make_accessor 'env';
make_accessor 'pre_modules';
make_accessor 'post_modules';
make_accessor 'log_level';
make_accessor 'class_prefix';
make_accessor 'engine';

sub app :Handler { $App or throw "App not initialized!" }

sub _modules {
   my ($self, $type) = @_;   # e.g. pre or post
   
   if (opendir(DIR, $self->dir . "/$type-modules")) {
      my $modules = [ grep /^[^\.]/, sort(readdir(DIR)) ];
      closedir(DIR);
      return $modules;
   }   
   return [];
}

sub activate {
   my ($class, $name) = @_;
   
   $App = $Apps{$name};
}

sub init {
   my ($class, %params) = @_;

   #... check properties
   assert $params{'name'}, "app name not defined!";
   assert -d $params{'dir'}, "app dir '$params{'dir'}' does not exist";
   
   #... create app
   my $self = bless {}, $class;
   $params{'dir'} =~ s|/$||g;           # trailing / makes bad things happen
   $self->name($params{'name'});
   $self->dir($params{'dir'});
   $self->env($params{'env'} || []);
   $self->pre_modules($params{'pre-modules'} || $self->_modules('pre'));
   $self->post_modules($params{'post-modules'} || $self->_modules('post'));
   $self->class_prefix(substr $params{'dir'}, (rindex $params{'dir'}, "/") + 1);
   $self->log_level(defined $params{'log_level'}
      ? $params{'log_level'}
      : WebTek::Logger::LOG_LEVEL_DEBUG()
   );
   $self->engine($params{'engine'});
   
   #... set global accessable
   $App = $Apps{$params{'name'}} = $self;
   
   #... init backend for app
   WebTek::Loader->init($params{'loader'});
}

sub dirs { [
   (map { $App->dir . "/pre-modules/$_" } @{$App->pre_modules}),
   $App->dir,
   (map { $App->dir . "/post-modules/$_" } @{$App->post_modules}),
] }

sub module {
   my ($self, $name) = @_;
   
   return 1 if grep { $_ eq $name } @{$self->pre_modules};
   return 1 if grep { $_ eq $name } @{$self->post_modules};
   return 0;
}

1;
