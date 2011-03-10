/*
 Copyright (C) 1999-2004 IC & S  dbmail@ic-s.nl

 This program is free software; you can redistribute it and/or 
 modify it under the terms of the GNU General Public License 
 as published by the Free Software Foundation; either 
 version 2 of the License, or (at your option) any later 
 version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/
/* 
*/

BEGIN TRANSACTION;

CREATE SEQUENCE dbmail_alias_idnr_seq;
CREATE TABLE dbmail_aliases (
    alias_idnr INT8 DEFAULT nextval('dbmail_alias_idnr_seq'),
    alias VARCHAR(100) NOT NULL, 
    deliver_to VARCHAR(250) NOT NULL,
    client_idnr INT8 DEFAULT '0' NOT NULL,
    PRIMARY KEY (alias_idnr)
);
CREATE INDEX dbmail_aliases_alias_idx ON dbmail_aliases(alias);
CREATE INDEX dbmail_aliases_alias_low_idx ON dbmail_aliases(lower(alias));

CREATE SEQUENCE dbmail_user_idnr_seq;
CREATE TABLE dbmail_users (
   user_idnr INT8 DEFAULT nextval('dbmail_user_idnr_seq'),
   userid VARCHAR(100) NOT NULL,
   passwd VARCHAR(34) NOT NULL,
   client_idnr INT8 DEFAULT '0' NOT NULL,
   maxmail_size INT8 DEFAULT '0' NOT NULL,
   curmail_size INT8 DEFAULT '0' NOT NULL,
   maxsieve_size INT8 DEFAULT '0' NOT NULL,
   cursieve_size INT8 DEFAULT '0' NOT NULL,
   encryption_type VARCHAR(20) DEFAULT '' NOT NULL,
   last_login TIMESTAMP DEFAULT '1979-11-03 22:05:58' NOT NULL,
   PRIMARY KEY (user_idnr)
);

CREATE UNIQUE INDEX dbmail_users_name_idx ON dbmail_users(userid);
CREATE INDEX dbmail_users_2 ON dbmail_users (lower(userid));

CREATE TABLE dbmail_usermap (
  login VARCHAR(100) NOT NULL,
  sock_allow varchar(100) NOT NULL,
  sock_deny varchar(100) NOT NULL,
  userid varchar(100) NOT NULL
);
CREATE UNIQUE INDEX usermap_idx_1 ON dbmail_usermap(login, sock_allow, userid);

CREATE SEQUENCE dbmail_mailbox_idnr_seq;
CREATE TABLE dbmail_mailboxes (
   mailbox_idnr INT8 DEFAULT nextval('dbmail_mailbox_idnr_seq'),
   owner_idnr INT8 REFERENCES dbmail_users(user_idnr) ON DELETE CASCADE ON UPDATE CASCADE,
   name VARCHAR(100) NOT NULL,
   seen_flag INT2 DEFAULT '0' NOT NULL,
   answered_flag INT2 DEFAULT '0' NOT NULL,
   deleted_flag INT2 DEFAULT '0' NOT NULL,
   flagged_flag INT2 DEFAULT '0' NOT NULL,
   recent_flag INT2 DEFAULT '0' NOT NULL,
   draft_flag INT2 DEFAULT '0' NOT NULL,
   no_inferiors INT2 DEFAULT '0' NOT NULL,
   no_select INT2 DEFAULT '0' NOT NULL,
   permission INT2 DEFAULT '2' NOT NULL,
   PRIMARY KEY (mailbox_idnr)
);
CREATE INDEX dbmail_mailboxes_owner_idx ON dbmail_mailboxes(owner_idnr);
CREATE INDEX dbmail_mailboxes_name_idx ON dbmail_mailboxes(name);
CREATE UNIQUE INDEX dbmail_mailboxes_owner_name_idx 
	ON dbmail_mailboxes(owner_idnr, name);

CREATE TABLE dbmail_subscription (
   user_id INT8 REFERENCES dbmail_users(user_idnr) ON DELETE CASCADE ON UPDATE CASCADE,
   mailbox_id INT8 REFERENCES dbmail_mailboxes(mailbox_idnr)
	ON DELETE CASCADE ON UPDATE CASCADE,
   PRIMARY KEY (user_id, mailbox_id)
);

CREATE TABLE dbmail_acl (
    user_id INT8 REFERENCES dbmail_users(user_idnr) ON DELETE CASCADE ON UPDATE CASCADE,
    mailbox_id INT8 REFERENCES dbmail_mailboxes(mailbox_idnr)
	ON DELETE CASCADE ON UPDATE CASCADE,
    lookup_flag INT2 DEFAULT '0' NOT NULL,
    read_flag INT2 DEFAULT '0' NOT NULL,
    seen_flag INT2 DEFAULT '0' NOT NULL,
    write_flag INT2 DEFAULT '0' NOT NULL,
    insert_flag INT2 DEFAULT '0' NOT NULL,
    post_flag INT2 DEFAULT '0' NOT NULL,
    create_flag INT2 DEFAULT '0' NOT NULL,
    delete_flag INT2 DEFAULT '0' NOT NULL,
    administer_flag INT2 DEFAULT '0' NOT NULL,
    PRIMARY KEY (user_id, mailbox_id)
);

CREATE SEQUENCE dbmail_physmessage_id_seq;
CREATE TABLE dbmail_physmessage (
   id INT8 DEFAULT nextval('dbmail_physmessage_id_seq'),
   messagesize INT8 DEFAULT '0' NOT NULL,   
   rfcsize INT8 DEFAULT '0' NOT NULL,
   internal_date TIMESTAMP WITHOUT TIME ZONE,
   PRIMARY KEY(id)
);

CREATE SEQUENCE dbmail_message_idnr_seq;
CREATE TABLE dbmail_messages (
   message_idnr INT8 DEFAULT nextval('dbmail_message_idnr_seq'),
   mailbox_idnr INT8 REFERENCES dbmail_mailboxes(mailbox_idnr)
	ON DELETE CASCADE ON UPDATE CASCADE,
   physmessage_id INT8 REFERENCES dbmail_physmessage(id)
	ON DELETE CASCADE ON UPDATE CASCADE,
   seen_flag INT2 DEFAULT '0' NOT NULL,
   answered_flag INT2 DEFAULT '0' NOT NULL,
   deleted_flag INT2 DEFAULT '0' NOT NULL,
   flagged_flag INT2 DEFAULT '0' NOT NULL,
   recent_flag INT2 DEFAULT '0' NOT NULL,
   draft_flag INT2 DEFAULT '0' NOT NULL,
   unique_id varchar(70) NOT NULL,
   status INT2 DEFAULT '0' NOT NULL,
   PRIMARY KEY (message_idnr)
);
CREATE INDEX dbmail_messages_1 ON dbmail_messages(mailbox_idnr);
CREATE INDEX dbmail_messages_2 ON dbmail_messages(physmessage_id);
CREATE INDEX dbmail_messages_3 ON dbmail_messages(seen_flag);
CREATE INDEX dbmail_messages_4 ON dbmail_messages(unique_id);
CREATE INDEX dbmail_messages_5 ON dbmail_messages(status);
CREATE INDEX dbmail_messages_6 ON dbmail_messages(status) WHERE status < '2';
CREATE INDEX dbmail_messages_7 ON dbmail_messages(mailbox_idnr,status,seen_flag);
CREATE INDEX dbmail_messages_8 ON dbmail_messages(mailbox_idnr,status,recent_flag);

CREATE SEQUENCE dbmail_messageblk_idnr_seq;
CREATE TABLE dbmail_messageblks (
   messageblk_idnr INT8 DEFAULT nextval('dbmail_messageblk_idnr_seq'),
   physmessage_id INT8 REFERENCES dbmail_physmessage(id)
	ON DELETE CASCADE ON UPDATE CASCADE,
   messageblk BYTEA NOT NULL,
   blocksize INT8 DEFAULT '0' NOT NULL,
   is_header INT2 DEFAULT '0' NOT NULL,
   PRIMARY KEY (messageblk_idnr)
);
CREATE INDEX dbmail_messageblks_physmessage_idx 
	ON dbmail_messageblks(physmessage_id);
CREATE INDEX dbmail_messageblks_physmessage_is_header_idx 
	ON dbmail_messageblks(physmessage_id, is_header);

CREATE TABLE dbmail_auto_notifications (
   user_idnr INT8 REFERENCES dbmail_users(user_idnr) ON DELETE CASCADE ON UPDATE CASCADE,
   notify_address VARCHAR(100),
   PRIMARY KEY (user_idnr)
);

CREATE TABLE dbmail_auto_replies (
   user_idnr INT8 REFERENCES dbmail_users (user_idnr) ON DELETE CASCADE ON UPDATE CASCADE,
   start_date timestamp without time zone not null,
   stop_date timestamp without time zone not null,
   reply_body TEXT,
   PRIMARY KEY (user_idnr)
);

CREATE SEQUENCE dbmail_seq_pbsp_id;
CREATE TABLE dbmail_pbsp (
  idnr INT8 NOT NULL DEFAULT NEXTVAL('dbmail_seq_pbsp_id'),
  since TIMESTAMP NOT NULL DEFAULT '1970-01-01 00:00:00',
  ipnumber INET NOT NULL DEFAULT '0.0.0.0',
  PRIMARY KEY (idnr)
);
CREATE UNIQUE INDEX dbmail_idx_ipnumber ON dbmail_pbsp (ipnumber);
CREATE INDEX dbmail_idx_since ON dbmail_pbsp (since);

--- Create the user for the delivery chain:
INSERT INTO dbmail_users (userid, passwd, encryption_type) 
	VALUES ('__@!internal_delivery_user!@__', '', 'md5');
--- Create the 'anyone' user which is used for ACLs.
INSERT INTO dbmail_users (userid, passwd, encryption_type) 
	VALUES ('anyone', '', 'md5');
--- Create the user to own #Public mailboxes
INSERT INTO dbmail_users (userid, passwd, encryption_type) 
	VALUES ('__public__', '', 'md5');

 


CREATE SEQUENCE dbmail_headername_idnr_seq;
CREATE TABLE dbmail_headername (
	id		INT8 DEFAULT nextval('dbmail_headername_idnr_seq'),
	headername	VARCHAR(100) NOT NULL DEFAULT '',
	PRIMARY KEY (id)
);
CREATE UNIQUE INDEX dbmail_headername_1 on dbmail_headername(lower(headername));

CREATE SEQUENCE dbmail_headervalue_idnr_seq;
CREATE TABLE dbmail_headervalue (
	headername_id	INT8 NOT NULL
		REFERENCES dbmail_headername(id)
		ON UPDATE CASCADE ON DELETE CASCADE,
        physmessage_id	INT8 NOT NULL
		REFERENCES dbmail_physmessage(id)
		ON UPDATE CASCADE ON DELETE CASCADE,
	id		INT8 DEFAULT nextval('dbmail_headervalue_idnr_seq'),
	headervalue	TEXT NOT NULL DEFAULT '',
	PRIMARY KEY (id)
);
CREATE UNIQUE INDEX dbmail_headervalue_1 ON dbmail_headervalue(physmessage_id, id);
CREATE INDEX dbmail_headervalue_2 ON dbmail_headervalue(physmessage_id);
CREATE INDEX dbmail_headervalue_3 ON dbmail_headervalue(substring(headervalue,0,255));


CREATE SEQUENCE dbmail_subjectfield_idnr_seq;
CREATE TABLE dbmail_subjectfield (
        physmessage_id  INT8 NOT NULL
			REFERENCES dbmail_physmessage(id)
			ON UPDATE CASCADE ON DELETE CASCADE,
	id		INT8 DEFAULT nextval('dbmail_subjectfield_idnr_seq'),
	subjectfield	VARCHAR(255) NOT NULL DEFAULT '',
	PRIMARY KEY (id)
);
CREATE UNIQUE INDEX dbmail_subjectfield_1 ON dbmail_subjectfield(physmessage_id, id);
CREATE INDEX dbmail_subjectfield_2 ON dbmail_subjectfield(subjectfield);


CREATE SEQUENCE dbmail_datefield_idnr_seq;
CREATE TABLE dbmail_datefield (
        physmessage_id  INT8 NOT NULL
			REFERENCES dbmail_physmessage(id)
			ON UPDATE CASCADE ON DELETE CASCADE,
	id		INT8 DEFAULT nextval('dbmail_datefield_idnr_seq'),
	datefield	TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT '1970-01-01 00:00:00',
	PRIMARY KEY (id)
);
CREATE UNIQUE INDEX dbmail_datefield_1 ON dbmail_datefield(physmessage_id, id);
CREATE INDEX dbmail_datefield_2 ON dbmail_datefield(datefield);

CREATE SEQUENCE dbmail_referencesfield_idnr_seq;
CREATE TABLE dbmail_referencesfield (
        physmessage_id  INT8 NOT NULL
			REFERENCES dbmail_physmessage(id) 
			ON UPDATE CASCADE ON DELETE CASCADE,
	id		INT8 DEFAULT nextval('dbmail_referencesfield_idnr_seq'),
	referencesfield	VARCHAR(255) NOT NULL DEFAULT '',
	PRIMARY KEY (id)
);
CREATE UNIQUE INDEX dbmail_referencesfield_1 ON dbmail_referencesfield(physmessage_id, referencesfield);
CREATE INDEX dbmail_referencesfield_2 ON dbmail_referencesfield(referencesfield);


CREATE SEQUENCE dbmail_fromfield_idnr_seq;
CREATE TABLE dbmail_fromfield (
        physmessage_id  INT8 NOT NULL
			REFERENCES dbmail_physmessage(id)
			ON UPDATE CASCADE ON DELETE CASCADE,
	id		INT8 DEFAULT nextval('dbmail_fromfield_idnr_seq'),
	fromname	VARCHAR(100) NOT NULL DEFAULT '',
	fromaddr	VARCHAR(100) NOT NULL DEFAULT '',
	PRIMARY KEY (id)
);
CREATE UNIQUE INDEX dbmail_fromfield_1 ON dbmail_fromfield(physmessage_id, id);
CREATE INDEX dbmail_fromfield_2 ON dbmail_fromfield(fromaddr);
CREATE INDEX dbmail_fromfield_3 ON dbmail_fromfield(fromname);

CREATE SEQUENCE dbmail_tofield_idnr_seq;
CREATE TABLE dbmail_tofield (
        physmessage_id  INT8 NOT NULL
			REFERENCES dbmail_physmessage(id)
			ON UPDATE CASCADE ON DELETE CASCADE,
	id		INT8 DEFAULT nextval('dbmail_tofield_idnr_seq'),
	toname		VARCHAR(100) NOT NULL DEFAULT '',
	toaddr		VARCHAR(100) NOT NULL DEFAULT '',
	PRIMARY KEY (id)
);
CREATE UNIQUE INDEX dbmail_tofield_1 ON dbmail_tofield(physmessage_id, id);
CREATE INDEX dbmail_tofield_2 ON dbmail_tofield(toname);
CREATE INDEX dbmail_tofield_3 ON dbmail_tofield(toaddr);

CREATE SEQUENCE dbmail_replytofield_idnr_seq;
CREATE TABLE dbmail_replytofield (
        physmessage_id  INT8 NOT NULL
			REFERENCES dbmail_physmessage(id)
			ON UPDATE CASCADE ON DELETE CASCADE,
	id		INT8 DEFAULT nextval('dbmail_replytofield_idnr_seq'),
	replytoname	VARCHAR(100) NOT NULL DEFAULT '',
	replytoaddr	VARCHAR(100) NOT NULL DEFAULT '',
	PRIMARY KEY (id)
);
CREATE UNIQUE INDEX dbmail_replytofield_1 ON dbmail_replytofield(physmessage_id, id);
CREATE INDEX dbmail_replytofield_2 ON dbmail_replytofield(replytoname);
CREATE INDEX dbmail_replytofield_3 ON dbmail_replytofield(replytoaddr);

CREATE SEQUENCE dbmail_ccfield_idnr_seq;
CREATE TABLE dbmail_ccfield (
        physmessage_id  INT8 NOT NULL
			REFERENCES dbmail_physmessage(id)
			ON UPDATE CASCADE ON DELETE CASCADE,
	id		INT8 DEFAULT nextval('dbmail_ccfield_idnr_seq'),
	ccname		VARCHAR(100) NOT NULL DEFAULT '',
	ccaddr		VARCHAR(100) NOT NULL DEFAULT '',
	PRIMARY KEY (id)
);
CREATE UNIQUE INDEX dbmail_ccfield_1 ON dbmail_ccfield(physmessage_id, id);
CREATE INDEX dbmail_ccfield_2 ON dbmail_ccfield(ccname);
CREATE INDEX dbmail_ccfield_3 ON dbmail_ccfield(ccaddr);

CREATE TABLE dbmail_replycache (
    to_addr character varying(100) DEFAULT ''::character varying NOT NULL,
    from_addr character varying(100) DEFAULT ''::character varying NOT NULL,
    handle    character varying(100) DEFAULT ''::character varying,
    lastseen timestamp without time zone NOT NULL
);
CREATE UNIQUE INDEX replycache_1 ON dbmail_replycache USING btree (to_addr, from_addr, handle);

CREATE SEQUENCE dbmail_sievescripts_idnr_seq;
CREATE TABLE dbmail_sievescripts (
	id		INT8 DEFAULT nextval('dbmail_sievescripts_idnr_seq'),
        owner_idnr	INT8 NOT NULL
			REFERENCES dbmail_users(user_idnr)
			ON UPDATE CASCADE ON DELETE CASCADE,
	active		INT2 DEFAULT '0' NOT NULL,
	name		VARCHAR(100) NOT NULL DEFAULT '',
	script		TEXT NOT NULL DEFAULT '',
	PRIMARY KEY	(id)
);

CREATE INDEX dbmail_sievescripts_1 on dbmail_sievescripts(owner_idnr,name);
CREATE INDEX dbmail_sievescripts_2 on dbmail_sievescripts(owner_idnr,active);

CREATE SEQUENCE dbmail_envelope_idnr_seq;
CREATE TABLE dbmail_envelope (
        physmessage_id  INT8 NOT NULL
			REFERENCES dbmail_physmessage(id)
			ON UPDATE CASCADE ON DELETE CASCADE,
	id		INT8 DEFAULT nextval('dbmail_envelope_idnr_seq'),
	envelope	TEXT NOT NULL DEFAULT '',
	PRIMARY KEY (id)
);
CREATE UNIQUE INDEX dbmail_envelope_1 ON dbmail_envelope(physmessage_id, id);

CREATE LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION dbmail_header_search(int8, varchar(100), text) RETURNS setof int8 AS $$
DECLARE
	param_mailbox_idnr ALIAS FOR $1;
	param_headername ALIAS FOR $2;
	param_headervalue ALIAS FOR $3;
	potential_header_array int8[];
	headername_array int8[];
	header_match_query text;
	matched_physmessage int8;
	matching_physmessage int8[];
	message_id_query text;
	matched_message_id int8;
BEGIN
	potential_header_array := array(SELECT physmessage_id FROM dbmail_messages WHERE mailbox_idnr = param_mailbox_idnr and status in (0,1));
	IF array_upper(potential_header_array, 1) is null THEN
		RETURN;
	END IF;

	headername_array := array(SELECT id FROM dbmail_headername WHERE headername ILIKE param_headername);
	IF array_upper(headername_array, 1) is null THEN
		RETURN;
	END IF;

	header_match_query := 'SELECT physmessage_id FROM dbmail_headervalue WHERE physmessage_id = ANY (' || quote_literal(potential_header_array) || ') AND headername_id = ANY (' || quote_literal(headername_array) || ') AND headervalue ILIKE ''%%'' || ' || quote_literal(param_headervalue) || ' || ''%%''';

	FOR matched_physmessage IN execute header_match_query LOOP
		matching_physmessage := matching_physmessage || matched_physmessage;
	END LOOP;

	IF array_upper(matching_physmessage, 1) is null THEN
		RETURN;
	END IF;

	message_id_query := 'SELECT message_idnr FROM dbmail_messages m WHERE mailbox_idnr = ' || quote_literal(param_mailbox_idnr) || ' AND status IN (0,1) AND physmessage_id = ANY (' || quote_literal(matching_physmessage) || ') ORDER BY message_idnr';

	FOR matched_message_id IN execute message_id_query LOOP
		return next matched_message_id;
	END LOOP;

	return;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION dbmail_header_fetch(int8, int8[], text[], boolean, OUT message_idnr int8, OUT headername varchar(100), OUT headervalue text) RETURNS setof record AS $$
DECLARE
	param_mailbox_idnr ALIAS FOR $1;
	param_message_idnrs ALIAS FOR $2;
	param_headernames ALIAS FOR $3;
	param_notheaders ALIAS FOR $4;
	r RECORD;
	headername_id_array bigint[];
	physmessage_query text;
	physmessage_id_array bigint[];
	headervalue_query text;
	headername_not text;
BEGIN
	-- Create our temp tables
	DROP TABLE IF EXISTS headername_lookup;
	CREATE TEMPORARY TABLE headername_lookup (id bigint, temp_headername varchar(100));
	DROP TABLE IF EXISTS physmessage_id_lookup;
	CREATE TEMPORARY TABLE physmessage_id_lookup (temp_message_idnr bigint, physmessage_id bigint);

	DROP TABLE IF EXISTS headervalue_lookup;
	CREATE TEMPORARY TABLE headervalue_lookup (headername_id bigint, physmessage_id bigint, temp_headervalue text);

	headername_not := '';
	IF param_notheaders = 't' THEN
		headername_not := '!';
	END IF;

	-- Fill the headername_lookup table with id & headername
	FOR r IN execute 'SELECT id, headername FROM dbmail_headername WHERE lower(headername) ' || headername_not || '= ANY(' || quote_literal(param_headernames) || ')' LOOP
		INSERT INTO headername_lookup VALUES (r.id, r.headername);
		headername_id_array := headername_id_array || r.id;
	END LOOP;

	IF array_upper(headername_id_array, 1) is null THEN
		RETURN;
	END IF;

	-- Create the physmessage_id query
	physmessage_query := 'SELECT message_idnr, physmessage_id FROM dbmail_messages WHERE mailbox_idnr = ' || quote_literal(param_mailbox_idnr) || ' AND message_idnr ';
	IF array_upper(param_message_idnrs, 1) = 1 THEN
		physmessage_query := physmessage_query || '= ' || quote_literal(param_message_idnrs[1]);
	ELSE
		physmessage_query := physmessage_query || 'BETWEEN ' || quote_literal(param_message_idnrs[1]) || ' AND ' || quote_literal(param_message_idnrs[2]);
	END IF;

	-- Fill the physmessage_id_lookup table with message_idnr & physmessage_id
	FOR r in execute physmessage_query LOOP
		INSERT INTO physmessage_id_lookup VALUES (r.message_idnr, r.physmessage_id);
		physmessage_id_array := physmessage_id_array || r.physmessage_id;
	END LOOP;

	IF array_upper(physmessage_id_array, 1) is null THEN
		RETURN;
	END IF;

	headervalue_query := 'SELECT headername_id, physmessage_id, headervalue FROM dbmail_headervalue WHERE physmessage_id = ANY(' || quote_literal(physmessage_id_array) || ') AND headername_id = ANY(' || quote_literal(headername_id_array) || ')';

	FOR r in execute headervalue_query LOOP
		INSERT INTO headervalue_lookup VALUES (r.headername_id, r.physmessage_id, r.headervalue);
	END LOOP;

	RETURN QUERY SELECT p.temp_message_idnr, h.temp_headername, v.temp_headervalue FROM physmessage_id_lookup AS p JOIN headervalue_lookup AS v ON p.physmessage_id = v.physmessage_id JOIN headername_lookup AS h ON h.id = v.headername_id;
END;
$$ LANGUAGE plpgsql;


COMMIT;



