package WebTek::Paginator;

# max demmelbauer
# 19-11-07
#
# paginate through data or model->find commands

use strict;
use WebTek::Util qw( assert make_accessor );

make_accessor('page');
make_accessor('items_per_page');
make_accessor('limit');
make_accessor('offset');

# ---------------------------------------------------------------------------
# create new paginator
# ---------------------------------------------------------------------------

sub new {
   my ($class, %params) = @_;
   
   assert $params{'model'} || $params{'data'}, "no model or data defined";

   #... create object with default values
   my $self = bless { 'params' => \%params }, $class;
   $self->page($params{'page'} || 1);
   $self->items_per_page($params{'items_per_page'} || 10);
   $self->limit($self->items_per_page);
   $self->offset($self->items_per_page * ($self->page - 1));
   
   return $self;
}

sub _fetch {
   my $self = shift;
   
   #... create result on first call
   unless ($self->{'result'}) {
      
      #... create items and count for a model definition
      if (my $model = $self->{'params'}->{'model'}) {
         #... call model->where
         if (defined $self->{'params'}->{'where'}) {
            my @args = @{$self->{'params'}->{'args'} ||[]};
            $self->{'result'} = {
               'items' => $model->where(
                  "$self->{'params'}->{'where'} limit ? offset ?",
                  @args, $self->limit, $self->offset
               ),
               'count' =>
                  $model->count_where($self->{'params'}->{'where'}, @args),
            };
         #... call model->find
         } else {
            my %find = %{$self->{'params'}->{'find'} || {}};
            $self->{'result'} = {
               'items' => $model->find(
                  %find,
                  'limit' => $self->limit,
                  'offset' => $self->offset,
               ),
               'count' => $model->_count(%find),
            };
         }

      #... create items and count for a the given data array
      } else {
         my @data = @{$self->{'params'}->{'data'}};
         my ($min, $max) = ($self->offset, $self->offset + $self->limit - 1);
         my @result = scalar @data
            ? @data[$min .. ($max > $#data ? $#data : $max)]
            : ();
         $self->{'result'} = {
            'items' => \@result,
            'count' => scalar @data,
         };
      }
      
      #... calculate the last_page
      $self->{'result'}->{'last_page'} =
         int(($self->{'result'}->{'count'} - 1) / $self->items_per_page) + 1;

   }
      
   return $self->{'result'};
}

# ---------------------------------------------------------------------------
# get items and count
# ---------------------------------------------------------------------------

sub items { shift->_fetch->{'items'} }

sub count { shift->_fetch->{'count'} }

sub last_page { shift->_fetch->{'last_page'} }

# ---------------------------------------------------------------------------
# iterate through pages
# ---------------------------------------------------------------------------

sub pages {
   my $self = shift;
   
   my @pages = map { $self->get($_) } 1 .. $self->last_page;
   return wantarray ? @pages : \@pages;
}

sub next {
   my $self = shift;
      
   return $self->get($self->page + 1);
}

sub prev {
   my $self = shift;
   
   return $self->get($self->page - 1);
}

sub get {
   my $self = shift;
   my $page = shift;
      
   #... there is no next page
   return undef if $page > $self->last_page or $page < 1;
   #... create paginator for the next page
   return ref($self)->new(%{$self->{'params'}}, 'page' => $page);
}

1;