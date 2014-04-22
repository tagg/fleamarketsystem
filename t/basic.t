use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('FleaMarket');
$t->get_ok('/')->status_is(200)->content_like(qr/Loppemarked/i);

done_testing();
