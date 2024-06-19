#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Funds.pm
# Description:  Accès à la base de données dinfo
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Wed Nov 12 10:43:34 CET 2014
# Revision:     
#
##############################################################################
#
package Accred::Local::Funds;
#
use strict;
use utf8;

use lib qq(/opt/dinfo/lib/perl);
use Accred::Local::LocalDB;

our $errmsg;

sub new {
  my ($class, $args) = @_;
  my  $self = {
    dinfodb => undef,
    verbose => undef,
      trace => undef,
  };
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  unless ($self->{dinfodb}) {
    $self->{dinfodb} = new Accred::Local::LocalDB (
        dbname => 'dinfo',
         trace => $self->{trace},
          utf8 => $self->{utf8},
      tracesql => 0,
    );
    unless ($self->{dinfodb}) {
      $errmsg = "Unable to connect to dinfo database : $Accred::Local::LocalDB::errmsg";
      return;
    }
  }
  $self->{lang} ||= 'en';
  bless $self, $class;
}

sub getUnits {
  my ($self, $unitid) = @_;
  return unless $unitid;
  
  my    $inunit = ($self->{language} eq 'en') ? 'unit'   : 'l\'unité';
  my   @unitids = (ref $unitid eq 'ARRAY') ? @$unitid : ( $unitid );  
  my   $fundlab = ($self->{language} eq 'en') ? 'Fund' : 'Fonds';
  my $infundlab = ($self->{language} eq 'en') ? 'Fund' : 'le fonds';
  my   $incflab = ($self->{language} eq 'en') ? 'CF'   : 'le CF';
  my $units;

  my (@fc, @ff);
  foreach my $unitid (@unitids) {
    if ($unitid =~ /^FC(.*)$/) {
      push (@fc, $1);
    }
    elsif ($unitid =~ /^FF(.*)$/) {
      push (@ff, $1);
    }
  }
  #
  # FCs
  #
  if (@fc) {
    my  $in = join (', ', map { '?' } @fc);
    my  $sql = qq{
      select id_unite as orgid,
             sigle, hierarchie, cf
        from unites
       where cf in ($in)
    };
    my $sth = $self->dbsafequery ($sql, @fc);
    while (my ($orgid, $sigle, $hierarchie, $cf) = $sth->fetchrow) {
      my $unitid = "FC$cf";
      my  $level = scalar split (/\s+/, $hierarchie);
      $units->{$unitid} = {
             id => $unitid,
           name => "CF $cf",
         inname => "$incflab $cf",
        altname => $sigle,
       longname => $sigle,
          orgid => $orgid,
        labelfr => "CF $cf",
        labelen => "CF $cf",
          label => "CF $cf",
           path => "FC0000",
          level => $level,
           type => 'Funds',
         folder => 1,
      };
    }
  }
  #
  # FFs
  #
  my $ff;
  if (@ff) {
    my  $in = join (', ', map { '?' } @ff);
    my $sql = qq{
      select no_fond,
             fonds.cf      as cf,
             fonds.libelle as fflib,
             id_unite      as orgid
        from fonds
        left outer join unites on unites.cf = substring(fonds.cf,2)
       where no_fond in ($in)
    };
    my $sth = $self->dbsafequery ($sql, @ff) or return;
    while (my ($ffid, $cfid, $fflib, $orgid) = $sth->fetchrow) {
      my $unitid = "FF$ffid";
      $units->{$unitid} = {
             id => $unitid,
           name => "$fundlab $ffid",
         inname => "$infundlab $ffid",
        altname => $fflib,
       longname => $fflib,
          orgid => $orgid,
        labelfr => $fflib,
        labelen => $fflib,
          label => $fflib,
           path => "FC0000 FF$ffid",
          level => 5,
           type => 'Funds',
         folder => 0,
      };
    }
  }
  return (ref $unitid eq 'ARRAY') ? $units : $units->{$unitid};
}
*getUnit = \&getUnits;

sub getUnitFromName {
  my ($self, $name, $date) = @_;
  return unless $name;
  
  if ($name =~ /^CF ?(.*)$/i || $name =~ /^(\d\d\d\d\d?)$/) { # CF
    my $cf = $1;
    my  $sql = qq{
      select dinfo.unites.cf,
             dinfo.unites1.cmpl_type
        from dinfo.unites
        join dinfo.unites1 on dinfo.unites1.id_unite = dinfo.unites.id_unite
       where dinfo.unites.cf = ?
    };
    my  $sth = $self->dbsafequery ($sql, $cf) or return;
    my ($cfid, $cmpl_type) = $sth->fetchrow;
    return unless $cfid;
    my $cmpltypes = { map { $_ => 1 } split (/,\s*/, $cmpl_type) };
    return unless ($cmpltypes->{F} || $cmpltypes->{FS});
    my $unitid = "FC$cf";
    return $self->getUnit ($unitid);
  }
  else {
    my $ff = $name;
    $ff = $2 if ($name =~ /^(Fund |FF)(.*)$/i);
    my $sql = qq{
      select no_fond
        from fonds
       where no_fond = ?
    };
    my $sth = $self->dbsafequery ($sql, $ff) or return;
    my ($ff) = $sth->fetchrow;
    return unless $ff;
    my $unitid = "FF$ff";
    return $self->getUnit ($unitid);
  }
}

sub badunit {
  my ($self, $unitid) = @_;
  return {
         id => $unitid,
       name => "Bad unit : $unitid",
    labelfr => "Unité incorrecte : $unitid",
    labelen => "Bad unit : $unitid",
      label => "Bad unit : $unitid",
       path => '',
      level => 0,
       type => 'Bad',
  };
}

sub getUnitType {
  my $self = shift;
  my   $en = $self->{language} eq 'en';
  return {
              id => 'Funds',
         package => 'Accred::Local::Funds',
           title => $en ? 'Signature register' : 'Registre des signatures',
            name => $en ? 'Funds' : 'Fonds',
         myunits => $en ? 'Signature register' : 'Registre des signatures',
     lookforunit => $en ? 'Search for an account' : 'Rechercher un CF',
            icon => '/images/funds.gif',
           order => 2,
    rolesmanager => 'fundadminroles',
  };
}

sub getRoots {
  my $self = shift;
  return;
}

sub listChildren {
  my ($self, $unitid) = @_;
  return unless ($unitid && ($unitid =~ /^FC(.*)$/));
  my $cf = $1;

  my   $fundlab = ($self->{language} eq 'en') ? 'Fund' : 'Fonds';
  my $infundlab = ($self->{language} eq 'en') ? 'Fund' : 'le fonds';
  my   $incflab = ($self->{language} eq 'en') ? 'CF'   : 'le CF';
  #
  # Unit info.
  #
  my  $sql = qq{
    select dinfo.unites.*,
           dinfo.unites1.cmpl_type
      from dinfo.unites
      join dinfo.unites1 on dinfo.unites1.id_unite = dinfo.unites.id_unite
     where dinfo.unites.cf = ?
  };
  my  $sth = $self->dbsafequery ($sql, $cf) or return;
  my $unit = $sth->fetchrow_hashref;
  return unless $unit;
  my $cmpltypes = { map { $_ => 1 } split (/,\s*/, $unit->{cmpl_type}) };
  return unless ($cmpltypes->{F} || $cmpltypes->{FS});
  my $idunit = $unit->{id_unite};
  my  $level = split (/\s+/, $unit->{hierarchie});
  my $folder = $level < 4 ? 1 : 0;
  #
  # Sub units.
  #
  my $sql = qq{
    select dinfo.unites.*,
           dinfo.unites1.cmpl_type
      from dinfo.unites
      join dinfo.unites1 on dinfo.unites1.id_unite = dinfo.unites.id_unite
     where dinfo.unites.id_parent = ?
  };
  my $sth = $self->dbsafequery ($sql, $idunit) or return;
  my @children;
  while (my $child = $sth->fetchrow_hashref) {
    my $cmpltypes = { map { $_ => 1 } split (/,\s*/, $child->{cmpl_type}) };
    next unless ($cmpltypes->{F} || $cmpltypes->{FS});
    my $labelen = $child->{libelle_en} || $child->{libelle};
    my   $label = ($self->{lang} eq 'en') ? $labelen : $child->{libelle};
    my      $cf = $child->{cf};
    push (@children, {
           id => "FC$cf",
         name => "CF $cf",
       inname => "$incflab $cf",
      altname => $child->{sigle},
     longname => $child->{sigle},
      labelfr => $child->{libelle},
      labelen => $labelen,
        label => $label,
         path => $child->{hierarchie},
        level => $level + 1,
         type => 'CF',
       folder => $folder,
    });
  }
  $sth->finish;
  #
  # Funds.
  #
  my $sql = qq{
    select *
     from fonds
    where   cf =  ?
      and etat = 'O'
  };
  my $sth = $self->dbsafequery ($sql, "F$cf") or return;
  while (my $child = $sth->fetchrow_hashref) {
    my $ff = $child->{no_fond};
    push (@children, {
           id => "FF$ff",
         name => "$fundlab $ff",
       inname => "$infundlab $cf",
      labelfr => $child->{libelle},
      labelen => $child->{libelle},
        label => $child->{libelle},
         path => $unit->{path} . ' FF' .$cf,
        level => $level + 1,
         type => 'Funds',
       folder => 0,
    });
  }
  $sth->finish;
  return @children;
}

sub getAllChildren {
  my $self = shift;
  #
  # Sub units.
  #
  my $sql = qq{
    select dinfo.unites.*,
           dinfo.unites1.cmpl_type
      from dinfo.unites
      join dinfo.unites1 on dinfo.unites1.id_unite = dinfo.unites.id_unite
  };
  my $sth = $self->dbsafequery ($sql) or return;
  my ($children, $units);
  while (my $record = $sth->fetchrow_hashref) {
    my $cmpltypes = { map { $_ => 1 } split (/,\s*/, $record->{cmpl_type}) };
    next unless ($cmpltypes->{F} || $cmpltypes->{FS});
    $units->{$record->{id_unite}} = $record;
  }
  foreach my $unitid (keys %$units) {
    my $parentid = $units->{$unitid}->{id_parent};
    next unless ($parentid && $units->{$parentid}->{cf});
    my $parentcf = 'FC' . $units->{$parentid}->{cf};
    push (@{$children->{$parentcf}}, 'FC' . $units->{$unitid}->{cf});
  }
  #
  # Funds.
  #
  my  $sql = qq{
    select no_fond, cf
      from fonds
     where etat = 'O'
  };
  my  $sth = $self->dbsafequery ($sql) or return;
  my $allcfids;
  while (my $record = $sth->fetchrow_hashref) {
    my $fundid = 'FF' . $record->{no_fond};
    my   $cfid = $record->{cf};
    $cfid =~ s/^F//;
    $cfid = 'FC' . $cfid;
    push (@{$children->{$cfid}}, $fundid);
    $allcfids->{$cfid} = 1;
  }
  $sth->finish;
  return $children;
}

sub listDescendantsIds { # TODO
  my ($self, $unitid) = @_;
  return unless ($unitid && ($unitid =~ /^F[CF](.*)$/));
  return (); 
}

sub getAncestors {
  my ($self, $unitid) = @_;
  return unless ($unitid && ($unitid =~ /^F[CF](.*)$/));

  my @ancestors;
  if ($unitid =~ /^FF(.*)$/) {
    my $no_fond = $1;
    my  $sql = qq{select cf from fonds where no_fond = ?};
    my  $sth = $self->dbsafequery ($sql, $no_fond) or return;
    my ($cf) = $sth->fetchrow;
    return unless $cf;
    $cf =~ s/^F//;
    push (@ancestors, "FC$cf");
    $unitid = "FC$cf";
  }
  if ($unitid =~ /^FC(.*)$/) {
    my $cf = $1;
    while ($cf) {
      my $sql = qq{
        select parents.cf
         from unites
         join unites as parents on unites.id_parent = parents.id_unite
        where unites.cf = ?;
      };
      my $sth = $self->dbsafequery ($sql, $cf) || last;
      my ($parentcf) = $sth->fetchrow ();
      push (@ancestors, "FC$parentcf") if $parentcf;
      $cf = $parentcf;
    }
  }
  return @ancestors;
}

sub getAllAncestors {
  my ($self) = @_;
  my $ancestors;;
  #
  # CFs
  #
  my $sql = qq{select id_unite, cf, id_parent from unites};
  my $sth = $self->dbsafequery ($sql);
  my ($orgs, $cf2idunite);
  while (my ($idunite, $cf, $idparent) = $sth->fetchrow) {
    next unless $cf;
    $orgs->{$idunite} = {
            cf => $cf,
      idparent => $idparent,
    };
    $cf2idunite->{$cf} = $idunite;
  }
  my $parentids;
  foreach my $idunite (keys %$orgs) {
    my       $cf = $orgs->{$idunite}->{cf};
    my $idparent = $orgs->{$idunite}->{idparent};
    my   $unitid = "FC$cf";
    my   $parent = $orgs->{$idparent} || next;
    my $parentid = "FC$parent->{cf}";
    $parentids->{$unitid} = $parentid;
  }
  #
  # FFs
  #
  my $sql = qq{select no_fond, cf from fonds};
  my $sth = $self->dbsafequery ($sql);
  while (my ($no_fond, $cf) = $sth->fetchrow) {
    next unless $cf; $cf =~ s/^F//;
    my   $unitid = "FF$no_fond";
    my $idparent = $cf2idunite->{$cf};
    my   $parent = $orgs->{$idparent} || next;
    my $parentid = "FC$parent->{cf}";
    $parentids->{$unitid} = $parentid;
  }
  #
  # Merge all.
  #
  foreach my $unitid (keys %$parentids) {
    my $parentid = $parentids->{$unitid};
    while ($parentid) {
      push (@{$ancestors->{$unitid}}, $parentid);
      $parentid = $parentids->{$parentid};
    }
  }
  return $ancestors;
}

sub expandUnitsList {
  my ($self, @unitids) = @_;
  my @retids;
  my $seen;
  foreach my $unitid (@unitids) {
    next if $seen->{$unitid};
    push (@retids, $unitid); $seen->{$unitid} = 1;
    my @subids = $self->getUnitSubtree ($unitid);
    foreach my $subid (@subids) {
      next if $seen->{$subid};
      push (@retids, $subid); $seen->{$subid} = 1;
    }
  }
  return @retids;
}

sub getAllParents {
  my $self = shift;
  my $parents;
  #
  # CF
  #
  my $sql = qq{
    select dinfo.unites.id_unite,
           dinfo.unites.id_parent,
           dinfo.unites.cf,
           dinfo.unites.hierarchie,
           dinfo.unites1.cmpl_type
      from dinfo.unites
      join dinfo.unites1 on dinfo.unites1.id_unite = dinfo.unites.id_unite
  };
  my $sth = $self->dbsafequery ($sql) || return;
  my $units;
  while (my ($id_unite, $id_parent, $cf, $hierarchie, $cmpl_type) = $sth->fetchrow) {
    my $cmpltypes = { map { $_ => 1 } split (/,\s*/, $cmpl_type) };
    next unless ($cmpltypes->{F} || $cmpltypes->{FS});
    $units->{$id_unite} = {
       id_parent => $id_parent,
              cf => $cf,
      hierarchie => $hierarchie
    };
  }
  $sth->finish;
  foreach my $id_unite (keys %$units) {
    my      $unit = $units->{$id_unite};
    my    @levels = split (/\s+/, $unit->{hierarchie});
    my     $level = @levels;
    my    $unitcf = $unit->{cf};
    my $id_parent = $unit->{id_parent};
    my  $parentcf = $units->{$id_parent}->{cf};
    my    $unitid = "FC$unitcf";
    my  $parentid = $parentcf ? "FC$parentcf" : 0;
    $parents->{$unitid} = {
      parent => $parentid,
       level => $level,
    };
  }
  #
  # Funds
  #
  my $sql = qq{
    select no_fond, cf
      from fonds
  };
  my $sth = $self->dbsafequery ($sql) || return;
  while (my ($no_fond, $cf) = $sth->fetchrow) {
    next unless ($no_fond && $cf);
    my    $unitid = "FF$no_fond";
    my  $parentid = $cf;
    $parentid =~ s/^F/FC/;
    $parents->{$unitid} = {
      parent => $parentid,
       level => 5,
    };
  }
  $sth->finish;
  return $parents;
}

sub getUnitParent {
  my ($self, $unitid) = @_;
  my @ancestors = $self->getAncestors ($unitid);
  return unless @ancestors;
  return $ancestors [0];
}

sub getUnitSubtree {
  my ($self, $unitid) = @_;
  return unless ($unitid && $unitid  =~ /^FC(.*)$/);

  my @children =  $self->listChildren ($unitid);
  return unless @children;

  my @subtree;
  foreach my $child (@children) {
    push (@subtree, $child->{id});
    my @children = $self->getUnitSubtree ($child->{id});
    push (@subtree, @children);
  }
  return @subtree;
}

sub getUnitSubtreeAsSubtree { # Very slooow, should be optimised.
  my ($self, $unitid) = @_;
  return unless ($unitid && $unitid  =~ /^FC(.*)$/);

  my @children =  $self->listChildren ($unitid);
  return unless @children;

  my $subtree;
  foreach my $child (@children) {
    my $childid = $child->{id};
    push (@{$subtree->{$unitid}}, {
        id => $childid,
      name => $child->{name},
    });
  }
  foreach my $child (@children) {
    my      $childid = $child->{id};
    my $childsubtree = $self->getUnitSubtreeAsSubtree ($childid);
    next unless $childsubtree;
    foreach my $subid (keys %$childsubtree) {
      $subtree->{$subid} = $childsubtree->{$subid};
    }
  }
  return $subtree;
}

sub getCFFunds {
  my ($self, $cf) = @_;
  my  $sql = qq{
    select no_fond
      from fonds
     where   cf = ?
       and etat = 'O'
  };
  my  $sth = $self->dbsafequery ($sql, $cf);
  return unless $sth;
  my @funds;
  my $fundlab = ($self->{language} eq 'en') ? 'Fund' : 'Fonds';
  while (my ($no_fond) = $sth->fetchrow) {
    push (@funds, {
           id => "FF$no_fond",
         name => "$fundlab $no_fond",
      labelfr => "$fundlab $no_fond",
      labelen => "$fundlab $no_fond",
        label => "$fundlab $no_fond",
         path => 'FC0000 FC$cf',
        level => 0,
    });
  }
  return @funds;
}

sub getDependsOnOrgUnits {
  my ($self, %optargs) = @_;
  my $optargs = \%optargs;
  my $unitdeps;
  my $sql = qq{
    select dinfo.unites.id_unite,
           dinfo.unites.cf,
           dinfo.unites1.cmpl_type
      from dinfo.unites
      join dinfo.unites1 on dinfo.unites1.id_unite = dinfo.unites.id_unite
  };
  my $sth = $self->dbsafequery ($sql);
  while (my ($unitid, $cfid, $cmpl_type) = $sth->fetchrow) {
    next unless ($unitid && $cfid);
    my $cmpltypes = { map { $_ => 1 } split (/,\s*/, $cmpl_type) };
    next unless ($cmpltypes->{F} || $cmpltypes->{FS});
    push (@{$unitdeps->{$unitid}}, {
        id => 'FC' . $cfid,
      type => 'Funds',
    });
  }
  return $unitdeps if $optargs->{noexpand};
  
  my $sql = qq{
    select dinfo.unites.id_unite,
           dinfo.fonds.no_fond,
           dinfo.unites1.cmpl_type
      from dinfo.unites
           join dinfo.unites1 on dinfo.unites1.id_unite = dinfo.unites.id_unite,
           dinfo.fonds
     where dinfo.unites.cf = substring(dinfo.fonds.cf,2)
       and dinfo.fonds.etat = 'O'
  };
  my $sth = $self->dbsafequery ($sql) or return;
  while (my ($unitid, $ffid, $cmpl_type) = $sth->fetchrow) {
    next unless ($unitid && $ffid);
    my $cmpltypes = { map { $_ => 1 } split (/,\s*/, $cmpl_type) };
    next unless ($cmpltypes->{F} || $cmpltypes->{FS});
    push (@{$unitdeps->{$unitid}}, {
        id => 'FF' . $ffid,
      type => 'Funds',
    });
  }
  return $unitdeps;
}

sub getDependsOnOrgUnit {
  my ($self, $orgid, %optargs) = @_;
  my $optargs = \%optargs;
  my @funds;
  my $sql = qq{
    select dinfo.unites.cf,
           dinfo.unites1.cmpl_type
      from dinfo.unites
      join dinfo.unites1 on dinfo.unites1.id_unite = dinfo.unites.id_unite
     where dinfo.unites.id_unite = ?
  };
  my $sth = $self->dbsafequery ($sql, $orgid);
  while (my ($cfid, $cmpl_type) = $sth->fetchrow) {
    next unless $cfid;
    my $cmpltypes = { map { $_ => 1 } split (/,\s*/, $cmpl_type) };
    next unless ($cmpltypes->{F} || $cmpltypes->{FS});
    push (@funds, {
        id => 'FC' . $cfid,
      type => 'Funds',
    });
  }
  return @funds if $optargs->{noexpand};
  
  my $sql = qq{
    select no_fond,
           dinfo.unites1.cmpl_type
      from fonds
      join unites1 on unites1.cf = substring(fonds.cf,2)
     where unites1.id_unite = ?
       and etat = 'O'
  };
  my $sth = $self->dbsafequery ($sql, $orgid) or return;
  while (my ($ffid, $cmpl_type) = $sth->fetchrow) {
    next unless $ffid;
    my $cmpltypes = { map { $_ => 1 } split (/,\s*/, $cmpl_type) };
    next unless ($cmpltypes->{F} || $cmpltypes->{FS});
    push (@funds, {
        id => 'FF' . $ffid,
      type => 'Funds',
    });
  }
  return @funds;
}

sub dbsafequery {
  my ($self, $sql, @values) = @_;

  unless ($self->{dinfodb}) {
    warn scalar localtime, "Fonds::Connecting to dinfodb.\n" if $self->{verbose};
    $self->{dinfodb} = new Accred::Local::LocalDB (
      dbname => 'dinfo',
       trace => 1,
        utf8 => 1,
    );
  }
  unless ($self->{dinfodb}) {
    warn scalar localtime, "Unable to initialize dinfo db for sql = $sql";
    exit;
  }
  my $sth = $self->{dinfodb}->prepare ($sql);
  unless ($sth) {
    warn scalar localtime, "Trying to reconnect..., sql = $sql";
    $sth = $self->{dinfodb}->prepare ($sql);
    warn scalar localtime, "Reconnection failed." unless $sth;
  }
  my $rv = $sth->execute (@values);
  unless ($rv) {
    warn scalar localtime, "Trying to reconnect..., sql = $sql";
    $rv = $sth->execute (@values);
    warn scalar localtime, "Reconnection failed." unless $rv;
  }
  return $sth;
}

sub setverbose {
  my $self = shift;
  $self->{verbose} = shift;
}


1;

