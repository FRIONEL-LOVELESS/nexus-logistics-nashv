-- HUD schema. Runs automatically on first start of the mysql:8 container
-- (files in /docker-entrypoint-initdb.d run in alphabetical order, inside MYSQL_DATABASE).
SET NAMES utf8mb4;

CREATE TABLE variants (
  id          TINYINT UNSIGNED NOT NULL,
  slug        VARCHAR(32)  NOT NULL,
  title       VARCHAR(80)  NOT NULL,
  subtitle    VARCHAR(200) NULL,
  disclaimer  VARCHAR(300) NULL,
  sort_order  SMALLINT     NOT NULL DEFAULT 0,
  is_active   TINYINT(1)   NOT NULL DEFAULT 1,
  updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_variants_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One row per sector (variant "sectors") or per organization (variant "companies").
CREATE TABLE sectors_or_orgs (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  variant_id          TINYINT UNSIGNED NOT NULL,
  slug                VARCHAR(64)  NOT NULL,
  code                VARCHAR(32)  NOT NULL,
  name                VARCHAR(120) NOT NULL,
  tagline             VARCHAR(200) NULL,
  mission             TEXT NULL,
  volunteer_help      TEXT NULL,
  preservation_notes  TEXT NULL,
  file_count          INT UNSIGNED NOT NULL DEFAULT 0,
  size_mb             DECIMAL(14,2) NOT NULL DEFAULT 0,
  reported_size       DECIMAL(14,2) NULL COMMENT 'raw size value from sector_totals.json (appears to be GB)',
  sort_order          SMALLINT NOT NULL DEFAULT 0,
  is_public           TINYINT(1) NOT NULL DEFAULT 1,
  updated_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_org_variant_slug (variant_id, slug),
  KEY ix_org_variant (variant_id, sort_order),
  CONSTRAINT fk_org_variant FOREIGN KEY (variant_id) REFERENCES variants (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Top-folder rollups (sectors) or flagship projects / official links (companies).
CREATE TABLE items (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  org_id      INT UNSIGNED NOT NULL,
  variant_id  TINYINT UNSIGNED NOT NULL,
  kind        ENUM('folder','project','link') NOT NULL,
  label       VARCHAR(200) NOT NULL,
  detail      VARCHAR(500) NULL,
  file_count  INT UNSIGNED NOT NULL DEFAULT 0,
  size_mb     DECIMAL(14,2) NOT NULL DEFAULT 0,
  url         VARCHAR(500) NULL,
  sort_order  SMALLINT NOT NULL DEFAULT 0,
  is_public   TINYINT(1) NOT NULL DEFAULT 1,
  updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_items_org (org_id, kind, sort_order),
  KEY ix_items_variant (variant_id),
  CONSTRAINT fk_items_org FOREIGN KEY (org_id) REFERENCES sectors_or_orgs (id) ON DELETE CASCADE,
  CONSTRAINT fk_items_variant FOREIGN KEY (variant_id) REFERENCES variants (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE status_events (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  variant_id  TINYINT UNSIGNED NOT NULL,
  org_id      INT UNSIGNED NULL,
  level       ENUM('info','ok','warn','alert') NOT NULL DEFAULT 'info',
  message     VARCHAR(280) NOT NULL,
  event_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_public   TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  KEY ix_events_variant (variant_id, event_at),
  CONSTRAINT fk_events_variant FOREIGN KEY (variant_id) REFERENCES variants (id) ON DELETE CASCADE,
  CONSTRAINT fk_events_org FOREIGN KEY (org_id) REFERENCES sectors_or_orgs (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Public, whitelisted views. The read-only API user can SELECT these views and nothing else.
CREATE VIEW v_public_variants AS
  SELECT id, slug, title, subtitle, disclaimer, sort_order
  FROM variants WHERE is_active = 1;

CREATE VIEW v_public_orgs AS
  SELECT o.id, v.slug AS variant_slug, o.code, o.name, o.tagline, o.mission, o.volunteer_help,
         o.preservation_notes, o.file_count, o.size_mb, o.sort_order
  FROM sectors_or_orgs o JOIN variants v ON v.id = o.variant_id
  WHERE o.is_public = 1 AND v.is_active = 1;

CREATE VIEW v_public_items AS
  SELECT i.org_id, v.slug AS variant_slug, i.kind, i.label, i.detail, i.file_count, i.size_mb, i.url, i.sort_order
  FROM items i
  JOIN variants v ON v.id = i.variant_id
  JOIN sectors_or_orgs o ON o.id = i.org_id AND o.is_public = 1
  WHERE i.is_public = 1 AND v.is_active = 1;

CREATE VIEW v_public_events AS
  SELECT e.id, v.slug AS variant_slug, e.level, e.message, e.event_at
  FROM status_events e JOIN variants v ON v.id = e.variant_id
  WHERE e.is_public = 1 AND v.is_active = 1;
