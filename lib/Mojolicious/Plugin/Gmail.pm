package Mojolicious::Plugin::Gmail;
use Mojo::Base 'Mojolicious::Plugin';

use Gmail;

use constant TEST     => $ENV{MOJO_MAIL_TEST} || 0;
use constant FROM     => 'test-mail-plugin@mojolicio.us';
use constant CHARSET  => 'UTF-8';
use constant ENCODING => 'base64';

our $VERSION = '1.1';

has conf => sub { +{} };

sub register {
  my ($plugin, $app, $conf) = @_;

  # default values
  $conf->{from    } ||= FROM;
  $conf->{charset } ||= CHARSET;
  $conf->{encoding} ||= ENCODING;

  $plugin->conf( $conf ) if $conf;

  $app->helper(
    mail => sub {
      my $self = shift;
      my $args = @_ ? { @_ } : return;

      # simple interface
      unless (exists $args->{mail}) {
        $args->{mail}->{ $_->[1] } = delete $args->{ $_->[0] }
          for grep $args->{ $_->[0] },
            [to   => 'To'  ], [from => 'From'], [reply_to => 'Reply-To'],
            [cc   => 'Cc'  ], [bcc  => 'Bcc' ], [subject  => 'Subject' ],
            [data => 'Data'], [type => 'Type'],
        ;
      }

      # hidden data and subject
      my @stash =
        map  { $_ => $args->{$_} }
        grep { !/^(to|from|reply_to|cc|bcc|subject|data|type|test|mail|attach|headers|attr|charset|mimeword|nomailer)$/ }
        keys %$args
      ;

      $args->{mail}->{Data   } ||= $self->render_mail(@stash);
      $args->{mail}->{Subject} ||= $self->stash ('subject');

      my $msg  = $plugin->build( %$args );
      my $test = $args->{test} || TEST;
      $msg->send( $conf->{'how'}, @{$conf->{'howargs'}||[]} ) unless $test;

      $msg->as_string;

      my $mail = Gmail->new(
        smtp  => $conf->{'smtp'},
        login => $conf->{'login'},
        pass  => $conf->{'pass'},
        port  => $conf->{'port'}
        layer => $conf->{'layer'},
        debug => 1,
      );

      my $ret = $mail->send(
        to          => $args->{mail}->{To},
        from        => $args->{mail}->{From},
        replyto     => $args->{mail}->{From},
        subject     => $args->{mail}->{Subject},
        body        => $args->{Mail}->{Data}
      );
    },
  );
}
1;
