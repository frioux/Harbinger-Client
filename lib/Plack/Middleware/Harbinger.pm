package Plack::Middleware::Harbinger;

use Moo;

extends 'Plack::Middleware';
use Sereal::Encoder 'encode_sereal';
use Time::HiRes;
use DBIx::Class::QueryLog;
use namespace::clean;
use IO::Socket::INET;

has _harbinger_ip => (
   is => 'ro',
   default => '127.0.0.1',
   init_arg => 'harbinger_ip',
);

has _harbinger_port => (
   is => 'ro',
   default => '8001',
   init_arg => 'harbinger_port',
);

has _udp_handle => (
   is => 'ro',
   builder => sub {
      IO::Socket::INET->new(
         PeerAddr => $_[0]->_harbinger_ip,
         PeerPort => $_[0]->_harbinger_port,
         Proto => 'udp'
      ) or die "couldn't connect to socket: $@" # might make this not so lethal
   },
);

sub call {
   my ($self, $env) = @_;

   # this needs to somehow pass through / wrap the other logger too
   my $ql    = DBIx::Class::QueryLog->new;
   my $start = [ Time::HiRes::gettimeofday ];
   $env->{'harbinger.querylog'} = $ql;
   my $res = $self->app->($env);

   $self->response_cb($res, sub {
      my $elapsed = int(Time::HiRes::tv_interval($start) * 1000);

      my $msg = encode_sereal({
         server => $env->{'harbinger.server'},
         ident  => $env->{'harbinger.ident'} || $env->{PATH_INFO},
         pid    => $$,
         # include port

         ms     => $elapsed,
         qc     => $ql->count,
         # include memory growth
      });

      # seems appropriately defanged
      send($self->_udp_handle, $msg, 0) == length($msg)
         or warn "cannot send to: $!";
   })
}

1;
