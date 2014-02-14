package Catalyst::TraitFor::Controller::Harbinger;

use Moose::Role;

around auto => sub {
   my ($orig, $self, $c, @rest) = @_;

   my $env = $c->engine->env;
   my $req = $c->request;
   $env->{'harbinger.ident'} = $req->action;
   $env->{'harbinger.server'} = $c->config->{server};
   $c->model('DB')->storage->debugobj->replace_logger(
      harbinger => $env->{'harbinger.querylog'},
   );
   $c->model('DB')->storage->debug(1);

   $self->$orig($c, @rest);
};

1;
