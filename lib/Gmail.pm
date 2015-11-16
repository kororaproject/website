package Gmail;

use strict;
use warnings;

use feature ':5.10';

use Data::Dumper;
#
# PERL INCLUDES
#
use Net::SMTPS;
use Net::SMTP;
use MIME::Base64;
use File::Spec qw(basename);
use Time::Piece;

sub new {
  my $class = shift;

  my %args = @_ ? ref @_ eq 'HASH' ? %{$_[0]} : (@_) : {};

  # ensure minimum args
  # login
  # pass
  # smtp (address)

  my $self = bless {
    sender    => undef,
    connected => 0,
    debug   => $args{'debug'}   // 0,
    smtp    => $args{'smtp'}    // 'smtp.gmail.com',
    port    => $args{'port'},
    layer   => $args{'layer'}   // 'tls', # ssl/tls, starttls, none
    auth    => $args{'auth'}    // 'LOGIN',
    from    => $args{'from'}    // $args{'login'},
    login   => $args{'login'},
    pass    => $args{'pass'},
    timeout => $args{'timeout'} // 60,
    ssl_verify_mode => $args{'ssl_verify_mode'} // '',
    ssl_ca_file => $args{'ssl_ca_file'} // '',
    ssl_ca_path => $args{'ssl_ca_path'}   // '',
  }, $class;

  # set port if default
  unless ($self->{port}) {
    $self->{port} = 25;
    $self->{port} = 465 if ($self->{layer} eq 'ssl');
    $self->{port} = 587 if ($self->{layer} eq 'starttls');
  }

  # ensure sane defaults
  $self->connect;

  return -1, $self->{error} if defined $self->{error};

  return $self;
}


sub banner {
  return shift->{sender}->banner;
}

sub bye {
  my $self = shift;
  $self->{sender}->quit;
}

sub connect {
  my $self = shift;

  # The module sets the SMTP google but could use another!
  printf("Connecting to %s using %s with %s and timeout of %s\n", $self->{smtp}, $self->{layer}, $self->{auth}, $self->{timeout}) if $self->{debug};

  my $l = $self->{layer};

  # Set security layer from $layer
  if (!defined($l) || $l eq 'none') {
    $self->{sender} = Net::SMTP->new(
      $self->{smtp},
      Debug   => $self->{debug},
      Port    => $self->{port},
      Timeout => $self->{timeout}
    );
  }
  else {
    $self->{sender} = Net::SMTPS->new(
      $self->{smtp},
      Debug           => $self->{debug},
      doSSL           => ($l eq 'tls') ? 'starttls' : ($l eq 'ssl') ? 'ssl' : undef,
      Port            => $self->{port},
      SSL_ca_file     => $self->{ssl_ca_file},
      SSL_ca_path     => $self->{ssl_ca_path},
      SSL_verify_mode => $self->{ssl_verify_mode},
      Timeout         => $self->{timeout},
    );
  }

  unless ($self->{sender}) {
    $self->{error} = sprintf "Could not connect to SMTP server (%s:%s)", $self->{smtp}, $self->{port};
    print $self->{error} . "\n" if $self->{debug};
  }

  unless($self->{auth} eq 'none') {
    $self->{error} = $self->{sender}->message unless $self->{sender}->auth(
      $self->{login},
      $self->{pass},
      $self->{auth}
    );
  }

  return !!$self->{sender};
}

sub send {
  my $self = shift;
  my %args = @_; # rest of params by hash

  my $verbose = $args{'verbose'} // 0;

  # Load all the email param
  my $mail = {};

  $mail->{to} = $args{'to'} // '';

#  if ($mail->{to} eq '') {
#    print "No RCPT found. Please add the TO field\n";
#    $self->{error} ='No RCPT found. Please add the TO field';
#    return undef;
#  }

  $mail->{from}    = $args{'from'}      // $self->{from};
  $mail->{replyto} = $args{'replyto'}   // $mail->{from};
  $mail->{cc}      = $args{'cc'}        // '';
  $mail->{bcc}     = $args{'bcc'}       // '';
  $mail->{charset} = $args{'charset'}   // 'UTF-8';

  $mail->{type}    = $args{'type'}      // 'text/plain';
  $mail->{subject} = $args{'subject'}   // '';
  $mail->{body}    = $args{'body'}      // '';

  $mail->{attachments} = _check_attachments( $args{'attachments'} // [] );

  my $boundary = 'gmail-boundary-' . gmtime->epoch;

  $self->{sender}->mail($mail->{from} . "\n");

  # add all our recipients to the list
  for my $recipients ( ($mail->{to}, $mail->{cc}, $mail->{bcc}) ) {
    unless ($self->{sender}->recipient(split(/;/, $recipients))) {
      $self->{error} = $self->{sender}->message;
      $self->{sender}->reset;
      return '';
    }
  }

  $self->{sender}->data;

  # send header
  $self->{sender}->datasend("From: " . $mail->{from} . "\n");
  $self->{sender}->datasend("To: " . $mail->{to} . "\n");
  $self->{sender}->datasend("Cc: " . $mail->{cc} . "\n") if ($mail->{cc} ne '');
  $self->{sender}->datasend("Reply-To: " . $mail->{replyto} . "\n");
  $self->{sender}->datasend("Subject: " . $mail->{subject} . "\n");
  $self->{sender}->datasend("Date: " . localtime->strftime("%a, %d %b %Y %T %z"). "\n");

  # check for attachments
  if (scalar @{$mail->{attachments}}) {
    print "With Attachments\n" if $verbose;
    $self->{sender}->datasend("MIME-Version: 1.0\n");
    $self->{sender}->datasend("Content-Type: multipart/mixed; BOUNDARY=\"$boundary\"\n");

    # Send text body
    $self->{sender}->datasend("\n--$boundary\n");
    $self->{sender}->datasend("Content-Type: ".$mail->{type}."; charset=".$mail->{charset}."\n");

    $self->{sender}->datasend("\n");
    $self->{sender}->datasend($mail->{body} . "\n\n");

    my $attachments=$mail->{attachmentlist};
    foreach my $file (@$attachments) {
      my($bytesread, $buffer, $data, $total);

      $file=~s/\A[\s,\0,\t,\n,\r]*//;
      $file=~s/[\s,\0,\t,\n,\r]*\Z//;

      my $opened=open(my $f,'<',$file);
      binmode($file);
      while (($bytesread = sysread($f, $buffer, 1024)) == 1024) {
        $total += $bytesread;
        $data .= $buffer;
      }
      if ($bytesread) {
        $data .= $buffer;
        $total += $bytesread;
      }
      close $f;
      # Get the file name without its directory
      my $filename = basename($file);
      # Get the MIME type
      my $type = 'meh'; #guess_media_type($file);
      print "Composing MIME with attach $file\n" if $self->{debug};
      if ($data) {
        $self->{sender}->datasend("--$boundary\n");
        $self->{sender}->datasend("Content-Type: $type; name=\"$filename\"\n");
        $self->{sender}->datasend("Content-Transfer-Encoding: base64\n");
        $self->{sender}->datasend("Content-Disposition: attachment; =filename=\"$filename\"\n\n");
        $self->{sender}->datasend(encode_base64($data));
        $self->{sender}->datasend("--$boundary\n");
      }
    }

    $self->{sender}->datasend("\n--$boundary--\n"); # send endboundary end message
  }

  # no attachments
  else {
    # send text body
    $self->{sender}->datasend("MIME-Version: 1.0\n");
    $self->{sender}->datasend("Content-Type: " . $mail->{type}. "; charset=" . $mail->{charset} . "\n");

    $self->{sender}->datasend("\n");
    $self->{sender}->datasend($mail->{body}."\n\n");
  }

  $self->{sender}->datasend("\n");

  unless ($self->{sender}->dataend) {
    $self->{error} = $self->{sender}->message;
    print "Sorry, there was an error during sending. Please, retry or use Debug\n" if $self->{debug};
    return undef;
  }

  return 1;
}

sub _check_attachments {
# Checks that all the attachments exist
  my $self = shift;
  my $attachments = shift;

  my $result = [];

  foreach my $file (@$attachments) {
    $file =~ s/\A[\s,\0,\t,\n,\r]*//;
    $file =~ s/[\s,\0,\t,\n,\r]*\Z//;

    unless (-f $file ) {
      print "Unable to find the attachment file: $file (removed from list)\n" if $self->{debug};
    }
    else {
      if ( open(my $f, '<', $file) ) {
        push @{$result}, $file;
        close $f;
        print "Attachment file: $file added\n" if $self->{debug};
      }
      else {
        print "Unable to open the attachment file: $file (removed from list)\n" if $self->{debug};
      }
    }
  }

  return $result;
}

1;
