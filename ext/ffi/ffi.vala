namespace FFI {
	using JSUtils;

	[CCode (cname = "dlopen")] 
	extern unowned void * dlopen (string filename, int flag);

	[CCode (cname = "dlerror")] 
	extern unowned string dlerror ();

	[CCode (cname = "dlsym")] 
	extern unowned void * dlsym (void * handle, string symbol);

	const int RTLD_LAZY = 0x00001;

	// The 'data' passed to closure binding
	public class Data : GLib.Object {
		public weak JSCore.Context c; 
		public weak JSCore.Object? self; 
		public weak JSCore.Object func;
		public CallbackInfo? info = null;
		public FFIPointerBinder? pointer_binder;
		public Data(JSCore.Context c, FFIPointerBinder? pointer_binder, JSCore.Object? self, JSCore.Object func, CallbackInfo? cb = null) {
			this.c = c;
			this.self = self;
			this.func = func;
			this.info = cb;
			this.pointer_binder = pointer_binder;
			self.protect(c);
			func.protect(c);
			ref();
		}
		
		public GLib.Value? call(void*[] args) {
			// void *p = *(void**)args[0];
			
			JSUtils.debug("Data#call: 001");			
						
			if (info == null) {
				JSUtils.call(c, self, func, null);			
				return null;
			}
			
			GLib.Value?[] vary = new GLib.Value?[args.length];
			
			JSUtils.debug("Data#call: 002");
			
			for (int i = 0; i<args.length; i++) {
				var q = carg2gval(info.args_types[i], args[i]);
				
				if (q == null) {
					JSUtils.debug("Data#call: NULL POINTER ARG");
				}
				
				if (info.args_types[i] == "pointer") {
					JSUtils.debug("Data#call: 003 make pointer jval %s".printf(value_type(q).to_string()));
					var obj = new JSCore.Object(c, pointer_binder.js_class, null);
					JSUtils.debug("Data#call: 004 set address");
					((JSUtils.Object)obj).set_prop(c, "address", q);
					q = obj;	
				}
				
				vary[i] = q;
			}
			
			JSUtils.debug("Data#call: 005 call jfunc");
			
			var res = JSUtils.call(c, self, func, vary);

			JSUtils.debug("Data#call: 006");

			return res;
			
		}
	}
	
	
	
	public class CallbackInfo {
		public string rtype;
		public string[] args_types;
		public string name;
		
		public static Gee.HashMap<string,CallbackInfo> callbacks;
		
		public CallbackInfo (string name, string rtype, string[] args_types) {
			this.name = name;
			this.rtype = rtype;
			this.args_types = args_types;
			callbacks[name] = this;
		}
		
		static construct {
			callbacks = new Gee.HashMap<string, CallbackInfo>();
		}
		
		public static bool is_registered(string name) {
			if (name in callbacks) {
				return true;
			}
			
			return false;
		}
		
		public static CallbackInfo? get_callback(string name) {
			if (is_registered(name)) {
				return callbacks[name];
			}
			
			return null;
		}
	}


	// TODO: move in to own library; quite useful
	//
	// Creates a C closure 
	public class FFIClosure : GLib.Object {
		public FFI.call_interface cif;
		public FFI.type[] targs;	
		public FFI.Status? status = null;
		

			
		[CCode (has_target = false)]
		public delegate void* t_cb(void* args);

		public static void dispatch(FFI.call_interface cif, void** ret, [CCode (array_length = false)] void*[] args, FFIClosure ffic) {
			var argv = new void*[ffic.n_args];
			
			for (int i = 0; i < ffic.n_args; i++) {
				argv[i] = args[i];
			} 
			
			*ret = ffic.invoke(argv);
		}

		public FFI.Closure* closure {get; private set;}
		public void* bound_callback {get; private set;}
		public void* data {get; private set;}
		public int n_args {get; private set;}
		public process_delegate process {get; private set;}
		
		public delegate void* process_delegate(void*[] args, void* data);
		
		public void* invoke(void*[] args) {
			return process(args, data);
		}

		public FFIClosure(int n_args, void* data, process_delegate cb) {
			this.process = cb;
			this.n_args = n_args;
			this.data = data;
			
			targs = new FFI.type[3];
			targs[0] = FFI.pointer;	
			targs[1] = FFI.pointer;	
			targs[2] = FFI.pointer;			
			FFI.call_interface tcif;
			
			status = FFI.call_interface.prepare(out tcif, FFI.ABI.DEFAULT , FFI.pointer, targs);
			
			cif = tcif;		
			
			this.closure = create_closure();
		} 

		private FFI.Closure* create_closure() {
			ref();
			void* z;
			
			FFI.Closure* closure;
			closure = FFI.closure_alloc(sizeof(FFI.Closure), out z);
					
			if (closure != null) {
				if (status == FFI.Status.OK) {
				  if (FFI.prep_closure_loc(closure, ref cif, (void*)dispatch, this, z) == FFI.Status.OK) {
					  this.bound_callback = z;
					  return closure;
				  }
				}
			}
			
			this.bound_callback = null;
			
			return closure;
		}
	}
	
	
	public static GLib.Value? carg2gval(string type, void* val) {
		GLib.Value? v;
		
		switch (FFIPointerBinder.resolve_type(type)) {
		case "string":
			v = (string)val;
			break;
			
		case "pointer":
			void *p = *(void**)val;
			v = (int)p;
			break;
		
		case "int32":
			v = *(int*)val;
			break;
			
		case "bool":
			v = *(bool*)val;
			break;			    
		
		default:
			v = null;
			break;
		}		
		
		return v;	
	}
	

	public class FFIPointerBinderKlass : JSUtils.Binder {
		public static size_t size_int32   = sizeof(int);
		public static size_t size_pointer = sizeof(void*);
		public static size_t size_bool  = sizeof(bool);
		public static Gee.HashMap<string, size_t?> size_map;
		
		static construct {
			size_map = new Gee.HashMap<string, size_t?>();
			size_map["pointer"] = size_pointer;
			size_map["int32"]   = size_int32;
			size_map["bool"]    = size_bool;
		}
		
		public FFIPointerBinderKlass() {
			base("FFIPointerClass");
			
			bind("apply", (instance, args, c, out e) => {
				return instance;
			});		
			
			
			// Return the size of a type
			ValueType?[] s_types = {ValueType.STRING};
			string[]     s_tnames = {"Syting/Symbol"};
			bind("size_of", (self, args, c, out e) => {
				string type = (string)args[0];
				
				GLib.Value? v = (int)size_map[type];
				
				return v;
			}, 1, s_types, s_tnames);
			
			// Returns a pointer of size, args[0]
			ValueType?[] m_types = {ValueType.DOUBLE};
			string[] m_tnames    = {"Integer"};
			bind("malloc", (self, args, c, out e) => {
				//JSUtils.debug_state = true;
				
				size_t size = (size_t)(int)(double)args[0];
		
				void* i = malloc(size);
				
				GLib.Value? addr = (int)(i);
				GLib.Value? ret;
				
				JSUtils.debug("alloc");
									
				var obj = new JSUtils.Object((JSUtils.Context)c, this.target.js_class, null);
				obj.set_prop(c, "address", addr);
				
				obj.set_prop(c, "binder", Type.from_instance(this.target).name());
				
				ret = obj;
				return obj;
			}, 1, m_types, m_tnames);
			
			close();
		}
	}

	
	// Represents a pointer
	public class FFIPointerBinder : JSUtils.Binder {
		// core types
		public static string[] types {get; private set; default = new string[0];}
		
		// typedefs
		public static Gee.HashMap<string, string> typedefs;
		
		// typedef what to
		public static bool typedef(string what, string to) {
			if (to in types) {
				if (what in typedefs) {
					return false;
				} else {
					typedefs[what] = to;
				}
				
				return true;
			}
			
			return false;
		}
		
		// resolves typedefs/callbacks to core type
		public static string? resolve_type(string type) {
			if (type in typedefs) {
				return resolve_type(typedefs[type]);
			}
			
			if (type in types) {
				return type;
			}
			
			if (type in CallbackInfo.callbacks.keys) {
				return type;
			}
			
			return null;
		}
		
		static construct {
			typedefs = new Gee.HashMap<string, string>();
			
			_types += "pointer";
			_types += "string";
			_types += "bool";
			_types += "int32";
			_types += "uint32";
			_types += "int8";
			_types += "uint8";
			_types += "void";
		}
		
		public FFIPointerBinder() {
			base("Pointer", new FFIPointerBinderKlass());
			
			
			bind("read_int32", (self, args, c, out e) => {
				//JSUtils.debug_state = true;
				
				JSUtils.debug("read_int");
				int addr = (int)(double)(((JSUtils.Object)self).get_prop(c, "address"));
				
				JSUtils.debug("read_int: %d".printf(addr));
				int i = *(int*)addr.to_pointer();
				
				GLib.Value? v = i;
				
				return v;
			}, 0);
			
			bind("read_string", (self, args, c, out e) => {
				//JSUtils.debug_state = true;
				
				JSUtils.debug("read_int");
				int addr = (int)(double)(((JSUtils.Object)self).get_prop(c, "address"));
				
				JSUtils.debug("read_int: %d".printf(addr));
				void *i = *(void**)addr.to_pointer();
				
				GLib.Value? v = (string)i;
				
				return v;
			}, 0);
			
			bind("read_bool", (self, args, c, out e) => {
				//JSUtils.debug_state = true;
				
				JSUtils.debug("read_int");
				int addr = (int)(double)(((JSUtils.Object)self).get_prop(c, "address"));
				
				JSUtils.debug("read_int: %d".printf(addr));
				bool i = *(bool*)addr.to_pointer();
				
				GLib.Value? v = i;
				
				return v;
			}, 0);	
			
			bind("read_pointer", (self, args, c, out e) => {
				//JSUtils.debug_state = true;
				
				JSUtils.debug("read_pointer");
				int addr = (int)(double)(((JSUtils.Object)self).get_prop(c, "address"));
				
				JSUtils.debug("read_pointer: %d".printf(addr));
				void** i = (void**)addr.to_pointer();
				
				GLib.Value? v = ptr2jobj(c, this.js_class, i[0]);
				
				return v;
			}, 0);												
			
			close();
		}
	}
	
	public static JSCore.Object? ptr2jobj(JSCore.Context c, JSCore.Class klass, void* p) {
		GLib.Value? addr = (int)(p);
		
		var obj = new JSUtils.Object((JSUtils.Context)c, klass, null);
		obj.set_prop(c, "address", addr);
		
		return obj;
	}
	
	public class FFIFuncBinderKlass : JSUtils.Binder {
		public FFIFuncBinderKlass() {
			base("FFIFuncClass");
			
			bind("apply", (instance, args, c, out e) => {

				return FFIFuncBinder.init_object(null, jsary2vary(c,(JSCore.Object)gval2jval(c,args[1])), c, out e);
				
			});		
			
			ValueType?[] rc_types = {ValueType.STRING, ValueType.STRING, ValueType.OBJECT};
			string[] rc_tnames    = {"Symbol", "Symbol", "Array"};
			bind("register_callback", (self, args, c, out e) => {
				string name = (string)args[0];
				string rtype = (string)args[1];
				string[] args_types = new string[0];
				
				if (ObjectType.from_object(c, (JSCore.Object)args[2]) != ObjectType.ARRAY) {
					raise(c, "Expects Array as argument 3 (signature: Symbol[])", out e);
					return null;
				}
				
				var vary = jsary2vary(c, (JSCore.Object)args[2]);
				
				int i = 0;
				foreach(var v in vary) {
					var n = FFIPointerBinder.resolve_type((string)v);
					if (n != null) {
						args_types += (string)v;
					} else {
						raise(c, "Bad value for param type: %s, at param %d".printf((string)v, i), out e);
						return null;
					}
					i++;
				}
				
				new CallbackInfo(name, rtype, args_types);
				
				return true; 
			}, 3, rc_types, rc_tnames);
			
			close();
		}
	}

	// FIXME: Maybe extract the ffi bits into thier own class?
	//        
	// Calls dynamic loaded c function
	public class FFIFuncBinder : JSUtils.Binder {
		public weak JSCore.Context default_context;
		
		public GLib.Value? invoke(JSCore.Context c, JSCore.Object self, string module, string symbol, string rt, GLib.Value?[] atypes, GLib.Value?[] args, out JSCore.Value e) {
			FFI.call_interface cif;
			void* func;
			
			string? rtype = FFIPointerBinder.resolve_type(rt);
			if (rtype == null) {
				raise(c, "BadReturnType - Can not resolve type: `%s`".printf(rt), out e);
				return null;
			}
			
			var handle = dlopen(module, RTLD_LAZY);
			
			if (handle == null) {
				raise(c, "Cannot DL %s.".printf(module), out e);
				return null;
			}
			
			func = dlsym(handle, symbol);
			
			if (func == null) {
				raise(c, "Cannot find symbol %s in %s.".printf(symbol, module), out e);
			}
			
			FFI.type r;
			FFI.type[] a = new FFI.type[atypes.length];
			
			switch (rtype) {
			case "string":
			  r = FFI.pointer;
			  break;
			case "int32":
				r = FFI.sint32;
				break;	
			case "bool":
				r = FFI.sint8;
				break;
			case "pointer":
				r = FFI.pointer;
				break;	  
			case "void":
				r = FFI.@void;
				break;
			default:
			  raise(c, "Bad Return Type: %s".printf(rtype), out e);
			  return null;	
			}
			
			for (var i = 0; i < atypes.length; i++) {
				if (CallbackInfo.is_registered((string)atypes[i])) {
					JSUtils.debug("Have Callback as argtype");
				
					a[i] = FFI.pointer;
				} else {
				
					switch ((string)FFIPointerBinder.resolve_type((string)atypes[i])) {
					case "string":
						a[i] = FFI.pointer;
						break;
						
					case "pointer":
						a[i] = FFI.pointer;
						break;				
					
					case "int32":
						a[i] = FFI.sint32;
						break;
					
					default:
						JSUtils.debug("INVOKE: 001");
						raise(c, "Bad Type for arg_types[%d].".printf(i), out e);
						return null;
					}
				}
			}
		
			JSUtils.debug("Prep cif");
		
			FFI.call_interface.prepare(out cif, FFI.ABI.DEFAULT, r, a);
			
			void*[] pargs = new void*[args.length];
			string?[] str_args = new string?[0];
			int?[] int_args    = new int?[0];
			void*[] ptr_args   = new void*[0];
			
			//JSUtils.debug_state = true;
			
			for (var i=0; i < args.length; i++) {
				if (CallbackInfo.is_registered((string)atypes[i])) {
					if (value_type(args[i]) != ValueType.OBJECT || ObjectType.from_object(c, (JSCore.Object)args[i]) != ObjectType.FUNCTION) {
						raise(c, "Expect Proc/Function as argument %d".printf(i), out e);
						return null;
					}
					
					JSUtils.debug("Create with CallbackInfo: %s".printf((string)atypes[i]));
					
					var cb = CallbackInfo.get_callback((string)atypes[i]);
					
					ptr_args += new FFIClosure(cb.args_types.length, new Data(default_context ?? c, pointer_binder , self, (JSCore.Object)args[i], cb), (args, data) => {								
						var ret = ((Data)data).call(args);
						
						JSUtils.debug("ClosureCallback: 001 - %s".printf(((Data)data).info.rtype));
						
						switch (((Data)data).info.rtype) {
						case "pointer":
						  return (void*)((int)(double)((JSUtils.Object)ret).get_prop(((Data)data).c, "address")).to_pointer();
						case "string":
						  return (void*)(string)ret;
						case "int32":
						  return (void*)(int)(double)ret;
						case "bool":
						  JSUtils.debug("ClosureCallback: 002 return bool");
						  return (void*)(bool)ret;
						}
						
						return null;
						
					}).closure;

					pargs[i] = &ptr_args[ptr_args.length-1];
				
				} else {
					switch ((string)atypes[i]) {
					case "string":
						str_args += (string?)args[i];
						pargs[i] = &str_args[str_args.length-1];
						JSUtils.debug("INVOKE: 802");
						break;
					
					case "pointer":
						if (value_type(args[i]) == ValueType.OBJECT && ObjectType.from_object(c, (JSCore.Object)args[i]) == ObjectType.FUNCTION) {
							// does not process return, args types
							// 
							// returns null; 
							
							JSUtils.debug("CLOSURE: 001");
							
							ptr_args += new FFIClosure(0, new Data(default_context ?? c, pointer_binder, self, (JSCore.Object)args[i]), (args, data) => {								
								((Data)data).call(args);
								return (void*)null;
							}).closure;

							pargs[i] = &ptr_args[ptr_args.length-1];
							
							break;
						}
						
						
					
						if (args[i] == null) {
							ptr_args += ((int)0).to_pointer();
							pargs[i] = &ptr_args[ptr_args.length-1];
							
							break;
						}
					
						var ptr = ((JSUtils.Object)args[i]).get_prop(c, "address");
						if (ptr != null) {
							ptr_args += ((int)(double)ptr).to_pointer();
							pargs[i] = &ptr_args[ptr_args.length-1];
						} else {
							JSUtils.debug("FUCK:");
							ptr_args += ((int)0).to_pointer();
							pargs[i] = &ptr_args[ptr_args.length-1];
						}
						break;			
					
					case "int32":
						int_args += (int)(double)args[i];
						pargs[i] = (void*)int_args[int_args.length-1];
						break;
					
					 default:
					   raise(c, "Bad type for parameter at args_types[%d]".printf(i), out e);
					   return null;
					}	
				}
			}		
			
			GLib.Value? result;
			call_cif(cif, func, rtype, pargs, out result);
			JSUtils.debug("INVOKE: 999");
			return result;
		}
		
		public void call_cif(FFI.call_interface cif, void* func, string rt, owned void*[] args, out GLib.Value? v) {	
			string? rtype = FFIPointerBinder.resolve_type(rt);
			if (rtype == null) {
				// TODO:
				//raise(c, "BadReturnType - Can not resolve type: `%s`".printf(rt), out e);
				return;
			}
			
			
			switch (rtype) {
			case "string":
				string o;
				JSUtils.debug("CALL: 001");
				cif.call<string*>(func, out o, args);
				JSUtils.debug("CALL: 002");

				
				v = (string)o;
				return;
				
			case "pointer":
				void* o;
				JSUtils.debug("CALL: 001");
				cif.call<void*>(func, out o, args);
				JSUtils.debug("CALL: 002");
				
				v = (int)o;

				
				return;			

			case "bool":
				bool i;
				JSUtils.debug("CALL: bool");
				cif.call<bool>(func, out i, args);
				
				
				v = i;
				return;	
				
			case "int32":
				int i = 44;
				JSUtils.debug("CALL: 003");
				cif.call<int>(func, out i, args);
				JSUtils.debug("CALL: 004 - %d".printf(i));

				
				v = i;
				return;	
				
			case "void":
				void* o = null;
				JSUtils.debug("CALL: 005 - %d".printf(args.length));
				cif.call<void*>(func, out o, args);
				JSUtils.debug("CALL: 006");

				
				v = null;
				return;				
					
			default:
				return;
			} 
		}
		
		public FFIPointerBinder? pointer_binder;	
		public FFIFuncBinder() {
			base("Func", new FFIFuncBinderKlass());
			
			pointer_binder = new FFIPointerBinder();
			
			bind("invoke", (self, args, c, out e) => {
				JSUtils.debug("FUNC_INVOKE: 001");
				
				unowned JSUtils.Object ins = (JSUtils.Object)self;
				
				string module = (string)ins.get_prop(c, "module");
				string symbol = (string)ins.get_prop(c, "symbol");
				string rtype  = (string)ins.get_prop(c, "return_type");
				
				JSUtils.debug("FUNC_INVOKE: 002 - %s".printf( symbol));
				
				GLib.Value?[] atypes = jsary2vary(c, (JSCore.Object)ins.get_prop(c, "args_types"));
				
				JSUtils.debug("FUNC_INVOKE: 003");
				
				GLib.Value? result = invoke(c, self, module, symbol, rtype, atypes, args, out e); 
				
				JSUtils.debug("FUNC_INVOKE: 999");
				
				if (rtype == "pointer") {
					var obj = new JSUtils.Object((JSUtils.Context)c, pointer_binder.js_class);
					obj.set_prop(c, "address", result);
					
					result = obj;
				}
				
				return result;
			});
			
			close();
			
			constructor((instance, args, c, out e)=>{
				init_object(instance, args, c, out e);	
			});
		}
		
		public static weak JSCore.Object? init_object(JSCore.Object? iobj, GLib.Value?[] args, JSCore.Context c, out JSCore.Value e) {
			JSUtils.debug("FUNC: 001");
		
			if (args.length != 4) {
				raise(c, "FFIFunc.new Expects exactly 4 arguments.", out e);
				return null;
			}
		
			weak JSCore.Object? instance;		
				
			if (iobj == null) {
				var u  = new JSCore.Object(c, (JSCore.Class?)typeof(FFIFuncBinder).get_qdata(Quark.from_string("jsclass")), null);
				instance = u;
				GLib.Value v = typeof(FFIFuncBinder).name();
				((JSUtils.Object)instance).set_prop(c, "binder", v);
						
			} else {
				instance = iobj;
			}
				
			unowned JSUtils.Object obj = (JSUtils.Object)instance;
			
			ValueType?[] types = {ValueType.STRING, ValueType.STRING, ValueType.STRING, ValueType.OBJECT};
			
			var idx = check_args(args, types);
			
			JSUtils.debug("FC 001");
			
			if (idx != null) {
				raise(c, "Expected %s for parameter %d (have %s (%s))".printf(types[(int)idx].to_string(), idx, value_type(args[(int)idx]).to_string(), object_to_string(c,(JSCore.Object)args[(int)idx])), out e);
				return null;
			}
			
			if (ObjectType.from_object(c, (JSCore.Object)args[3]) != ObjectType.ARRAY) {
				raise(c, "Expected Array for parameter 4", out e);
				return null;
			}
			
			var rtype = FFIPointerBinder.resolve_type((string)args[2]);
			if (rtype == null) {
				raise(c, "BadReturnType - Can not resolve type: `%s`".printf((string)args[2]), out e);
				return null;
			}
			
			JSUtils.debug("FC 002");
			
			
			var atypes = jsary2vary(c, (JSCore.Object)args[3]);
			types = new ValueType?[atypes.length];
			
			JSUtils.debug("FC 003");
			
			for (var i = 0; i < atypes.length; i++) {
				types[i] = ValueType.STRING;
			}
			
			idx = check_args(atypes, types);
			
			JSUtils.debug("FC 004");
			
			if (idx != null) {
				raise(c, "Expects <String|Symbol> as value in arg_types[%d]".printf(idx), out e);
				return null;
			}
			
			for (int i=0;i < atypes.length; i++) {
				if (FFIPointerBinder.resolve_type((string)atypes[i]) == null ) {
					raise(c, "BadParamType: Cannot resolve type `%s` at args_type[%d]".printf((string)atypes[i],i), out e);
					return null;
				}
			}
			
			obj.set_prop(c, "module",      args[0]);
			obj.set_prop(c, "symbol",      args[1]);
			obj.set_prop(c, "return_type", args[2]);
			obj.set_prop(c, "args_types",  args[3]);


			JSUtils.debug("FUNC: 999");
			
			return instance;		
		}
	}
	
	public static JSUtils.LibInfo? init(Context c) {
		//debug_state = true;
		var ffi = new JSCore.Object(c, null,null); 
		ffi.protect(c);
		
		var top = (JSUtils.Object)c.get_global_object();
		top.set_prop(c, "FFI", ffi);
		
		var func = new FFIFuncBinder();
		func.default_context = c;
		
		c.retain();
		
		unowned JSCore.Object uo_ffi = ffi;
		
		func.set_constructor_on(c, uo_ffi);
		func.pointer_binder.set_constructor_on(c, uo_ffi);
		
		JSUtils.LibInfo? ret = new JSUtils.LibInfo();
		ret.interfaces = {func, func.pointer_binder};
		ret.iface = "FFI";
		
		return ret;
	}
}
