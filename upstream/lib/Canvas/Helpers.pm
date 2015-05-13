#
# Copyright (C) 2013-2014   Ian Firns   <firnsy@kororaproject.org>
#                           Chris Smart <csmart@kororaproject.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
package Canvas::Helpers;

use Mojo::Base 'Mojolicious::Plugin';

#
# PERL INCLUDES
#
use Data::Dumper;
use List::Util qw(min max);
use List::MoreUtils qw(any);
use Mojo::Util qw(b64_decode b64_encode md5_sum trim url_escape);
use POSIX qw(floor);
use Time::Piece;

#
# LOCAL INCLUDES
#
use Canvas::Util::MultiMarkdown;
use Canvas::Store::User;
use Canvas::Store::UserMeta;

#
# CONSTANTS
#

use constant TAG_BLACKLIST => qw(an as at if in is of on or and the);

use constant DISTANCE_TIME_FORMAT => {
  less_than_x_seconds => {
    one   => "less than one second ago",
    other => "less than %d seconds ago",
  },
  less_than_x_minutes => {
    one   => "less than one minute ago",
    other => "less than %d minutes ago",
  },
  x_minutes           => {
    one   => "one minute ago",
    other => "%d minutes ago",
  },
  half_a_minute       => "half a minute ago",
  about_x_hours       => {
    one   => "about one hour ago",
    other => "about %d hours ago",
  },
  x_days              => {
    one   => "one day ago",
    other => "%d days ago",
  },
  about_x_months      => {
    one   => "about one month ago",
    other => "about %d months ago",
  },
  x_months            => {
    one   => "one month ago",
    other => "%d months ago",
  },
  about_x_years       => {
    one   => "about one year ago",
    other => "about %d years ago",
  },
  over_x_years        => {
    one   => "over one year ago",
    other => "over %d years ago",
  },
  almost_x_years      => {
    one   => "almost one year ago",
    other => "almost %d years ago",
  },
};

sub register {
  my( $self, $app ) = @_;

  $app->helper(exception_reaper => sub {
    my( $self, $exception, $req ) = @_;

    my $message = "WHOA!!! Shit's getting real!\n\n";

    # exception
    $message .= "ERROR:\n";
    $message .= sprintf "%s\n", $exception->message;

    $message .= "\nCONTEXT:\n";
    foreach my $line ( @{$exception->lines_before} ) {
      $message .= sprintf "%-8d =>    %s\n", $line->[0], $line->[1];
    }

    if( defined $exception->line->[1] ) {
      $message .= sprintf "\n%-8d =>    %s\n\n", $exception->line->[0], $exception->line->[1];
    }

    foreach my $line (@{$exception->lines_after}) {
      $message .= sprintf "%-8d =>    %s\n", $line->[0], $line->[1];
    }

    if( defined $exception->line->[2] ) {
      $message .= "\n\nINSIGHT:\n";
      foreach my $line (@{$exception->lines_before}) {
        $message .= sprintf "%-8d =>    %s\n", $line->[0], $line->[2];
      }

      $message .= sprintf "\n%-8d =>    %s\n", $exception->line->[0], $exception->line->[2];
    }

    if (@{$exception->frames}) {
      $message .= "\nFRAMES:\n";
      foreach my $frame (@{$exception->frames}) {
        $message .= sprintf "%s:%d\n", $frame->[1], $frame->[2];
      }
    }

    # request
    $message .= "\nREQUEST:\n";

    $message .= sprintf "Method     => %s\n", $req->method;
    $message .= sprintf "URL        => %s\n", $req->url->to_string;
    $message .= sprintf "Base URL   => %s\n", $req->url->base->to_string;
    $message .= sprintf "Parameters => %s\n", Dumper $req->params->to_hash;
    $message .= sprintf "Session    => %s\n", Dumper $self->session;
    $message .= sprintf "Version    => %s\n", $req->version;

    $message .= "Headers => \n";
    foreach my $name ( @{$self->req->headers->names} ) {
      my $value = $self->req->headers->header($name);
      $message .= sprintf "  - %s: %s\n", $name, $value;
    }

    # versions
    $message .= sprintf "\nPERL VERSION:\n%s (%s)\n", $^V, $^O;
    $message .= sprintf "\nMOJO VERSION:\nv%s (%s)\n", $Mojolicious::VERSION, $Mojolicious::CODENAME;

    # home
    $message .= sprintf "\nHOME: %s\n", $app->home->to_string;

    # include
    $message .= "\nINCLUDES:\n";
    foreach my $inc ( @INC ) {
      $message .= sprintf "  - %s\n", $inc;
    }

    # PID
    $message .= sprintf "\nPID: %d\n", $$;

    # name
    $message .= sprintf "\nNAME: %s\n", $0;

    # executable
    $message .= sprintf "\nEXECUTABLE: %s\n", $^X;

    # time
    $message .= sprintf "\nTIME: %s\n", gmtime->datetime;

    # footer
    $message .= "\n" .
                "Good Luck!\n" .
                "--\n" .
                "Canvas CoreBOT";

    unless( $exception->{message} eq 'render_only' ) {
      $self->mail(
        from    => 'matrix@kororaproject.org',
        to      => 'webmaster@kororaproject.org',
        subject => 'Core Exception!',
        data    => $message,
      );
    }

  });

  $app->helper(ub64_decode => sub {
    my ($self, $in) = @_;

    return undef unless $in;

    $in =~ tr|-_~|+/=|;
    my $out = b64_decode($in);

    return $out;
  });

  $app->helper(ub64_encode => sub {
    my ($self, $in) = @_;

    return undef unless $in;

    my $out = b64_encode($in);
    $out =~ tr|+/=|-_~|;

    return $out;
  });

  $app->helper(sanitise_with_dashes => sub {
    my ($self, $stub) = @_;

    $stub = trim $stub;

    # preserve escaped octets
    $stub =~ s|%([a-fA-F0-9][a-fA-F0-9])|---$1---|g;
    # remove percent signs that are not part of an octet
    $stub =~ s/%//g;
    # restore octets.
    $stub =~ s|---([a-fA-F0-9][a-fA-F0-9])---|%$1|g;

    $stub = lc $stub;

    # kill entities
    $stub =~ s/&.+?;//g;
    $stub =~ s/\./-/g;

    $stub =~ s/[^%a-z0-9 _-]//g;
    $stub =~ s/\s+/-/g;
    $stub =~ s|-+|-|g;
    $stub =~ s/-+$//g;

    return $stub;
  });

  $app->helper(sanitise_taglist => sub {
    my ($self, $taglist) = @_;

    my %tags = map { trim($_) => 1 }
                 grep { $_ }
                   map  { $self->sanitise_with_dashes($_) }
                     split /[ ,]+/, $taglist;

    # scrub stupidness
    foreach my $t (TAG_BLACKLIST) {
      delete $tags{$t};
    }


    return [ keys %tags ];
  });

  $app->helper(is_active_auth => sub {
    my( $self ) = @_;

    return 0 unless defined $self->auth_user;

    return 0 unless $self->auth_user->is_active_account;

    return 1
  });

  $app->helper(paginate => sub {
    my ($self, $pager) = (shift, shift);

    my $items     = $pager->{item_count}  // 0;
    my $page_size = $pager->{page_size}   // 0;
    my $page      = $pager->{page}        // 1;
    my $page_last = $pager->{page_last}   // 0;

    my $page_prev = $page - 1;
    my $page_next = $page + 1;
    my $page_lm1  = $page_last - 1;

    my $adjacents = 2;


    # only build if we have more than one page
    if ($page_last > 1) {
      my $page_show_max = 6;
      my $url = $self->url_with;

      my @template;
      my $p = 0;

      #
      # add "first" marker
      #push @template, '<li class="' . ( ($page > $page_show_max) ? '' : 'disabled' ) . '"><a href="' . $url->query([ page => ($page-$page_show_max>1) ? ($page-$page_show_max) : 1]) . '"><i class="fa fa-fw fa-angle-double-left"></i></a></li>';

      #
      # add "previous" marker
      if ($page > 1) {
        push @template, sprintf('<li><a href="%s"><i class="fa fa-fw fa-angle-left"></i></a></li>', $url->query([page => $page_prev]));
      }
      else {
        push @template, '<li class="disabled"><span><i class="fa fa-fw fa-angle-left"></i></span></li>';
      }

      # not enough pages to bother breaking it up
      if ($page_last < 7 + ($adjacents * 2)) {
        foreach $p (1..$page_last) {
          push @template, sprintf('<li class="%s"><a href="%s">%s</a></li>', (($p == $page) ? 'active': ''), $url->query([page => ($p > 1) ? $p : undef]), $p);
        }
      }
      # enough pages to hide some
      elsif ($page_last > 5 + ($adjacents * 2)) {
        # close to beginning; only hide later pages
        if ($page < 1 + ($adjacents * 2)) {
          for ($p = 1; $p < 4 + ($adjacents * 2); $p++) {
            push @template, sprintf('<li class="%s"><a href="%s">%s</a></li>', (($p == $page) ? 'active': ''), $url->query([page => ($p > 1) ? $p : undef]), $p);
          }
          push @template, sprintf('<li><span>...</span></li>');
          push @template, sprintf('<li class="%s"><a href="%s">%s</a></li>', '', $url->query([page => $page_lm1]), $page_lm1);
          push @template, sprintf('<li class="%s"><a href="%s">%s</a></li>', '', $url->query([page => $page_last]), $page_last);
        }
        # in middle; hide some front and some back
        elsif ($page_last - ($adjacents * 2) > $page && $page > ($adjacents * 2)) {

          push @template, sprintf('<li class="%s"><a href="%s">%s</a></li>', '', $url->query([page => 1]), '1');
          push @template, sprintf('<li class="%s"><a href="%s">%s</a></li>', '', $url->query([page => 2]), '2');
          push @template, sprintf('<li><span>...</span></li>');

          for ($p = $page - $adjacents; $p <= $page + $adjacents; $p++) {
            push @template, sprintf('<li class="%s"><a href="%s">%s</a></li>', (($p == $page) ? 'active': ''), $url->query([page => ($p > 1) ? $p : undef]), $p);
          }

          push @template, sprintf('<li><span>...</span></li>');
          push @template, sprintf('<li class="%s"><a href="%s">%s</a></li>', '', $url->query([page => $page_lm1]), $page_lm1);
          push @template, sprintf('<li class="%s"><a href="%s">%s</a></li>', '', $url->query([page => $page_last]), $page_last);
        }
        # close to end; only hide early pages
        else { 

          push @template, sprintf('<li class="%s"><a href="%s">%s</a></li>', '', $url->query([page => 1]), '1');
          push @template, sprintf('<li class="%s"><a href="%s">%s</a></li>', '', $url->query([page => 2]), '2');
          push @template, sprintf('<li><span>...</span></li>');

          for ($p = $page_last - (2 + ($adjacents * 2)); $p <= $page_last; $p++) {
            push @template, sprintf('<li class="%s"><a href="%s">%s</a></li>', (($p == $page) ? 'active': ''), $url->query([page => ($p > 1) ? $p : undef]), $p);
          }
        }
      }


      # add "next" marker
      if ($page < $page_last) {
        push @template, sprintf('<li><a href="%s"><i class="fa fa-fw fa-angle-right"></i></a></li>', $url->query([page => $page_next]));
      }
      else {
        push @template, '<li class="disabled"><span><i class="fa fa-fw fa-angle-right"></i></span></li>';
      }

      # add "last" marker
      #push @template,'<li class="' . (($page+$page_show_max < $page_last) ? '' : 'disabled') . '"><a href="' . $url->query([ page => ($page+$page_show_max < $page_last ? $page+$page_show_max : $page_last)]) . '"><i class="fa fa-fw fa-angle-double-right"></i></a></li>';

      return '<ul class="pagination pagination-sm">' . join('', @template) . '</ul>';
    }

    return '';
  });

  $app->helper(render_markdown => sub {
    my( $self, $post ) = @_;

    my $m = Canvas::Util::MultiMarkdown->new(
      tab_width   => 2,
      heading_ids => 0,
      img_ids     => 0,
    );

    return $m->markdown( $post );
  });

  $app->helper(build_query => sub {
    my $self = shift;
    my $map = shift;

    return {} unless( ref( $map ) eq 'HASH' );

    my $q = {};

    while( my ( $k, $v ) = each %{ $map } ) {
      foreach my $r ( @{ $v } ) {
        $q->{ $k } = $self->param( $r ) if defined( $self->param( $r ) );
      }
    }

    return $q;
  });

  $app->helper(email_gravatar => sub {
    my ($self, $email, $size, $class) = @_;

    $email  //= '';
    $size   //= 32;
    $class  //= '';

    return sprintf('<img src="//www.gravatar.com/avatar/%s.jpg?s=%d&amp;d=retro" class="%s" alt="">', md5_sum($email), $size, $class);
  });

  $app->helper(pluralise => sub {
    my ($self, $amount, $unit) = @_;

    if ($amount ne '1') {
      $unit .= 's';
      $unit =~ s/os$/oes/;
      $unit =~ s/([^aeiou])ys$/$1ies/;
    }

    return $amount . ' ' . $unit;
  });


  # time prettifier
  $app->helper(locale_time => sub {
    my ($self, $label, $count) = @_;

    if (defined $count) {
      my $plural = "other";

      if ($count == 1 && exists DISTANCE_TIME_FORMAT->{$label}{one}) {
        $plural = 'one';
      }
      elsif( $count < 1 && exists DISTANCE_TIME_FORMAT->{$label}{zero} ) {
        $plural = 'zero';
      }

      return sprintf(DISTANCE_TIME_FORMAT->{$label}{$plural}, $count);
    }

    return DISTANCE_TIME_FORMAT->{$label};
  });

  # time prettifier
  $app->helper(distance_of_time_in_words => sub {
    my ($self, $from_time, $to_time) = (shift, shift, shift);
    my %options = @_;

    $from_time = Time::Piece->strptime($from_time, '%s') unless ref($from_time) eq 'Time::Piece';

    return 'not sure' unless ref $from_time eq 'Time::Piece';

    $to_time //= gmtime;

    my $distance = $to_time - $from_time;
    my $distance_in_minutes = floor($distance->minutes);
    my $distance_in_seconds = $distance->seconds - ( $distance_in_minutes * 60 );

    if( any { $distance_in_minutes == $_ } (0..1) ) {
      unless( $options{include_seconds} ) {
        return $distance_in_minutes == 0 ?
          $self->locale_time('less_than_x_minutes', 1) :
          $self->locale_time('x_minutes', $distance_in_minutes);
      }

      if( any { $distance_in_seconds == $_ } (0..4) ) {
        return $self->locale_time('less_than_x_seconds', 5);
      }
      elsif( any { $distance_in_seconds == $_ } (5..9) ) {
        return $self->locale_time('less_than_x_seconds', 10);
      }
      elsif( any { $distance_in_seconds == $_ } (10..19) ) {
        return $self->locale_time('less_than_x_seconds', 20);
      }
      elsif( any { $distance_in_seconds == $_ } (20..39) ) {
        return $self->locale_time('half_a_minute');
      }
      elsif( any { $distance_in_seconds == $_ } (40..59) ) {
        return $self->locale_time('less_than_x_minutes', 1);
      }
      else {
        return $self->locale_time('x_minutes', 1);
      }
    }
    elsif( any { $distance_in_minutes == $_ } (2..44) ) {
      return $self->locale_time('x_minutes', $distance_in_minutes);
    }
    elsif( any { $distance_in_minutes == $_ } (45..89) ) {
      return $self->locale_time('about_x_hours', 1);
    }
    elsif( any { $distance_in_minutes == $_ } (90..1439) ) {
      return $self->locale_time('about_x_hours', floor($distance_in_minutes / 60.0) );
    }
    elsif( any { $distance_in_minutes == $_ } (1440..2519) ) {
      return $self->locale_time('x_days', 1);
    }
    elsif( any { $distance_in_minutes == $_ } (2520..43199) ) {
      return $self->locale_time('x_days', floor($distance_in_minutes / 1440.0));
    }
    elsif( any { $distance_in_minutes == $_ } (43200..86399) ) {
      return $self->locale_time('about_x_months', 1);
    }
    elsif( any { $distance_in_minutes == $_ } (86400..525599) ) {
      return $self->locale_time('x_months', floor($distance_in_minutes / 43200.0) );
    }
    else {
      my $remainder         = ($distance_in_minutes % 525600);
      my $distance_in_years = floor($distance->years);

      if ($remainder < 131400) {

        say Dumper $distance_in_years;
        return $self->locale_time('about_x_years',  $distance_in_years);
      }
      elsif( $remainder < 394200 ) {
        return $self->locale_time('over_x_years',   $distance_in_years);
      }
      else {
        return $self->locale_time('almost_x_years', $distance_in_years + 1);
      }
    }
  });

  # notify users on key
  $app->helper(notify_users => sub {
    my ($c, $channel, $value, $from, $subject, $message) = @_;

    return unless length trim $channel;

    $value //= 1;

    my $emails = $c->pg->db->query("SELECT u.email FROM users u JOIN usermeta um ON (um.user_id=u.id) WHERE um.meta_key=? AND um.meta_value=?", $channel, $value)->arrays;

    foreach my $e (@{$emails}) {
      # send the message
      $c->mail(
        from    => $from,
        to      => $e->[0],
        subject => $subject,
        data    => $message,
      );
    }
  });
}

1;
