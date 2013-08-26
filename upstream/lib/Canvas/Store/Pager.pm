#
# Copyright (C) 2013    Ian Firns   <firnsy@kororaproject.org>
#                       Chris Smart <csmart@kororaproject.org>
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
package Canvas::Store::Pager;
use strict;
use warnings;

use Carp;
use Canvas::Util::Abstract;
use Data::Dumper;

use vars qw( $VERSION );

$VERSION = '0.566';

sub import {
  my( $class ) = @_; # the pager class or subclass

  my $caller;

  # find the app - supports subclassing (My::Pager is_a CDBI::P::Pager, not_a CDBI)
  foreach my $level ( 0 .. 10 ) {
    $caller = caller( $level );
    last if UNIVERSAL::isa( $caller, 'Class::DBI' )
  }

  warn( "can't find the CDBI app" ), return unless $caller;
  #croak( "can't find the CDBI app" ) unless $caller;

  no strict 'refs';
  *{"$caller\::pager"} = \&pager;
}

sub pager {
  my $cdbi = shift;

  my $class = __PACKAGE__;

  my $self = bless {
    __pager_cdbi_app          => $cdbi,
    __pager_entries_per_page  => 100,
    __pager_current_page      => 0,
    __pager_first_page        => 0,
    __pager_last_page         => 0,
    __pager_total_entries     => 0,
    __pager_where             => {},
  }, $class;

  $self->_init( @_ );

  return $self;
}

# _init is also called by results, so preserve any existing settings if
# new settings are not provided
sub _init {
  my $self = shift;

  return unless @_;

  my( $where, $order_by, $per_page, $page );

  if( ref( $_[0] ) or $_[0] =~ /^\d+$/ ) {
    $where    = shift if ref $_[0]; # SQL::Abstract accepts a hashref or an arrayref

    $order_by = shift unless( defined($_[0]) && $_[0] =~ /^\d+$/ );
    $per_page = shift if( defined($_[0]) && $_[0] =~ /^\d+$/ );
    $page     = shift if( defined($_[0]) && $_[0] =~ /^\d+$/ );
  }
  else {
    my %args  = @_;

    $where    = $args{where};
    $order_by = $args{order_by};
    $per_page = $args{entries_per_page};
    $page     = $args{current_page};
  }

  # Emulate AbstractSearch's search_where ordering -VV 20041209
#  $order_by = delete $$abstract_attr{order_by} if ($abstract_attr and !$order_by);

  $self->entries_per_page( $per_page )  if $per_page;
  $self->where( $where )                if $where;
  $self->order_by( $order_by )          if $order_by;
  $self->current_page( $page )          if $page;
}

=item search_where

Retrieves results from the pager. Accepts the same arguments as the C<pager>
method.

=cut

# like CDBI::AbstractSearch::search_where, with extra limitations
sub search_where {
  my $self = shift;

  $self->_init( @_ );
  $self->_setup_pager;

  my $cdbi = $self->{__pager_cdbi_app};

  my $order_by  = $self->order_by || [ $cdbi->primary_columns ];
  my $where     = $self->where;
  my $sql       = Canvas::Util::Abstract->new();

  $order_by = [ $order_by ] unless ref $order_by;
  my( $phrase, @bind ) = $sql->where( $where, $order_by );

  # If the phrase starts with the ORDER clause (i.e. no WHERE spec), then we are
  # emulating a { 1 => 1 } search, but avoiding the bug in Class::DBI::Plugin::AbstractCount 0.04,
  # so we need to replace the spec - patch from Will Hawes
  if( $phrase =~ /^\s*ORDER\s*/i ) {
    $phrase = ' 1=1' . $phrase;
  }

  # add paged limit and offset
  if( $self->{__pager_total_entries} ) {
    $phrase .= ' LIMIT ' . $self->{__pager_entries_per_page};
    $phrase .= ' OFFSET ' . ( $self->{__pager_entries_per_page} * $self->{__pager_current_page} ) . ' ';
  };

  $phrase =~ s/^\s*WHERE\s*//i;

  return $cdbi->retrieve_from_sql( $phrase, @bind );
}

=item retrieve_all

Convenience method, generates a WHERE clause that matches all rows from the table.

Accepts the same arguments as the C<pager> or C<search_where> methods, except that no
WHERE clause should be specified.

Note that the argument parsing routine called by the C<pager> method cannot cope with
positional arguments that lack a WHERE clause, so either use named arguments, or the
'bit by bit' approach, or pass the arguments directly to C<retrieve_all>.

=cut

sub retrieve_all
{
  my $self = shift;

  my $get_all = {}; # { 1 => 1 };

  unless ( @_ )
  {   # already set pager up via method calls
    $self->where( $get_all );
    return $self->search_where;
  }

  my @args = ( ref( $_[0] ) or $_[0] =~ /^\d+$/ ) ?
    ( $get_all, @_ ) :          # send an array
    ( where => $get_all, @_ );  # send a hash

  return $self->search_where( @args );
}

sub _setup_pager
{
  my ( $self ) = @_;

  # get the total count for our query
  $self->{__pager_total_entries} = $self->_count_search_where( $self->{__pager_where} // {} );

  # calculate total pages and last page
  if( $self->{__pager_total_entries} ) {
    $self->{__pager_total_pages} = int( $self->{__pager_total_entries} / $self->{__pager_entries_per_page} );
    $self->{__pager_total_pages}++ if( $self->{__pager_total_entries} % $self->{__pager_entries_per_page} );
    $self->{__pager_last_page} = $self->{__pager_total_pages} - 1;
  }
  # otherwise we're empty
  else {
    $self->{__pager_total_pages} = 0;
    $self->{__pager_last_page} = 0;
  }

  croak( 'Fewer than one entry per page!' ) if $self->{__pager_entries_per_page} < 1;

  # bounds check the current page
  $self->current_page( $self->first_page ) unless defined $self->current_page;
  $self->current_page( $self->first_page ) if $self->current_page < $self->first_page;
  $self->current_page( $self->last_page  ) if $self->current_page > $self->last_page;
}


#
# PUBLIC ATTRIBUTES
#

sub first_page {
  my $self = shift;
  my $_first_page = $_[0];

  if( defined($_first_page) ) {
    $self->{__pager_first_page} = $_first_page;
  }

  return $self->{__pager_first_page};
}

sub last_page {
  my $self = shift;
  my $_last_page = $_[0];

  if( defined($_last_page) ) {
    $self->{__pager_last_page} = $_last_page;
  }

  return $self->{__pager_last_page};
}

sub current_page {
  my $self = shift;
  my $_current_page = $_[0];

  if( defined($_current_page) ) {
    $self->{__pager_current_page} = $_current_page;
  }

  return $self->{__pager_current_page};
}

sub total_entries {
  my $self = shift;
  my $_total_entries = $_[0];

  if( defined($_total_entries) ) {
    $self->{__pager_total_entries} = $_total_entries;
  }

  return $self->{__pager_total_entries};
}

sub entries_per_page {
  my $self = shift;
  my $_entries_per_page = $_[0];

  if( defined($_entries_per_page) ) {
    $self->{__pager_entries_per_page} = $_entries_per_page;
  }

  return $self->{__pager_entries_per_page};
}

sub where {
  my $self = shift;
  my $_where = $_[0];

  if( defined($_where) ) {
    $self->{__pager_where} = $_where;
  }

  return $self->{__pager_where};
}

sub order_by {
  my $self = shift;
  my $_order_by = $_[0];

  if( defined($_order_by) ) {
    $self->{__pager_order_by} = $_order_by;
  }

  return $self->{__pager_order_by};
}


#
# PRIVATE
#

sub _count_search_where {
  my $self = shift;
  my $class    = $self->{__pager_cdbi_app};
  my %where = ();
  if ( ref $_[0] ) {
    $class->_croak( "where-clause must be a hashref it it's a reference" )
    unless ref( $_[0] ) eq 'HASH';
    %where = %{ $_[0] };
  }
  else {
    %where = @_;
  }

  $class->can( 'retrieve_from_sql' )
    or $class->croak( "$class should inherit from Class::DBI >= 0.95" );

  my ( %columns, %accessors ) = ();
  for my $column ( $class->columns ) {
    ++$columns{ $column };
    $accessors{ $column->accessor } = $column;
  }

  COLUMN: for my $column ( keys %where ) {
    # Column names are (of course) OK
    next COLUMN if exists $columns{ $column };

    # Accessor names are OK, but replace them with corresponding column name
    $where{ $accessors{ $column }} = delete $where{ $column }, next COLUMN
    if exists $accessors{ $column };

    # SQL::Abstract keywords are OK
    next COLUMN
    if $column =~ /^-(?:and|or|nest|(?:(not_)?(?:like|between)))$/;

    # Check for functions
    if ( index( $column, '(' ) > 0
      && index( $column, ')' ) > 1 )
    {
      my @tokens = ( $column =~ /(-?\w+(?:\s*\(\s*)?|\W+)/g );
      TOKEN: for my $token ( @tokens ) {
        if ( $token !~ /\W/ ) { # must be column or accessor name
          next TOKEN if exists $columns{ $token };
          $token = $accessors{ $token }, next TOKEN
          if exists $accessors{ $token };
          $class->_croak(
            qq{"$token" is not a column/accessor of class "$class"} );
        }
      }

      my $normalized = join "", @tokens;
      $where{ $normalized } = delete $where{ $column }
      if $normalized ne $column;
      next COLUMN;
    }

    $class->_croak( qq{"$column" is not a column/accessor of class "$class"} );
  }

  my( $phrase, @bind ) = Canvas::Util::Abstract->new()->where( \%where );
  $class->sql_count_search_where( $phrase )->select_val( @bind );
}

1;
