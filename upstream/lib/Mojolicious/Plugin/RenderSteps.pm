package Mojolicious::Plugin::RenderSteps;

use Mojo::Base 'Mojolicious::Plugin';

our $VERSION = '0.01';

sub register {
  my ($self, $app) = @_;
  $app->helper(
    render_steps => sub {
      my ($self, $template, @steps) = @_;

      my $tx = $self->tx;
      $self->render_later;
      $self->stash->{'rendersteps.depth'}++;

      my $delay = Mojo::IOLoop->delay(@steps);

      # special handling for redirects
      $delay->on(redirect => sub { 
        $self->stash->{'rendersteps.redirect'} = pop;

        # drop remaining steps since we're redirecting
        $delay->remaining([]);
      });

      # render exceptions on error
      $delay->on(error => sub {
        $self->reply->exception(pop)
      });

      $delay->on(finish => sub {
          unless (--$self->stash->{'rendersteps.depth'}) {
            if ($self->stash->{'rendersteps.redirect'}) {
              $self->redirect_to($self->stash->{'rendersteps.redirect'});
            }
            else {
              $self->render_maybe($template)
                or $self->reply->not_found
            }
          }

          undef $tx;
        }
      );

      $delay->wait unless Mojo::IOLoop->is_running;
    }
  );
}

1;
