package WebTek::Message;

# max demmelbauer
# 30-03-06

use strict;
use WebTek::App qw( app );
use WebTek::Util qw( assert );
use WebTek::Logger qw( ALL );
use WebTek::GetText;
use WebTek::Exception;

our %Messages = ();

sub exists {
   my ($class, %params) = @_;
   
   #... check params
   assert exists $params{'key'}, "no key defined";
   assert $params{'language'}, "no language defined";

   #... check key
   return $Messages{app->name}->{$params{'language'}}
      && exists $Messages{app->name}->{$params{'language'}}->{$params{'key'}};
}

sub message {
   my ($class, %params) = @_;
   
   #... check language
   assert $params{'language'}, "no language defined";
   my $language = $params{'language'};
   
   #... ask params
   return $params{$language} if defined $params{$language};

   #... check key
   assert exists $params{'key'}, "no key defined";
   
   #... ask message file
   my $key = $params{'key'};
   my $default = defined $params{'default'} ? $params{'default'} : $key;
   return $default unless $Messages{app->name}->{$language};
   return $default unless $Messages{app->name}->{$language}->{$key};
   return $Messages{app->name}->{$language}->{$key};
}

sub load {
   my ($class, $language) = @_;

   #... check language
   return unless $language =~ /^\w\w$/;
   
   #... find all necesarry files
   my @files;
   foreach my $e ('', map ".$_", @{app->env}) {
      my @f = grep -f, map "$_/messages/$language$e.po", @{app->dirs};
      push @files, @f;      
   }
   
   #... get existing messages
   my $msgs = $Messages{app->name} && $Messages{app->name}->{$language} || {};

   #... load message-files
   foreach my $file (@files) {
      log_debug("load message $file");
      $msgs = { %$msgs, %{WebTek::GetText::read_po($file)} };
   }
      
   #... remember messages
   $Messages{app->name}->{$language} = $msgs;
}

1;