package WebTek::Page;

use strict;

sub form_end :Macro
   :Param(render the form-end-tag and extends response.message with form error-information)
   :Param(message="msg2" define the response.message container, default="default")
{
   my ($self, %params) = @_;
   
   my $html = '</div></form>';
   #... may update the response->message with form error-information
   if ($self->{__form_errors} and @{$self->{__form_errors}}) {
      my $err = $self->errors(keys => join ',', @{$self->{__form_errors}});
      if (my $msg = $params{message}) {
         response->message->$msg(response->message->$msg . $err);   
      } else {
         response->message(response->message . $err);            
      }
   }
   return $html;
}

1;