#!/bin/bash -x
PACKAGE_MGR=dnf
CANVAS_DB_PASS=c3nva$
CANVAS_DB=canvas
CANVAS_USER=vagrant
CANVAS_LOG=/var/log/canvasd.log

# Packages need to get Mojo::Pg from cpan
CPAN_PACKAGES=(
  cpan
  make
  perl-Test-Most
  perl-IO-Tty
  perl-Module-Signature
  perl-YAML
  perl-IO-Socket-IP
)

PACKAGES=(

  postgresql
  postgresql-server

  tmux

  perl-DBD-Pg
  perl-Class-DBI-Pg
  perl-Cache-FastMmap
  perl-Class-DBI
  perl-List-MoreUtils
  perl-MIME-Lite
# cpan version of Mojo::Pg requires a new version of Mojo
# perl-Mojolicious
  perl-Time-Piece
)

install_package_dependencies() {
  # Install required packages
  ${PACKAGE_MGR} -y install "${PACKAGES[@]}"

  # Attempt to install Mojo rpm
  ${PACKAGE_MGR} -y install perl-Mojo-Pg
  if [ "$?" -eq 0 ]; then
    # Explicit install of Mojolicious incase it is not pulled in automatically
    ${PACKAGE_MGR} -y install perl-Mojolicious
  else
    # Fall back to cpan if Mojo::Pg is not currently packaged
    ${PACKAGE_MGR} -y install "${CPAN_PACKAGES[@]}"
    cpan -i Mojo::Pg
  fi
}

populate_database() {
  postgresql-setup --initdb 2>/dev/null
  if [ "$?" -eq 0 ]; then
    sed -ri 's/(^host.*) ident/\1 md5/'  /var/lib/pgsql/data/pg_hba.conf
    systemctl enable postgresql
    systemctl start postgresql

    ret=false
    getent passwd ${CANVAS_USER} >/dev/null 2>&1 && ret=true
    if ! $ret; then
     useradd ${CANVAS_USER}
    fi
    PG_PASS_FILE="$(eval echo ~${CANVAS_USER})/.pgpass"

    su --login postgres --command "createdb ${CANVAS_DB}"
    su --login postgres --command "createuser ${CANVAS_USER}"

    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"${CANVAS_DB}\" to ${CANVAS_USER};"
    sudo -u postgres psql -c "ALTER USER ${CANVAS_USER} WITH PASSWORD '${CANVAS_DB_PASS}';"

    if [ ! -e "${PG_PASS_FILE}" ]; then
      echo "localhost:*:${CANVAS_DB}:${CAN}"> "${PG_PASS_FILE}"
      chmod 0600 "${PG_PASS_FILE}"
    fi
    sudo -u ${CANVAS_USER} psql -d "${CANVAS_DB}" -a -f /vagrant/canvas.pgsql

    sudo -u postgres psql -d "${CANVAS_DB}" -c "INSERT INTO users (username, password, email, status, access) VALUES ('test', '\$P\$BMnMk58plsy5BfSZiue33VhoMNWBDd1', 'test@foo.com', 'active', 255);"
  fi
}

vagrant_provision() {
  [ -h /vagrant/canvas.conf ] || ln -s /vagrant/vagrant/canvas.conf /vagrant/canvas.conf

  touch "${CANVAS_LOG}"
  chown ${CANVAS_USER}:${CANVAS_USER} "${CANVAS_LOG}"

  PID=$(echo -n "$(pidof tmux)")
  if [ -z "$PID"  ]; then
    su ${CANVAS_USER} <<EOF
      tmux new-session -d -s canvas
      tmux rename-window -t canvas:0 'canvasd'
      tmux send-keys -t canvas:0 "cd /vagrant" C-m
      tmux send-keys -t canvas:0 "/usr/local/bin/morbo /vagrant/canvasd | tee ${CANVAS_LOG}" C-m
EOF
  fi
}


install_package_dependencies
populate_database
[ "$1" == "provision" ] && vagrant_provision

# vim: textwidth=0 tabstop=2 shiftwidth=2 expandtab smarttab:

