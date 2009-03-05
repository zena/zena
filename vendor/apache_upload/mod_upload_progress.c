// Apache upload progress module. Works with mod_passenger (aka mod_rails) (c) Peter Sarnacki 2009. It's MIT license.
// More info here: http://drogomir.com/blog/2008/6/18/upload-progress-bar-with-mod_passenger-and-apache

#include <ap_config.h>
#include <http_core.h>
#include <http_log.h>
#include <apr_pools.h>
#include <apr_strings.h>
#include "unixd.h"

#if APR_HAS_SHARED_MEMORY
#include "apr_rmm.h"
#include "apr_shm.h"
#endif

#if APR_HAVE_UNISTD_H
#include <unistd.h>
#endif

#define PROGRESS_ID "X-Progress-ID"

#define CACHE_LOCK() do {                                  \
    if (config->cache_lock)                               \
        apr_global_mutex_lock(config->cache_lock);        \
} while (0)

#define CACHE_UNLOCK() do {                                \
    if (config->cache_lock)                               \
        apr_global_mutex_unlock(config->cache_lock);      \
} while (0)

typedef struct {
  int track_enabled;
  int report_enabled;
} DirConfig;


typedef struct upload_progress_node_s{
  int done;
  int length;
  int received;
  int err_status;
  char *key;
  int started_at;
  int speed; /* bytes per second */
  time_t expires;
  struct upload_progress_node_s* next;
  struct upload_progress_node_s* prev;
}upload_progress_node_t;

typedef struct {
  upload_progress_node_t *head; /* keep head of the list */
}upload_progress_cache_t;

typedef struct {
  request_rec *r;
  upload_progress_node_t *node;
}upload_progress_context_t;


typedef struct {
  apr_rmm_off_t cache_offset;
  apr_pool_t *pool;
  apr_global_mutex_t *cache_lock;
  char *lock_file;           /* filename for shm lock mutex */
  apr_size_t cache_bytes; 

#if APR_HAS_SHARED_MEMORY
    apr_shm_t *cache_shm;
    apr_rmm_t *cache_rmm;
#endif
  char *cache_file;
  upload_progress_cache_t *cache;
  
  
} ServerConfig;

static const char* upload_progress_shared_memory_size_cmd(cmd_parms *cmd, void *dummy, const char *arg);
static void upload_progress_child_init(apr_pool_t *p, server_rec *s);
static int reportuploads_handler(request_rec *r);
upload_progress_node_t* insert_node(request_rec *r, const char *key);
upload_progress_node_t *store_node(ServerConfig *config, const char *key);
upload_progress_node_t *find_node(request_rec *r, const char *key);
int add_upload_to_track(request_rec* r, const char* id);
const char *get_progress_id(request_rec *r);
static const char *track_upload_progress_cmd(cmd_parms *cmd, void *dummy, int arg);
static const char *report_upload_progress_cmd(cmd_parms *cmd, void *dummy, int arg);
void *upload_progress_config_create_dir(apr_pool_t *p, char *dirspec);
void *upload_progress_config_create_server(apr_pool_t *p, server_rec *s);
static void upload_progress_register_hooks(apr_pool_t *p);
static int upload_progress_handle_request(request_rec *r);
static int track_upload_progress(ap_filter_t *f, apr_bucket_brigade *bb,
                           ap_input_mode_t mode, apr_read_type_e block,
                           apr_off_t readbytes);
int upload_progress_init(apr_pool_t *, apr_pool_t *, apr_pool_t *, server_rec *);

//from passenger
typedef const char * (*CmdFunc)();// Workaround for some weird C++-specific compiler error.

static const command_rec upload_progress_cmds[] =
{
    AP_INIT_FLAG("TrackUploads", (CmdFunc) track_upload_progress_cmd, NULL, OR_AUTHCFG,
                 "Track upload progress in this location"),
    AP_INIT_FLAG("ReportUploads", (CmdFunc) report_upload_progress_cmd, NULL, OR_AUTHCFG,
                 "Report upload progress in this location"),
    AP_INIT_TAKE1("UploadProgressSharedMemorySize", (CmdFunc) upload_progress_shared_memory_size_cmd, NULL, RSRC_CONF,
                 "Size of shared memory used to keep uploads data, default 100KB"),
    { NULL }
};

module AP_MODULE_DECLARE_DATA upload_progress_module =
{
  STANDARD20_MODULE_STUFF,
  upload_progress_config_create_dir,
  NULL,
  upload_progress_config_create_server,
  NULL,
  upload_progress_cmds,
  upload_progress_register_hooks,      /* callback for registering hooks */
};

static void upload_progress_register_hooks (apr_pool_t *p)
{
  ap_hook_fixups(upload_progress_handle_request, NULL, NULL, APR_HOOK_FIRST);
  ap_hook_handler(reportuploads_handler, NULL, NULL, APR_HOOK_FIRST);
  ap_hook_post_config(upload_progress_init, NULL, NULL, APR_HOOK_MIDDLE);
  ap_hook_child_init(upload_progress_child_init, NULL, NULL, APR_HOOK_MIDDLE);
  ap_register_input_filter("UPLOAD_PROGRESS", track_upload_progress, NULL, AP_FTYPE_RESOURCE);
}

ServerConfig *get_server_config(request_rec *r) {
  return (ServerConfig*)ap_get_module_config(r->server->module_config, &upload_progress_module);
}

static int upload_progress_handle_request(request_rec *r)
{
  DirConfig* dir = (DirConfig*)ap_get_module_config(r->per_dir_config, &upload_progress_module);
  ServerConfig *config = get_server_config(r);
  
  if(dir->track_enabled) {
    if(r->method_number == M_POST) {
      ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "Upload Progress: Upload in trackable location: %s.", r->uri);
      const char* id = get_progress_id(r);
      if(id != NULL) {
        ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "Upload Progress: Progress id found: %s.", id);
        CACHE_LOCK();
        upload_progress_node_t *node = find_node(r, id);
	CACHE_UNLOCK();
        if(node == NULL) {
          add_upload_to_track(r, id);
          ap_add_input_filter("UPLOAD_PROGRESS", NULL, r, r->connection);
	} else {
          ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "Upload Progress: Node with id '%s' already exists.", id);
	}
        return DECLINED;
      }
    }
  }
  
  return DECLINED;
}

static const char *report_upload_progress_cmd(cmd_parms *cmd, void *config, int arg)
{
    DirConfig* dir = (DirConfig*)config ;
    dir->report_enabled = arg;
    return NULL;
}

static const char *track_upload_progress_cmd(cmd_parms *cmd, void *config, int arg)
{
    DirConfig* dir = (DirConfig*)config ;
    dir->track_enabled = arg;
    return NULL;
}

static const char* upload_progress_shared_memory_size_cmd(cmd_parms *cmd, void *dummy,
                                           const char *arg) {
    ServerConfig *config = (ServerConfig*)ap_get_module_config(cmd->server->module_config, &upload_progress_module);

    int n = atoi(arg);

    if (n <= 0) {
        return "UploadProgressSharedMemorySize should be positive";
    }

    config->cache_bytes = (apr_size_t)n;
    return NULL;
}

void *
upload_progress_config_create_dir(apr_pool_t *p, char *dirspec) {
    DirConfig* dir = (DirConfig*)apr_pcalloc(p, sizeof(DirConfig));
    dir->report_enabled = 0;
    dir->track_enabled = 0;
    return dir;
}

void *upload_progress_config_create_server(apr_pool_t *p, server_rec *s) {
	ServerConfig *config = (ServerConfig *)apr_pcalloc(p, sizeof(ServerConfig));
        config->cache_file = apr_pstrdup(p, "/tmp/upload_progress_cache");
        config->cache_bytes = 51200;
        apr_pool_create(&config->pool, p);
        return config;
}

static int track_upload_progress(ap_filter_t *f, apr_bucket_brigade *bb,
                           ap_input_mode_t mode, apr_read_type_e block,
                           apr_off_t readbytes)
{
    apr_status_t rv;
    upload_progress_node_t *node;
    ServerConfig* config = get_server_config(f->r);
    
     if ((rv = ap_get_brigade(f->next, bb, mode, block,
                                 readbytes)) != APR_SUCCESS) {
       return rv;
     }

    apr_off_t length;
    apr_brigade_length(bb, 1, &length);
    const char* id = get_progress_id(f->r);
    if(id == NULL) 
        return APR_SUCCESS;

    CACHE_LOCK();
    node = find_node(f->r, id);
    CACHE_UNLOCK();
    if(node == NULL) {
      return APR_SUCCESS;
    } else {
      CACHE_LOCK();
      node->received += (int)length;
      int upload_time = time(NULL) - node->started_at;
      if(upload_time > 0) {
        node->speed = (int)(node->received / upload_time);
      }
      CACHE_UNLOCK();
    }
    
    return APR_SUCCESS;
}

const char *get_progress_id(request_rec *r) {
  char *p, *start_p, *end_p;
  int i;
  //try to find progress id in headers
  const char *id  = apr_table_get(r->headers_in, PROGRESS_ID);
  //if not found check args
  if(id == NULL) {
    if (r->args) {
        i = 0;
        p = r->args;
        do {
            int len = strlen(p);
            if (len >= 14 && strncasecmp(p, "X-Progress-ID=", 14) == 0) {
                i = 1;
                break;
            }
            if (len<=0)
                break;
        } 
        while(p++);

        if (i) {
            i = 0;
            start_p = p += 14;
            end_p = r->args + strlen(r->args);
            while (p <= end_p && *p++ != '&') {
                i++;
            }
            return apr_pstrndup(r->connection->pool, start_p, p-start_p-1);
        }
    }
  }
  return id;
}

const char *get_json_callback_param(request_rec *r) {
  char *p, *start_p, *end_p;
  int i;
  const char *callback = NULL;

  if (r->args) {
      i = 0;
      p = r->args;
      do {
          int len = strlen(p);
          if (len >= 9 && strncasecmp(p, "callback=", 9) == 0) {
              i = 1;
              break;
          }
          if (len<=0)
              break;
      } 
      while(p++);

      if (i) {
          i = 0;
          start_p = p += 9;
          end_p = r->args + strlen(r->args);
          while (p <= end_p && *p++ != '&') {
              i++;
          }
          return apr_pstrndup(r->connection->pool, start_p, p-start_p-1);
      }
  }
  return callback;
}

void cache_free(ServerConfig *config, const void *ptr)
{
  if (config->cache_rmm) {
    if (ptr)
    /* Free in shared memory */
    apr_rmm_free(config->cache_rmm, apr_rmm_offset_get(config->cache_rmm, (void *)ptr));
  } else {
    if (ptr)
    /* Cache shm is not used */
      free((void *)ptr);
  }
}

char *fetch_key(ServerConfig *config, char *key) {
 return (char *)apr_rmm_addr_get(config->cache_rmm, apr_rmm_offset_get(config->cache_rmm, key));
}

int check_node(ServerConfig *config, upload_progress_node_t *node, const char *key) {
  char *node_key = fetch_key(config, node->key);
  return strcasecmp(node_key, key) == 0 ? 1 : 0;
}

upload_progress_node_t *fetch_node(ServerConfig *config, upload_progress_node_t *node) {
  return (upload_progress_node_t *)apr_rmm_addr_get(config->cache_rmm, apr_rmm_offset_get(config->cache_rmm, node));
}

upload_progress_cache_t *fetch_cache(ServerConfig *config) {
  return (upload_progress_cache_t *)apr_rmm_addr_get(config->cache_rmm, apr_rmm_offset_get(config->cache_rmm, config->cache));
}

upload_progress_node_t *fetch_first_node(ServerConfig *config) {
  upload_progress_cache_t *cache;
  
  cache = fetch_cache(config);
  if(cache->head == NULL) {
    return NULL;
  }
  
  return fetch_node(config, cache->head);
}

upload_progress_node_t *fetch_last_node(ServerConfig *config) {
  upload_progress_cache_t *cache;
  upload_progress_node_t *node;
  
  cache = fetch_cache(config);
  if(cache->head == NULL) {
    return NULL;
  }
  
  node = fetch_node(config, cache->head);
  while(node->next != NULL) {
    node = fetch_node(config, node->next);
  }
  
  return node;
}

upload_progress_node_t *store_node(ServerConfig *config, const char *key) {
  apr_rmm_off_t block = apr_rmm_calloc(config->cache_rmm, sizeof(upload_progress_node_t));
  upload_progress_node_t *node;
   
  node = block ? (upload_progress_node_t *)apr_rmm_addr_get(config->cache_rmm, block) : NULL;
  node->next = NULL;
  if(node == NULL) {
    return NULL;
  }
  
  block = apr_rmm_calloc(config->cache_rmm, strlen(key)+1);
  node->key = block ? (char *)apr_rmm_addr_get(config->cache_rmm, block) : NULL;
  if(node->key != NULL) {
    sprintf(node->key, "%s\0", key);
  }
  return node;
}

upload_progress_node_t* insert_node(request_rec *r, const char *key) {
  upload_progress_node_t *node;
  upload_progress_cache_t *cache;
  
  ServerConfig *config = (ServerConfig*)ap_get_module_config(r->server->module_config, &upload_progress_module);
  
  CACHE_LOCK();
  upload_progress_node_t *head = fetch_first_node(config);
  node = store_node(config, key);
  
  if(head == NULL) { 
    /* list is empty */
    cache = fetch_cache(config);
    cache->head = node;
    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "Upload Progress: Inserted node into an empty list.");
  } else {
    upload_progress_node_t *tail = fetch_last_node(config);
    tail->next = node;
    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "Upload Progress: Inserted node at the end of the list.");
  }
  
  node->length = r->clength;
  node->received = 0;
  node->done = 0;
  node->err_status = 0;
  node->started_at = time(NULL);
  node->speed = 0;
  node->expires = -1;
  sscanf(apr_table_get(r->headers_in, "Content-Length"), "%d", &(node->length));
  node->next = NULL;
  CACHE_UNLOCK();
  return node;
}

upload_progress_node_t *find_node(request_rec *r, const char *key) {
  upload_progress_node_t *node;

  ServerConfig *config = (ServerConfig*)ap_get_module_config(r->server->module_config, &upload_progress_module);

  node = fetch_first_node(config);
  if(node == NULL) {
    return NULL;
  }
  
  while(node != NULL) {
    if(check_node(config, node, key)) {
      return node;
    }
    node = fetch_node(config, node->next);
  }
  return node;
}

static apr_status_t upload_progress_cleanup(void *data)
{
    upload_progress_context_t *ctx = (upload_progress_context_t *)data;
    if (ctx->node) {
	if(ctx->r->status >= HTTP_BAD_REQUEST) 
	    ctx->node->err_status = ctx->r->status;
        ctx->node->done = 1;
        ctx->node->expires = time(NULL) + 60; /*expires in 60s */
    }
    return APR_SUCCESS;
}

static void clean_old_connections(request_rec *r) {
    upload_progress_node_t *prev = NULL;
    ServerConfig *config = get_server_config(r);
    CACHE_LOCK();
    upload_progress_node_t *node = fetch_first_node(config);
    while(node != NULL) {
        if(time(NULL) > node->expires && node->done == 1 && node->expires != -1) {
            /*clean*/
	    if(prev == NULL) {
		/* head */
		upload_progress_cache_t *cache = fetch_cache(config);
		cache->head = fetch_node(config, node->next);
		cache_free(config, node->key);
		cache_free(config, node);
		node = cache->head;
		continue;
	    } else {
		prev->next = node->next;
		cache_free(config, node->key);
		cache_free(config, node);
		node = prev;
		continue;
	    }
        }
	prev = node;
	node = fetch_node(config, node->next);
  }
  CACHE_UNLOCK();
}

int add_upload_to_track(request_rec* r, const char* key) {
  ServerConfig *config = get_server_config(r);
  upload_progress_node_t* node;
  
  clean_old_connections(r);

  CACHE_LOCK();
  node = find_node(r, key);
  if(node == NULL) {
    node = insert_node(r, key);
    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "Upload Progress: Added upload with id=%s to list.", key);
    upload_progress_context_t *ctx = (upload_progress_context_t*)apr_pcalloc(r->pool, sizeof(upload_progress_context_t));
    ctx->node = node;
    ctx->r = r;
    CACHE_UNLOCK();
    apr_pool_cleanup_register(r->pool, ctx, upload_progress_cleanup, apr_pool_cleanup_null);
    return OK;
  }
  CACHE_UNLOCK();
  return OK;
}

void upload_progress_destroy_cache(ServerConfig *config) {
    upload_progress_cache_t *cache = fetch_cache(config);
    upload_progress_node_t *node, *temp;
   
    cache_free(config, cache);
    node = fetch_node(config, cache->head);
    while(node != NULL) {
      temp = fetch_node(config, node->next);
      
      cache_free(config, node);
      node = temp;
    }
}

static apr_status_t upload_progress_cache_module_kill(void *data)
{
    ServerConfig *st = (ServerConfig*)data;

    upload_progress_destroy_cache(st);

#if APR_HAS_SHARED_MEMORY
    if (st->cache_rmm != NULL) {
        apr_rmm_destroy (st->cache_rmm);
        st->cache_rmm = NULL;
    }
    if (st->cache_shm != NULL) {
        apr_status_t result = apr_shm_destroy(st->cache_shm);
        st->cache_shm = NULL;
        return result;
    }
#endif
    return APR_SUCCESS;
}

apr_status_t upload_progress_cache_init(apr_pool_t *pool, ServerConfig *config)
{

#if APR_HAS_SHARED_MEMORY
    apr_status_t result;
    apr_size_t size;
    upload_progress_cache_t *cache;
    apr_rmm_off_t block;

    if (config->cache_file) {
        /* Remove any existing shm segment with this name. */
        apr_shm_remove(config->cache_file, config->pool);
    }

    size = APR_ALIGN_DEFAULT(config->cache_bytes);
    result = apr_shm_create(&config->cache_shm, size, config->cache_file, config->pool);
    if (result != APR_SUCCESS) {
        return result;
    }

    /* Determine the usable size of the shm segment. */
    size = apr_shm_size_get(config->cache_shm);

    /* This will create a rmm "handler" to get into the shared memory area */
    result = apr_rmm_init(&config->cache_rmm, NULL,
                          apr_shm_baseaddr_get(config->cache_shm), size,
                          config->pool);
    if (result != APR_SUCCESS) {
        return result;
    }

    apr_pool_cleanup_register(config->pool, config , upload_progress_cache_module_kill, apr_pool_cleanup_null);
    
    /* init cache object */
    CACHE_LOCK();
    block = apr_rmm_calloc(config->cache_rmm, sizeof(upload_progress_cache_t));
    cache = block ? (upload_progress_cache_t *)apr_rmm_addr_get(config->cache_rmm, block) : NULL;
    if(cache == NULL) {
      CACHE_UNLOCK();
      return 0;
    }
    cache->head = NULL;
    config->cache_offset = block;
    config->cache = cache;
    CACHE_UNLOCK();
    
#endif

    return APR_SUCCESS;
}

int upload_progress_init(apr_pool_t *p, apr_pool_t *plog,
                    apr_pool_t *ptemp,
                    server_rec *s) {
    apr_status_t result;
    server_rec *s_vhost;
    ServerConfig *st_vhost;
    
    ServerConfig *config = (ServerConfig*)ap_get_module_config(s->module_config, &upload_progress_module);

    void *data;
    const char *userdata_key = "upload_progress_init";

    /* upload_progress_init will be called twice. Don't bother
     * going through all of the initialization on the first call
     * because it will just be thrown away.*/
    apr_pool_userdata_get(&data, userdata_key, s->process->pool);
    if (!data) {
        apr_pool_userdata_set((const void *)1, userdata_key,
                               apr_pool_cleanup_null, s->process->pool);

    #if APR_HAS_SHARED_MEMORY
        /* If the cache file already exists then delete it.  Otherwise we are
         * going to run into problems creating the shared memory. */
        if (config->cache_file) {
            char *lck_file = apr_pstrcat(ptemp, config->cache_file, ".lck",
                                         NULL);
            apr_file_remove(lck_file, ptemp);
        }
    #endif
        return OK;
    }
                    
    #if APR_HAS_SHARED_MEMORY
    
    /* initializing cache if shared memory size is not zero and we already
     * don't have shm address
     */
    if (!config->cache_shm && config->cache_bytes > 0) {
    #endif
        result = upload_progress_cache_init(p, config);
        if (result != APR_SUCCESS) {
            ap_log_error(APLOG_MARK, APLOG_ERR, result, s,
                         "Upload Progress cache: could not create shared memory segment");
            return DONE;
        }

#if APR_HAS_SHARED_MEMORY
        if (config->cache_file) {
            config->lock_file = apr_pstrcat(config->pool, config->cache_file, ".lck",
                                        NULL);
        }
#endif

        result = apr_global_mutex_create(&config->cache_lock,
                                         config->lock_file, APR_LOCK_DEFAULT,
                                         config->pool);
        if (result != APR_SUCCESS) {
            return result;
        }

#ifdef AP_NEED_SET_MUTEX_PERMS
        result = unixd_set_global_mutex_perms(config->cache_lock);
        if (result != APR_SUCCESS) {
            ap_log_error(APLOG_MARK, APLOG_CRIT, result, s,
                         "Upload progress cache: failed to set mutex permissions");
            return result;
        }
#endif
        /* merge config in all vhost */
        s_vhost = s->next;
        while (s_vhost) {
            st_vhost = (ServerConfig *)
                       ap_get_module_config(s_vhost->module_config,
                                            &upload_progress_module);

#if APR_HAS_SHARED_MEMORY
            st_vhost->cache_shm = config->cache_shm;
            st_vhost->cache_rmm = config->cache_rmm;
            st_vhost->cache_file = config->cache_file;
            st_vhost->cache_offset = config->cache_offset;
            st_vhost->cache = config->cache;
            ap_log_error(APLOG_MARK, APLOG_DEBUG, result, s,
                         "Upload Progress: merging Shared Cache conf: shm=0x%pp rmm=0x%pp "
                         "for VHOST: %s", config->cache_shm, config->cache_rmm,
                         s_vhost->server_hostname);
#endif
            st_vhost->lock_file = config->lock_file;
            s_vhost = s_vhost->next;
        }
#if APR_HAS_SHARED_MEMORY
    }
    else {
        ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, s,
                     "Upload Progress cache: cache size is zero, disabling "
                     "shared memory cache");
    }
#endif

  return(OK);
}

static int reportuploads_handler(request_rec *r)
{ 
    int length, received, done, speed, err_status, found=0;
    char *response;
    DirConfig* dir = (DirConfig*)ap_get_module_config(r->per_dir_config, &upload_progress_module);

    if(!dir->report_enabled) {
        return DECLINED;
    }
    if (r->method_number != M_GET) {
        return HTTP_METHOD_NOT_ALLOWED;
    }

    /* get the tracking id if any */
    const char *id = get_progress_id(r);

    if (id == NULL) {
	ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "Upload Progress: Not found id in location with reports enabled. uri=%s", id, r->uri);
        return HTTP_NOT_FOUND;
    } else {
        ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "Upload Progress: Found id=%s in location with reports enables. uri=%s", id, r->uri);
    }

    ServerConfig *config = (ServerConfig*)ap_get_module_config(r->server->module_config, &upload_progress_module);

    if (config->cache_rmm == NULL) {
        ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "Upload Progress: Cache error while generating report");
        return HTTP_INTERNAL_SERVER_ERROR ;
    }

    CACHE_LOCK();
    upload_progress_node_t *node = find_node(r, id);
    if (node != NULL) {
	ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "Node with id=%s found for report", id);
        received = node->received;
        length = node->length;
        done = node->done;
        speed = node->speed;
        err_status = node->err_status;
        found = 1;
        CACHE_UNLOCK();
    } else {
        ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "Node with id=%s not found for report", id);
    }
    
    CACHE_UNLOCK();

    ap_set_content_type(r, "text/javascript");

    apr_table_set(r->headers_out, "Expires", "Mon, 28 Sep 1970 06:00:00 GMT");
    apr_table_set(r->headers_out, "Cache-Control", "no-cache");


/*
 There are 4 possibilities
   * request not yet started: found = false
   * request in error:        err_status >= NGX_HTTP_SPECIAL_RESPONSE
   * request finished:        done = true
   * request not yet started but registered:        length==0 && rest ==0
   * reauest in progress:     rest > 0 
 */

   
    if (!found) {
      response = apr_psprintf(r->pool, "new Object({ 'state' : 'starting' })");
    } else if (err_status >= HTTP_BAD_REQUEST  ) {
      response = apr_psprintf(r->pool, "new Object({ 'state' : 'error', 'status' : %d })", err_status);
    } else if (done) {
      response = apr_psprintf(r->pool, "new Object({ 'state' : 'done' })");
    } else if ( length == 0 && received == 0 ) {
      response = apr_psprintf(r->pool, "new Object({ 'state' : 'starting' })");
    } else {
      response = apr_psprintf(r->pool, "new Object({ 'state' : 'uploading', 'received' : %d, 'size' : %d, 'speed' : %d  })", received, length, speed);
    }

    char *completed_response;
    
    /* get the jsonp callback if any */
    const char *jsonp = get_json_callback_param(r);
   
    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                       "Upload Progress: JSON-P callback: %s.", jsonp);

    // fix up response for jsonp request, if needed
    if (jsonp) {
      completed_response = apr_psprintf(r->pool, "%s(%s);\r\n", jsonp, response);
    } else {
      completed_response = apr_psprintf(r->pool, "%s\r\n", response);
    }
    
    ap_rputs(completed_response, r);

    return OK;
}


static void upload_progress_child_init(apr_pool_t *p, server_rec *s)
{
    apr_status_t sts;
    ServerConfig *st = (ServerConfig *)ap_get_module_config(s->module_config,
                                                 &upload_progress_module);

    if (!st->cache_lock) return;

    sts = apr_global_mutex_child_init(&st->cache_lock,
                                      st->lock_file, p);
    if (sts != APR_SUCCESS) {
        ap_log_error(APLOG_MARK, APLOG_CRIT, sts, s,
                     "Failed to initialise global mutex %s in child process %"
                     APR_PID_T_FMT ".",
                     st->lock_file, getpid());
    }
}
