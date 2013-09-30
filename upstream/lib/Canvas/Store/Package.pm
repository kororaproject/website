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
package Canvas::Store::Package;

use strict;
use base 'Canvas::Store';

__PACKAGE__->table('canvas_package');
__PACKAGE__->columns(All => qw/id name description summary license url category type tags created updated/);

__PACKAGE__->has_many(template_packages => 'Canvas::Store::TemplatePackage'  => 'package_id');
__PACKAGE__->has_many(package_ratings   => 'Canvas::Store::PackageRating'    => 'package_id');
__PACKAGE__->has_many(package_details   => 'Canvas::Store::PackageDetails'   => 'package_id');

#
# inflate/deflate created/updated values
__PACKAGE__->has_a(
  created => 'Time::Piece',
  inflate => sub { Time::Piece->strptime( shift, "%Y-%m-%d %H:%M:%S") },
  deflate => sub { shift->strftime("%Y-%m-%d %H:%M:%S") }
);

__PACKAGE__->has_a(
  updated => 'Time::Piece',
  inflate => sub { Time::Piece->strptime( shift, "%Y-%m-%d %H:%M:%S") },
  deflate => sub { shift->strftime("%Y-%m-%d %H:%M:%S") }
);


#
# latest updated packages
__PACKAGE__->set_sql(latest => qq {
  SELECT canvas_package.id
  FROM canvas_package
  JOIN canvas_packagedetails
    ON canvas_packagedetails.package_id=canvas_package.id
  ORDER BY canvas_packagedetails.build_time DESC
  LIMIT 100
});

1;
