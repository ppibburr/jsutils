namespace JSUtils {
	public const string VERSION = "0.1.0";
	
	public static void raise(JSCore.Context ctx, string msg, out JSCore.Value err) {
		GLib.Value?[] args = new GLib.Value?[1];
		args[0] = msg;
		err = (JSCore.Value)new JSCore.Object.error(ctx, 1, vary2jary(ctx, args), null);
	}

	public enum ValueType {
			NULL,
			OBJECT,
			STRING,
			DOUBLE,
			FLOAT,
			INT,
			BOOLEAN
		}
		
	public enum ObjectType {
		OBJECT,
		FUNCTION,
		CONSTRUCTOR,
		ARRAY;
		
		public static ObjectType from_object(JSCore.Context c, JSCore.Object obj) {
			if (obj.is_function(c)) {
				return FUNCTION;
			} else if (obj.is_constructor(c)) {
				return CONSTRUCTOR;
			} else {
				var code = new JSCore.String.with_utf8_c_string("Array.isArray(this);");
				var v = c.evaluate_script(code, obj, null, 0, null);
				if (v.is_boolean(c) && v.to_boolean(c) ) {
					return ARRAY;
				} else {
					return OBJECT;
				}
			}
		}
	}
	
	public static ValueType value_type(GLib.Value? val) {
		if (val == null) {
			return ValueType.NULL;
		}
		
		if (val.holds(typeof(string))) {
			return ValueType.STRING;
		} else if (val.holds(typeof(bool))) {
			return ValueType.BOOLEAN;
		} else if (val.holds(typeof(double))) {
			return ValueType.DOUBLE;
		} else if (val.holds(typeof(float))) {
			return ValueType.FLOAT;	
		} else if (val.holds(typeof(int))) {
			return ValueType.INT;				
		} else if (val.holds(typeof(void*))) {
			return ValueType.OBJECT;
		} else {
			return ValueType.NULL;
		}
	}
	
	public static GLib.Value?[] jsary2vary(JSCore.Context c, JSCore.Object obj) {
		// TODO:
		int len = (int)obj.get_property(c, new JSCore.String.with_utf8_c_string("length"), null).to_number(c,null);
		
		GLib.Value?[] vals = new GLib.Value?[len];
		
		for (var i = 0; i < len; i++) {
			var v = obj.get_property(c, new JSCore.String.with_utf8_c_string(@"$i"), null);
			vals[i] = jval2gval(c, v, null);
		}
		
		return vals;
	}			
	
	public string jval2string(JSCore.Context c, JSCore.Value v, out JSCore.Value e) {
		var j   = v.to_string_copy(c, v);
		var len = j.get_length()+1;
		
		char[] buff = new char[len];
		
		j.get_utf8_c_string(buff, len);
		
		return (string)buff;
	}
	
	public static GLib.Value? jval2gval(JSCore.Context c, JSCore.Value arg, out JSCore.Value e) {
		GLib.Value? v = null;
		
		if (arg.is_string(c)) {
			v = jval2string(c, arg, out e);
		
		} else if (arg.is_number(c)) {
			v = arg.to_number(c, null);
			
		} else if (arg.is_boolean(c)) {
			v = arg.to_boolean(c);
			
		} else if (arg.is_null(c)) {
			v = null;
			
		} else if (arg.is_object(c)) {
			v = arg.to_object(c, null);			
		
		} else {
			raise(c, "Bad Conversion", out e);
			
			return null;
		}
		
		
		return v;		
	}				
	
	
	public static JSCore.Value gval2jval(JSCore.Context c, GLib.Value? val) {
		switch (value_type(val)) {
		case ValueType.STRING:
		  JSCore.Value? v = new JSCore.Value.string(c, new JSCore.String.with_utf8_c_string((string)val));
		  return v;
		  
		case ValueType.DOUBLE:  
		  return new JSCore.Value.number(c, (double)val);

		case ValueType.FLOAT:  
		  return new JSCore.Value.number(c, (double)(float)val);
		  
		case ValueType.INT:  
		  return new JSCore.Value.number(c, (double)(int)val);				  

		case ValueType.BOOLEAN:  
		  return new JSCore.Value.boolean(c, (bool)val);
		  
		case ValueType.OBJECT:  
		  return c.evaluate_script(new JSCore.String.with_utf8_c_string("this;"), (JSCore.Object)val, null, 0, null);
		  
		default:
		  return new JSCore.Value.null(c);
		}		
	}	
	
	public static void*[] vary2jary(JSCore.Context c, GLib.Value?[] args) {
		void*[] jargs = {};
		int i = 0;
		
		foreach (var v in args) {
			jargs += (void*)gval2jval(c, v);
			i++;
		}
		
		return jargs;			
	}
	
	public static GLib.Value? call(JSCore.Context c, JSCore.Object self, JSCore.Object fun, GLib.Value?[] args) {
		var jargs = vary2jary(c, args);
		
		unowned JSCore.Value res = fun.call_as_function(c, self, (JSCore.Value[]?)jargs, null);

		return jval2gval(c,res,null);
	}
	
	public string v2str(GLib.Value? val, JSCore.Context? c = null) {
		switch (value_type(val)) {
		case ValueType.NULL:
			return "(NULL)";
		
		case ValueType.BOOLEAN:
			return val.get_boolean().to_string();
		
		case ValueType.DOUBLE:
			double d = val.get_double();
			return d.to_string();
			
		case ValueType.FLOAT:
			double d = val.get_float();
			return d.to_string();
		
		case ValueType.INT:
			double d = val.get_int();
			return d.to_string();										
			
		case ValueType.STRING:
			return (string)val;
		  
		case ValueType.OBJECT:
			return c != null ? object_to_string(c, (JSCore.Object)val) : "[Object]";
		
		default:
		  return "(NULL)";
		}	
	}
	
	public static string object_to_string(JSCore.Context c, JSCore.Object obj) {
		return (string)jval2gval(c, c.evaluate_script(new JSCore.String.with_utf8_c_string("this.toString();"), obj, null, 0, null), null);
	}				
	
	public class Object : JSCore.Object {
		public Object(JSCore.Context c, JSCore.Class? klass=null, void* data=null) {
			base(c,klass,data);
		}
		
		public void set_prop(JSCore.Context c, string name, GLib.Value? v) {
			var js = new JSCore.String.with_utf8_c_string(name);
			set_property(c, js, gval2jval(c, v), JSCore.PropertyAttribute.ReadOnly, null);
		}
		
		public GLib.Value? get_prop(JSCore.Context c, string name) {
			var js = new JSCore.String.with_utf8_c_string(name);
			return jval2gval(c, get_property(c, js, null), null);
		}
		
		public GLib.Value? to_gval() {
			GLib.Value? v = this;
			return v;
		}			
	}

	public class Context : JSCore.GlobalContext {
		public JSCore.Object global_object() {
			return ((JSCore.Context)this).get_global_object();			
		}
		
		public Context(JSCore.Class? kls=null) {
			base(kls);
			retain();
		}
		
		public GLib.Value? exec(string code, JSCore.Object? self = null, out JSCore.Value e = null) {
			var js = new JSCore.String.with_utf8_c_string(code);
			//JSCore.Value e2;
			var j = ((JSCore.Context)this).evaluate_script(js, null, null, 0, out e);
			
			if (j == null) {
				debug("null result");
				debug(object_to_string(this, (JSCore.Object)e));
				
				return null;
			}
			
			var result = jval2gval(this, j, null);

			return result;
		}
	
		
		// Initializes libseed in this context
		[CCode (has_target = false)]
		public delegate void init_seed_sig(int argc, string** argv, void* ctx);
		public void init_seed(string[] argv) {

			var handle = dlopen("libseed-gtk3.so", RTLD_LAZY);
			var func   = dlsym(handle, "seed_init_with_context");

			((init_seed_sig)func)(0, null, (void*)this);
		}
		
		public JSUtils.Binder add_toplevel_class(JSUtils.Binder klass) {
			klass.set_constructor_on(this, this.get_global_object());
			
			return klass;
		}	
	
		[CCode (has_target = false)]
		public delegate LibInfo? init_lib(JSUtils.Context ctx);
		
		private static string[]? _search_paths = null;
		public static string[] search_paths {
			get {
				if (_search_paths == null) {
				    _search_paths = new string[0];	
				    _search_paths += GLib.Environment.get_variable("JSUTILS_LIB_DIR") ?? @"/usr/lib/jsutils/$(JSUtils.VERSION)";
				}
				
				return _search_paths;
			}
			
			set {
				_search_paths = value;
			}
		}
		
		public static void _add_search_path(string path) {
			if (path in search_paths) {
			
			} else {
				_search_paths += path;
			}
		}
			
		
		private static Gee.HashMap<string, LibInfo?> _so_map = null;	
		public static Gee.HashMap<string, LibInfo?> so_map {
			get {
				if (_so_map == null) {
					_so_map =  new Gee.HashMap<string, LibInfo?>();	
				}
				
				return _so_map;
			}
		}
		
		public LibInfo? load_so(owned string name) {			
			string path = name;
			
			if (!f_exist(path)) {
				path = @"$(name).so";					
				if (!f_exist(path)) {		
					if (!f_exist(path)) {			
						path = @"./$(name)";	
						if (!f_exist(path)) {	
							foreach (var search in search_paths) {
								if (!f_exist(path)) {
									path = @"$(search)/$(name)";
									
									if (!f_exist(path)) {
										path = @"$(search)/$(name).so";
								   
										if (!f_exist(path)) {
										
											path = @"$(search)/$(name)/$(name).so";
											
											if (f_exist(path)) {
												break;
											}
										}							
									}				
								}
							}
						}
					}
				}
			} else {
				JSUtils.debug(@"Says we have $path");
			}
			
			if (!f_exist(path)) {
				JSUtils.debug("no so found: %s\n".printf(path));
				return null;
			}			
			
			name = GLib.Path.get_basename(path);
			
			var split = name.split(".");
			name = split[0];
			
			JSUtils.debug("FIND_SO: %s\n".printf(path));
			
			if ("so" in split) {
				
			} else {
				return null;
			}
			
			if (name in so_map) {
				var fun    = (init_lib)dlsym(so_map[name].handle, @"$(name)_init");
				
				var binders = fun(this);				
				
				return so_map[name];
			}			
			
			JSUtils.debug(@"so: $name - $path");
			var handle = dlopen(path, RTLD_LAZY);
			var fun    = (init_lib)dlsym(handle, @"$(name)_init");
			
			var binders = fun(this);
            
            JSUtils.debug(@"so $path init-ed");
            binders.handle = handle;
            so_map[name] = binders;
            
			return binders;
		}	
		
		public bool init_core() {
			if (load_so("bridge.so") == null) {
				return false;
			}
			
			return true;
		}
	}
		
		
	public static bool f_exist(string path) {
		return FileUtils.test (path, FileTest.EXISTS) && !FileUtils.test (path, FileTest.IS_DIR);
	}	
	
	public class LibInfo {
		public Binder?[] interfaces;
		public string? iface_name = null;
		public string? parent_iface = null;
		public void* handle;
	}
	
	public static void debug(string msg) {
		if (debug_state) {
			stderr.printf("%s\n", msg);
		}
	}
	
	public bool debug_state = false;	
	
	[CCode (cname = "dlopen")] 
	extern unowned void * dlopen (string filename, int flag);

	[CCode (cname = "dlerror")] 
	extern unowned string dlerror ();

	[CCode (cname = "dlsym")] 
	extern unowned void * dlsym (void * handle, string symbol);

	const int RTLD_LAZY = 0x00001;	
	
	public delegate void exit_delegate(int code);
    public void exit(int code) {
		((exit_delegate)dlsym(null, "exit"))(code);
	}
}
