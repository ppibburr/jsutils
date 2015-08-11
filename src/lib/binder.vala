
namespace JSUtils {
	// JS Functions will invoke the `func` member
	// via a map in the <Binder>'s 'qdata' with the function/this Object's 'binder' or 'static_binder' property as the key
	//
	// Other fields exist for information when invoking or generating ruby code to bridge to the native function
	public class BoundFunction {
		public Binder.bound_function func;
		public string name;
		public int n_args = -1;
		public ValueType?[] atypes;
		public string[]? anames;
		public BoundFunction(string n, int n_args, ValueType?[] atypes = null, string[]? anames = null, Binder.bound_function func) {
			this.func = func;
			this.name = n;
			this.n_args = n_args;
			this.atypes = atypes;
			this.anames = anames;
		}
	}

	// Determines loading/bridging techniques
	public enum BinderType {
		CLASS,
		MODULE;
	}		
	
	// Simple API to extend the JavaScript Runtime
	// 
	// Provides a JSCore.Class at member 'jsclass'
	public class Binder {
		// Retrieves a BoundFunction of name from Type binder's qdata map
		public static BoundFunction? get_binding(string binder, string name) {
			var type = Type.from_name(binder);
			
			if (type == Type.INVALID) {
				return null;
			}
			
			var BoundFunction = ((Gee.HashMap<string, BoundFunction>)type.get_qdata(Quark.from_string("map")));
			
			return BoundFunction[name];
		}
	   
		// Ensures that the map exists on Type target's qdata 
		public static void ensure_init(Binder target) {
			if ((Gee.HashMap<string, BoundFunction>?)Type.from_instance(target).get_qdata(Quark.from_string("map")) == null) {
				Type.from_instance(target).set_qdata(Quark.from_string("map"), new Gee.HashMap<string, BoundFunction>());
			}
		}				
		
		// BEGIN argument utils
		
		// Returns the last JSCore.Value in args as JSCore.Object or null if the value is not a function
		public static unowned JSCore.Object? get_cb(JSCore.Context c, GLib.Value?[] args) {
			if (args.length == 0) {
				return null;
			}
			
			if (value_type(args[args.length-1]) == ValueType.OBJECT) {
				unowned JSCore.Object? o = (JSCore.Object?)args[args.length-1];
				
				if (ObjectType.from_object(c, o) == ObjectType.FUNCTION) {
					return o;
				}
			}
			
			return null;
		}
		
		// Returns null if all arguments are of the proper ValueType, else returns the index of the first non-conforming argument
		// @param args  The arguments to check
		// @param types The corresponding ValueType's
		public static int? check_args(GLib.Value?[] args, ValueType?[] types) {
			int i = 0;
			
			foreach(var a in args) {
				if (value_type(a) != types[i]) {
					return i;
				}
				
				i++;
			}
			
			return null;
		}
		
		// END argument utils			
					
		
		// The closure type passed to aBinder#bind			
		public delegate GLib.Value? bound_function(JSCore.Object self, GLib.Value?[] args, JSCore.Context c, out JSCore.Value e);			

		// The closure type passed to aBinder#initializer 
		public delegate void i_cb(JSCore.Context c, JSCore.Object o);

		// The closute type passed to aBinder#finalizer
		public delegate void f_cb(JSCore.Object o);	

		// The closure type passed to aBinder#constructor 
		public delegate void c_cb(JSCore.Object instance, GLib.Value?[] args, JSCore.Context c, out JSCore.Value err);				
		
		// Module or Class
		public BinderType type = BinderType.CLASS;			

		// Store of the generated JSCore.StaticFunction's
		public JSCore.StaticFunction[] static_functions {get; private set;}

		// The definition we will be initializing
		public JSCore.ClassDefinition definition;

		// The resulting class (available after invoking 'close()')
		public JSCore.Class js_class;

		// The prototype (static members)
		public Binder? prototype;

		// The 'instance' members
		public Binder? target;
		
		public Binder(string class_name, Binder? prototype = null) {
			this.definition = JSCore.ClassDefinition();
			this.definition.className = class_name;
			this.prototype = prototype;
			
			if (prototype != null) {
				prototype.target = this;
			}
			
			
		}
		
		// Creates the JSClass ans sets up static delegate to instance callbacks mapping
		public void close() {
			ensure_init(this);
			
			var sf = new JSCore.StaticFunction[static_functions.length+1];
			
			for (var i = 0; i < static_functions.length; i++) {
				sf[i] = static_functions[i];
			}
			
			this.definition.staticFunctions = (JSCore.StaticFunction*)sf;
		
			this.js_class = new JSCore.Class(ref definition);
		
			Type.from_instance(this).set_qdata(Quark.from_string("jsclass"), this.js_class);
		}
		
		public virtual void bind(string name, bound_function cb, int n_args = -1, ValueType?[] atypes = null, string[]? anames = null) {
			set_binding(name, n_args, atypes, anames, cb);
			
			var sfun = JSCore.StaticFunction() {
				name = name,
				attributes = JSCore.PropertyAttribute.ReadOnly,
				
			
				
				callAsFunction = (c, fun, self, a, out e) => {
					
					//print("Hahaha\n");
					var static_binder = v2str(((JSUtils.Object)self).get_prop(c, "static_binder"));
					var tname         = v2str(((JSUtils.Object)fun).get_prop(c, "name"));
					var binder        = v2str(((JSUtils.Object)self).get_prop(c, "binder"));
					//print("EOHahaha\n");
					
					var args = new GLib.Value?[0];
					foreach (unowned JSCore.ConstValue v in a) {
						args += jval2gval(c, (JSCore.Value)v, out e);
					}								
							
					JSUtils.debug("bound_static_function: static_binder - %s, binder - %s, func_name - %s".printf(static_binder, binder, tname));
					var func = get_binding(binder, tname) ?? get_binding(static_binder, tname);
					
					if (func.n_args != -1 && a.length > func.n_args) {
						raise(c, "Too many arguments passed to %s, %d for %d".printf(func.name, a.length, func.n_args), out e);
						return null;
					}
					
					if (func.n_args != -1 && a.length < func.n_args) {
						raise(c, "Too few arguments passed to %s, %d for %d".printf(func.name, a.length, func.n_args), out e);
						return null;
					}	
					
					if (func.n_args > 0) {
						if (func.atypes != null) {
							int? idx = check_args(args, func.atypes);
							
							if (idx != null ) {
								raise(c, "ArgumentError: argument %d expects %s".printf(idx+1, func.anames != null ? func.anames[(int)idx] : func.atypes[(int)idx].to_string()), out e);
								return null;
							} 
						}
					}						
					
					if (e != null) {
						return new JSCore.Value.null(c);
					}
				
					GLib.Value? val = func.func(self, args, c, out e);

					JSCore.Value jv = gval2jval(c, val);
					
					return jv;
				}
			};
			
			_static_functions += sfun;	
		}
		
		
		public void set_binding(string n, int n_args = -1, ValueType?[] atypes = null, string[]? anames = null, bound_function cb) {
			ensure_init(this);
			var BoundFunction = new BoundFunction(n, n_args, atypes, anames, cb);
			((Gee.HashMap<string, BoundFunction>)Type.from_instance(this).get_qdata(Quark.from_string("map")))[n] = BoundFunction;
		}
		
		
		public void initializer(i_cb cb) {
			
		}
		
		public void finalizer(f_cb cb) {
			
		}
		
		public void constructor(c_cb cb) {
			Type.from_instance(this).set_qdata(Quark.from_string("constructor"),(void*) cb);
		}
		
		public JSCore.Object set_constructor_on(JSCore.Context c, JSCore.Object? where) {
			debug("SET_CONSTRUCT: 001");

			 
			
			var con = (JSUtils.Object)new JSCore.Object.constructor(c, this.js_class, (ctx, self, args, out e)=>{
				var type_name = v2str(((JSUtils.Object)self).get_prop(ctx, "binder"));
				
				unowned JSCore.Class jc = (JSCore.Class)Type.from_name(type_name).get_qdata(Quark.from_string("jsclass"));
				Binder.c_cb? cb = (Binder.c_cb?)Type.from_name(type_name).get_qdata(Quark.from_string("constructor"));
		
				var obj = new JSUtils.Object(ctx, jc, null);
				
				obj.set_prop(ctx, "binder", type_name);			
				
				if (cb != null) {
					GLib.Value?[] vary = new GLib.Value?[0];
					
					foreach (unowned JSCore.Value v in args) {
						vary += jval2gval(ctx, v, out e);
					}				
					
					cb(obj, vary, ctx, out e);
				}
				
				
				
				return obj;
			});
			
			Type.from_instance(this).set_qdata(Quark.from_string("jsconstructor"), (void*)con);
			
			GLib.Value? type_name = Type.from_instance(this).name();
			
			con.set_prop(c, "binder",  type_name);	
			
			((JSUtils.Object)where).set_prop(c, this.definition.className, con.to_gval());
				
			if (prototype != null) {
				prototype.set_as_prototype(c, con);
			}	
			
			debug("SET_CONSTRUCT: 002");
			return con;
		}
		
		public JSCore.Object create_toplevel_module(JSCore.Context c) {
			var o = (JSUtils.Object)c.get_global_object();
			
			return create_module(c, o);
		}
		
		public JSCore.Object create_module(JSCore.Context c, JSCore.Object where) {
			
			var m = new JSUtils.Object(c, this.js_class, null);
			
			GLib.Value v = Type.from_instance(this).name();
			
			m.set_prop(c, "static_binder", v);
			//m.set_prop(c, "binder", v);
								
			((JSUtils.Object)where).set_prop(c, this.definition.className, m.to_gval());
		
			return m;
		}
		
		public void set_as_prototype(JSCore.Context c, JSCore.Object obj) {
				var p = new JSUtils.Object(c, this.js_class, null);
				GLib.Value? pt_type_name = Type.from_instance(this).name();

				p.set_prop(c, "binder", pt_type_name);	
				((JSUtils.Object)obj).set_prop(c, "static_binder", pt_type_name);	
				
				obj.set_prototype(c, p);				
		} 
		
		public void init_global(JSCore.Context c) {
			GLib.Value? val = Type.from_instance(this).name();
			
			((JSUtils.Object)c.get_global_object()).set_prop(c, "binder", val);
		
			set_constructor_on(c, null);
		}
		
	}
}
