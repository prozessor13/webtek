package WebTek::Engine::CGI;

# initialize the WebTek::Request with data using CGI module

use strict;
use WebTek::App qw( app );
use WebTek::Util qw( assert );
use WebTek::Config qw( config );
use WebTek::Logger qw( ALL );
use WebTek::Request qw( request );
use WebTek::Response qw( response );
use WebTek::Exception;
use WebTek::Data::Date qw( date );
use Encode qw( _utf8_on decode encode );
use CGI::Simple;
use CGI::Simple::Cookie;

my $Cgi;

sub _upload_file {
   my $fh = shift;

   my ($data, $buffer, $file);
   my $config = config('cgi')->{'request'};
   my $tempfile = "$config->{'TEMP_DIR'}/webtek-upload-".time.int(rand(1000));
   my $upload_hook = $config->{'UPLOAD_HOOK'};
   binmode($fh, ":raw");
   open $file, ">:raw", $tempfile or
      throw "cannot open temp file '$tempfile' (during upload)";
   while (read($fh, $buffer, 4096)) {
      print $file $buffer;
      $data .= $buffer;
      $upload_hook->($data) if $upload_hook
   }
   close $file;
   return $tempfile;
}

sub prepare {
   my $self = shift;

   WebTek::Request->init;

   my $is_utf8 = (config->{'charset'} =~ /utf-?8/i);
      
   #... initialize CGI system
   CGI::Simple::_reset_globals;
   my %config = %{config('cgi')->{'request'}};
   assert $config{'POST_MAX'}, "config request.POST_MAX not defined!";
   assert $config{'TEMP_DIR'}, "config request.TEMP_DIR not defined!";
   $CGI::Simple::POST_MAX = $config{'POST_MAX'};
   $CGI::Simple::DISABLE_UPLOADS = 0;
   $Cgi = new CGI::Simple;

   #... HTTP headers are in
   #        $ENV{'HTTP_ABC_DEF'}, $ENV{'HTTPS_ABC_DEF'}
   #    and we need them in
   #        $headers_hash->{'Abc-Def'}
   my $headers = {};
   foreach my $env_key (keys %ENV) {
      next unless ($env_key =~ /^HTTPS?_(\w+)$/);
      my $key = $1;  # e.g. "ABC_DEF";
      $key =~ s/([^_]+)/ ucfirst(lc($1)) /eg;
      $key =~ s/_/-/g;
      $headers->{$key} = $ENV{$env_key};
   }
   request->headers($headers);
   
   request->hostname($Cgi->remote_host);
   request->remote_ip($Cgi->remote_addr);
   request->method($Cgi->request_method);
   request->user($Cgi->remote_user);
   request->referer($Cgi->referer);

   #... get location, uri and path_info
   my $uri = $Cgi->url(-absolute => 1, -path => 1);
   my $path_info = $Cgi->path_info;
   my $location = $Cgi->script_name;
   if ($is_utf8) {
      _utf8_on($uri);
      _utf8_on($path_info);
      _utf8_on($location);
   }
   request->unparsed_uri($Cgi->url(-absolute => 1, -path => 1, -query => 1));
   request->uri($uri);
   request->path_info($path_info);
   request->location($location);

   #... read cookies
   my %cookies = CGI::Simple::Cookie->fetch;
   request->cookies({ map { $_ => $cookies{$_}->value } keys %cookies });

   #... read query parameters
   my $params = {};
   foreach my $name ($Cgi->param) {
      my @values = $Cgi->param($name);
      if ($is_utf8) { foreach (@values) { _utf8_on($_) } }
      else { @values = map { decode(config->{'charset'}, $_) } @values; }
      $params->{$name} = \@values;
   }
   request->params($params);

   #... read uploads
   my $uploads = {};
   my $u = $Cgi->upload;
   foreach my $name ($Cgi->upload_fieldnames) {
      my $filename = $Cgi->param($name);
      next unless $Cgi->upload($filename); # upload field is empty? skip it
      $uploads->{$name} = WebTek::Request::Upload->new(
         'name' => $name,
         'filename' => $filename,
         'size' => $Cgi->upload_info($filename, 'size'),
         'content_type' => $Cgi->upload_info($filename, 'mime'),
         'tempname' => _upload_file($Cgi->upload($filename)),
      );
   }
   request->uploads($uploads);

   #... init response and session
   WebTek::Response->init;
   config->{'session'}->{'class'}->init;
}

sub dispatch {
   my ($self, $root) = @_;
   
   WebTek::Dispatcher->dispatch($root);
}

sub error {
   my ($self, $error) = @_;
   
   log_error $error;
   
   print "Status: 500\n";
   print "Expires: Mon, 26 Jul 1997 05:00:00 GMT\n"; 
   print "Cache-Control: no-cache\n";
   print "Pragma: no-cache\n";
   print "Content-Type: text/html\n";
   print("<html><body><b>general error</b>");
   if (config()->{'display-general-errors-to-browser'}) {
      $error =~ s/\n/<br>/g;
      print("<br><br>$error");
   }
   print("</body></html>");
}

sub finalize {
   my $self = shift;

   #... remove tmp upload files
   my $uploads = request->uploads;
   foreach my $upload (keys %$uploads) {
      unlink $uploads->{$upload}->tempname if -e $uploads->{$upload}->tempname;
   }
   
   #... create cookies
   my @cookies;
   foreach my $cookie (values %{response->cookies}) {
      my %params = map { ("-$_" => $cookie->{$_}) } keys %$cookie;
      $params{'-path'} = "/";
      push @cookies, CGI::Simple::Cookie->new(%params);
   }
   
   #... print status & headers
   print "Expires: Mon, 26 Jul 1997 05:00:00 GMT\n"; 
   print "Cache-Control: no-cache\n";
   print "Pragma: no-cache\n";
   print $Cgi->header(
      -status => response->status,
      -type => response->content_type,
      -cookie => \@cookies,
      %{response->headers},
   );

   #... print body (may convert to a different encoding)
   (response->content_type =~ /^text/)
      ? print encode(config->{'charset'}, response->buffer)
      : print response->buffer;
}

sub log {
   my ($class, $level, $msg) = @_;
   
   $level = (qw( debug info waring error fatal))[$level];
   my $time = date('now', 'GMT')->to_string('format' => '%Y-%m-%d %H%M%S');
   print STDERR "[$time] [WebTek:$level] $msg\n";
}

1;