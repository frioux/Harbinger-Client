package Harbinger::Client;

use Moo;
use warnings NONFATAL => 'all';

use Harbinger::Client::Measurement;
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
   lazy => 1,
   builder => sub {
      IO::Socket::INET->new(
         PeerAddr => $_[0]->_harbinger_ip,
         PeerPort => $_[0]->_harbinger_port,
         Proto => 'udp'
      ) or warn "couldn't connect to socket: $@"
   },
);

has _default_args => (
   is => 'ro',
   default => sub { [] },
   init_arg => 'default_args',
);

sub start {
   my $self = shift;

   Harbinger::Client::Measurement->start(
      @{$self->_default_args},
      @_,
   )
}

sub instant {
   my $self = shift;

   $self->send(
      Harbinger::Client::Measurement->new(
         @{$self->_default_args},
         @_,
      )
   )
}

sub send {
   my ($self, $doom) = @_;

   return unless
      my $msg = $doom->as_sereal;

   # seems appropriately defanged
   send($self->_udp_handle, $msg, 0) == length($msg)
      or warn "cannot send to: $!";
}

1;
