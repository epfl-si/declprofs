#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Utils.pm
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Tue Jul  9 14:20:42 CEST 2002
# Revision:     
#
##############################################################################
#
#
package Accred::Utils;
#
use strict;
use utf8;
use LWP::UserAgent;
use Net::SMTP;
use Carp qw(cluck);

use Accred::Config;
use Accred::Messages;
use Accred::AccredDB;
use Accred::Accreds;
use Accred::InternalWorkflow;
use Accred::Logs;
use Accred::Notifications;
use Accred::Persons;
use Accred::Positions;
use Accred::Properties;
use Accred::PropsAdmin;
use Accred::Rights;
use Accred::RightsAdmin;
use Accred::Roles;
use Accred::RolesAdmin;
use Accred::Summary;
use Accred::Units;
use Accred::UnitsAdmin;
use Accred::Workflows;
use Accred::Local::Notifier;

my $modulecache = {};
my $verbose = 0;

my @allmodules = qw{
  AccredDB Config Accreds InternalWorkflow Logs Notifications Persons
  Positions Properties PropsAdmin Rights RightsAdmin Roles RolesAdmin
  Summary Units UnitsAdmin Workflows Local::Notifier
};

my @localmodules = qw{
  Notifier
};
my $localmodules = { map { $_ => 1 } @localmodules };

my @pubsubs = qw(
  head banner leftmenu tail error success importmodules checkdate redirect
  reloadopener printstack prettydate sendmail profile cache escape
);

sub import {
  my $callpkg = caller (0);
  no strict 'refs';
  foreach my $sub (@pubsubs) {
    *{$callpkg."::$sub"} = \&$sub;
  }
  use strict 'refs';
  return;
}

sub importmodules {
  my ($object, @modules) = @_;
  (my $objectname = $object) =~ s/Accred::(.*)=HASH.*$/$1/;
  @modules = @allmodules unless @modules;
  (my $callermod = ref $object) =~ s/^Accred:://;
  foreach my $module (@modules) {
    next if ($module eq $callermod);
    my $lcmodule = lc $module;
    if ($object->{req}) {
      unless ($object->{req}->{$lcmodule}) {
        my $modobj = $localmodules->{$module}
          ? "Accred::Local::$module"->new ($object)
          : "Accred::$module"->new ($object)
          ;
        next unless $modobj;
        warn "Utils:importmodules:$objectname: Caching $module\n" if $verbose;
        $object->{req}->{$lcmodule} = $modobj;
      } else {
        warn "Utils:importmodules:$objectname: From req $module\n" if $verbose;
      }
      $object->{$lcmodule} = $object->{req}->{$lcmodule};
      next;
    }
    warn "Utils:importmodules:$objectname: Loading $module for $object\n" if $verbose;
    $object->{$lcmodule} = "Accred::$module"->new ($object);
  }
}

sub check_recursion () {
  my @caller = caller  (1);
  my   $call = $caller [3];
  my $count = 1;
  for(my $ix = 2; @caller = caller ($ix); $ix++) {
    return 1 if ($caller[3] eq $call);
  }
  return 0;
}

sub head {
  my $req = shift;
  return if $req->{headdone}; $req->{headdone} = 1;
  
  binmode STDOUT, ":utf8";
  if ($req->{command} eq 'exportmenu') {
    exportmenu ($req);
    quit ($req);
  }

  my $csrftoken = $req->makecsrftoken () if $req->{userid};
  if ($req->{modifiers}->{embedded}) {
    print qq{Expires: -1\n};
    print qq{Content-type: text/html;charset=utf-8\n};
    if ($req->{userid} && !$req->{nocsrftoken}) {
      print qq{X-HTTP-CSRFToken: $csrftoken\n};
    }
    return;
  }

  my $doctype1 = qq{<!DOCTYPE HTML PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" }.
                 qq{"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">};

  my $doctype2 = qq{<!DOCTYPE HTML PUBLIC "-//W3C//DTD XHTML 1.1//EN" }.
                 qq{"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">};

  my $doctype3 = qq{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" }.
                 qq{"http://www.w3.org/TR/html4/loose.dtd">};
  my $doctype4 = qq{<!DOCTYPE html>};
  
  my $title = 'Accréditation des personnes';
  print qq{Content-type: text/html;charset=utf-8\n\n};
  print qq{$doctype4\n};

  print qq{
    <html>
      <head>
        <meta http-equiv="Set-Cookie" content="accreds_lang=$req->{language}; path=/"/> 
        <meta http-equiv="X-UA-Compatible" content="IE=edge" />
        <link rel="stylesheet" type="text/css" href="https://www.epfl.ch/css/epfl.css"/>
        <link rel="stylesheet" type="text/css" href="/styles/accred.css">
        <link rel="stylesheet" type="text/css" href="/styles/mytree.css">
        <link rel="stylesheet" type="text/css" href="/styles/datepicker.css">

        <script type="text/javascript" src="/js/accred.js"    charset="UTF-8"></script>
        <script type="text/javascript" src="/js/sorttable.js" charset="UTF-8"></script>
        <script type="text/javascript" src="/js/datepicker.js"></script>
        <script type="text/javascript" src="/js/timepicker.js"></script>
        <script type="text/javascript" src="//www.epfl.ch/js/jquery-epfl.min.js"></script>
        <script type="text/javascript">jQuery.noConflict();</script>
        <script src="https://www.epfl.ch/js/globalnav.js" type="text/javascript"></script>

        <script> csrftoken = '$csrftoken'; </script>
        <title> $title </title> 
  };
  my $bgcolor = 'white'; # $req->{config}->{test} ? 'lightblue' : 'white';
  print qq{
      </head>
      <body style="background-color: $bgcolor;">
  };
}

sub tail {
  my $req = shift;
  return if $req->{redirect};
  quit () if $req->{modifiers}->{embedded};
  print qq{
    <script> alert ('$req->{msg}'); </script>
  } if $req->{msg};
  print qq{
        </div>
      </body>
    </html>
  };
  quit ();
}

sub error {
  my ($req, $msg) = @_;
  $req->{nocsrftoken} = 1;
  head ($req) unless $req->{headdone};
  escape ($msg);
  if ($req->{modifiers}->{embedded}) {
    print qq{X-HTTP-Target: error\n\n};
    print msg('Error'), ' : ', $msg, "\n";
  } else {
    print '<h3>', msg('Error'), ' : ', $msg, "</h3>\n";
  }
  quit ();
}

sub error1 {
  my $req = shift;
  my $msg = shift;
  $msg =~ s/'/\\'/g;
  print qq{X-HTTP-Target: none\n\n};
  print qq{
    <script>
      alert ('}.msg("Error").qq{ : $msg');
    </script>
  };
  quit ();
}

sub escape {
  $_[0] =~ s/</&lt;/g;
  $_[0] =~ s/>/&gt;/g;
  $_[0] =~ s/"/&quot;/g;
  $_[0] =~ s/&/&amp;/g;
}

sub banner {
  my     $req = shift;
  my      $me = $req->{me};
  my      $su = $req->{su};
  my     $now = $req->{now};
  my    $args = $req->{args};
  my  $userid = $req->{userid};
  my  $cgidir = $req->{cgidir};
  my $dateref = $req->{dateref};
  return if $req->{modifiers}->{embedded};

  my $ladate;
  if ($now) {
    my ($jref, $mref, $aref) = (localtime ())[3..5];
    $mref++; $aref += 1900;
    $ladate = sprintf ("%02d/%02d/%04d", $jref, $mref, $aref);
    $ladate = msg('Today');
  } else {
    my ($aref, $mref, $jref) = ($dateref =~ /^(\d*)-(\d*)-(\d*).*$/);
    $ladate = sprintf ("%02d/%02d/%04d", $jref, $mref, $aref);
  }
  
  my $lang = $req->{language} || 'fr';
  # TODO: cache ?
  my $header = wget ("https://www.epfl.ch/templates/fragments/header.$lang.html");
  $header =~ s/http:\/\/search.epfl.ch\//https:\/\/search.epfl.ch\//g;

  print qq{$header};
  my $langtitle = ($lang eq 'fr') ? 'Language choice' : 'Choix de la langue';
  my $current = ($lang eq 'fr')
    ? qq{
        <li class="nav-item">
          <span class="visuallyhidden-xxs visuallyhidden-xs"> français </span>
        </li>
      }
    : qq{
        <li class="nav-item">
          <span class="visuallyhidden-xxs visuallyhidden-xs"> English  </span>
        </li>
      }
    ;
  my $other = ($lang eq 'fr')
    ? qq{
        <li class="nav-item nav-item-active pointerlink">
          <a onclick="setlang ('en');">
            <span class="visuallyhidden-xxs visuallyhidden-xs"> English  </span>
          </a>
        </li>
      }
    : qq{
        <li class="nav-item nav-item-active pointerlink">
          <a onclick="setlang ('fr');">
            <span class="visuallyhidden-xxs visuallyhidden-xs"> français </span>
          </a>
        </li>
      }
    ;

  print qq{
    <div style="width: 100%; height: 20px; margin-top: -30px; position: absolute;">
      <div style="width: 1120px; height: 20px; margin: auto;">
        <script>
          function setlang (lang) {
            document.cookie = "accreds_lang=" + lang + "; path=/";
            window.location.reload ();
          }
        </script>
        <ul class="nav-list" id="languages" title="$langtitle">
          $current
          $other
        </ul>
        <div style="clear:both"></div>
      </div>
    </div>
  };
  my  $user = $req->{persons}->getPerson ($userid);
  my $uname = $user->{name};
  my $super = '';
  if ($req->{modifiers}->{resetspoof}) {
    my $cookie = "accred::userid=; expires=Thu, 01-Jan-70 00:00:01 GMT; path=/";
    print qq{
      <script language="javascript">
        document.cookie = '$cookie';
        document.location.href = '$cgidir/main.pl';
      </script>
    };
  }
  my $resetspoof;
  if ($req->{realuserid} && ($req->{realuserid} != $userid)) {
    $resetspoof = qq{
      (<a class="pointerlink" onclick="resetspoof ();">}. msg('BecomeMyselfAgain') . qq{</a>)
    };
  }

  print qq{
    <div style="position: absolute; width: 100%; margin: auto; height: 30px;">
      <table style="
                width: 1120px;
               height: 100%;
               margin: auto;
           margin-top: -10px;
               border: 0;">
        <tr style="background-color: #EEEEFF; color: black">
          <th style="text-align: left;">
            $uname $super $resetspoof
          </th>
  };
  
  my $modurl = qq{$cgidir/accreds.pl/setdaterefform};
  print qq{
    <th align="right">}.
      msg('RefDate').
      qq{ : <a class="pointerlink" onclick="loadcontent ('$modurl');"> $ladate </a>
    </th>
  } if ($su || $req->{timemaster});
  print qq{
          </tr>
        </table>
      </div>
  };
  my $bgcolor = 'white'; # $req->{config}->{test} ? 'lightblue' : 'white';
  print qq{<div id="main-content" style="background-color: $bgcolor;">\n};
}

sub leftmenu {
  my $req = shift;
  return if $req->{modifiers}->{embedded};
  unless ($req->{modifiers}->{noleftmenu}) {
    my $bgcolor = 'white'; # $req->{config}->{test} ? 'lightblue' : 'white';
    print qq{
      <div id="leftmenu" class="left">
        <table style="border: 0; height: 100%; margin: 0; background-color: $bgcolor;">
          <tr>
            <td style="vertical-align: top; border: 0;" id="treeroot">
    };
    tree ($req);
    print qq{
            </td>
          </tr>
        </table>
      </div>
      <script>
        var leftmenu = document.getElementById ('leftmenu');
        window.onscroll = fixleftmenu;
      </script>
    };
  }
  print qq{
    <div id="leftnavigbutton" class="navigbutton"
         onclick="back ();"></div>
    <div id="rightnavigbutton" class="navigbutton"
         onclick="forward ();"></div>
    <div id="reloadbutton" class="navigbutton"
         onclick="reload ();"></div>

    <div id="result-content" class="goright">
      <section class="container">
        <div id="datapage"></div>
      </section>
  };
}

sub exportmenu {
  my $req = shift;
  print qq{Expires: -1\n};
  print qq{Content-type: text/html;charset=utf-8\n\n};
  tree ($req);
}

sub tree {
  my    $req = shift;
  my $userid = $req->{userid};
  my $cgidir = $req->{cgidir};
  my     $su = $req->{su};
  my $config = new Accred::Config (
    language => $req->{language},
  );
  my $unittypes = $config->{unittypes};
  my @unittypes = sort {
    $unittypes->{$a}->{order} <=> $unittypes->{$b}->{order};
  } keys %$unittypes;
  my @authlist = $req->{accreds}->isAccreditor ($userid);

  print qq{
    <span class="branch"
          style="margin-left: 0px; display: block;"
          id="rootbranch">
  };
  dobranch (
        id => 'me',
      name => msg('Me'),
      icon => '/images/ic-personnes.gif',
      view => "loadcontent ('$cgidir/accreds.pl/viewpers');",
  );
  dobranch (
        id => 'accreds',
      name => msg('Management'),
    expand => 1,
      icon => '/images/ic-gestion.gif',
      view => "loadcontent ('$cgidir/main.pl/main');",
    opened => 1,
  );
  #
  # Dashboard
  #
  my $isrolesmanager = $req->{roles}->isRolesManager (
    persid => $userid,
  );
  if ($isrolesmanager) {
    dobranch (
          id => 'dashboard',
        name => msg('Dashboard'),
      expand => 0,
        icon => '/images/ic-activites.gif',
        view => "loadcontent ('$cgidir/dashboard.pl/mainpage');"
    );
  }
  #
  # Summary
  #
  dobranch (
        id => 'summary',
      name => msg('Summary'),
    expand => 0,
      icon => '/images/wand.png',
      view => "loadcontent ('$cgidir/summary.pl/main');",
    opened => 1,
  ) if ($req->{roles}->isRolesManager (persid => $userid) ||
        $req->{rights}->isRightAdmin  (persid => $userid));
  #
  # Auditing tools
  #
  dobranch (
        id => 'auditing',
      name => msg('Auditing'),
    expand => 0,
      icon => '/images/wand.png',
      view => "loadcontent ('$cgidir/auditing.pl/main');",
    opened => 1,
  ) if ($su || $req->{auditor});
  #
  # Units
  #
  my $actions = $req->{accreds}->getActionUnits ($userid);
  if ($actions && keys %$actions) {
    my $unitsbytype;
    foreach my $unitid (keys %$actions) {
      my   $utype = $req->{units}->getUnitType ($unitid);
      my $utypeid = $utype->{id};
      push (@{$unitsbytype->{$utypeid}}, $unitid);
    }
    foreach my $utypeid (@unittypes) {
      next unless $unitsbytype->{$utypeid};
      my $utype = $unittypes->{$utypeid};
      dobranch (
            id => $utype->{id},
          name => $utype->{myunits},
        expand => 1,
          icon => $utype->{icon},
          view => "loadcontent ('$cgidir/accreds.pl/myunits?utype=$utypeid');",
        opened => 1,
      );

      my @unitids = @{$unitsbytype->{$utype->{id}}};
      my   $units = $req->{units}->getUnits (\@unitids);
      foreach my $unitid (
              sort {
                $units->{$a}->{name} cmp $units->{$b}->{name}
              } keys %$units) {
        my $unit = $units->{$unitid};
        my $uname = $unit->{name};
        $uname .= ' - ' . $unit->{longname} if $unit->{longname};
        dobranch (
              id => "menu$unitid",
            name => $uname,
          expand => $unit->{folder},
            icon => '/images/ic-unites.gif',
         delayed => 1,
            view => "loadcontent ('$cgidir/accreds.pl/viewunit?unitid=$unitid');",
        );
      }
      print qq{
        </span>
      };
    }
  }
  #
  # Persons
  #
  dobranch (
      id => 'persons',
    name => msg('People'),
    icon => '/images/ic-personnes.gif',
    view => "loadcontent ('$cgidir/accreds.pl/persons');",
  );
  #
  # Sciper
  #
  dobranch (
      id => 'persons',
    name => msg('Persons'),
    icon => '/images/ic-personnes.gif',
    view => "loadcontent ('$cgidir/persons.pl/main');",
  ) if ($su || @authlist);
  #
  # Revalidations
  #
  dobranch (
      id => 'revalidations',
    name => msg('Revalidations'),
    icon => '/images/ic-revalidation.gif',
    view => "loadcontent ('$cgidir/accreds.pl/revalidations');",
  ) if ($su || @authlist);
  #
  # Logs
  #
  dobranch (
      id => 'logs',
    name => msg('Logs'),
    icon => '/images/ic-logs.gif',
    view => "loadcontent ('$cgidir/logs.pl/viewlogs');"
  );
  #
  # Workflows
  #
  dobranch (
      id => 'workflows',
    name => msg('Workflows'),
    icon => '/images/ic-logs.gif',
    view => "loadcontent ('$cgidir/workflows.pl/listworkflows');"
  ) if $req->{config}->{workflow};
  #
  # Active workflows
  #
  dobranch (
        id => 'activeworkflows',
      name => msg('ActiveWorkflows'),
      icon => '/images/ic-revalidation.gif',
      view => "loadcontent ('$cgidir/workflows.pl/activeworkflows');",
  ) if $req->{config}->{workflow};
  #
  # End Accreditations
  #
  print qq{
        </span>
  };
  #
  # More
  #
  dobranch (
        id => 'more',
      name => msg('SeeMore'),
    expand => 1,
      icon => '/images/ic-voirplus.gif',
      view => "swapBranch ('more');",
  );
  #
  # Roles
  #
  dobranch (
        id => 'roles',
      name => msg('Roles'),
    expand => 1,
      icon => '/images/ic-roles.gif',
      view => "swapBranch ('roles');",
  );
  foreach my $utypeid (@unittypes) {
    my $utype = $unittypes->{$utypeid};
    my @allroles = $req->{rolesadmin}->listAllRoles ($utype->{id});
    next unless @allroles;
    dobranch (
          id => "roles$utype->{id}",
        name => $utype->{leftname},
      expand => 1,
        icon => '/images/ic-roles.gif',
        view => "loadcontent ('$cgidir/rolesadmin.pl/listroles?unittype=$utype->{id}');",
    );
    foreach my $role (sort { $a->{name} cmp $b->{name} } @allroles) {
      dobranch (
            id => "role$role->{id}",
          name => $role->{name},
          icon => '/images/ic-roles.gif',
          view => "loadcontent ('$cgidir/rolesadmin.pl/viewrole?roleid=$role->{id}');"
      );
    }
    print qq{
          </span>
    };
  }
  print qq{
        </span>
  };
  #
  # Rights
  #
  dobranch (
        id => 'rights',
      name => msg('Rights'),
    expand => 1,
      icon => '/images/ic-droits.gif',
      view => "swapBranch ('rights');",
    opened => 0,
  );
  foreach my $utypeid (@unittypes) {
    my $utype = $unittypes->{$utypeid};
    my @allrights = $req->{rightsadmin}->listAllRights ($utype->{id});
    next unless @allrights;
    dobranch (
          id => "rights$utype->{id}",
        name => $utype->{leftname},
      expand => 1,
        icon => '/images/ic-fonctions.gif',
        view => "loadcontent ('$cgidir/rightsadmin.pl/listrights?unittype=$utype->{id}');"
    );
    foreach my $right (
              sort {
                    $a->{ordre} <=> $b->{ordre} || $a->{name}  cmp $b->{name}
                   } @allrights) {
      dobranch (
            id => "right$right->{id}",
          name => $right->{name},
          icon => '/images/ic-droits.gif',
          view => "loadcontent ('$cgidir/rightsadmin.pl/viewright?rightid=$right->{id}');"
      );
    }
    print qq{
          </span>
    };
  }
  print qq{
        </span>
  };
  #
  # Proprerties
  #
  $req->{propsadmin} ||= new Accred::PropsAdmin ($req);
  dobranch (
        id => 'properties',
      name => msg('Properties'),
    expand => 1,
      icon => '/images/ic-proprietes.gif',
      view => "loadcontent ('$cgidir/propsadmin.pl/listproperties');",
  );
  my @allprops = $req->{propsadmin}->listProperties ();
  foreach my $prop (sort { $a->{name} cmp $b->{name} } @allprops) {
    dobranch (
          id => 'properties' . $prop->{id},
        name => $prop->{name},
      expand => 0,
        icon => '/images/ic-proprietes.gif',
        view => "loadcontent ('$cgidir/propsadmin.pl/viewproperty?propid=$prop->{id}');",
    );
  }
  print qq{
        </span>
  };
  #
  # positions
  #
  dobranch (
        id => 'positions',
      name => msg('Positions'),
    expand => 0,
      icon => '/images/ic-fonctions.gif',
      view => "loadcontent ('$cgidir/positions.pl/listpositions');",
  );
  print qq{
          </span>
  };
  print qq{
        </span>
  }; # End more

  #
  # Prestations
  #

  dobranch (
        id => 'prestations',
      name => msg('Prestations'),
    expand => 0,
      icon => '/images/ic-prestations.gif',
      view => 'https://prestations.epfl.ch/cgi-bin/prestations/priv',
    target => '_blank',
    opened => 0,
  );
  
  #
  # Documentation
  #

  dobranch (
        id => 'documentation',
      name => msg('Documentation'),
    expand => 0,
      icon => '/images/ic-prestations.gif',
      view => 'https://accreditation.epfl.ch/',
    target => '_blank',
    opened => 0,
  );
  
  #
  # About
  #
  
  dobranch (
        id => 'about',
      name => msg('About'),
    expand => 0,
      icon => '/images/question.jpg',
      view => "loadcontent ('$cgidir/accreds.pl/about');",
    opened => 0,
  );
  
  #
  # Logout
  #
  
  if (0 && $req->isauthenticated ()) {
    dobranch (
          id => 'logout',
        name => msg('Logout'),
      expand => 0,
        icon => '/images/logout.gif',
        view => "document.location.href='$cgidir/main.pl/logout';",
      opened => 0,
    );
  }
  print qq{
      </span>
  };
  print qq{
    </span>
  };
}

sub dobranch {
  my    $args = { @_ };
  my      $id = $args->{id};
  my    $name = $args->{name};
  my  $expand = $args->{expand};
  my    $icon = $args->{icon};
  my    $view = $args->{view};
  my  $target = $args->{target};
  my  $opened = $args->{opened};
  my $delayed = $args->{delayed};

  my  $style  = qq{style="background-color:#003366;color:#FFFFFF";};
  my $expicon = $expand
    ? ($opened ? '/images/minus.gif' : '/images/plus.gif')
    : '/images/tee.gif';
  my $onclick = $expand
    ? qq{onclick="swapBranch('$id');"}
    : '';

  print qq{
      <div class="trigger" id="div$id">
        <img src="$expicon" $onclick
             border="0"
             vertical-align="middle"
             id="folder$id"
        >
        <img src="$icon"
             border="0"
             vertical-align="middle"
             style="width: 16px; margin: 0;"
        >
  };
  if ($target) {
    print qq{
      <a href="$view" target="$target" title="$name" style="vertical-align: baseline;">
        $name
      </a>
    };
  } else {
    print qq{
      <a onclick="$view" title="$name" style="vertical-align: baseline;">
        $name
      </a>
    };
  }
  print qq{
      </div>
  };
  if ($expand) {
    my $display = $opened ? 'block' : 'none';
    print qq{
        <span class="branch" id="branch$id" style="display: $display;">
    };
    if ($delayed) {
      print qq{
        </span>
      };
    }
  }
}

my $depth = 0;
sub printtree {
  my ($root, $subtree) = @_;
  my  @subdirs = $subtree->{$root} ? @{$subtree->{$root}} : ();
  foreach my $unit (@subdirs) {
    print " "x$depth, "$unit->{id}\n"; $depth += 2;
    printtree ($unit->{id}, $subtree);
    $depth -= 2;
  }
}

sub maininit {
  my $req = shift;
  return if $req->{modifiers}->{embedded};
  return if $req->{modifiers}->{noleftmenu};
  print qq{
    <div id="result-content" class="goright">
      <section class="container">
        <div id="datapage"></div>
      </section>
  };
}

sub quit {
  my $req = shift;
  exit (); 
  $! = 0;
  die "Accred OK.";
}

sub seterror {
  my ($req, $msg) = @_;
  $req->{msg} = $msg;
}

sub setmsg {
  my ($req, $msg) = @_;
  $req->{msg} = $msg;
}

sub preamble {
  my $req = shift;
  my $msg = $req->{msg};
  print qq{
    <script> alert ('$msg'); </script>
  } if $req->{msg};
}

sub wget {
  my $url = shift;
  my $lwp = new LWP::UserAgent;
  $lwp->timeout(2);
  my $req = new HTTP::Request ('GET', $url);
  my $res = $lwp->request ($req);
  return $res->decoded_content if ($res->code == 200);
  return "<h1> Unable to fetch Web2010 header. </h1>";
}

sub errorlog {
  my ($req, $i) = 0;
  my $stack = "@_ from $req->{client}, stack = \n";
  while (my ($pack, $file, $line, $subname, $hasargs, $wanrarray) = caller ($i++)) {
    $stack .= "$file:$line\n";
  }
  my $now = scalar localtime;
  warn "[$now] [Accred warning] : $stack\n";
}

sub checkdate {
  my ($j, $m, $a) = @_;
  my @monthslen = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
  $monthslen [1] += 1 if (($a % 4) == 0);

  error (undef, "Date invalide : $j/$m/$a")
    if (($j !~ /^\d+$/) || ($m !~ /^\d+$/) || ($a !~ /^\d+$/)
    );

  error (undef, "Date invalide : $j/$m/$a")
    if (($a < 2000) || ($m < 1) || ($m > 12) ||
        ($j < 1) || ($j > $monthslen [$m-1])
    );
}

sub prettydate {
  my ($req, $date) = @_;
  my ($year, $month, $day, $hour, $min, $sec) =
    ($date =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/);
  $req->{language} ||= 'en';
  my  $mnames = $Accred::Messages::shortmonths->{$req->{language}};
  my   $mname = $mnames->[$month - 1];
  my $prettydate;
  if ($req->{language} eq 'en') {
    $prettydate = sprintf ("%s %02d %d %02d:%02d:%02d", $mname, $day, $year, $hour, $min, $sec);
  } else {
    $prettydate = sprintf ("%02d %s %d %02d:%02d:%02d", $day, $mname, $year, $hour, $min, $sec);
  }
  return $prettydate;
}

sub fixcase {
  my $string = shift;
  $string =~ tr/A-Z/a-z/;
  if ($string =~ /^(.*)([- ]+)(.*)$/) {
    my ($a, $b, $c) = ($1, $2, $3);
    $string = fixcase ($a) . $b . fixcase ($c);
  } else {
    $string = ucfirst $string
      unless ($string =~ /^(a|au|des|de|du|en|et|zur|le|la|les|sur|von|la)$/);
  }
  return $string;
}

sub setopenerurl {
  my $url = shift;
  print qq{
    <script>
      opener.location.href = '$url';
      window.close ();
    </script>
  };
}

sub reloadopener {
  print qq{X-HTTP-Target: none\n\n};
  print qq{
    <script>
      closepopup ();  
      reload ();
    </script>
  };
  quit ();
}

sub success {
  my ($req, $msg) = @_;
  print qq{X-HTTP-Target: popup\n\n};
  print qq{
    <h3> $msg </h3>
    <p style="text-align: center;">
      <input type="button" value="}.msg('OK').qq{" onclick="reload ();">
    </p>
  };
  quit;
}

sub closepopup {
  print qq{
    <script>
      closepopup ();  
    </script>
  };
}

sub redirect {
  my $url = shift;
  print qq{X-HTTP-Target: none\n\n};
  print qq{
    <script language="javascript">
      closepopup (); 
      loadcontent ('$url', 'load');
    </script>
  };
}

sub printstack {
  my $depth = 0;
  while (my ($package, $filename, $line) = caller ($depth++)) {
    warn "$filename : $package line $line.\n";
  }
}

sub sendmail {
  my ($to, $subject, $body) = @_;
  unless ($to =~ /^[\w\._\-]+@[\w\._\-]+\.[\w]{2,}$/) {
    warn "Utils::sendmail Bad email address : $to\n";
    return;
  }
  my $smtp = Net::SMTP->new ('mail.epfl.ch',
    Timeout => 60, 
      Debug => 0,
  );
  my $from = 'noreply@epfl.ch';
  my $data = "To: $to\n".
             "From: $from\n".
             "Reply-to: 1234\@epfl.ch\n".
             "Subject: $subject\n".
             "Content-Type: text/html; charset=utf-8\n".
             "\n".
             "$body\n";
  $smtp->mail ($from) or do {
    warn "sendmail: Fails to set from value to email.\n"; 
    return;
  };
  $smtp->to   ($to)   or do {
    warn "sendmail: Fails to set to value to email.\n"; 
    return;
  };
  $smtp->data ($data) or do {
    warn "sendmail: Fails to set data value to email.\n"; 
    return;
  };
  $smtp->quit;
}

sub sendmail_sendmail {
  my ($to, $subject, $body) = @_;
  $to = 'claude.lecommandeur@epfl.ch';
  unless ($to =~ /^[\w\._\-]+@[\w\._\-]+\.[\w]{2,}$/) {
    warn "Utils::sendmail_sendmail Bad email address : $to\n";
    return;
  }
  local (*STDOUT); close (STDOUT);
  open (MAIL, "|/usr/sbin/sendmail $to 2>&1 > /dev/null") ||
    error (undef, "Unable to send email to $to.");
  binmode (MAIL, ':utf8');
  print MAIL
    "From: noreply\@epfl.ch\n".
    "Subject: $subject.\n",
    $body
    ;
  close (MAIL);
}

sub sendmailcore {
  my ($to, $subject, $body) = @_;
  $to = 'claude.lecommandeur@epfl.ch';
  unless ($to =~ /^[\w\._\-]+@[\w\._\-]+\.[\w]{2,}$/) {
    warn "Utils::sendmailcore Bad email address : $to\n";
    return;
  }
  local (*STDOUT); close (STDOUT);
  CORE::open (MAIL, "|/usr/sbin/sendmail $to 2>&1 > /dev/null") ||
    error (undef, "Unable to send email to $to.");
  CORE::binmode (MAIL, ':utf8');
  CORE::print MAIL
    "From: noreply\@epfl.ch\n".
    "Subject: $subject.\n",
    $body
    ;
  CORE::close (MAIL);
}

sub chooseperson {
  my ($req, $title, $action, $hiddens, $fieldname) = @_;
  my $args = $req->{args};

  $fieldname ||= 'persid';
  if ($args->{persname}) {
    $args->{persname} =~ s/^\s*//; $args->{persname} =~ s/\s*$//;
    if ($args->{persname} =~ /^\d\d\d\d\d\d$/) { # Sciper
      my $pers = $req->{persons}->getPerson ($args->{persname});
      error ($req, msg('UnknownPersonId')) unless $pers;
      return $pers->{id};
    }
    my @persids = $req->{persons}->getPersonFromNameLike ($args->{persname});
    my @persidslist;
    foreach my $persid (@persids) {
      my @accreds = $req->{accreds}->getAccredsOfPerson ($persid);
      push (@persidslist, $persid) if @accreds;
    }
    error ($req, msg('UnknownName')) unless @persidslist;
    return $persidslist [0] if (@persidslist == 1);

    my $persons = $req->{persons}->getPersons (\@persidslist);
    print qq{X-HTTP-Target: popup\n\n};
    print qq{
      <h3> $title </h3>
      <b> }.msg('SeveralResults').qq{ </b>
      <br><br>
      <form onsubmit="return postform (this, '$action');">
    };
    foreach my $hidden (keys %$hiddens) {
      print qq{<input type="hidden" name="$hidden" value="$hiddens->{$hidden}">\n};
    }
    #
    print qq{
        <select name="$fieldname">
    };
    foreach my $persid (
        sort {
          $persons->{$a}->{surname} cmp $persons->{$b}->{surname};
        } @persidslist) {
      my  $pers = $persons->{$persid};
      my $pname = $pers->{name};
      print qq{<option value="$persid">$pname ($persid)</option>\n};
    }
    print qq{
        </select>
        <input type="submit" value="}.msg('OK').qq{">
      </form>
    };
    return;
  } else {
    print qq{X-HTTP-Target: popup\n\n};
    print qq{
      <h3> $title </h3>
      <form name="persform" onsubmit="return postform (this, '$action');">
    };
    foreach my $hidden (keys %$hiddens) {
      print qq{<input type="hidden" name="$hidden" value="$hiddens->{$hidden}">\n};
    }
    print qq{
        <table cellspacing="5" style="margin: auto;">
          <tr>
            <th>
              }.msg('PersonName').qq{
            </th>
            <td>
              <input name="persname" size="30">
            </td>
          </tr>
          <tr>
            <td colspan="2" align="center">
              <input type="submit" value="}.msg('OK').qq{">
              <input type="reset"  value="}.msg('Cancel').qq{"
                     onclick="closepopup ();">
            </td>
          </tr>
        </table>
      </form>
      <br>
      <script>
        document.persform.pname.focus ();
      </script>
    };
    return;
  }
}

use vars qw{$profile};
$profile = 1 if eval "use Time::HiRes; 1;";
sub profile {
  return $profile;
}

sub cache {
  my ($func, $life) = @_;
  my $cache;

  my $afunc = sub {
    my $key = join (',', @_);
    my $now = time;

    if ($key eq 'CLEARCACHE') {
      $cache = {};
      return;
    }
    # Should the cache be cleaned?
    if ($key eq 'CLEANCACHE') {
      foreach my $ckey (keys %$cache) {
        delete $cache->{$ckey} if $cache->{$ckey}->{expires} < $now;
      }
      return;
    }
    unless (exists $cache->{$key} and $cache->{$key}->{expires} >= $now) {
      my $val = $func->(@_);
      $cache->{$key} = {
          value => $val,
        expires => $now + $life,
      };
    }
    return $cache->{$key}->{value};
  };
  return $afunc;
}

1;
