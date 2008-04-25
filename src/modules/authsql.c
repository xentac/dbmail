/*
 Copyright (C) 1999-2004 IC & S  dbmail@ic-s.nl
 Copyright (C) 2005-2008 NFG Net Facilities Group BV support@nfg.nl

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

/**
 * \file authsql.c
 * \brief implements SQL authentication. Prototypes of these functions
 * can be found in auth.h . 
 */

#include "dbmail.h"
#define THIS_MODULE "auth"

extern db_param_t _db_params;
#define DBPFX _db_params.pfx

/* string to be returned by auth_getencryption() */
#define _DESCSTRLEN 50


int auth_connect()
{
	/* this function is only called after a connection has been made
	 * if, in the future this is not the case, db.h should export a 
	 * function that enables checking for the database connection
	 */
	return 0;
}

int auth_disconnect()
{
	return 0;
}

int auth_user_exists(const char *username, u64_t * user_idnr)
{
	return db_user_exists(username, user_idnr);
}

GList * auth_get_known_users(void)
{
	GList * users = NULL;
	C c; R r; 

	c = db_con_get();
	TRY
		r = db_query(c, "SELECT userid FROM %susers ORDER BY userid",DBPFX);
		while (db_result_next(r)) 
			users = g_list_append(users, g_strdup(db_result_get(r, 0)));
	CATCH(SQLException)
		LOG_SQLERROR;
	FINALLY
		db_con_close(c);
	END_TRY;
	
	return users;
}

GList * auth_get_known_aliases(void)
{
	GList * aliases = NULL;
	C c; R r;

	c = db_con_get();
	TRY
		r = db_query(c,"SELECT alias FROM %saliases ORDER BY alias",DBPFX);
		while (db_result_next(r))
			aliases = g_list_append(aliases, g_strdup(db_result_get(r,0)));
	CATCH(SQLException)
		LOG_SQLERROR;
	FINALLY
		db_con_close(c);
	END_TRY;
	
	return aliases;
}

int auth_getclientid(u64_t user_idnr, u64_t * client_idnr)
{
	assert(client_idnr != NULL);
	*client_idnr = 0;
	C c; R r; int t = TRUE;

	c = db_con_get();
	TRY
		r = db_query(c, "SELECT client_idnr FROM %susers WHERE user_idnr = %llu",DBPFX, user_idnr);
		if (db_result_next(r))
			*client_idnr = db_result_get_u64(r,0);
	CATCH(SQLException)
		LOG_SQLERROR;
		t = DM_EQUERY;
	FINALLY
		db_con_close(c);
	END_TRY;

	return t;
}

int auth_getmaxmailsize(u64_t user_idnr, u64_t * maxmail_size)
{
	assert(maxmail_size != NULL);
	*maxmail_size = 0;
	C c; R r; int t = TRUE;
	
	c = db_con_get();
	TRY
		r = db_query(c, "SELECT maxmail_size FROM %susers WHERE user_idnr = %llu",DBPFX, user_idnr);
		if (db_result_next(r))
			*maxmail_size = db_result_get_u64(r,0);
	CATCH(SQLException)
		LOG_SQLERROR;
		t = DM_EQUERY;
	FINALLY
		db_con_close(c);
	END_TRY;
	
	return t;
}


char *auth_getencryption(u64_t user_idnr)
{
	char *res = NULL;
	C c; R r;
	
	assert(user_idnr > 0);
	c = db_con_get();
	TRY
		r = db_query(c, "SELECT encryption_type FROM %susers WHERE user_idnr = %llu",DBPFX, user_idnr);
		if (db_result_next(r))
			res = g_strdup(db_result_get(r,0));
	CATCH(SQLException)
		LOG_SQLERROR;
	FINALLY
		db_con_close(c);
	END_TRY;

	return res;
}


static GList *user_get_deliver_to(const char *username)
{
	INIT_QUERY;
	C c; R r; S s;
	GList *d = NULL;

	snprintf(query, DEF_QUERYSIZE,
		 "SELECT deliver_to FROM %saliases "
		 "WHERE lower(alias) = lower(?) "
		 "AND lower(alias) <> lower(deliver_to)",
		 DBPFX);
	
	c = db_con_get();
	TRY
		s = db_stmt_prepare(c, query);
		db_stmt_set_str(s, 1, username);

		r = db_stmt_query(s);
		while (db_result_next(r))
			d = g_list_prepend(d, g_strdup(db_result_get(r,0)));
	CATCH(SQLException)
		LOG_SQLERROR;
	FINALLY
		db_con_close(c);
	END_TRY;

	return d;
}


int auth_check_user_ext(const char *username, GList **userids, GList **fwds, int checks)
{
	int occurences = 0;
	GList *d = NULL;
	char *endptr;
	u64_t id, *uid;

	if (checks > 20) {
		TRACE(TRACE_ERROR,"too many checks. Possible loop detected.");
		return 0;
	}

	TRACE(TRACE_DEBUG, "[%d] checking user [%s] in alias table", checks, username);

	d = user_get_deliver_to(username);

	if (! d) {
		if (checks == 0) {
			TRACE(TRACE_DEBUG, "user %s not in aliases table", username);
			return 0;
		}
		/* found the last one, this is the deliver to
		 * but checks needs to be bigger then 0 because
		 * else it could be the first query failure */
		id = strtoull(username, &endptr, 10);
		if (*endptr == 0) {
			/* numeric deliver-to --> this is a userid */
			uid = g_new0(u64_t,1);
			*uid = id;
			*(GList **)userids = g_list_prepend(*(GList **)userids, uid);

		} else {
			*(GList **)fwds = g_list_prepend(*(GList **)fwds, g_strdup(username));
		}
		TRACE(TRACE_DEBUG, "adding [%s] to deliver_to address", username);
		return 1;
	} 

	while (d) {
		/* do a recursive search for deliver_to */
		char *deliver_to = (char *)d->data;
		TRACE(TRACE_DEBUG, "checking user %s to %s", username, deliver_to);

		occurences += auth_check_user_ext(deliver_to, userids, fwds, checks+1);

		if (! g_list_next(d)) break;
		d = g_list_next(d);
	}

	g_list_destroy(d);

	return occurences;
}

int auth_adduser(const char *username, const char *password, const char *enctype,
		 u64_t clientid, u64_t maxmail, u64_t * user_idnr)
{
	*user_idnr=0; 
	return db_user_create(username, password, enctype, clientid, maxmail, user_idnr);
}


int auth_delete_user(const char *username)
{
	return db_user_delete(username);
}


int auth_change_username(u64_t user_idnr, const char *new_name)
{
	return db_user_rename(user_idnr, new_name);
}

int auth_change_password(u64_t user_idnr, const char *new_pass, const char *enctype)
{
	C c; S s; int t = FALSE;

	if (strlen(new_pass) >= DEF_QUERYSIZE/2) {
		TRACE(TRACE_ERROR, "new password length is insane");
		return -1;
	}

	c = db_con_get();
	TRY
		s = db_stmt_prepare(c, "UPDATE %susers SET passwd = ?, encryption_type = ? WHERE user_idnr=?", DBPFX);
		db_stmt_set_str(s, 1, new_pass);
		db_stmt_set_str(s, 2, enctype?enctype:"");
		db_stmt_set_u64(s, 3, user_idnr);
		t = db_stmt_exec(s);
	CATCH(SQLException)
		LOG_SQLERROR;
		t = DM_EQUERY;
	FINALLY
		db_con_close(c);
	END_TRY;

	return t;
}

int auth_change_clientid(u64_t user_idnr, u64_t new_cid)
{
	return db_update("UPDATE %susers SET client_idnr = %llu WHERE user_idnr=%llu", DBPFX, new_cid, user_idnr);
}

int auth_change_mailboxsize(u64_t user_idnr, u64_t new_size)
{
	return db_change_mailboxsize(user_idnr, new_size);
}

int auth_validate(clientinfo_t *ci, char *username, char *password, u64_t * user_idnr)
{
	const char *query_result;
	int is_validated = 0;
	char salt[13];
	char cryptres[35];
	char real_username[DM_USERNAME_LEN];
	char *md5str;
	int result, t = FALSE;
	C c; R r;

	memset(salt,0,sizeof(salt));
	memset(cryptres,0,sizeof(cryptres));
	memset(real_username,0,sizeof(real_username));

	assert(user_idnr != NULL);
	*user_idnr = 0;

	if (username == NULL || password == NULL) {
		TRACE(TRACE_DEBUG, "username or password is NULL");
		return 0;
	}

	/* the shared mailbox user should not log in! */
	if (strcmp(username, PUBLIC_FOLDER_USER) == 0)
		return 0;

	strncpy(real_username, username, DM_USERNAME_LEN);
	if (db_use_usermap()) {  /* use usermap */
		result = db_usermap_resolve(ci, username, real_username);
		if (result == DM_EGENERAL)
			return 0;
		if (result == DM_EQUERY)
			return DM_EQUERY;
	}
	
	/* lookup the user_idnr */
	if (auth_user_exists(real_username, user_idnr) == DM_EQUERY)
		return DM_EQUERY;

	c = db_con_get();
	TRY
		r = db_query(c, "SELECT user_idnr, passwd, encryption_type FROM %susers WHERE user_idnr = %llu", DBPFX, *user_idnr);
		if (db_result_next(r)) {
			/* get encryption type */
			query_result = db_result_get(r,2);

			if (!query_result || strcasecmp(query_result, "") == 0) {
				TRACE(TRACE_DEBUG, "validating using plaintext passwords");
				/* get password from database */
				query_result = db_result_get(r,1);
				is_validated = (strcmp(query_result, password) == 0) ? 1 : 0;
			} else if (strcasecmp(query_result, "crypt") == 0) {
				TRACE(TRACE_DEBUG, "validating using crypt() encryption");
				query_result = db_result_get(r,1);
				is_validated = (strcmp((const char *) crypt(password, query_result),	/* Flawfinder: ignore */
						       query_result) == 0) ? 1 : 0;
			} else if (strcasecmp(query_result, "md5") == 0) {
				/* get password */
				query_result = db_result_get(r,1);
				if (strncmp(query_result, "$1$", 3)) {
					TRACE(TRACE_DEBUG, "validating using MD5 digest comparison");
					/* redundant statement: query_result = db_result_get(0, 1); */
					md5str = dm_md5(password);
					is_validated = (strncmp(md5str, query_result, 32) == 0) ? 1 : 0;
				} else {
					TRACE(TRACE_DEBUG, "validating using MD5 hash comparison");
					strncpy(salt, query_result, 12);
					strncpy(cryptres, (char *) crypt(password, query_result), 34);	/* Flawfinder: ignore */
					TRACE(TRACE_DEBUG, "salt   : %s", salt);
					TRACE(TRACE_DEBUG, "hash   : %s", query_result);
					TRACE(TRACE_DEBUG, "crypt(): %s", cryptres);
					is_validated = (strncmp(query_result, cryptres, 34) == 0) ? 1 : 0;
				}
			} else if (strcasecmp(query_result, "md5sum") == 0) {
				TRACE(TRACE_DEBUG, "validating using MD5 digest comparison");
				query_result = db_result_get(r,1);
				md5str = dm_md5(password);
				is_validated = (strncmp(md5str, query_result, 32) == 0) ? 1 : 0;
			} else if (strcasecmp(query_result, "md5base64") == 0) {
				TRACE(TRACE_DEBUG, "validating using MD5 digest base64 comparison");
				query_result = db_result_get(r,1);
				md5str = dm_md5_base64(password);
				is_validated = (strncmp(md5str, query_result, 32) == 0) ? 1 : 0;
				g_free(md5str);
			}
		}
	CATCH(SQLException)
		LOG_SQLERROR;
		t = DM_EQUERY;
	FINALLY
		db_con_close(c);
	END_TRY;

	if (t == DM_EQUERY) return t;

	if (is_validated)
		db_user_log_login(*user_idnr);
	else
		*user_idnr = 0;
	
	return (is_validated ? 1 : 0);
}

u64_t auth_md5_validate(clientinfo_t *ci UNUSED, char *username,
		unsigned char *md5_apop_he, char *apop_stamp)
{
	/* returns useridnr on OK, 0 on validation failed, -1 on error */
	char *checkstring = NULL;
	char *md5_apop_we;
	u64_t user_idnr = 0;
	const char *query_result;
	C c; R r;
	int t = FALSE;

	/* lookup the user_idnr */
	if (auth_user_exists(username, &user_idnr) == DM_EQUERY)
		return DM_EQUERY;

	c = db_con_get();
	TRY
		r = db_query(c, "SELECT passwd,user_idnr FROM %susers WHERE user_idnr = %llu", DBPFX, user_idnr);
		if (db_result_next(r)) { /* user found */
			/* now authenticate using MD5 hash comparisation  */
			query_result = db_result_get(r,0); /* value holds the password */

			TRACE(TRACE_DEBUG, "apop_stamp=[%s], userpw=[%s]", apop_stamp, query_result);

			checkstring = g_strdup_printf("%s%s", apop_stamp, query_result);
			md5_apop_we = dm_md5(checkstring);

			TRACE(TRACE_DEBUG, "checkstring for md5 [%s] -> result [%s]", checkstring, md5_apop_we);
			TRACE(TRACE_DEBUG, "validating md5_apop_we=[%s] md5_apop_he=[%s]", md5_apop_we, md5_apop_he);

			if (strcmp((char *)md5_apop_he, md5_apop_we)) {
				TRACE(TRACE_MESSAGE, "user [%s] is validated using APOP", username);
				/* get user idnr */
				query_result = db_result_get(r,1);
				user_idnr = (query_result) ? strtoull(query_result, NULL, 10) : 0;
			}
		}
	CATCH(SQLException)
		LOG_SQLERROR;
		t = DM_EQUERY;
	FINALLY
		db_con_close(c);
	END_TRY;

	if (t == DM_EQUERY) return t;

	if (user_idnr == 0)
		TRACE(TRACE_MESSAGE, "user [%s] could not be validated", username);
	else
		db_user_log_login(user_idnr);

	if (checkstring) g_free(checkstring);

	return user_idnr;
}

char *auth_get_userid(u64_t user_idnr)
{
	C c; R r;
	char *result = NULL;
	c = db_con_get();

	TRY
		r = db_query(c, "SELECT userid FROM %susers WHERE user_idnr = %llu", DBPFX, user_idnr);
		if (db_result_next(r))
			result = g_strdup(db_result_get(r,0));
	CATCH(SQLException)
		LOG_SQLERROR;
	FINALLY
		db_con_close(c);
	END_TRY;

	return result;
}

int auth_check_userid(u64_t user_idnr)
{
	C c; R r; gboolean t = TRUE;

	c = db_con_get();
	TRY
		r = db_query(c, "SELECT userid FROM %susers WHERE user_idnr = %llu", DBPFX, user_idnr);
		if (db_result_next(r))
			t = FALSE;
	CATCH(SQLException)
		LOG_SQLERROR;
	FINALLY
		db_con_close(c);
	END_TRY;

	return t;
}

int auth_addalias(u64_t user_idnr, const char *alias, u64_t clientid)
{
	C c; R r; S s; int t = FALSE;
	INIT_QUERY;

	/* check if this alias already exists */
	snprintf(query, DEF_QUERYSIZE,
		 "SELECT alias_idnr FROM %saliases "
		 "WHERE lower(alias) = lower(?) AND deliver_to = ? "
		 "AND client_idnr = ?",DBPFX);

	c = db_con_get();
	TRY
		s = db_stmt_prepare(c,query);
		db_stmt_set_str(s, 1, alias);
		db_stmt_set_u64(s, 2, user_idnr);
		db_stmt_set_u64(s, 3, clientid);

		r = db_stmt_query(s);

		if (db_result_next(r)) {
			TRACE(TRACE_INFO, "alias [%s] for user [%llu] already exists", alias, user_idnr);
			t = TRUE;
		}
	CATCH(SQLException)
		LOG_SQLERROR;
		t = DM_EQUERY;
	END_TRY;

	if (t) {
		db_con_close(c);
		return t;
	}

	Connection_clear(c);

	TRY
		s = db_stmt_prepare(c, "INSERT INTO %saliases (alias,deliver_to,client_idnr) VALUES (?,?,?)",DBPFX);
		db_stmt_set_str(s, 1, alias);
		db_stmt_set_u64(s, 2, user_idnr);
		db_stmt_set_u64(s, 3, clientid);

		t = db_stmt_exec(s);
	CATCH(SQLException)
		LOG_SQLERROR;
		t = DM_EQUERY;
	FINALLY
		db_con_close(c);
	END_TRY;

	return t;
}

int auth_addalias_ext(const char *alias,
		    const char *deliver_to, u64_t clientid)
{
	C c; R r; S s; int t = FALSE;
	INIT_QUERY;

	c = db_con_get();
	TRY
		/* check if this alias already exists */
		if (clientid != 0) {
			snprintf(query, DEF_QUERYSIZE,
				 "SELECT alias_idnr FROM %saliases "
				 "WHERE lower(alias) = lower(?) AND "
				 "lower(deliver_to) = lower(?) "
				 "AND client_idnr = ? ",DBPFX);

			s = db_stmt_prepare(c, query);
			db_stmt_set_str(s, 1, alias);
			db_stmt_set_str(s, 2, deliver_to);
			db_stmt_set_u64(s, 3, clientid);

		} else {
			snprintf(query, DEF_QUERYSIZE,
				 "SELECT alias_idnr FROM %saliases "
				 "WHERE lower(alias) = lower(?) "
				 "AND lower(deliver_to) = lower(?) ",DBPFX);

			s = db_stmt_prepare(c,query);
			db_stmt_set_str(s, 1, alias);
			db_stmt_set_str(s, 2, deliver_to);
		}

		r = db_stmt_query(s);
		if (db_result_next(r)) {
			TRACE(TRACE_INFO, "alias [%s] --> [%s] already exists", alias, deliver_to);
			t = TRUE;
		}
	CATCH(SQLException)
		LOG_SQLERROR;
		t = DM_EQUERY;
	END_TRY;

	if (t) {
		db_con_close(c);
		return t;
	}

	Connection_clear(c);

	TRY
		s = db_stmt_prepare(c, "INSERT INTO %saliases (alias,deliver_to,client_idnr) VALUES (?,?,?)",DBPFX);
		db_stmt_set_str(s, 1, alias);
		db_stmt_set_str(s, 2, deliver_to);
		db_stmt_set_u64(s, 3, clientid);

		t = db_stmt_exec(s);
	CATCH(SQLException)
		LOG_SQLERROR;
		t = DM_EQUERY;
	FINALLY
		db_con_close(c);
	END_TRY;

	return t;
}

int auth_removealias(u64_t user_idnr, const char *alias)
{
	C c; S s; gboolean t = FALSE;
	
	c = db_con_get();
	TRY
		s = db_stmt_prepare(c, "DELETE FROM %saliases WHERE deliver_to=? AND lower(alias) = lower(?)",DBPFX);
		db_stmt_set_u64(s, 1, user_idnr);
		db_stmt_set_str(s, 2, alias);
		t = db_stmt_exec(s);
	CATCH(SQLException)
		LOG_SQLERROR;
	FINALLY
		db_con_close(c);
	END_TRY;

	return t;
}

int auth_removealias_ext(const char *alias, const char *deliver_to)
{
	C c; S s; gboolean t = FALSE;

	c = db_con_get();
	TRY
		s = db_stmt_prepare(c, "DELETE FROM %saliases WHERE lower(deliver_to) = lower(?) AND lower(alias) = lower(?)", DBPFX);
		db_stmt_set_str(s, 1, deliver_to);
		db_stmt_set_str(s, 2, alias);
		t = db_stmt_exec(s);
	CATCH(SQLException)
		LOG_SQLERROR;
	FINALLY
		db_con_close(c);
	END_TRY;

	return t;
}

GList * auth_get_user_aliases(u64_t user_idnr)
{
	C c; R r;
	GList *l = NULL;

	c = db_con_get();
	TRY
		r = db_query(c, "SELECT alias FROM %saliases WHERE deliver_to = '%llu' ORDER BY alias",DBPFX, user_idnr);
		while (db_result_next(r))
			l = g_list_prepend(l,g_strdup(db_result_get(r,0)));
	CATCH(SQLException)
		LOG_SQLERROR;
	FINALLY
		db_con_close(c);
	END_TRY;

	return l;
}

GList * auth_get_aliases_ext(const char *alias)
{
	C c; R r;
	GList *l = NULL;

	c = db_con_get();
	TRY
		r = db_query(c, "SELECT deliver_to FROM %saliases WHERE alias = '%s' ORDER BY alias DESC",DBPFX, alias);
		while (db_result_next(r))
			l = g_list_prepend(l,g_strdup(db_result_get(r,0)));
	CATCH(SQLException)
		LOG_SQLERROR;
	FINALLY
		db_con_close(c);
	END_TRY;

	return l;
}

gboolean auth_requires_shadow_user(void)
{
	return FALSE;
}
