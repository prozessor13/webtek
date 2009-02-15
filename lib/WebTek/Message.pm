package WebTek::Message;

# max demmelbauer
# 30-03-06

use strict;
use WebTek::App qw( app );
use WebTek::Util qw( assert );
use WebTek::Logger qw( ALL );
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
   
   #... load message-files
   my $msgs = {};
   foreach my $file (@files) {
      log_debug("load message $file");
      $msgs = { %$msgs, %{read_po($file)} };
   }
      
   #... remember messages
   $Messages{app->name}->{$language} = $msgs;
}

sub read_po {   
   my $file = shift;
   
   sub _unescape {   #... unescape \n,\r,\t
      my $string = shift;
      $string =~ s/\\n/\n/g;
      $string =~ s/\\r/\r/g;
      $string =~ s/\\t/\t/g;
      $string =~ s/\\"/"/g;
      return $string;
   }
      
   my ($msgs, $infos, $lineno, $state, $key, $value) = ({}, {});
   foreach my $line (split /\n/, slurp($file)) {
      $lineno++;
      next if ($line =~ /^#/);            # ignore comments
      next if ($line =~ /^\s*$/);         # empty lines
      if (defined $value and $line =~ /^"(.*)"$/) {   # multiline
         $value .= $1;
      } elsif ($line =~ /^msgid\s*"(.*)"$/) {
         my $new_value = $1;
         if ($state eq "value") {
            $msgs->{_unescape($key)} = _unescape($value);
            $infos->{_unescape($key)} = $lineno;
         }
         $key = $value = $new_value;
         $state = "key";
      } elsif ($state eq "key" and $line =~ /^msgstr(\[0\])?\s*"(.*)"$/) {
         $key = $value;
         $value = $2;
         $state = "value";
      } else { warn "cannot parse line $lineno in $file" }
   }
   #... store last key
   if ($state eq "value") {
      $msgs->{_unescape($key)} = _unescape($value);
      $infos->{_unescape($key)} = $lineno;
   }
   
   return wantarray ? ($msgs, $infos) : $msgs;
}

1;