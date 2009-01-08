my @files = WebTek::Util::find(
   'name' => '*.properties',
   'dir' => app->dir,
);

foreach my $file (@files) {
   
   print "convert file $file\n";
   
   #... load properties file
   my $properties = properties($file);
   
   #... create po entries
   my @m = ("msgid \"\"\nmsgstr \"Content-Type: text/plain; charset=UTF-8\"\n\n");
   foreach my $key (sort keys %$properties) {
      my $value = $properties->{$key};
      $value =~ s/"/\\"/g;
      $value =~ s/\n//g;
      push @m, "msgid \"$key\"\nmsgstr \"$value\"\n\n";
   }
   
   #... save po file
   $file =~ s/.properties$/.po/;
   WebTek::Util::write($file, @m);

}

sub properties {
   my $file = shift;
   
   #... may overwrite existing messages
   my $messages = {};

   #... parse message-files
   log_debug("load message $file");
   my $key = "";
   my $value = "";
   my $multiline = 0;
   my $lineno = 0;
   open(FILE, "<:utf8", "$file") or throw "Message: cannot open $file";
   foreach my $line (<FILE>) {
      $lineno++;
      next if ($line =~ /^#/);      # ignore comments
      next if ($line =~ /^\s+$/);   # ignore empty lines
      chop $line if $line =~ /\n$/; # remove trailing newline
      if ($multiline) {
         if ($line =~ /\\$/) { chop $line }
         else { $multiline = 0 }
         $value .= $line;
      } elsif ($line =~ /^\s*([^=:\s]+)\s*[=:\s]\s*(.*)$/) {
         #... store previous key
         if ($key) { $messages->{$key} = $value }
         #... parse new key
         $key = $1;
         $value = $2;
         if ($value =~ /\\$/) { chop $value; $multiline = 1 }
      } else { warn "cannot parse line $lineno in $file" }
   }
   #... store last key
   if ($key) { $messages->{$key} = $value }
   close(FILE);   
   
   return $messages;
}

1;