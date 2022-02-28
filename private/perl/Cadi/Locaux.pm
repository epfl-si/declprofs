#!/usr/bin/perl
#
use strict;
use utf8;

use lib qw(/opt/dinfo/lib/perl);
use Cadi::CadiDB;

package Cadi::Locaux;

my $searchkeys = {
              'id' => 'dinfo.locaux.room_id',
            'name' => 'dinfo.locaux.room_abr',
            'zone' => 'dinfo.locaux.room_zone',
           'floor' => 'dinfo.locaux.room_etage',
          'dincat' => 'dinfo.locaux.room_din',
           'alias' => 'dinfo.locaux.room_alias',
        'adminuse' => 'dinfo.locaux.room_uti_admin',
      'facultyuse' => 'dinfo.locaux.room_uti_faculte',
              'cf' => 'dinfo.locaux.room_cf_4',
          'places' => 'dinfo.locaux.n_places',
         'surface' => 'dinfo.locaux.n_surf_esp',
          'height' => 'dinfo.locaux.height',
     'stationpost' => 'dinfo.locaux.stationpost',

         'site_id' => 'dinfo.sites.site_id',
       'site_name' => 'dinfo.sites.site_abr',
      'site_label' => 'dinfo.sites.site_lib',

     'building_id' => 'dinfo.batiments.bat_id',
   'building_name' => 'dinfo.batiments.bat_abr',
  'building_label' => 'dinfo.batiments.bat_name',

          'unitid' => 'dinfo.unites.id_unite',
        'unitname' => 'dinfo.unites.sigle',
       'unitlabel' => 'dinfo.unites.libelle',
};

my $selectrooms = qq{
    select dinfo.locaux.room_id          as id,
           dinfo.locaux.room_abr         as name,
           dinfo.locaux.room_zone        as zone,
           dinfo.locaux.room_etage       as floor,
           dinfo.locaux.room_din         as dincat,
           dinfo.locaux.room_alias       as alias,
           dinfo.locaux.room_uti_admin   as adminuse,
           dinfo.locaux.room_uti_faculte as facultyuse,
           dinfo.locaux.room_cf_4        as cf,
           dinfo.locaux.n_places         as places,
           dinfo.locaux.n_surf_esp       as surface,
           dinfo.locaux.height           as height,
           dinfo.locaux.stationpost      as stationpost,
           
           dinfo.sites.site_id           as site_id,
           dinfo.sites.site_abr          as site_name,
           dinfo.sites.site_lib          as site_label,

           dinfo.batiments.bat_id        as building_id,
           dinfo.batiments.bat_abr       as building_name,
           dinfo.batiments.bat_name      as building_label,
           
           dinfo.unites.id_unite         as unitid,
           dinfo.unites.sigle            as unitname,
           dinfo.unites.libelle          as unitlabel

      from dinfo.locaux
      join dinfo.sites
        on dinfo.sites.site_id = dinfo.locaux.site_id
      join dinfo.batiments
        on dinfo.batiments.bat_id = dinfo.locaux.bat_id
      left outer join dinfo.unites
        on dinfo.unites.cf = dinfo.locaux.room_cf_4
};

sub new { # Exported
  my $class = shift;
  my  %args = @_;
  my $self = {
      caller => undef,
          db => undef,
      errmsg => undef,
     errcode => undef,
        utf8 => 1,
    language => 'fr',
       debug => 0,
     verbose => 0,
       trace => 0,
    tracesql => 0,
  };
  foreach my $arg (keys %args) {
    $self->{$arg} = $args {$arg};
  }
  $self->{db} = new Cadi::CadiDB (
    dbname => 'dinfo',
     trace => $self->{trace},
      utf8 => $self->{utf8},
  );
  bless $self, $class;
}

sub getRoomInfos {
  my ($self, $id) = @_;
  my @rooms = $self->getRoomsInfos ($id);
  return unless @rooms;
  return $rooms [0];
}

sub getRoomsInfos {
  my ($self, @ids) = @_;
  my $caller = $self->{caller};
  my     $db = $self->{db};
  return $self->error ("getRoomInfos: $CadiDB::errmsg") unless $db;
  
  my (@wheres, @args);
  foreach my $id (@ids) {
    if ($id =~ /^\d*$/) {
      push (@wheres, "room_id = ?");
      push (@args, $id);
    } else {
      my $canon = $id;
      $canon =~ tr/a-z/A-Z/;
      $canon =~ s/[\s\.]//g;
      my $oper = ($canon =~ '%') ? 'like' : '=';
      push (@wheres, "canon $oper ? or room_alias $oper ?");
      push (@args, $canon, $id);
    }
  }
  my $where = join (' or ', @wheres);
  my   $sql = "$selectrooms where $where";
  my   $sth = $db->prepare ($sql);
  return $self->error ("getRoomInfos : $db->{errmsg}") unless $sth;
  my $rv = $db->execute ($sth, @args);
  return $self->error ("getRoomInfos : $db->{errmsg}") unless $rv;
  my @rooms;
  while (my $room = $sth->fetchrow_hashref) {
    $room->{display} = $room->{name};
    push (@rooms, $room);
  }
  return $self->error ("getRoomsInfos : no matching room for @ids") unless @rooms;
  $sth->finish;
  return @rooms;
}

sub searchRooms {
  my ($self, $key, $value) = @_;
  return $self->matchRooms ({ $key => $value });
}

sub matchRooms {
  my ($self, $filter) = @_;
  my $db = $self->{db};
  return $self->error ("matchRooms : $DBI::errstr") unless $db;
  
  my (@wheres, @values);
  foreach my $key (keys %$filter) {
    next unless $searchkeys->{$key};
    my $value = $filter->{$key};
    my $op = ($value =~ /%/) ? 'like' : '=';
    push (@wheres, "$searchkeys->{$key} $op ?");
    push (@values, $value);
  }
  return $self->error ("Locaux::matchRooms : No valid search key")
    unless @wheres;
  
  my $where = join (' and ', @wheres);
  my   $sql = "$selectrooms where $where";
  #warn "COUCOU:sql = $sql, values = @values\n";
  my $db = $self->{db};
  
  my $sth = $db->prepare ($sql);
  return $self->error ("Locaux::matchRooms : $db->{errmsg}")  unless $sth;
  my $rv = $db->execute ($sth, @values);
  return $self->error ("Locaux::matchRooms : $db->{errmsg}")  unless $rv;
  my $rooms;
  while (my $room = $sth->fetchrow_hashref) {
    my $roomid = $room->{id};
    $room->{type}     = 'room';
    $room->{display}  = "Room $room->{name}";
    $rooms->{$roomid} = $room;
  }
  $sth->finish;
  my @rooms = sort { $a->{display} cmp $b->{display} } values %$rooms;
  return \@rooms;
}

sub errmsg {
  my $self = shift;
  return $self->{errmsg};
}

sub error {
  my ($self, $msg) = @_;
  $self->{errmsg} = $msg;
  warn "$msg\n";
  return;
}

1;
