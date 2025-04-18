-- DROP SCHEMA whitelabel;

CREATE SCHEMA whitelabel AUTHORIZATION postgres;

-- Enum Types
CREATE TYPE whitelabel."album_status" AS ENUM (
'Draft',
'Scheduled',
'Released',
'Removed');

CREATE TYPE whitelabel."album_type" AS ENUM (
'Single',
'EP',
'Album',
'Compilation');

CREATE TYPE whitelabel."asset_type" AS ENUM (
'Image',
'Video',
'Text');

CREATE TYPE whitelabel."channel_status" AS ENUM (
'Active',
'Inactive');

CREATE TYPE whitelabel."copyright_status" AS ENUM (
'Pending',
'Registered');

CREATE TYPE whitelabel."discovery_status" AS ENUM (
'Active',
'Inactive');

CREATE TYPE whitelabel."funding_status" AS ENUM (
'Pending',
'Repaid');

CREATE TYPE whitelabel."mastering_status" AS ENUM (
'InProgress',
'Completed');

CREATE TYPE whitelabel."pitch_status" AS ENUM (
'Pending',
'Approved',
'Rejected');

CREATE TYPE whitelabel."recognition_status" AS ENUM (
'Pending',
'Matched',
'Unmatched');

CREATE TYPE whitelabel."release_type" AS ENUM (
'Single',
'EP',
'Album',
'Beat');

CREATE TYPE whitelabel."song_status" AS ENUM (
'Draft',
'Scheduled',
'Released',
'Removed');

CREATE TYPE whitelabel."tenant_status" AS ENUM (
'Active',
'Inactive');

CREATE TYPE whitelabel."upload_status" AS ENUM (
'Pending',
'Matched',
'Unmatched');

CREATE TYPE whitelabel."user_role" AS ENUM (
'SuperAdmin',
'Admin',
'User');

-- New enum types
CREATE TYPE whitelabel."list_status" AS ENUM (
'Active',
'Inactive',
'Pending');

CREATE TYPE whitelabel."license_status" AS ENUM (
'Pending',
'Approved',
'Rejected',
'Expired');

CREATE TYPE whitelabel."link_status" AS ENUM (
'Active',
'Inactive',
'Broken');

CREATE TYPE whitelabel."config_status" AS ENUM (
'Active',
'Inactive',
'Pending');

-- Sequences
CREATE SEQUENCE whitelabel.advancefunding_funding_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.album_album_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.artist_artist_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.artistlabel_artistlabel_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.audiorecognition_recognition_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.blocklist_blocklist_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.channelmonetization_monetization_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.copyrightregistration_copyright_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.coversonglicensing_license_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.greenlist_greenlist_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.label_label_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.mastering_mastering_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.prioritypitch_pitch_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.promotionalassets_asset_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.releaselink_link_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.song_song_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.spotifydiscoverymode_discovery_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.tenant_tenant_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.tenantconfiguration_config_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.uploadsession_session_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

CREATE SEQUENCE whitelabel.usagediscovery_usage_id_seq
INCREMENT BY 1
MINVALUE 1
MAXVALUE 2147483647
START 1
CACHE 1
NO CYCLE;

-- Create auth schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS auth AUTHORIZATION postgres;

-- Create function for updating the updated_at column
CREATE OR REPLACE FUNCTION auth.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Tables
CREATE TABLE auth.users (
tenant_id int4 NULL,
username varchar(50) NOT NULL,
first_name varchar(50) NOT NULL,
last_name varchar(50) NOT NULL,
email text NOT NULL,
phone varchar(100) NOT NULL,
"role" whitelabel."user_role" NOT NULL,
password_hash text NOT NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
user_id uuid DEFAULT gen_random_uuid() NOT NULL,
created_by_user_id uuid NULL,
updated_by_user_id uuid NULL,
CONSTRAINT unique_email_tenant UNIQUE (email, tenant_id),
CONSTRAINT users_email_check CHECK ((email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'::text)),
CONSTRAINT users_pkey PRIMARY KEY (user_id),
CONSTRAINT users_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES auth.users(user_id),
CONSTRAINT users_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES auth.users(user_id)
);

-- Create index for email lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON auth.users (email);

-- Create trigger for automatically updating updated_at column
CREATE TRIGGER set_updated_at
    BEFORE UPDATE
    ON auth.users
    FOR EACH ROW
EXECUTE PROCEDURE auth.update_updated_at_column();

-- Set ownership
ALTER TABLE auth.users OWNER TO postgres;

CREATE TABLE whitelabel.tenant (
tenant_id serial4 NOT NULL,
tenant_name varchar(100) NOT NULL,
domain_url varchar(255) NULL,
logo_url varchar(255) NULL,
primary_color varchar(7) NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
status whitelabel."tenant_status" DEFAULT 'Active'::whitelabel.tenant_status NULL,
created_by_user_id uuid NULL,
updated_by_user_id uuid NULL,
CONSTRAINT tenant_pkey PRIMARY KEY (tenant_id),
CONSTRAINT tenant_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES auth.users(user_id),
CONSTRAINT tenant_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES auth.users(user_id)
);

CREATE TABLE whitelabel.tenant_configuration (
config_id serial4 NOT NULL,
tenant_id int4 NOT NULL,
feature_enabled varchar(50) NOT NULL,
config_value jsonb NULL,
theme jsonb NULL,
status whitelabel."config_status" DEFAULT 'Active'::whitelabel.config_status NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NOT NULL,
created_by_user_id uuid NULL,
updated_by_user_id uuid NULL,
CONSTRAINT tenant_configuration_pkey PRIMARY KEY (config_id),
CONSTRAINT tenant_configuration_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES auth.users(user_id),
CONSTRAINT tenant_configuration_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id),
CONSTRAINT tenant_configuration_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES auth.users(user_id)
);

CREATE TABLE whitelabel.artist (
artist_id serial4 NOT NULL,
tenant_id int4 NULL,
artist_name varchar(100) NOT NULL,
first_name varchar(50) NOT NULL,
last_name varchar(50) NOT NULL,
bio text NULL,
"role" varchar(50) NOT NULL,
instagram_profile_url varchar(255) NULL,
twitter_profile_url varchar(255) NULL,
facebook_profile_url varchar(255) NULL,
youtube_profile_url varchar(255) NULL,
snapchat_profile_url varchar(255) NULL,
spotify_artist_url varchar(255) NULL,
itunes_artist_url varchar(255) NULL,
youtube_artist_url varchar(255) NULL,
profile_photo_url varchar(255) NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
created_by_user_id uuid NULL,
updated_by_user_id uuid NULL,
user_id uuid NULL,
artist_page_slug varchar NOT NULL,
CONSTRAINT artist_pkey PRIMARY KEY (artist_id),
CONSTRAINT artist_unique UNIQUE (artist_page_slug),
CONSTRAINT artist_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES auth.users(user_id),
CONSTRAINT artist_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES auth.users(user_id),
CONSTRAINT fk_artist_tenant FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id),
CONSTRAINT fk_artist_user FOREIGN KEY (user_id) REFERENCES auth.users(user_id)
);

CREATE TABLE whitelabel.channel_monetization (
monetization_id serial4 NOT NULL,
tenant_id int4 NOT NULL,
artist_id int4 NOT NULL,
channel_name varchar(100) NOT NULL,
revenue_share numeric(5, 2) NOT NULL,
start_date date NOT NULL,
status whitelabel."channel_status" DEFAULT 'Active'::whitelabel.channel_status NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
created_by_user_id int4 NOT NULL,
updated_by_user_id int4 NULL,
CONSTRAINT channel_monetization_pkey PRIMARY KEY (monetization_id),
CONSTRAINT channel_monetization_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES whitelabel.artist(artist_id),
CONSTRAINT channel_monetization_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id)
);

CREATE TABLE whitelabel."label" (
label_id serial4 NOT NULL,
tenant_id int4 NULL,
label_name varchar(100) NOT NULL,
founded_date date NULL,
instagram_profile_url varchar(255) NULL,
youtube_profile_url varchar(255) NULL,
contact_email varchar(100) NOT NULL,
phone varchar(100) NOT NULL,
profile_photo_url varchar(255) NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
created_by_user_id uuid NULL,
updated_by_user_id uuid NULL,
CONSTRAINT label_pkey PRIMARY KEY (label_id),
CONSTRAINT label_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES auth.users(user_id),
CONSTRAINT label_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id),
CONSTRAINT label_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES auth.users(user_id)
);

CREATE TABLE whitelabel.album (
album_id serial4 NOT NULL,
tenant_id int4 NOT NULL,
album_title varchar(100) NOT NULL,
artist_id int4 NULL,
featured_artists jsonb NULL,
label_id int4 NOT NULL,
release_date date NULL,
preorder_date date NULL,
album_type whitelabel."album_type" NOT NULL,
total_tracks int4 NULL,
cover_art_url varchar(255) NULL,
primary_genre varchar(50) NOT NULL,
subgenre varchar(50) NULL,
"language" varchar(50) NULL,
explicit_content bool DEFAULT false NULL,
upc varchar(12) NULL,
territory_rights jsonb NULL,
description text NULL,
composition_copyright_year int4 NULL,
composition_copyright_owner varchar(255) NULL,
sound_recording_copyright_year int4 NULL,
sound_recording_copyright_owner varchar(255) NULL,
original_release_date date NULL,
smart_url varchar(255) NULL,
status whitelabel."album_status" DEFAULT 'Draft'::whitelabel.album_status NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
created_by_user_id uuid NULL,
updated_by_user_id uuid NULL,
CONSTRAINT album_pkey PRIMARY KEY (album_id),
CONSTRAINT album_upc_key UNIQUE (upc),
CONSTRAINT album_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES whitelabel.artist(artist_id),
CONSTRAINT album_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES auth.users(user_id),
CONSTRAINT album_label_id_fkey FOREIGN KEY (label_id) REFERENCES whitelabel."label"(label_id),
CONSTRAINT album_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id),
CONSTRAINT album_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES auth.users(user_id)
);

CREATE TABLE whitelabel.artist_label (
artist_label_id serial4 NOT NULL,
artist_id int4 NOT NULL,
label_id int4 NOT NULL,
start_date date NOT NULL,
end_date date NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
created_by_user_id uuid NULL,
updated_by_user_id uuid NULL,
CONSTRAINT artist_label_pkey PRIMARY KEY (artist_label_id),
CONSTRAINT artist_label_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES whitelabel.artist(artist_id),
CONSTRAINT artist_label_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES auth.users(user_id),
CONSTRAINT artist_label_label_id_fkey FOREIGN KEY (label_id) REFERENCES whitelabel."label"(label_id),
CONSTRAINT artist_label_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES auth.users(user_id)
);

CREATE TABLE whitelabel.song (
song_id serial4 NOT NULL,
tenant_id int4 NOT NULL,
label_id int4 NOT NULL,
artist_id int4 NOT NULL,
album_id int4 NULL,
title varchar(100) NOT NULL,
featured_artists jsonb NULL,
release_date date NULL,
preorder_date date NULL,
release_type whitelabel."release_type" NOT NULL,
track_number int4 NULL,
audio_file_url varchar(255) NULL,
mastered_file_url varchar(255) NULL,
cover_art_url varchar(255) NULL,
duration int4 NULL,
primary_genre varchar(50) NOT NULL,
subgenre varchar(50) NULL,
"language" varchar(50) NULL,
bpm int4 NULL,
musical_key varchar(20) NULL,
isrc varchar(12) NULL,
upc varchar(12) NULL,
explicit_content bool DEFAULT false NULL,
"version" varchar(50) NULL,
territory_rights jsonb NULL,
composers jsonb NULL,
songwriters jsonb NULL,
producers jsonb NULL,
lyricists jsonb NULL,
lyrics text NULL,
instrumentation jsonb NULL,
mood jsonb NULL,
composition_copyright_year int4 NULL,
composition_copyright_owner varchar(255) NULL,
sound_recording_copyright_year int4 NULL,
sound_recording_copyright_owner varchar(255) NULL,
publishing_info jsonb NULL,
original_release_date date NULL,
smart_url varchar(255) NULL,
status whitelabel."song_status" DEFAULT 'Draft'::whitelabel.song_status NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
created_by_user_id uuid NULL,
updated_by_user_id uuid NULL,
CONSTRAINT song_isrc_key UNIQUE (isrc),
CONSTRAINT song_pkey PRIMARY KEY (song_id),
CONSTRAINT song_upc_key UNIQUE (upc),
CONSTRAINT song_album_id_fkey FOREIGN KEY (album_id) REFERENCES whitelabel.album(album_id),
CONSTRAINT song_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES whitelabel.artist(artist_id),
CONSTRAINT song_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES auth.users(user_id),
CONSTRAINT song_label_id_fkey FOREIGN KEY (label_id) REFERENCES whitelabel."label"(label_id),
CONSTRAINT song_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id),
CONSTRAINT song_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES auth.users(user_id)
);

CREATE TABLE whitelabel.spotify_discovery_mode (
discovery_id serial4 NOT NULL,
tenant_id int4 NOT NULL,
song_id int4 NOT NULL,
enabled_date date NOT NULL,
status whitelabel."discovery_status" DEFAULT 'Active'::whitelabel.discovery_status NULL,
performance_metrics jsonb NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
created_by_user_id int4 NOT NULL,
updated_by_user_id int4 NULL,
CONSTRAINT spotify_discovery_mode_pkey PRIMARY KEY (discovery_id),
CONSTRAINT spotify_discovery_mode_song_id_fkey FOREIGN KEY (song_id) REFERENCES whitelabel.song(song_id),
CONSTRAINT spotify_discovery_mode_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id)
);

CREATE TABLE whitelabel.usage_discovery (
usage_id serial4 NOT NULL,
tenant_id int4 NOT NULL,
song_id int4 NOT NULL,
platform_name varchar(50) NOT NULL,
usage_count int4 NOT NULL,
last_detected_date timestamp NOT NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
created_by_user_id int4 NOT NULL,
updated_by_user_id int4 NULL,
CONSTRAINT usage_discovery_pkey PRIMARY KEY (usage_id),
CONSTRAINT usage_discovery_song_id_fkey FOREIGN KEY (song_id) REFERENCES whitelabel.song(song_id),
CONSTRAINT usage_discovery_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id)
);

CREATE TABLE whitelabel.advance_funding (
funding_id serial4 NOT NULL,
tenant_id int4 NOT NULL,
artist_id int4 NOT NULL,
song_id int4 NULL,
amount numeric(10, 2) NOT NULL,
funding_date date NOT NULL,
status whitelabel."funding_status" DEFAULT 'Pending'::whitelabel.funding_status NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
created_by_user_id int4 NOT NULL,
updated_by_user_id int4 NULL,
CONSTRAINT advance_funding_pkey PRIMARY KEY (funding_id),
CONSTRAINT advance_funding_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES whitelabel.artist(artist_id),
CONSTRAINT advance_funding_song_id_fkey FOREIGN KEY (song_id) REFERENCES whitelabel.song(song_id),
CONSTRAINT advance_funding_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id)
);

CREATE TABLE whitelabel.audio_recognition (
recognition_id serial4 NOT NULL,
tenant_id int4 NOT NULL,
song_id int4 NULL,
audio_hash varchar(255) NOT NULL,
recognized_date timestamp NOT NULL,
match_confidence numeric(5, 2) NULL,
status whitelabel."recognition_status" DEFAULT 'Pending'::whitelabel.recognition_status NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
created_by_user_id int4 NOT NULL,
updated_by_user_id int4 NULL,
CONSTRAINT audio_recognition_audio_hash_key UNIQUE (audio_hash),
CONSTRAINT audio_recognition_pkey PRIMARY KEY (recognition_id),
CONSTRAINT audio_recognition_song_id_fkey FOREIGN KEY (song_id) REFERENCES whitelabel.song(song_id),
CONSTRAINT audio_recognition_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id)
);

CREATE TABLE whitelabel.green_list (
greenlist_id serial4 NOT NULL,
tenant_id int4 NOT NULL,
song_id int4 NOT NULL,
added_date timestamp NOT NULL,
notes text NULL,
url varchar(255) NULL,
status whitelabel."list_status" DEFAULT 'Active'::whitelabel.list_status NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
added_by_user_id uuid NULL,
created_by_user_id uuid NULL,
updated_by_user_id uuid NULL,
CONSTRAINT green_list_pkey PRIMARY KEY (greenlist_id),
CONSTRAINT green_list_added_by_user_id_fkey FOREIGN KEY (added_by_user_id) REFERENCES auth.users(user_id),
CONSTRAINT green_list_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES auth.users(user_id),
CONSTRAINT green_list_song_id_fkey FOREIGN KEY (song_id) REFERENCES whitelabel.song(song_id),
CONSTRAINT green_list_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id),
CONSTRAINT green_list_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES auth.users(user_id)
);

CREATE TABLE whitelabel.block_list (
blocklist_id serial4 NOT NULL,
tenant_id int4 NOT NULL,
song_id int4 NOT NULL,
blocked_date timestamp NOT NULL,
reason text NULL,
url varchar(255) NULL,
status whitelabel."list_status" DEFAULT 'Active'::whitelabel.list_status NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
blocked_by_user_id uuid NULL,
created_by_user_id uuid NULL,
updated_by_user_id uuid NULL,
CONSTRAINT block_list_pkey PRIMARY KEY (blocklist_id),
CONSTRAINT block_list_blocked_by_user_id_fkey FOREIGN KEY (blocked_by_user_id) REFERENCES auth.users(user_id),
CONSTRAINT block_list_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES auth.users(user_id),
CONSTRAINT block_list_song_id_fkey FOREIGN KEY (song_id) REFERENCES whitelabel.song(song_id),
CONSTRAINT block_list_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id),
CONSTRAINT block_list_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES auth.users(user_id)
);

CREATE TABLE whitelabel.copyright_registration (
copyright_id serial4 NOT NULL,
tenant_id int4 NOT NULL,
song_id int4 NOT NULL,
registration_number varchar(50) NULL,
registration_date date NULL,
status whitelabel."copyright_status" DEFAULT 'Pending'::whitelabel.copyright_status NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
created_by_user_id int4 NOT NULL,
updated_by_user_id int4 NULL,
CONSTRAINT copyright_registration_pkey PRIMARY KEY (copyright_id),
CONSTRAINT copyright_registration_song_id_fkey FOREIGN KEY (song_id) REFERENCES whitelabel.song(song_id),
CONSTRAINT copyright_registration_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id)
);

CREATE TABLE whitelabel.cover_song_licensing (
license_id serial4 NOT NULL,
tenant_id int4 NOT NULL,
song_id int4 NOT NULL,
original_song_id int4 NULL,
license_number varchar(50) NULL,
license_date date NULL,
fee numeric(10, 2) NULL,
status whitelabel."license_status" DEFAULT 'Pending'::whitelabel.license_status NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
created_by_user_id int4 NOT NULL,
updated_by_user_id int4 NULL,
CONSTRAINT cover_song_licensing_pkey PRIMARY KEY (license_id),
CONSTRAINT cover_song_licensing_original_song_id_fkey FOREIGN KEY (original_song_id) REFERENCES whitelabel.song(song_id),
CONSTRAINT cover_song_licensing_song_id_fkey FOREIGN KEY (song_id) REFERENCES whitelabel.song(song_id),
CONSTRAINT cover_song_licensing_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id)
);

CREATE TABLE whitelabel.mastering (
mastering_id serial4 NOT NULL,
tenant_id int4 NOT NULL,
song_id int4 NOT NULL,
mastered_by_user_id int4 NULL,
mastering_date timestamp NOT NULL,
status whitelabel."mastering_status" DEFAULT 'InProgress'::whitelabel.mastering_status NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
created_by_user_id int4 NOT NULL,
updated_by_user_id int4 NULL,
CONSTRAINT mastering_pkey PRIMARY KEY (mastering_id),
CONSTRAINT mastering_song_id_fkey FOREIGN KEY (song_id) REFERENCES whitelabel.song(song_id),
CONSTRAINT mastering_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id)
);

CREATE TABLE whitelabel.priority_pitch (
pitch_id serial4 NOT NULL,
tenant_id int4 NOT NULL,
song_id int4 NOT NULL,
pitch_date timestamp NOT NULL,
status whitelabel."pitch_status" DEFAULT 'Pending'::whitelabel.pitch_status NULL,
priority_level int4 NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
user_id uuid NULL,
created_by_user_id uuid NULL,
updated_by_user_id uuid NULL,
CONSTRAINT priority_pitch_pkey PRIMARY KEY (pitch_id),
CONSTRAINT priority_pitch_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES auth.users(user_id),
CONSTRAINT priority_pitch_song_id_fkey FOREIGN KEY (song_id) REFERENCES whitelabel.song(song_id),
CONSTRAINT priority_pitch_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id),
CONSTRAINT priority_pitch_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES auth.users(user_id),
CONSTRAINT priority_pitch_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(user_id)
);

CREATE TABLE whitelabel.promotional_assets (
asset_id serial4 NOT NULL,
tenant_id int4 NOT NULL,
song_id int4 NOT NULL,
asset_type whitelabel."asset_type" NOT NULL,
file_url varchar(255) NOT NULL,
created_date timestamp NOT NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
created_by_user_id int4 NOT NULL,
updated_by_user_id int4 NULL,
CONSTRAINT promotional_assets_pkey PRIMARY KEY (asset_id),
CONSTRAINT promotional_assets_song_id_fkey FOREIGN KEY (song_id) REFERENCES whitelabel.song(song_id),
CONSTRAINT promotional_assets_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id)
);

CREATE TABLE whitelabel.release_link (
link_id serial4 NOT NULL,
tenant_id int4 NOT NULL,
song_id int4 NOT NULL,
platform_name varchar(50) NOT NULL,
url varchar(255) NOT NULL,
created_date timestamp NOT NULL,
status whitelabel."link_status" DEFAULT 'Active'::whitelabel.link_status NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
created_by_user_id int4 NOT NULL,
updated_by_user_id int4 NULL,
CONSTRAINT release_link_pkey PRIMARY KEY (link_id),
CONSTRAINT release_link_song_id_fkey FOREIGN KEY (song_id) REFERENCES whitelabel.song(song_id),
CONSTRAINT release_link_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES whitelabel.tenant(tenant_id)
);

CREATE TABLE whitelabel.upload_session (
session_id serial4 NOT NULL,
user_id int4 NOT NULL,
audio_hash varchar(255) NOT NULL,
file_url varchar(255) NOT NULL,
status whitelabel."upload_status" DEFAULT 'Pending'::whitelabel.upload_status NULL,
created_at timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at timestamp NULL,
CONSTRAINT upload_session_pkey PRIMARY KEY (session_id),
CONSTRAINT upload_session_audio_hash_fkey FOREIGN KEY (audio_hash) REFERENCES whitelabel.audio_recognition(audio_hash)
);

CREATE UNIQUE INDEX artistslug_unique ON whitelabel.artist USING btree (artist_page_slug);
