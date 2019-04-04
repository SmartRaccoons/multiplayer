CREATE DATABASE `Multibase` /*!40100 DEFAULT CHARACTER SET utf8 */;

CREATE TABLE `auth_user` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `draugiem_uid` int(11) DEFAULT NULL,
  `facebook_uid` varchar(100) DEFAULT NULL,
  `facebook_token_for_business` varchar(100) DEFAULT NULL,
  `google_uid` varchar(100) DEFAULT NULL,
  `inbox_uid` varchar(100) DEFAULT NULL,
  `name` varchar(100) NOT NULL,
  `img` varchar(1000) DEFAULT NULL,
  `last_login` datetime NOT NULL,
  `date_joined` datetime NOT NULL,
  `language` varchar(12) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `draugiem_uid` (`draugiem_uid`),
  KEY `facebook_uid` (`facebook_uid`),
  KEY `google_uid` (`google_uid`),
  KEY `inbox_uid` (`inbox_uid`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `auth_user_session_draugiem` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `code` varchar(50) DEFAULT NULL,
  `api_key` varchar(50) DEFAULT NULL,
  `last_updated` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `auth_user_id` (`user_id`),
  KEY `auth_hash` (`code`),
  CONSTRAINT `auth_user_id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `auth_user_session_facebook` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `code` varchar(1024) DEFAULT NULL,
  `last_updated` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `auth_user__user_id` (`user_id`),
  KEY `auth_user__code` (`code`),
  CONSTRAINT `auth_user__id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `auth_user_session_google` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `code` varchar(1024) DEFAULT NULL,
  `last_updated` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `auth_user_google_user_id` (`user_id`),
  KEY `auth_user_google_code` (`code`),
  CONSTRAINT `auth_user_google_id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `transaction_draugiem` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `transaction_id` varchar(100) NOT NULL,
  `service` varchar(10) NOT NULL,
  `user_id` int(11) NOT NULL,
  `language` varchar(12) NOT NULL,
  `fulfill` int(1) DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `fulfilled` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `transaction_draugiem_user_id` (`user_id`),
  CONSTRAINT `transaction_draugiem_auth_user_id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `transaction_facebook` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `service` varchar(10) NOT NULL,
  `user_id` int(11) NOT NULL,
  `language` varchar(12) NOT NULL,
  `fulfill` int(1) DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `fulfilled` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `transaction_facebook_user_id` (`user_id`),
  CONSTRAINT `transaction_facebook_auth_user_id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `transaction_inbox` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `transaction_id` varchar(100) NOT NULL,
  `service` varchar(10) NOT NULL,
  `user_id` int(11) NOT NULL,
  `language` varchar(12) NOT NULL,
  `fulfill` int(1) DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `fulfilled` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `transaction_inbox_user_id` (`user_id`),
  CONSTRAINT `transaction_inbox_auth_user_id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;



CREATE TABLE `coins_history` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `coins` int(6) DEFAULT NULL,
  `action` datetime NOT NULL,
  `type` int(2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `coins_history_user_id` (`user_id`),
  KEY `coins_history_action` (`action`),
  KEY `coins_history_type` (`type`),
  CONSTRAINT `coins_history_user_id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
