USE cadi;
-- MySQL dump 10.13  Distrib 5.1.73, for redhat-linux-gnu (x86_64)
--
-- Host: cadidb.epfl.ch    Database: cadi
-- ------------------------------------------------------
-- Server version	5.1.73-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `DBClients`
--

DROP TABLE IF EXISTS `DBClients`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `DBClients` (
  `name` varchar(32) NOT NULL,
  `owner` char(6) DEFAULT NULL,
  `contact` varchar(64) DEFAULT NULL,
  `creation` datetime DEFAULT NULL,
  KEY `name` (`name`),
  KEY `owner` (`owner`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Manco`
--

DROP TABLE IF EXISTS `Manco`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Manco` (
  `ID` int(10) NOT NULL AUTO_INCREMENT,
  `year` mediumint(7) DEFAULT NULL,
  `yt` varchar(8) DEFAULT NULL,
  `image` blob,
  `mnh` int(10) DEFAULT NULL,
  `mh` int(10) DEFAULT NULL,
  `used` int(10) DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=MyISAM AUTO_INCREMENT=132 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `WSAppsCallers`
--

DROP TABLE IF EXISTS `WSAppsCallers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `WSAppsCallers` (
  `ws` varchar(16) NOT NULL,
  `app` varchar(16) NOT NULL,
  `sciper` char(16) NOT NULL,
  `password` varchar(64) DEFAULT NULL,
  `creator` char(6) NOT NULL,
  `added` datetime DEFAULT NULL,
  `removed` datetime DEFAULT NULL,
  KEY `ws` (`ws`,`app`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `WSAppsHosts`
--

DROP TABLE IF EXISTS `WSAppsHosts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `WSAppsHosts` (
  `ws` varchar(16) NOT NULL,
  `app` varchar(16) NOT NULL,
  `addr` varchar(16) NOT NULL,
  `creator` char(6) NOT NULL,
  `added` datetime DEFAULT NULL,
  `removed` datetime DEFAULT NULL,
  KEY `ws` (`ws`,`app`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `WSClients`
--

DROP TABLE IF EXISTS `WSClients`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `WSClients` (
  `name` varchar(32) NOT NULL,
  `owner` char(6) DEFAULT NULL,
  `contact` varchar(64) DEFAULT NULL,
  `creation` datetime DEFAULT NULL,
  `removed` datetime DEFAULT NULL,
  KEY `name` (`name`),
  KEY `owner` (`owner`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `WSServices`
--

DROP TABLE IF EXISTS `WSServices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `WSServices` (
  `name` varchar(32) NOT NULL,
  `creation` datetime DEFAULT NULL,
  `removed` datetime DEFAULT NULL,
  KEY `name` (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `access`
--

DROP TABLE IF EXISTS `access`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `access` (
  `tbl` mediumint(9) DEFAULT NULL,
  `champs` mediumint(9) DEFAULT NULL,
  `sciper` char(6) DEFAULT NULL,
  `role` mediumint(9) DEFAULT NULL,
  `droit` mediumint(9) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `champs`
--

DROP TABLE IF EXISTS `champs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `champs` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `name` varchar(16) DEFAULT NULL,
  `tbl` mediumint(9) DEFAULT NULL,
  `description` text,
  `type` varchar(16) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=340 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `datafields`
--

DROP TABLE IF EXISTS `datafields`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `datafields` (
  `name` varchar(32) DEFAULT NULL,
  `ptype` varchar(32) DEFAULT NULL,
  `ordre` smallint(6) DEFAULT NULL,
  `label` varchar(128) DEFAULT NULL,
  `dont` varchar(64) DEFAULT NULL,
  `type` varchar(64) DEFAULT NULL,
  `arity` smallint(6) DEFAULT NULL,
  `sqltable` varchar(64) DEFAULT NULL,
  `sqlfield` varchar(64) DEFAULT NULL,
  `inkey` varchar(32) DEFAULT NULL,
  `outkey` varchar(32) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `datatypes`
--

DROP TABLE IF EXISTS `datatypes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `datatypes` (
  `name` varchar(32) NOT NULL DEFAULT '',
  `label` varchar(128) DEFAULT NULL,
  `refkey` varchar(64) DEFAULT NULL,
  `displaytype` varchar(16) DEFAULT NULL,
  `displayfield` varchar(32) DEFAULT NULL,
  `mastertable` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dbs`
--

DROP TABLE IF EXISTS `dbs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dbs` (
  `name` varchar(16) NOT NULL DEFAULT '',
  `type` varchar(16) DEFAULT NULL,
  `description` text,
  `server` varchar(16) DEFAULT NULL,
  `responsable` varchar(6) DEFAULT NULL,
  PRIMARY KEY (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `delegates`
--

DROP TABLE IF EXISTS `delegates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `delegates` (
  `provider` varchar(6) DEFAULT NULL,
  `sciper` varchar(6) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `events`
--

DROP TABLE IF EXISTS `events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `events` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `date` datetime DEFAULT NULL,
  `type` mediumint(9) DEFAULT NULL,
  `args` text,
  `author` varchar(8) DEFAULT NULL,
  `status` smallint(6) DEFAULT NULL,
  `appl` varchar(8) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `date` (`date`,`type`),
  KEY `type_date` (`type`,`date`)
) ENGINE=MyISAM AUTO_INCREMENT=1518373 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `eventstypes`
--

DROP TABLE IF EXISTS `eventstypes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `eventstypes` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `nom` varchar(32) NOT NULL DEFAULT '',
  `libelle` varchar(64) DEFAULT NULL,
  `description` text,
  PRIMARY KEY (`id`),
  KEY `nom` (`nom`)
) ENGINE=MyISAM AUTO_INCREMENT=66 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `filters`
--

DROP TABLE IF EXISTS `filters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `filters` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `name` varchar(32) DEFAULT NULL,
  `type` varchar(32) DEFAULT NULL,
  `value` text,
  `owner` varchar(6) DEFAULT NULL,
  `description` text,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=44 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `logs`
--

DROP TABLE IF EXISTS `logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `logs` (
  `date` datetime DEFAULT NULL,
  `caller` varchar(32) DEFAULT NULL,
  `opcode` smallint(6) DEFAULT NULL,
  `author` char(6) DEFAULT NULL,
  `objid` varchar(16) DEFAULT NULL,
  `detail` varchar(128) DEFAULT NULL,
  KEY `date` (`date`,`caller`,`opcode`,`author`,`objid`,`detail`),
  KEY `detail` (`detail`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notifications` (
  `date` datetime DEFAULT NULL,
  `event` mediumint(9) DEFAULT NULL,
  `listener` varchar(32) DEFAULT NULL,
  `status` mediumint(9) DEFAULT NULL,
  `errmsg` text,
  KEY `event` (`event`,`listener`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `oldtokens`
--

DROP TABLE IF EXISTS `oldtokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `oldtokens` (
  `token` varchar(64) DEFAULT NULL,
  `username` varchar(16) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pendingnotifications`
--

DROP TABLE IF EXISTS `pendingnotifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `pendingnotifications` (
  `event` mediumint(9) DEFAULT NULL,
  `listener` varchar(32) DEFAULT NULL,
  `tries` smallint(6) DEFAULT NULL,
  `status` smallint(6) DEFAULT NULL,
  `await` tinyint(1) DEFAULT NULL,
  KEY `event` (`event`,`listener`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `providers`
--

DROP TABLE IF EXISTS `providers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `providers` (
  `id` varchar(6) NOT NULL DEFAULT '',
  `name` varchar(16) NOT NULL DEFAULT '',
  `description` text,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `resources`
--

DROP TABLE IF EXISTS `resources`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resources` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `name` varchar(32) DEFAULT NULL,
  `owner` varchar(6) DEFAULT NULL,
  `libelle` varchar(64) DEFAULT NULL,
  `description` text,
  `type` mediumint(9) DEFAULT NULL,
  `acl` text,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=7 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `resources_admins`
--

DROP TABLE IF EXISTS `resources_admins`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resources_admins` (
  `resource` mediumint(9) DEFAULT NULL,
  `sciper` char(6) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `resources_types`
--

DROP TABLE IF EXISTS `resources_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resources_types` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `name` varchar(32) DEFAULT NULL,
  `libelle` varchar(64) DEFAULT NULL,
  `description` text,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subscriptions`
--

DROP TABLE IF EXISTS `subscriptions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `subscriptions` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `sciper` varchar(6) NOT NULL DEFAULT '',
  `type` mediumint(9) DEFAULT NULL,
  `detail` varchar(64) DEFAULT NULL,
  `digest` char(1) DEFAULT NULL,
  `description` text,
  PRIMARY KEY (`id`),
  KEY `sciper` (`sciper`)
) ENGINE=MyISAM AUTO_INCREMENT=11 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tbls`
--

DROP TABLE IF EXISTS `tbls`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tbls` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `provider` varchar(6) DEFAULT NULL,
  `name` varchar(16) DEFAULT NULL,
  `db` varchar(16) DEFAULT NULL,
  `description` text,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=55 DEFAULT CHARSET=latin1 COMMENT='Table des tables';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tmptodel`
--

DROP TABLE IF EXISTS `tmptodel`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tmptodel` (
  `username` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`username`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tmptokens`
--

DROP TABLE IF EXISTS `tmptokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tmptokens` (
  `client_id` varchar(32) NOT NULL,
  `code` varchar(64) NOT NULL,
  `username` varchar(64) DEFAULT NULL,
  `uniqueid` char(6) DEFAULT NULL,
  `resource` varchar(64) DEFAULT NULL,
  `scopes` varchar(128) DEFAULT NULL,
  `value` varchar(64) NOT NULL,
  `created` datetime DEFAULT NULL,
  `lastused` datetime DEFAULT NULL,
  PRIMARY KEY (`value`),
  KEY `code` (`code`),
  KEY `username` (`username`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

DROP TABLE IF EXISTS `config`;
CREATE TABLE `config` (
  `id` varchar(32) NOT NULL,
  `value` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

INSERT INTO cadi.config (id,value) VALUES
	 ('env.toml','env = "dev"

[prodemco]
oracle.connectionstring = "host=agatst02.epfl.ch;port=50024;sid=AGAT"
ftp.host = "prodemco.ch"
ftp.subfolder = "test"

[sll]
ftp.host = "dummy"
ftp.port = 2022
ftp.user = "sll-epfl"

[uc]
tools.url = "https://uctools.epfl.ch/AXL-dev/WebServiceUC.asmx"

[ldap]
hosts = [
    "ldap-master-test.epfl.ch"
]
host.read = "test-ldap.epfl.ch"
master = "ldap-master-test.epfl.ch"
master32 = "ldap-master-test.epfl.ch"
base = "c=ch"

[scoldap]
hosts = [
    "scoldap-master-test.epfl.ch"
]
master = "scoldap-master-test.epfl.ch"
master32 = "scoldap-master-test.epfl.ch"
base = "o=epfl,c=ch"

[activedirectory]
hosts = [
    "ldaps://tad1.extest.epfl.ch",
    "ldaps://tad2.extest.epfl.ch"
]
domain = "extest.epfl.ch"
root = "DC=extest,DC=epfl,DC=ch"

[sapservices]
restadapter.url = "https://testsapservices.epfl.ch/poq/RESTAdapter"

[sid]
ftp.host = "cmp2prd8.epfl.ch"
ftp.user = "cmp2cadi"

[accrednotifier]
execmode = "test"

[notifier]
host = "notifier-test.epfl.ch"
port = 443
file = "/cgi-bin/notify"
verbose = 1

[collecte]
orcid.url = "https://orcid-integration-test.epfl.ch/export/"

[units]
api.url = "https://units-test.epfl.ch/units-api/v1/units"

[atela]
url = "https://test-atela.epfl.ch"

[lists]
host = "listes1.epfl.ch"
port = 4322

[catalyse]
sciquest.test.url = "https://erm-test.epfl.ch/erd-services/json/import/"
sciquest.test-proj.url = "https://erm-dev.epfl.ch/erd-services/json/import/"
ivalua.test.url = "https://catalyse-test.epfl.ch/api.aspx/v1.0/bas/"
ivalua.test-proj.url = "https://catalyse-test-projet.epfl.ch/api.aspx/v1.0/bas/"
ivalua.formation.url = "https://catalyse-formation.epfl.ch/async.aspx/en/eai/api/"
catalyse.server = "test-proj"

[camipro]
mycamipro.api.user.url = "https://mycamipro.epfl.ch/ws/v2/user/"

[cascad]
wsad = "https://test-websrv.epfl.ch/cgi-bin/rwsad/"
wsgroups = "https://groups-test.epfl.ch/api/v1/events/accreditations"

[emails]
address.service = "https://mail.epflmscloud.ch/createmailbox/"
ewa.mailbox = "idev-md@groupes.epfl.ch"

[archibus]
datasource = "CRISTALMSSQL"
user = "svc1369cristal-cadid"

[websrv]
host = "https://websrv-test.epfl.ch"

[accred]
absences.url = "http://localhost:8080/absences"
absences.user = "accred"

[eduid]
internal.api = "https://eduid-test.epfl.ch/api/v1"

[mdapi]
base.url = "https://api-test.epfl.ch"
user = "M04572"

[coreapi]
creategaspar.url = "https://api-test.epfl.ch/v1/gaspar"

[misc]
cognac.email = "cognac.crons-test@groupes.epfl.ch"
');
