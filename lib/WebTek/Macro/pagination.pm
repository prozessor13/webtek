use WebTek::Export qw( pagination );

sub pagination :Macro
   :Param(render the pagination navigation)
   :Param(container="tplname" optional tplname for the container)
   :Param(prev="tplname" optional tplname for the prev button)
   :Param(next="tplname" optional tplname for the next button)
   :Param(page="tplname" optional tplname for a page button)
   :Param(actual_page="tplname" optional tplname for the actual page button)
   :Param(filler="tplname" optional tplname for the filler tpl)
   :Param(padding="2" optional padding width)
{
   my ($self, %params) = @_;
   
   assert $params{'id'}, "no pagination id defined!";
   my $p = $self->paginator($params{'id'});
   
   #... check if there exists a paginator for this id
   return "" unless $p;
   #... dont display the paginator for only one page
   return "" if $p->last_page <= 1;

   #... set default templates and values
   $params{'prev'} = exists $params{'prev'}
      ? $params{'prev'}
      : '/others/pagination/previous_page';
   $params{'next'} = exists $params{'next'}
      ? $params{'next'}
      : '/others/pagination/next_page';
   $params{'page'} = exists $params{'page'}
      ? $params{'page'}
      : '/others/pagination/page';
   $params{'actual_page'} = exists $params{'actual_page'}
      ? $params{'actual_page'}
      : '/others/pagination/actual_page';
   $params{'filler'} = exists $params{'filler'}
      ? $params{'filler'}
      : '/others/pagination/filler';
   $params{'container'} = exists $params{'container'}
      ? $params{'container'}
      : '/others/pagination/container';
   $params{'padding'} ||= 2;
   
   my $pagination = "";
   
   #... create prev link
   if ($p->page > 1 and $params{'prev'}) {
      $pagination .= $self->
         render_template($params{'prev'}, { 'page' => $p->page - 1 });
   }
   #... create first page
   my $tpl = (1 == $p->page) ? $params{'actual_page'} : $params{'page'};
   $pagination .= $self->render_template($tpl, { 'page' => 1 });      
   #... create first filler
   if (($p->page - $params{'padding'}) > 2) {
      $pagination .= $self->render_template($params{'filler'});
   }
   #... create mid pages
   foreach my $i (2 .. ($p->last_page - 1)) {
      next if $i < ($p->page - $params{'padding'});
      next if $i > ($p->page + $params{'padding'});
      my $tpl = $i == $p->page ? $params{'actual_page'} : $params{'page'};
      $pagination .= $self->render_template($tpl, { 'page' => $i });      
   }
   #... create last filler
   if (($p->page + $params{'padding'}) < ($p->last_page - 1)) {
      $pagination .= $self->render_template($params{'filler'});
   }
   #... create last page
   $tpl = ($p->last_page == $p->page)
      ? $params{'actual_page'}
      : $params{'page'};
   $pagination .= $self->render_template($tpl, { 'page' => $p->last_page });      
   #... create next link
   if ($p->last_page > $p->page and $params{'next'}) {
      $pagination .= $self->
         render_template($params{'next'}, { 'page' => $p->page + 1 });
   }
   
   return $self->
      render_template($params{'container'}, { 'pagination' => $pagination });
}
