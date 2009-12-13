package WebTek::GetText;

# max demmelbauer
# 15-05-08
#
# extract message keys from .pm and .tpl files

use strict;
use WebTek::Util::File qw( slurp );
use WebTek::Compiler;

# ---------------------------------------------------------------------------
# utils
# ---------------------------------------------------------------------------

sub _find_messages {
   my ($array, $info, $messages) = @_;
   
   foreach my $item (@$array) {
      if (ref $item and $item->{type} eq 'macro') {
         #... find nested
         foreach my $key (keys %{$item->{params}}) {
            _find_messages($item->{params}{$key}, $info, $messages);
         }
         #... process message macros
         my ($macro) = reverse split /\./, $item->{name};
         next unless $macro eq 'message';
         next unless $item->{params}{key};
         my $param = $item->{params}{key};
         my $key = (@$param > 1 or ref $param->[0])
            ? 'nested message key'
            : $param->[0];
         push @$messages, [$key, ["$info\:$item->{line_number}"]];
      }
   }
   
   return $messages;
}

# ---------------------------------------------------------------------------
# public methods for generating po (template) files
# ---------------------------------------------------------------------------

sub search_keys_in_pm {
   my $file = shift;

   my (@gettext, $lineno);

   foreach my $line (split /\n/, slurp($file)) {
      $lineno++;
      if ($line =~ /(self|Message)\-\>message(\(.*?\))?/) {
         my %params = eval $2;
         my $key = $params{key}
            ? $params{key}
            : 'nested message key';
         push @gettext, [$key, ["$file\:$lineno"]];
      }
   }

   return @gettext;
}

sub search_keys_in_tpl {
   my $file = shift;

   my $array = WebTek::Compiler->parse(slurp($file));
   return @{_find_messages($array, $file, [])};
}

sub search_keys_in_dir {
   my $dir = shift;
   
   my @keys;
   
   #... search po's
   if (-d (my $d = "$dir/messages")) {
      foreach my $file (WebTek::Util::find(name => '*.po', dir => $d)) {
         my ($messages, $infos) = read_po($file);
         #... add message keys
         my @keys_msgs = map { [$_, []] } keys %$messages;
         push @keys, @keys_msgs if @keys_msgs;
         #... search keys in messate-content
         foreach my $key (keys %$messages) {
            my $array = WebTek::Compiler->parse($messages->{$key});
            push @keys, @{_find_messages($array, "$file:$infos->{$key}", [])};
         }
      }
   }
   #... search tpl's
   if (-d (my $d = "$dir/templates")) {
      foreach my $file (WebTek::Util::find(name => '*.tpl', dir => $d)) {
         my @keys_tpl = search_keys_in_tpl($file);
         push @keys, @keys_tpl if @keys_tpl;
      }      
   }
   #... search pm's
   my @pms = WebTek::Util::find(name => '*.pm', dir => $dir);
   foreach my $file (@pms) {
      next unless $file =~ /^$dir\/[A-Z]/;
      my @keys_pms = search_keys_in_pm($file);
      push @keys, @keys_pms if @keys_pms;
   }
   #... group keys
   my %keys;
   sub _m { my ($a1, $a2) = @_; foreach (@$a2) { push @$a1, $_ if $_ }; $a1 };
   foreach my $key (@keys) {
      my ($k, $v) = @$key;
      $keys{$k} = _m($v, $keys{$k} || []);
   }
   #.. sort keys
   return sort { $a->[0] cmp $b->[0] } map { [$_, $keys{$_}] } keys %keys;
}

1;