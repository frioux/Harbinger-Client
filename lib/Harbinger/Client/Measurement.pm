package Harbinger::Client::Measurement;

use List::Util 'first';
use Module::Runtime 'use_module';
use Sereal::Encoder 'encode_sereal';
use Try::Tiny;
use Time::HiRes;
use Moo;

sub _measure_memory {
   my $pid = shift;

   my $ret = try {
      if ($^O eq 'MSWin32') {
         use_module('Win32::Process::Memory')
            ->new({ pid  => $pid })
            ->get_memtotal
      } else {
         (
            first { $_->pid == $pid } @{
               use_module('Proc::ProcessTable')
               ->new
               ->table
            }
         )->rss
      }
   } catch { 0 };

   int($ret / 1024)
}

use namespace::clean;

has server => ( is => 'rw' );
has ident => ( is => 'rw' );

has pid => (
   is => 'rw',
   default => sub { $$ },
);

has count => ( is => 'rw' );

has port => ( is => 'rw' );

has milliseconds_elapsed => (
   is => 'rw',
   default => 0,
);

has db_query_count => (
   is => 'rw',
   default => 0,
);
has memory_growth_in_kb => (
   is => 'rw',
   default => sub { _measure_memory($$) },
);

has _start_time => ( is => 'rw' );
has _start_kb => ( is => 'rw' );
has _ql => ( is => 'rw' );

sub start {
   my ($self, @args) = @_;

   shift->new({
      _start_time => [ Time::HiRes::gettimeofday ],
      _start_kb => _measure_memory($$),
      _ql => use_module('DBIx::Class::QueryLog')->new,
      @args,
   })
}

sub finish {
   my ($self, %args) = @_;

   $self->milliseconds_elapsed(
      int(Time::HiRes::tv_interval($self->_start_time) * 1000)
   );
   $self->db_query_count($self->_ql->count);
   $self->memory_growth_in_kb(_measure_memory($self->pid) - $self->_start_kb);
   $self->$_($args{$_}) for keys %args;

   return $self
}

sub as_sereal {
   my $self = shift;

   return encode_sereal({
      server => $self->server,
      ident  => $self->ident,
      pid    => $self->pid,
      port   => $self->port,

      ms     => $self->milliseconds_elapsed,
      qc     => $self->db_query_count,
      mg     => $self->memory_growth_in_kb,
      c      => $self->count,
   })
}

1;
