
DROP INDEX dbmail_sievescripts_1;
CREATE UNIQUE INDEX dbmail_sievescripts_1 ON dbmail_sievescripts(owner_idnr, name);

SET client_encoding = 'UTF8';

CREATE TABLE dbmail_mimeparts (
    id character(64) NOT NULL,
    data bytea NOT NULL,
    size bigint NOT NULL
);


ALTER TABLE ONLY dbmail_mimeparts
    ADD CONSTRAINT dbmail_mimeparts_pkey PRIMARY KEY (id);


CREATE TABLE dbmail_partlists (
    physmessage_id bigint NOT NULL,
    is_header smallint DEFAULT (0)::smallint NOT NULL,
    part_key integer DEFAULT 0 NOT NULL,
    part_depth integer DEFAULT 0 NOT NULL,
    part_order integer DEFAULT 0 NOT NULL,
    part_id character(64) NOT NULL
);


CREATE INDEX dbmail_partlists_1 ON dbmail_partlists USING btree (physmessage_id);
CREATE INDEX dbmail_partlists_2 ON dbmail_partlists USING btree (part_id);

ALTER TABLE ONLY dbmail_partlists
    ADD CONSTRAINT dbmail_partlists_part_id_fkey FOREIGN KEY (part_id) REFERENCES dbmail_mimeparts(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE ONLY dbmail_partlists
    ADD CONSTRAINT dbmail_partlists_physmessage_id_fkey FOREIGN KEY (physmessage_id) REFERENCES dbmail_physmessage(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE ONLY dbmail_mailboxes ALTER COLUMN name TYPE VARCHAR(255);
ALTER TABLE ONLY dbmail_mailboxes ADD mtime TIMESTAMP WITHOUT TIME ZONE;

CREATE PROCEDURAL LANGUAGE plpgsql;

CREATE FUNCTION mailbox_mtime_insert() RETURNS "trigger"
    AS $$
BEGIN
	UPDATE dbmail_mailboxes SET mtime=NOW() WHERE mailbox_idnr=NEW.mailbox_idnr;
	RETURN NEW;
END;
$$
    LANGUAGE plpgsql;
ALTER FUNCTION public.mailbox_mtime_insert() OWNER TO dbmail;

CREATE FUNCTION mailbox_mtime_update() RETURNS "trigger"
    AS $$
BEGIN
	UPDATE dbmail_mailboxes SET mtime=NOW() WHERE mailbox_idnr=OLD.mailbox_idnr;
	RETURN OLD;
END;
$$
    LANGUAGE plpgsql;
ALTER FUNCTION public.mailbox_mtime_update() OWNER TO dbmail;


CREATE TABLE dbmail_keywords (
	message_idnr bigint NOT NULL,
	keyword varchar(64) NOT NULL
);
ALTER TABLE ONLY dbmail_keywords
    ADD CONSTRAINT dbmail_keywords_pkey PRIMARY KEY (message_idnr, keyword);
ALTER TABLE ONLY dbmail_keywords
    ADD CONSTRAINT dbmail_keywords_fkey FOREIGN KEY (message_idnr) REFERENCES dbmail_messages (message_idnr) ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TRIGGER mailbox_stamp_insert
    AFTER INSERT ON dbmail_messages
    FOR EACH ROW
    EXECUTE PROCEDURE mailbox_mtime_insert();

CREATE TRIGGER mailbox_stamp_update
    AFTER DELETE OR UPDATE ON dbmail_messages
    FOR EACH ROW
    EXECUTE PROCEDURE mailbox_mtime_update();

CREATE FUNCTION insert_keyword_mailbox() RETURNS "trigger" AS $$
BEGIN
	UPDATE dbmail_mailboxes SET mtime=NOW() WHERE mailbox_idnr=(SELECT mailbox_idnr FROM dbmail_messages WHERE message_idnr=NEW.message_idnr); 
	RETURN NEW;
END;
$$
    LANGUAGE plpgsql;
ALTER FUNCTION public.insert_keyword_mailbox() OWNER TO dbmail;

CREATE FUNCTION update_keyword_mailbox() RETURNS "trigger" AS $$
BEGIN
	UPDATE dbmail_mailboxes SET mtime=NOW() WHERE mailbox_idnr=(SELECT mailbox_idnr FROM dbmail_messages WHERE message_idnr=OLD.message_idnr); 
	RETURN OLD;
END;
$$
    LANGUAGE plpgsql;
ALTER FUNCTION public.update_keyword_mailbox() OWNER TO dbmail;

CREATE TRIGGER insert_keyword_mailbox
	AFTER INSERT ON dbmail_keywords
	FOR EACH ROW
	EXECUTE PROCEDURE insert_keyword_mailbox();

CREATE TRIGGER update_keyword_mailbox
	AFTER DELETE OR UPDATE ON dbmail_keywords
	FOR EACH ROW
	EXECUTE PROCEDURE update_keyword_mailbox();
