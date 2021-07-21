CREATE DATABASE `Multibase` /*!40100 DEFAULT CHARACTER SET utf8 */;

CREATE TABLE `auth_user` (
  `id` int NOT NULL AUTO_INCREMENT,
  `draugiem_uid` int DEFAULT NULL,
  `facebook_uid` varchar(100) DEFAULT NULL,
  `facebook_token_for_business` varchar(100) DEFAULT NULL,
  `facebook_subscriptions` JSON DEFAULT NULL,
  `google_uid` varchar(100) DEFAULT NULL,
  `apple_uid` varchar(100) DEFAULT NULL,
  `inbox_uid` varchar(100) DEFAULT NULL,
  `vkontakte_uid` varchar(100) DEFAULT NULL,
  `odnoklassniki_uid` varchar(100) DEFAULT NULL,
  `name` varchar(100) NOT NULL,
  `img` varchar(1000) DEFAULT NULL,
  `last_login` datetime NOT NULL,
  `date_joined` datetime NOT NULL,
  `language` varchar(12) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `auth_user__draugiem_uid` (`draugiem_uid`),
  KEY `auth_user__facebook_uid` (`facebook_uid`),
  KEY `auth_user__google_uid` (`google_uid`),
  KEY `auth_user__inbox_uid` (`inbox_uid`)
  KEY `auth_user__vkontakte_uid` (`vkontakte_uid`)
  KEY `auth_user__odnoklassniki_uid` (`odnoklassniki_uid`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;


CREATE TABLE `auth_user_session_draugiem` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `code` varchar(50) DEFAULT NULL,
  `api_key` varchar(50) DEFAULT NULL,
  `last_updated` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `auth_user_session_draugiem__user_id` (`user_id`),
  KEY `auth_user_session_draugiem__code` (`code`),
  CONSTRAINT `auth_user_session_draugiem__id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE `auth_user_session_facebook` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `code` text DEFAULT NULL,
  `last_updated` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `auth_user_session_facebook__user_id` (`user_id`),
  KEY `auth_user_session_facebook__code` (`code`(20)),
  CONSTRAINT `auth_user_session_facebook__id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE `auth_user_session_google` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `code` text DEFAULT NULL,
  `last_updated` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `auth_user_session_google__user_id` (`user_id`),
  KEY `auth_user_session_google__code` (`code`(20)),
  CONSTRAINT `auth_user_session_google__id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE `auth_user_session_apple` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `code` text DEFAULT NULL,
  `last_updated` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `auth_user_session_apple__user_id` (`user_id`),
  KEY `auth_user_session_apple__code` (`code`(20)),
  CONSTRAINT `auth_user_session_apple__id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE `auth_user_session_email` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `code` varchar(100) DEFAULT NULL,
  `last_updated` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `auth_user_session_email__user_id` (`user_id`),
  KEY `auth_user_session_email__code` (`code`),
  CONSTRAINT `auth_user_session_email__id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE `transaction_draugiem` (
  `id` int NOT NULL AUTO_INCREMENT,
  `transaction_id` varchar(100) NOT NULL,
  `service` varchar(10) NOT NULL,
  `user_id` int NOT NULL,
  `fulfill` int DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `fulfilled` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `transaction_draugiem__user_id` (`user_id`),
  CONSTRAINT `transaction_draugiem__id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE `transaction_facebook` (
  `id` int NOT NULL AUTO_INCREMENT,
  `service` varchar(10) NOT NULL,
  `user_id` int NOT NULL,
  `language` varchar(12) NOT NULL,
  `fulfill` int DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `fulfilled` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `transaction_facebook__user_id` (`user_id`),
  CONSTRAINT `transaction_facebook__id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE `transaction_inbox` (
  `id` int NOT NULL AUTO_INCREMENT,
  `transaction_id` varchar(100) NOT NULL,
  `service` varchar(10) NOT NULL,
  `user_id` int NOT NULL,
  `language` varchar(12) NOT NULL,
  `fulfill` int DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `fulfilled` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `transaction_inbox__user_id` (`user_id`),
  CONSTRAINT `transaction_inbox__id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE `transaction_odnoklassniki` (
  `id` int NOT NULL AUTO_INCREMENT,
  `service` varchar(10) NOT NULL,
  `user_id` int NOT NULL,
  `fulfill` int DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `fulfilled` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `transaction_odnoklassniki__user_id` (`user_id`),
  CONSTRAINT `transaction_odnoklassniki__id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE `transaction_cordova` (
  `id` int NOT NULL AUTO_INCREMENT,
  `transaction_id` text NOT NULL,
  `service` varchar(10) NOT NULL,
  `platform` varchar(10) NOT NULL,
  `user_id` int NOT NULL,
  `fulfill` int DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `fulfilled` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `transaction_cordova__user_id` (`user_id`),
  CONSTRAINT `transaction_cordova__id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE `coins_history` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `coins` int DEFAULT NULL,
  `action` datetime NOT NULL,
  `type` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `coins_history__user_id` (`user_id`),
  KEY `coins_history__action` (`action`),
  KEY `coins_history__type` (`type`),
  CONSTRAINT `coins_history___id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE `user_message` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int DEFAULT NULL,
  `message` text,
  `added` datetime NOT NULL,
  `actual` datetime DEFAULT NULL,
  `platform` json DEFAULT NULL,
  `language` json DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `user_message_user_id` (`user_id`),
  CONSTRAINT `user_message_user_id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE `user_message_read` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `user_message_id` int NOT NULL,
  `added` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `user_message_read_user_id` (`user_id`),
  KEY `user_message_read_user_message_id` (`user_message_id`),
  CONSTRAINT `user_message_read_user_id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`),
  CONSTRAINT `user_message_read_user_message_id_ref` FOREIGN KEY (`user_message_id`) REFERENCES `user_message` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE `auth_user_cordova_params` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `token` varchar(1024) DEFAULT NULL,
  `last_updated` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id_UNIQUE` (`user_id`),
  KEY `auth_user_cordova_params_id` (`user_id`),
  CONSTRAINT `auth_user_cordova_params_id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE `deletion_facebook` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `code` text DEFAULT NULL,
  `status` text DEFAULT NULL,
  `initiated` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `deletion_facebook__user_id` (`user_id`),
  KEY `deletion_facebook__code` (`code`(20)),
  CONSTRAINT `deletion_facebook__id_ref` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;
