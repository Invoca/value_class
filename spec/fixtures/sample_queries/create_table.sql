CREATE TABLE `access_tokens` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `token` varchar(255) NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `organization_membership_id` int(11) NOT NULL,
  `lock_version` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_access_tokens_on_token` (`token`),
  KEY `index_access_tokens_on_organization_membership_id` (`organization_membership_id`),
  CONSTRAINT `index_access_tokens_on_organization_membership_id` FOREIGN KEY (`organization_membership_id`) REFERENCES `organization_memberships` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
