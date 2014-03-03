package FleaMarket;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('controller#index');

  $r->get('/hjaelper')->to('controller#hjaelper');
  $r->post('/hjaelper')->to('controller#hjaelperpost');

  $r->get('/hjaelperdata')->to('controller#hjaelperdata');
}

1;
