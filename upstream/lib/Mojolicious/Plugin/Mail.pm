package Mojolicious::Plugin::Mail;
use Mojo::Base 'Mojolicious::Plugin';

use MIME::Lite;
use Mojo::ByteStream 'b';

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
    },
  );

  $app->helper(
    render_mail => sub {
      my $self = shift;
      my $data = $self->render(@_, format => 'mail', partial => 1);

      delete @{$self->stash}{ qw(partial cb format mojo.captures mojo.started mojo.content mojo.routed) };
      $data;
    },
  );
}

sub build {
  my $self = shift;
  my $conf = $self->conf;
  my $p    = { @_ };

  my $mail     = $p->{mail};
  my $charset  = $p->{charset } || $conf->{charset };
  my $encoding = $p->{encoding} || $conf->{encoding};
  my $encode   = $encoding eq 'base64' ? 'B' : 'Q';
  my $mimeword = defined $p->{mimeword} ? $p->{mimeword} : !$encoding ? 0 : 1;

  # tuning

  $mail->{From} ||= $conf->{from} || '';
  $mail->{Type} ||= $conf->{type} || '';

  if ($mail->{Data} && $mail->{Type} !~ /multipart/) {
    $mail->{Encoding} ||= $encoding;
    _enc($mail->{Data} => $charset);
  }

  # year, baby!

  my $msg = MIME::Lite->new( %$mail );

  # header
  $msg->delete('X-Mailer'); # remove default MIME::Lite header

  $msg->add   ( %$_ ) for @{$p->{headers} || []}; # XXX: add From|To|Cc|Bcc => ... (mimeword)
  $msg->add   ('X-Mailer' => join ' ', 'Mojolicious',  $Mojolicious::VERSION, __PACKAGE__, $VERSION, '(Perl)')
    unless $msg->get('X-Mailer') || $p->{nomailer};

  # attr
  $msg->attr( %$_ ) for @{$p->{attr   } || []};
  $msg->attr('content-type.charset' => $charset) if $charset;

  # attach
  $msg->attach( %$_ ) for
    grep {
      if (!$_->{Type} || $_->{Type} =~ /text/i) {
        $_->{Encoding} ||= $encoding;
        _enc($_->{Data} => $charset);
      }
      1;
    }
    grep { $_->{Data} || $_->{Path} }
    @{$p->{attach} || []}
  ;

  $msg;
}

sub _enc($$) {
  my $charset = $_[1] || CHARSET;
  $_[0] = b($_[0])->encode('UTF-8')->to_string if $_[0] && $charset && $charset =~ /utf-8/i;
  $_[0];
}

1;
